extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := load("res://scenes/main.tscn").instantiate() as Node2D
	root.add_child(scene)
	var hud: VillageHUD = scene.get_node("UI/VillageHUD")
	var interaction: VillageInteraction = scene.get_node("VillageInteraction")
	if "--portrait" in OS.get_cmdline_user_args():
		await _capture("res://docs/ui-portrait-preview.png")
		hud.show_catalog()
		await _capture("res://docs/ui-portrait-build-preview.png")
		quit()
		return
	await _capture("res://docs/ui-village-preview.png")
	interaction.select_building(scene.get_node("Buildings/WarTent"))
	await _capture("res://docs/ui-building-preview.png")
	interaction.begin_placement(&"war_tent", scene.get_node("Buildings/WarTent"))
	var map: VillageMap = scene.get_node("VillageMap")
	interaction.set_placement_screen_position(map.get_global_transform_with_canvas() * map.cell_to_world(Vector2i(30, 19)))
	await _capture("res://docs/ui-placement-preview.png")
	interaction.cancel_placement()
	hud.show_catalog()
	await _capture("res://docs/ui-build-preview.png")
	hud.close_modal()
	hud._show_army()
	await _capture("res://docs/ui-army-preview.png")
	hud._start_building(&"wall")
	await _capture("res://docs/ui-wall-controls-preview.png")
	quit()


func _capture(path: String) -> void:
	for frame in range(8):
		await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(path)
	if error != OK:
		push_error("Could not save UI preview: %s" % path)
	else:
		print("UI preview: %s" % path)
