extends SceneTree

const FPS := 30
const FOLDER := "res://.godot/tower_3d_preview"
var projectiles: Array[ArrowProjectile] = []


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
	for frame in range(4):
		await process_frame
	var army: ArmyManager = scene.get_node("ArmyManager")
	army.set_process(false)
	for worker in scene.get_node("BuilderManager").workers:
		worker.set_process(false)
	assert(army.train_archer())
	army.advance_training(10.0)
	var unit := army.archers[0]
	unit.set_process(false)
	var tower := VillageBuilding.new()
	tower.building_type = "defense_tower"
	tower.cell = Vector2i(18, 24)
	scene.get_node("Buildings").add_child(tower)
	assert(army.station_archer(tower))
	unit.arrow_fired.connect(func(projectile: ArrowProjectile) -> void:
		projectile.set_physics_process(false)
		projectiles.append(projectile)
	)
	var camera: Camera2D = scene.get_node("MapCamera")
	var zoom := camera.zoom
	var camera_position := camera.global_position
	DirAccess.make_dir_recursive_absolute(FOLDER)
	var crop_origin := tower.get_global_transform_with_canvas().origin
	var manifest := {"fps": FPS, "camera_zoom": [zoom.x, zoom.y], "tower_screen_origin": [crop_origin.x, crop_origin.y]}
	var file := FileAccess.open(FOLDER + "/capture.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest, "\t"))
	file.close()
	var frame_index := 0
	var quick := "--quick" in OS.get_cmdline_user_args()
	# Eight directions, at normal speed; all poses are sampled from the real unit clock.
	for facing in ([1, 5] if quick else range(8)):
		var angle: float = facing * PI / 4.0
		unit.shoot_at(unit.global_position + Vector2(cos(angle), sin(angle) * 0.75) * 250.0)
		for sample in range(36):
			await _capture(viewport, unit, frame_index, 1.0 / FPS)
			frame_index += 1
		assert(camera.zoom == zoom and camera.global_position == camera_position)
		print("3D tower capture: direction %d, frame %d" % [facing, frame_index])
	# Half speed at 30 distinct samples/s, without duplicated video frames.
	for facing in ([] if quick else [1, 5]):
		var angle: float = facing * PI / 4.0
		unit.shoot_at(unit.global_position + Vector2(cos(angle), sin(angle) * 0.75) * 250.0)
		for sample in range(66):
			await _capture(viewport, unit, frame_index, 0.5 / FPS)
			frame_index += 1
	assert(army.return_archer_from_tower(tower))
	for sample in range(30):
		await _capture(viewport, unit, frame_index, 1.0 / FPS)
		frame_index += 1
	print("3D tower capture: %d actual gameplay frames at 30 FPS" % frame_index)
	quit()


func _capture(viewport: SubViewport, unit: ArcherUnit, index: int, delta: float) -> void:
	unit.advance_behavior(delta)
	for projectile in projectiles:
		if is_instance_valid(projectile) and not projectile.is_queued_for_deletion():
			projectile.advance_flight(delta)
	await process_frame
	RenderingServer.force_draw(false)
	assert(viewport.get_texture().get_image().save_png("%s/frame_%04d.png" % [FOLDER, index]) == OK)
	if index == 0:
		var visual := unit.stationed_building._tower_visual
		assert(visual.get_texture().get_image().save_png(FOLDER + "/tower.png") == OK)
