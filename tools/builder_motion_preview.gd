extends SceneTree

const FRAME_RATE := 30
const CAPTURE_SECONDS := 36


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
	for frame in range(6):
		await process_frame
	scene.get_node("UI").hide()
	var manager: BuilderManager = scene.get_node("BuilderManager")
	var economy: VillageEconomy = scene.get_node("VillageEconomy")
	var camera: Camera2D = scene.get_node("MapCamera")
	for worker in manager.workers:
		worker.set_process(false)
		worker._wait = 100.0
	var building := economy.start_building(&"gold_storage", Vector2i(30, 14))
	building.set_process(false)
	var worker := manager.worker_for(building)
	camera.zoom = Vector2.ONE * 0.83
	camera.global_position = Vector2(480, -25)
	camera.force_update_scroll()
	var folder := "res://.godot/builder_motion_preview"
	DirAccess.make_dir_recursive_absolute(folder)
	var worked_sides: Array[int] = []
	var saw_run := false
	var saw_hammer := false
	for index in range(FRAME_RATE * CAPTURE_SECONDS):
		worker.advance_behavior(1.0 / FRAME_RATE)
		building.advance_construction(1.0 / FRAME_RATE)
		if worker.animation == &"run":
			saw_run = true
		if worker.animation == &"hammer":
			saw_hammer = true
			if not worked_sides.has(worker._site_side):
				worked_sides.append(worker._site_side)
		await process_frame
		RenderingServer.force_draw(false)
		viewport.get_texture().get_image().save_png("%s/frame_%03d.png" % [folder, index])
	assert(saw_run and saw_hammer and worked_sides.size() >= 2, "The real timed construction runs, hammers and changes sides")
	assert(worker.state == BuilderUnit.State.HOME and not worker.visible, "The worker returns home after the actual timer ends")
	print("Builder motion preview: %d frames, timed work from %d sides, return home verified" % [FRAME_RATE * CAPTURE_SECONDS, worked_sides.size()])
	quit()
