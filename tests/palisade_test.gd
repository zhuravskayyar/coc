extends SceneTree

var failures := 0
var checks := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := load("res://scenes/main.tscn").instantiate() as Node2D
	root.add_child(scene)
	await process_frame
	var map: VillageMap = scene.get_node("VillageMap")
	var origin := Vector2i(5, 5)
	for mask in range(16):
		var center := map.place_wall(origin)
		_check(center != null, "The central wall can be placed")
		for i in range(4):
			if mask & (1 << i):
				var neighbor := map.place_wall(origin + BuildingCatalog.WALL_DIRECTIONS[i])
				_check(neighbor != null, "Every requested neighbor can be placed")
				_check(neighbor.wall_connection_mask == 1 << ((i + 2) % 4), "A neighbor connects back to the central wall")
		_check(center.wall_connection_mask == mask, "All sixteen connection masks select the expected topology: %d" % mask)
		_check(center._texture != null, "Every topology has a real imported sprite")
		_check(center._texture.resource_path.ends_with("mask_%02d_v2.png" % mask), "Sprite selection matches the actual neighbor mask")
		_check(center.get_footprint() == Vector2i.ONE, "Every connection variant occupies one cell")
		_check(not map.is_walkable_cell(origin), "A wall blocks walking through its own cell")
		_check(map.place_wall(origin) == null, "A second wall cannot overlap the first")
		for i in range(4):
			if mask & (1 << i):
				_check(map.remove_wall(origin + BuildingCatalog.WALL_DIRECTIONS[i]), "Connected walls can be removed")
		_check(center.wall_connection_mask == 0, "Removing neighbors restores the isolated pole")
		_check(map.remove_wall(origin), "The central wall can be removed")
		_check(map.is_walkable_cell(origin), "Removal releases its navigation cell immediately")
		await process_frame
	var first := map.place_wall(origin)
	var second := map.place_wall(origin + Vector2i.RIGHT)
	_check(first.wall_connection_mask == 2 and second.wall_connection_mask == 8, "A two-cell row has two facing end pieces")
	first.cell = origin + Vector2i(2, 0)
	_check(first.wall_connection_mask == 8 and second.wall_connection_mask == 2, "Moving a wall updates both its old and new neighboring directions")
	_check(not map.is_cell_occupied(origin), "Moving a wall frees its old cell")
	first.free()
	_check(second.wall_connection_mask == 0, "Deleting a wall directly updates its neighbor")
	map.remove_wall(second.cell)
	await process_frame
	var diagonal_a := map.place_wall(Vector2i(8, 8))
	var diagonal_b := map.place_wall(Vector2i(9, 9))
	_check(diagonal_a.wall_connection_mask == 0 and diagonal_b.wall_connection_mask == 0, "Diagonal cells do not connect")
	map.remove_wall(diagonal_a.cell)
	map.remove_wall(diagonal_b.cell)
	_check(map.place_wall(Vector2i(-1, 0)) == null, "Walls cannot be placed outside the map")
	_check(map.place_wall(Vector2i(44, 43)) == null, "The far edge is also rejected")
	var edge := map.place_wall(Vector2i(0, 0))
	_check(edge != null and edge.wall_connection_mask == 0, "The boundary does not invent outside neighbors")
	map.remove_wall(edge.cell)
	var temple: VillageBuilding = scene.get_node("Buildings/Temple")
	_check(map.place_wall(temple.cell) == null, "Walls cannot overlap an existing building")
	_check(not map.remove_wall(temple.cell), "The wall eraser cannot delete other buildings")
	var nearby := map.place_wall(Vector2i(19, 20))
	_check(nearby != null and nearby.wall_connection_mask == 0, "An adjacent temple is not treated as another wall")
	map.remove_wall(nearby.cell)
	await process_frame
	var controller = map.get_node("WallPlacement")
	var camera: Camera2D = scene.get_node("MapCamera")
	camera.zoom = Vector2.ONE
	camera.global_position = map.cell_to_world(origin)
	camera.force_update_scroll()
	var key := InputEventKey.new()
	key.physical_keycode = KEY_W
	key.pressed = true
	root.push_input(key)
	_check(controller.enabled and map.placement_grid.visible, "W enables wall placement and the existing placement grid")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = map.get_global_transform_with_canvas() * map.cell_to_world(origin)
	root.push_input(click, true)
	_check(map.is_cell_occupied(origin), "A real viewport click places a wall at its projected grid cell")
	click = click.duplicate()
	click.shift_pressed = true
	root.push_input(click, true)
	_check(not map.is_cell_occupied(origin), "Shift-click removes the clicked wall")
	for zoom in [0.45, 1.8]:
		camera.zoom = Vector2.ONE * zoom
		camera.global_position = map.cell_to_world(origin + Vector2i(1, 0))
		camera.force_update_scroll()
		click = InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		click.position = map.get_global_transform_with_canvas() * map.cell_to_world(origin)
		root.push_input(click, true)
		_check(map.is_cell_occupied(origin), "Placement follows the camera projection at zoom %s" % zoom)
		click = click.duplicate()
		click.shift_pressed = true
		root.push_input(click, true)
		_check(not map.is_cell_occupied(origin), "Removal follows the camera projection at zoom %s" % zoom)
	key = InputEventKey.new()
	key.keycode = KEY_ESCAPE
	key.pressed = true
	root.push_input(key)
	_check(not controller.enabled and not map.placement_grid.visible, "Escape closes placement and its grid")
	await process_frame
	_check(map.get_occupied_cells().size() == 76, "The initial village is unchanged after all placement tests")
	print("Palisade checks: %d passed, %d failed" % [checks - failures, failures])
	quit(1 if failures else 0)


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)
