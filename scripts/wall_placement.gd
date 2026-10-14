extends Node2D

signal mode_changed(active: bool, erasing: bool)

var enabled := false
var erase_mode := false
var _hover_cell := Vector2i(-1, -1)
var _hover_mask := -1
var _placeable := false
var _erasing := false
var _hint: Label
var _preview_visual: Palisade3DVisual
@onready var village_map: VillageMap = get_parent()


func _ready() -> void:
	_hint = Label.new()
	_hint.name = "WallPlacementHint"
	_hint.text = "Частокіл · Клік — поставити · Shift + клік — прибрати · Esc — завершити"
	_hint.position = Vector2(16, 16)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.add_theme_color_override("font_shadow_color", Color.BLACK)
	_hint.add_theme_constant_override("shadow_offset_x", 1)
	_hint.add_theme_constant_override("shadow_offset_y", 1)
	_hint.hide()
	village_map.get_parent().get_node("UI").add_child(_hint)
	set_process(false)


func set_enabled(value: bool) -> void:
	enabled = value
	if enabled and not is_instance_valid(_preview_visual):
		_preview_visual = Palisade3DVisual.get_shared_visual(maxi(_hover_mask, 0), true)
	_hint.visible = enabled
	set_process(enabled)
	if enabled:
		village_map.show_placement_grid()
	else:
		village_map.hide_placement_grid()
	mode_changed.emit(enabled, erase_mode)
	queue_redraw()


func set_erase_mode(value: bool) -> void:
	erase_mode = value
	mode_changed.emit(enabled, erase_mode)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_W:
			set_enabled(not enabled)
			get_viewport().set_input_as_handled()
		elif enabled and event.keycode == KEY_ESCAPE:
			set_enabled(false)
			get_viewport().set_input_as_handled()
	elif enabled and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		edit_at_screen_position(event.position, erase_mode or event.shift_pressed)
		get_viewport().set_input_as_handled()


func edit_at_screen_position(screen_position: Vector2, erasing: bool) -> void:
	var local_position := village_map.get_global_transform_with_canvas().affine_inverse() * screen_position
	var cell := village_map.world_to_cell(local_position)
	if erasing:
		village_map.remove_wall(cell)
	else:
		var economy := village_map.get_parent().get_node("VillageEconomy") as VillageEconomy
		economy.start_building(&"wall", cell)
	queue_redraw()


func _process(_delta: float) -> void:
	var cell := village_map.world_to_cell(village_map.get_local_mouse_position())
	var mask := village_map.get_wall_connection_mask(cell)
	var economy := village_map.get_parent().get_node("VillageEconomy") as VillageEconomy
	var placeable := village_map.can_place_building(&"wall", cell) and economy.get_build_error(&"wall").is_empty()
	var erasing := erase_mode or Input.is_key_pressed(KEY_SHIFT)
	if cell != _hover_cell or mask != _hover_mask or placeable != _placeable or erasing != _erasing:
		_hover_cell = cell
		_hover_mask = mask
		_placeable = placeable
		_erasing = erasing
		_preview_visual = Palisade3DVisual.get_shared_visual(mask, true)
		queue_redraw()


func _draw() -> void:
	if not enabled or not village_map.is_buildable_cell(_hover_cell):
		return
	var outline := village_map.get_cell_polygon(_hover_cell)
	outline.append(outline[0])
	var color := Color(0.45, 1.0, 0.55) if _placeable and not _erasing else Color(1.0, 0.3, 0.25)
	draw_polyline(outline, color, 2.0, true)
	if not _placeable or _erasing:
		return
	if not is_instance_valid(_preview_visual):
		return
	var rect := _preview_visual.get_draw_rect()
	rect.position += village_map.cell_to_world(_hover_cell)
	draw_texture_rect(_preview_visual.get_texture(), rect, false, Color(1, 1, 1, 0.55))
