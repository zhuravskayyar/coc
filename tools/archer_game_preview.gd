extends SceneTree

const FPS := 30
const SHOT_FRAMES := 60
const INITIAL_IDLE_FRAMES := 30
const WALK_FRAMES := 105
const RUN_FRAMES := 105
const RECOVERY_IDLE_FRAMES := 30
const TOTAL_FRAMES := INITIAL_IDLE_FRAMES + WALK_FRAMES + RUN_FRAMES + RECOVERY_IDLE_FRAMES + SHOT_FRAMES * 2
const FOLDER := "res://.godot/archer_game_preview_v2"
var projectiles: Array[ArrowProjectile] = []
var release_events: Array[Dictionary] = []
var capture_frame := 0


func _initialize() -> void:
	root.hide()
	call_deferred("_run")


func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(960, 540)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var scene := load("res://scenes/main.tscn").instantiate() as Node2D
	viewport.add_child(scene)
	for frame in range(5):
		await process_frame
	var army: ArmyManager = scene.get_node("ArmyManager")
	army.set_process(false)
	for worker in scene.get_node("BuilderManager").workers:
		worker.set_process(false)
	assert(army.train_archer())
	army.advance_training(10.0)
	var archer := army.archers[0]
	archer.set_process(false)
	archer._path.clear()
	archer._wait = 1000.0
	var camera: Camera2D = scene.get_node("MapCamera")
	var map: VillageMap = scene.get_node("VillageMap")
	# Pick a clear existing navigation route inside the unchanged camera view.
	var route := _find_preview_route(map, viewport)
	assert(route.size() == 11, "Preview needs ten clear navigation steps")
	archer._cell = route[0]
	archer.global_position = archer._world(archer._cell)
	archer.facing = 1 if route[-1].x > route[0].x else 3
	archer.set_animation(&"idle")
	archer._finish_locomotion_blend()
	var camera_zoom := camera.zoom
	var camera_position := camera.global_position
	print("Archer capture uses actual scene camera: zoom=%s position=%s; UI visible=%s" % [camera_zoom, camera_position, scene.get_node("UI").visible])
	archer.arrow_fired.connect(_on_arrow_fired)
	DirAccess.make_dir_recursive_absolute(FOLDER)
	var records: Array[Dictionary] = []
	var route_cells: Array[Array] = []
	for cell in route:
		route_cells.append([cell.x, cell.y])
	var walk_count := 0
	var run_count := 0
	var walk_distance := 0.0
	var run_distance := 0.0
	var walk_start := INITIAL_IDLE_FRAMES
	var run_start := walk_start + WALK_FRAMES
	var idle_start := run_start + RUN_FRAMES
	var shot_start := idle_start + RECOVERY_IDLE_FRAMES
	for index in range(TOTAL_FRAMES):
		capture_frame = index
		if index == walk_start:
			archer.follow_path(route)
		elif index == run_start:
			# Continue the same real route from the current position; no pose or position reset.
			archer.follow_path(archer._path, true)
		elif index == idle_start:
			assert(archer._path.is_empty(), "Navigation reaches its destination before recovery idle")
			archer._wait = 1000.0
		elif index == shot_start or index == shot_start + SHOT_FRAMES:
			var facing := 1 if index == shot_start else 5
			var angle := facing * PI / 4.0
			archer.shoot_at(archer.global_position + Vector2(cos(angle), sin(angle) * 0.75) * 240)
		var old_position := archer.global_position
		var old_animation := archer.animation
		archer.advance_behavior(1.0 / FPS)
		if old_animation == &"walk":
			walk_count += 1
			walk_distance += old_position.distance_to(archer.global_position)
		elif old_animation == &"run":
			run_count += 1
			run_distance += old_position.distance_to(archer.global_position)
		for projectile in projectiles:
			if is_instance_valid(projectile) and not projectile.is_queued_for_deletion():
				projectile.advance_flight(1.0 / FPS)
		await process_frame
		RenderingServer.force_draw(false)
		assert(camera.zoom == camera_zoom and camera.global_position == camera_position, "Capture must keep the actual gameplay camera")
		var screen_position := archer.get_global_transform_with_canvas().origin
		var sprite_rect := _screen_rect(archer.sprite)
		records.append({
			"index": index,
			"time_seconds": float(index + 1) / FPS,
			"animation": String(archer.animation),
			"facing": archer.facing,
			"animation_time": archer._animation_time,
			"animation_frame": archer.sprite.frame,
			"blend_active": archer.sprite.material != null,
			"world_position": [archer.global_position.x, archer.global_position.y],
			"screen_position": [screen_position.x, screen_position.y],
			"sprite_screen_rect": [sprite_rect.position.x, sprite_rect.position.y, sprite_rect.size.x, sprite_rect.size.y],
		})
		var error := viewport.get_texture().get_image().save_png("%s/frame_%04d.png" % [FOLDER, index])
		assert(error == OK, "Frame PNG must save")
		if index % FPS == 0:
			print("Archer capture frame %s/%s, %s" % [index, TOTAL_FRAMES, archer.animation])
	assert(walk_count >= FPS * 3 and run_count >= FPS * 3, "Both real movement clips must run for at least three seconds")
	assert(release_events.size() == 2, "Both opposed shots must release exactly once")
	var metadata := {
		"fps": FPS,
		"frame_count": TOTAL_FRAMES,
		"viewport_size": [viewport.size.x, viewport.size.y],
		"camera_zoom": [camera_zoom.x, camera_zoom.y],
		"camera_position": [camera_position.x, camera_position.y],
		"ui_visible": scene.get_node("UI").visible,
		"route_cells": route_cells,
		"movement": {
			"walk": {"frames": walk_count, "distance_pixels": walk_distance},
			"run": {"frames": run_count, "distance_pixels": run_distance},
		},
		"segments": [
			{"label": "Idle", "first_frame": 0, "last_frame": walk_start - 1},
			{"label": "Idle to Walk, normal navigation", "first_frame": walk_start, "last_frame": run_start - 1},
			{"label": "Walk to Run, same route and foot phase", "first_frame": run_start, "last_frame": idle_start - 1},
			{"label": "Run to Idle, destination reached", "first_frame": idle_start, "last_frame": shot_start - 1},
			{"label": "Attack SE", "first_frame": shot_start, "last_frame": shot_start + SHOT_FRAMES - 1},
			{"label": "Attack NW", "first_frame": shot_start + SHOT_FRAMES, "last_frame": TOTAL_FRAMES - 1},
		],
		"frames": records,
		"release_events": release_events,
	}
	var metadata_file := FileAccess.open("%s/capture.json" % FOLDER, FileAccess.WRITE)
	assert(metadata_file != null, "Capture metadata must save")
	metadata_file.store_string(JSON.stringify(metadata, "\t"))
	metadata_file.close()
	print("Archer in-game capture: %d frames at 30 FPS; Walk %.2fs, Run %.2fs; Idle/Walk/Run transitions and two opposed shots; camera zoom=%s" % [TOTAL_FRAMES, float(walk_count) / FPS, float(run_count) / FPS, camera_zoom])
	quit()


