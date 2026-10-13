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
	var economy: VillageEconomy = scene.get_node("VillageEconomy")
	var map: VillageMap = scene.get_node("VillageMap")
	var hud: VillageHUD = scene.get_node("UI/VillageHUD")
	var interaction: VillageInteraction = scene.get_node("VillageInteraction")
	var camera: Camera2D = scene.get_node("MapCamera")
	var hut := economy.start_building(&"builder_hut", Vector2i(26, 14))
	var camp := economy.start_building(&"unit_camp", Vector2i(29, 14))
	hut.set_process(false)
	camp.set_process(false)
	camera.global_position = map.get_footprint_center(camp.cell, camp.get_footprint()) + Vector2(-150, -50)
	camera.zoom = Vector2.ONE * 1.0
	camera.force_update_scroll()
	interaction.select_building(null)
	await _capture(viewport, "res://docs/construction-start-preview.png")
	hut.advance_construction(7.5)
	camp.advance_construction(15.0)
	await _capture(viewport, "res://docs/construction-progress-preview.png")
	interaction.select_building(camp)
	await _capture(viewport, "res://docs/construction-selection-preview.png")
	interaction.select_building(null)
	hut.advance_construction(7.5)
	camp.advance_construction(15.0)
	await _capture(viewport, "res://docs/construction-finished-preview.png")
	hud.show_catalog()
	hud._select_category("Ресурси")
	await _capture(viewport, "res://docs/construction-catalog-preview.png")
	quit()


func _capture(viewport: SubViewport, path: String) -> void:
	for frame in range(6):
		await process_frame
	RenderingServer.force_draw(false)
	var error := viewport.get_texture().get_image().save_png(path)
	if error != OK:
		push_error("Could not save construction preview: %s" % path)
	else:
		print("Construction preview: %s" % path)
