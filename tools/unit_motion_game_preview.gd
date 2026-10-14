extends SceneTree

const FPS := 30
const FOLDER := "res://.godot/unit_motion/game"
var arrows: Array[ArrowProjectile] = []
var release_count := 0


func _initialize() -> void:
	root.hide()
	call_deferred("_run")


func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var scene := load("res://scenes/main.tscn").instantiate() as Node2D
	viewport.add_child(scene)
	for frame in range(6):
		await process_frame
	var army: ArmyManager = scene.get_node("ArmyManager")
	var economy: VillageEconomy = scene.get_node("VillageEconomy")
	var manager: BuilderManager = scene.get_node("BuilderManager")
	var map: VillageMap = scene.get_node("VillageMap")
	var camera: Camera2D = scene.get_node("MapCamera")
	var camera_zoom := camera.zoom
	var camera_position := camera.global_position
	army.set_process(false)
	for worker in manager.workers:
		worker.set_process(false)
		worker._wait = 1000
	assert(army.train_archer() and army.train_militia())
	army.advance_training(20.0)
	var archer := army.archers[0]
	var militia := army.soldiers[0]
	archer.set_process(false)
	militia.set_process(false)
	var route := _find_route(map, viewport)
	assert(route.size() == 11)
	var parallel_start := route[0] + Vector2i(1, -1)
	var parallel_end := route[-1] + Vector2i(1, -1)
	var parallel := map.find_cell_path(parallel_start, parallel_end)
	if parallel.size() < 2:
		parallel_start = route[0] + Vector2i(-1, 1)
		parallel_end = route[-1] + Vector2i(-1, 1)
		parallel = map.find_cell_path(parallel_start, parallel_end)
	assert(parallel.size() >= 2)
	_prepare(archer, route[0])
	_prepare(militia, parallel[0])
	archer.arrow_fired.connect(func(projectile: ArrowProjectile) -> void:
		projectile.set_physics_process(false)
		arrows.append(projectile)
		release_count += 1
	)
	var building := economy.start_building(&"gold_storage", Vector2i(30, 14))
	assert(building != null)
	building.set_process(false)
	var builder := manager.worker_for(building)
	assert(builder != null)
	var tower := VillageBuilding.new()
	tower.building_type = "defense_tower"
	tower.cell = Vector2i(18, 24)
	scene.get_node("Buildings").add_child(tower)
	var sides: Array[int] = []
	var saw_run := false
	var saw_hammer := false
	DirAccess.make_dir_recursive_absolute(FOLDER)
	for frame in range(1080):
		if frame == 30:
			archer.follow_path(route)
			militia.follow_path(parallel)
		elif frame == 135:
			archer.follow_path(archer._path, true)
			militia.follow_path(militia._path, true)
		elif frame == 270:
			archer._path.clear()
			militia._path.clear()
			archer._wait = 1000
			militia._wait = 1000
			archer.set_animation(&"idle")
			militia.set_animation(&"idle")
		elif frame in [300, 360]:
			archer.shoot_at(archer.global_position + Vector2(240, 180) * (1 if frame == 300 else -1))
			militia.attack_toward(militia.global_position + Vector2(240, 180) * (1 if frame == 300 else -1))
		elif frame == 420:
			assert(army.station_archer(tower))
		elif frame in [450, 510]:
			archer.shoot_at(archer.global_position + Vector2(240, 180) * (1 if frame == 450 else -1))
		elif frame == 570:
			assert(army.return_archer_from_tower(tower))
		archer.advance_behavior(1.0 / FPS)
		militia.advance_behavior(1.0 / FPS)
		builder.advance_behavior(1.0 / FPS)
		building.advance_construction(1.0 / FPS)
		saw_run = saw_run or builder.animation == &"run"
		if builder.animation == &"hammer":
			saw_hammer = true
			if not sides.has(builder._site_side):
				sides.append(builder._site_side)
		for projectile in arrows:
			if is_instance_valid(projectile) and not projectile.is_queued_for_deletion():
				projectile.advance_flight(1.0 / FPS)
		await process_frame
		RenderingServer.force_draw(false)
		assert(camera.zoom == camera_zoom and camera.global_position == camera_position)
		assert(viewport.get_texture().get_image().save_png("%s/frame_%04d.png" % [FOLDER, frame]) == OK)
		if frame % 90 == 89:
			print("Gameplay frame %d/1080 / builder %s / arrows %d" % [frame + 1, builder.animation, release_count])
	assert(release_count == 4, "Every ground/tower shot releases exactly one arrow")
	assert(saw_run and saw_hammer and sides.size() >= 2, "Real construction runs, hammers and changes sides")
	assert(builder.state == BuilderUnit.State.HOME and not builder.visible, "Real worker returns home when construction finishes")
	print("Gameplay verified: 1080 real frames at 30 FPS; navigation, two ground shots, two live tower shots, construction and return home")
	quit()


func _prepare(unit: VillageUnit, cell: Vector2i) -> void:
	unit._cell = cell
	unit.global_position = unit._world(cell)
	unit._path.clear()
	unit._wait = 1000
	unit.set_animation(&"idle")


func _find_route(map: VillageMap, viewport: SubViewport) -> Array[Vector2i]:
	var best: Array[Vector2i] = []
	var score := INF
	var visible_area := Rect2(Vector2(80, 170), Vector2(viewport.size) - Vector2(160, 300))
	for y in range(2, VillageMap.BUILDABLE_SIZE - 2):
		for x in range(2, VillageMap.BUILDABLE_SIZE - 2):
			for direction in [Vector2i.RIGHT, Vector2i.DOWN]:
				var start := Vector2i(x, y)
				var finish: Vector2i = start + direction * 10
				if not map.is_buildable_cell(finish):
					continue
				var clear := true
				for step in range(11):
					var cell: Vector2i = start + direction * step
					var screen := map.get_global_transform_with_canvas() * map.cell_to_world(cell)
					if not map.is_walkable_cell(cell) or not visible_area.has_point(screen):
						clear = false
					for row in range(-2, 3):
						for column in range(-2, 3):
							if map.is_cell_occupied(cell + Vector2i(column, row)):
								clear = false
				if not clear:
					continue
				var route := map.find_cell_path(start, finish)
				if route.size() != 11:
					continue
				var middle := map.get_global_transform_with_canvas() * ((map.cell_to_world(start) + map.cell_to_world(finish)) * 0.5)
				var distance := middle.distance_squared_to(Vector2(viewport.size) * 0.5)
				if distance < score:
					score = distance
					best = route
	return best