func _find_preview_route(map: VillageMap, viewport: SubViewport) -> Array[Vector2i]:
	var best: Array[Vector2i] = []
	var best_score := INF
	# Stay between the normal HUD bars and away from building overhangs.
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
						break
					for row in range(-2, 3):
						for column in range(-2, 3):
							if map.is_cell_occupied(cell + Vector2i(column, row)):
								clear = false
					if not clear:
						break
				if not clear:
					continue
				var route := map.find_cell_path(start, finish)
				if route.size() != 11:
					continue
				var midpoint := map.get_global_transform_with_canvas() * ((map.cell_to_world(start) + map.cell_to_world(finish)) * 0.5)
				var score := midpoint.distance_squared_to(Vector2(viewport.size) * 0.5)
				if score < best_score:
					best_score = score
					best = route
	return best


func _screen_rect(item: Sprite2D) -> Rect2:
	var rect := item.get_rect()
	var transform := item.get_global_transform_with_canvas()
	var result := Rect2(transform * rect.position, Vector2.ZERO)
	for point in [Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
		result = result.expand(transform * point)
	return result


func _on_arrow_fired(projectile: ArrowProjectile) -> void:
	projectile.set_physics_process(false)
	projectiles.append(projectile)
	var screen_position := projectile.get_global_transform_with_canvas().origin
	release_events.append({
		"frame": capture_frame,
		"world_position": [projectile.global_position.x, projectile.global_position.y],
		"screen_position": [screen_position.x, screen_position.y],
		"direction": [projectile.direction.x, projectile.direction.y],
	})
