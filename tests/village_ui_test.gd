extends SceneTree

var failures := 0
var checks := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var scene := load("res://scenes/main.tscn").instantiate() as Node2D
	root.add_child(scene)
	await _settle()
	var hud: VillageHUD = scene.get_node("UI/VillageHUD")
	var interaction: VillageInteraction = scene.get_node("VillageInteraction")
	var map: VillageMap = scene.get_node("VillageMap")
	var tent: VillageBuilding = scene.get_node("Buildings/WarTent")
	var camera: Camera2D = scene.get_node("MapCamera")
	_check(not hud.has_modal() and not hud._selection_panel.visible, "Village starts with an unobstructed map")
	await _click(hud._build.get_global_rect().get_center())
	_check(hud.has_modal(), "Build button opens the catalog through viewport input")
	_check(hud._catalog_grid.get_child_count() == 2, "Army category shows the two existing army buildings")
	var camera_before := camera.global_position
	await _click(hud._modal_panel.get_global_rect().get_center())
	_check(hud.has_modal() and camera.global_position == camera_before and interaction.selected == null, "Modal input does not select or move the village underneath")
	hud._select_category("Ресурси")
	await _settle()
	_check(hud._catalog_grid.get_child_count() == 2, "Resources use the two existing gold assets")
	hud._select_category("Оборона")
	await _settle()
	_check(hud._catalog_grid.get_child_count() == 1, "Defense catalog exposes the existing palisade")
	hud._select_category("Інше")
	await _settle()
	_check(hud._catalog_grid.get_child_count() == 2, "Other category includes the temple and builder hut")
	hud.close_modal()
	var selected_screen := map.get_global_transform_with_canvas() * map.get_footprint_center(tent.cell, tent.get_footprint())
	await _click(selected_screen)
	_check(interaction.selected == tent and hud._selection_panel.visible, "Clicking the tent selects it and opens its action panel")
	var original_cell := tent.cell
	interaction.begin_placement(&"war_tent", tent)
	_check(not map.placement_grid.is_cell_blocked(tent.cell) and map.is_cell_occupied(tent.cell), "Moving footprint is available in the preview without freeing real occupancy")
	interaction.set_placement_screen_position(map.get_global_transform_with_canvas() * map.cell_to_world(Vector2i(20, 20)))
	_check(not interaction.placement_valid and hud._confirm.disabled, "Occupied footprints disable confirmation")
	await _click(map.get_global_transform_with_canvas() * map.cell_to_world(Vector2i(20, 20)))
	_check(interaction.is_placing() and tent.cell == original_cell, "Clicking an occupied footprint cannot move a building")
	interaction.set_placement_screen_position(map.get_global_transform_with_canvas() * map.cell_to_world(Vector2i(31, 19)))
	_check(interaction.placement_valid, "Empty footprint is accepted by the shared grid")
	await _click(hud._confirm.get_global_rect().get_center())
	_check(tent.cell == Vector2i(31, 19) and not interaction.is_placing(), "Confirmation moves the building without following the pointer into the HUD")
	_check(not map.is_cell_occupied(original_cell) and map.is_cell_occupied(tent.cell), "Movement updates the existing occupancy grid")
	interaction.begin_placement(&"war_tent", tent)
	interaction.set_placement_screen_position(map.get_global_transform_with_canvas() * map.cell_to_world(Vector2i(35, 19)))
	await _click_button(hud._placement_panel, "Скасувати")
	_check(tent.cell == Vector2i(31, 19), "Cancel leaves the original placement untouched")
	_check(hud._selection_panel.visible and hud._selection_content.get_child_count() > 0, "Cancel restores the populated building action panel")
	var count := scene.get_node("Buildings").get_child_count()
	await _click(hud._build.get_global_rect().get_center())
	await _click(hud._category_buttons[2].get_global_rect().get_center())
	await _click_button(hud._catalog_grid.get_child(1), "Розмістити")
	_check(interaction.placing_type == &"gold_storage" and not hud.has_modal(), "Mouse selects a building from the catalog")
	var construction_point := map.get_global_transform_with_canvas() * map.cell_to_world(Vector2i(30, 14))
	await _hover(construction_point)
	_check(scene.get_node("Buildings").get_child_count() == count, "Hover previews without constructing")
	await _click(construction_point)
	_check(not interaction.is_placing() and interaction.selected.building_type == "gold_storage", "Map click places the preview without Enter or a confirmation button")
	_check(scene.get_node("Buildings").get_child_count() == count + 1 and map.is_cell_occupied(Vector2i(30, 14)), "Construction registers the clicked building footprint exactly once")
	# Move through the action button, then confirm directly on the map too.
	# Close the taller construction panel before selecting the tent beneath it.
	await _click(hud._selection_content.get_child(0).get_child(1).get_global_rect().get_center())
	await _click(map.get_global_transform_with_canvas() * map.get_footprint_center(tent.cell, tent.get_footprint()))
	_check(interaction.selected == tent, "Selecting the moved tent still targets it beside a construction site")
	await _click_button(hud._selection_panel, "Перемістити")
	# Keep this map click beside the resized bottom action panel.
	await _click(map.get_global_transform_with_canvas() * map.cell_to_world(Vector2i(35, 17)))
	_check(tent.cell == Vector2i(35, 17) and not interaction.is_placing(), "Mouse-only movement places at the clicked cell")
	# Repeated palisade construction and erasing need no W, Shift or Esc.
	await _click(hud._build.get_global_rect().get_center())
	await _click(hud._category_buttons[1].get_global_rect().get_center())
	await _click_button(hud._catalog_grid.get_child(0), "Розмістити")
	var walls := map.get_node("WallPlacement")
	_check(walls.enabled and hud._wall_panel.visible, "Mouse opens the existing palisade tool from the catalog")
	var wall_cell := Vector2i(18, 17)
	var wall_point := map.get_global_transform_with_canvas() * map.cell_to_world(wall_cell)
	var neighbor_point := map.get_global_transform_with_canvas() * map.cell_to_world(wall_cell + Vector2i.RIGHT)
	var economy: VillageEconomy = scene.get_node("VillageEconomy")
	var gold_before_walls := economy.gold
	await _click(wall_point)
	await _click(neighbor_point)
	_check(economy.gold == gold_before_walls - 50, "Mouse-built wall sections charge their gold cost through the economy")
	_check(map.is_cell_occupied(wall_cell) and map.is_cell_occupied(wall_cell + Vector2i.RIGHT) and walls.enabled, "Successive clicks place connected palisade sections")
	_check(map.get_wall_connection_mask(wall_cell) == 2, "Mouse-built palisade preserves connection logic")
	await _click(hud._wall_erase.get_global_rect().get_center())
	await _click(wall_point)
	_check(not map.is_cell_occupied(wall_cell) and map.get_wall_connection_mask(wall_cell + Vector2i.RIGHT) == 0, "Erase button removes a section and refreshes its neighbor without Shift")
	await _click(map.get_global_transform_with_canvas() * map.cell_to_world(Vector2i(20, 20)))
	_check(map.is_cell_occupied(Vector2i(20, 20)), "Palisade erase mode cannot remove other buildings")
	await _click(hud._wall_place.get_global_rect().get_center())
	await _click(wall_point)
	_check(map.is_cell_occupied(wall_cell) and not walls.erase_mode, "Place button restores palisade construction")
	await _tap(map.get_global_transform_with_canvas() * map.cell_to_world(wall_cell + Vector2i(2, 0)))
	_check(map.is_cell_occupied(wall_cell + Vector2i(2, 0)) and camera._touches.is_empty(), "Catalog palisade still supports touch without stale camera state")
	await _click(hud._wall_done.get_global_rect().get_center())
	_check(not walls.enabled and not hud._wall_panel.visible and not map.placement_grid.visible, "Done button ends palisade mode without Esc")
	# Mouse wheel zoom and right-button panning remain usable.
	var zoom_before := camera.zoom.x
	var wheel := InputEventMouseButton.new()
	wheel.position = Vector2(640, 300)
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	root.push_input(wheel)
	_check(camera.zoom.x > zoom_before, "Mouse wheel zooms the map")
	var pan_before := camera.global_position
	var drag := InputEventMouseMotion.new()
	drag.position = Vector2(640, 300)
	drag.relative = Vector2(32, 14)
	drag.button_mask = MOUSE_BUTTON_MASK_RIGHT
	root.push_input(drag)
	_check(camera.global_position != pan_before, "Right mouse drag pans the map")
	# Touch selection must not leave the camera thinking a finger is still pressed.
	interaction.select_building(null)
	selected_screen = map.get_global_transform_with_canvas() * map.get_footprint_center(tent.cell, tent.get_footprint())
	var touch := InputEventScreenTouch.new()
	touch.position = selected_screen
	touch.pressed = true
	root.push_input(touch)
	touch = touch.duplicate()
	touch.pressed = false
	root.push_input(touch)
	await _settle()
	_check(interaction.selected == tent and camera._touches.is_empty(), "Tap selects and releases camera touch state")
	await _tap(hud._build.get_global_rect().get_center())
	_check(hud.has_modal(), "Touch opens the catalog with mouse emulation disabled")
	hud.close_modal()
	interaction.select_building(null)
	var first := InputEventScreenTouch.new()
	first.position = selected_screen
	first.pressed = true
	root.push_input(first)
	var second := first.duplicate() as InputEventScreenTouch
	second.index = 1
	second.position += Vector2(40, 0)
	root.push_input(second)
	first.pressed = false
	second.pressed = false
	root.push_input(first)
	root.push_input(second)
	_check(interaction.selected == null and camera._touches.is_empty(), "Two-finger gestures do not select buildings or leave stale camera touches")
	# Check common landscape and portrait sizes, including modal bounds.
	for dimensions in [Vector2i(1280, 720), Vector2i(960, 540), Vector2i(720, 1280)]:
		root.size = dimensions
		hud.show_catalog()
		await _settle()
		# Controls are in the logical viewport; Godot projects this to the window.
		var screen := Rect2(Vector2.ZERO, hud.get_viewport_rect().size)
		for control in [hud._profile, hud._builder, hud._resources, hud._utility, hud._attack, hud._build, hud._navigation, hud._modal_panel]:
			_check(screen.encloses(control.get_global_rect()), "UI remains within %s: %s" % [dimensions, control.get_class()])
		_check(not hud._builder.get_global_rect().intersects(hud._profile.get_global_rect()) and not hud._builder.get_global_rect().intersects(hud._resources.get_global_rect()), "Top HUD panels don't overlap at %s" % dimensions)
		_check(not hud._navigation.get_global_rect().intersects(hud._attack.get_global_rect()) and not hud._navigation.get_global_rect().intersects(hud._build.get_global_rect()), "Bottom navigation doesn't overlap at %s" % dimensions)
		hud.close_modal()
	print("Village UI checks: %d passed, %d failed" % [checks - failures, failures])
	quit(1 if failures else 0)


func _settle() -> void:
	for frame in range(4):
		await process_frame


func _click(position: Vector2) -> void:
	var press := InputEventMouseButton.new()
	press.position = position
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	root.push_input(press)
	var release := press.duplicate() as InputEventMouseButton
	release.pressed = false
	root.push_input(release)
	await _settle()


func _tap(position: Vector2) -> void:
	var press := InputEventScreenTouch.new()
	press.position = position
	press.pressed = true
	root.push_input(press)
	var release := press.duplicate() as InputEventScreenTouch
	release.pressed = false
	root.push_input(release)
	await _settle()


func _hover(position: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = position
	root.push_input(motion)
	await _settle()


func _click_button(parent: Node, title: String) -> void:
	for node in parent.find_children("*", "Button", true, false):
		var button := node as Button
		if button.text == title:
			await _click(button.get_global_rect().get_center())
			return
	_check(false, "Button not found: %s" % title)


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)
