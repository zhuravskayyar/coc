extends SceneTree


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
	await process_frame
	for frame in range(4):
		await process_frame
	var manager: BuilderManager = scene.get_node("BuilderManager")
	var builder: BuilderUnit = manager.workers[0]
	for worker in manager.workers:
		worker.set_process(false)
	assert(builder.begin_wander(), "The builder can leave its hut")
	var sprite: Sprite2D = builder.get_node("Sprite")
	var map: VillageMap = scene.get_node("VillageMap")
	var camera: Camera2D = scene.get_node("MapCamera")
	assert(sprite.texture != null, "The builder sprite is imported")
	assert(sprite.texture.get_image().get_pixel(0, 0).a == 0.0, "The builder has a transparent background")
	assert(map.is_walkable_cell(map.world_to_cell(map.to_local(builder.global_position))), "The builder stands outside occupied building cells")
	var anchor := Vector2(128, 193.401)
	assert((sprite.offset + anchor).is_zero_approx(), "The sprite ground anchor coincides with the unit origin")
	assert(scene.get_node("Buildings").get_child_count() == 7 and map.get_occupied_cells().size() == 76, "Adding the unit preserves the existing building layout")
	await _capture(viewport, "res://docs/builder-village-preview.png")
	camera.zoom = Vector2.ONE * 1.25
	camera.global_position = builder.global_position + Vector2(70, 20)
	camera.force_update_scroll()
	await _capture(viewport, "res://docs/builder-close-preview.png")
	var building := (scene.get_node("VillageEconomy") as VillageEconomy).start_building(&"gold_storage", Vector2i(30, 14))
	assert(building != null, "Construction starts with an available builder")
	building.set_process(false)
	var worker := manager.worker_for(building)
	for tick in range(700):
		worker.advance_behavior(0.05)
		if worker.state == BuilderUnit.State.HAMMERING and worker._site_side in [0, 1]:
			break
	assert(worker.state == BuilderUnit.State.HAMMERING, "The builder has arrived and is hammering")
	worker.advance_behavior(0.42)
	camera.global_position = building.global_position + Vector2(30, -20)
	camera.force_update_scroll()
	await _capture(viewport, "res://docs/builder-working-preview.png")
	print("Builder import, transparent sprite, ground anchor and village placement: passed")
	quit()


func _capture(viewport: SubViewport, path: String) -> void:
	for frame in range(8):
		await process_frame
	RenderingServer.force_draw(false)
	var error := viewport.get_texture().get_image().save_png(path)
	assert(error == OK, "Could not save builder preview")
	print("Builder preview: %s" % path)
