extends SceneTree


func _initialize() -> void:
	root.hide()
	call_deferred("_run")


func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1400, 1100)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var scene := load("res://scenes/main.tscn").instantiate() as Node2D
	viewport.add_child(scene)
	await process_frame
	var buildings := scene.get_node("Buildings")
	for building in buildings.get_children():
		building.free()
	var map: VillageMap = scene.get_node("VillageMap")
	for x in range(16, 23):
		map.place_wall(Vector2i(x, 16))
		map.place_wall(Vector2i(x, 22))
	for y in range(17, 22):
		map.place_wall(Vector2i(16, y))
		map.place_wall(Vector2i(22, y))
	for cell in [Vector2i(19, 15), Vector2i(19, 14), Vector2i(19, 17), Vector2i(19, 18), Vector2i(21, 19), Vector2i(20, 19), Vector2i(15, 15)]:
		map.place_wall(cell)
	var camera: Camera2D = scene.get_node("MapCamera")
	camera.global_position = map.grid_to_world(Vector2(19, 18.5))
	camera.zoom = Vector2.ONE * 1.4
	camera.force_update_scroll()
	for i in range(4):
		await process_frame
	RenderingServer.force_draw(false)
	var image := viewport.get_texture().get_image()
	if image == null or image.is_empty():
		push_error("No image was rendered for the palisade preview")
		quit(1)
		return
	var result := image.save_png("res://docs/palisade-preview.png")
	print("Palisade scene preview: ", result)
	quit(0 if result == OK else 1)
