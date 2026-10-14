class_name VillageInteraction
extends Node2D

signal selection_changed(building: VillageBuilding)
signal placement_changed(active: bool, valid: bool)

@onready var village_map: VillageMap = $"../VillageMap"
@onready var buildings: Node2D = $"../Buildings"
@onready var wall_placement: Node2D = $"../VillageMap/WallPlacement"
@onready var economy: VillageEconomy = $"../VillageEconomy"

var selected: VillageBuilding
var placing_type := StringName()
var moving: VillageBuilding
var placement_cell := Vector2i(-1, -1)
var placement_valid := false
var _touch_start := Vector2.ZERO
var _touch_dragged := false
var _active_touches: Dictionary[int, bool] = {}
var _preview_texture: Texture2D
var _preview_anchor := Vector2.ZERO
var _preview_scale := 1.0
var _preview_tower: Tower3DVisual
var _preview_palisade: Palisade3DVisual


func _ready() -> void:
	z_index = 45
	set_process(false)
	economy.changed.connect(_on_economy_changed)


func _on_economy_changed() -> void:
	if is_placing():
		_update_validity()


func select_building(building: VillageBuilding) -> void:
	selected = building
	selection_changed.emit(selected)
	queue_redraw()


func begin_placement(building_type: StringName, building: VillageBuilding = null) -> void:
	if is_instance_valid(building) and building.is_under_construction():
		return
	cancel_placement()
	wall_placement.set_enabled(false)
	placing_type = building_type
	moving = building
	selected = building
	selection_changed.emit(selected)
	placement_cell = building.cell if building != null else Vector2i(17, 16)
	var definition := BuildingCatalog.get_visual_definition(building_type)
	if building_type == &"wall":
		_refresh_palisade_preview()
	elif definition.has("model"):
		_preview_tower = Tower3DVisual.new()
		add_child(_preview_tower)
		_preview_tower.configure_ground_width(BuildingCatalog.get_footprint(building_type).x * VillageMap.TILE_SIZE.x)
		_preview_texture = _preview_tower.get_texture()
		_preview_anchor = _preview_tower.ground_anchor
		_preview_scale = _preview_tower.draw_scale
	else:
		_preview_texture = load(definition["texture"]) as Texture2D if definition.has("texture") else null
	if _preview_texture != null and not definition.has("model"):
		var source_width := float(definition["source_ground_width"])
		_preview_anchor = VillageBuilding._get_source_ground_anchor(_preview_texture, source_width)
		_preview_scale = BuildingCatalog.get_footprint(building_type).x * VillageMap.TILE_SIZE.x / source_width
	village_map.show_placement_grid()
	if moving != null:
		var blocked := village_map.get_occupied_cells()
		var footprint := moving.get_footprint()
		for row in range(footprint.y):
			for column in range(footprint.x):
				blocked.erase(moving.cell + Vector2i(column, row))
		village_map.placement_grid.set_blocked_cells(blocked)
	_update_validity()
	set_process(true)
	queue_redraw()


func is_placing() -> bool:
	return not placing_type.is_empty()


func confirm_placement() -> bool:
	if not is_placing() or not village_map.can_place_building(placing_type, placement_cell, moving):
		return false
	var building := moving
	if building != null:
		building.cell = placement_cell
	else:
		building = economy.start_building(placing_type, placement_cell)
		if building == null:
			_update_validity()
			return false
	cancel_placement()
	select_building(building)
	return true


func cancel_placement() -> void:
	placing_type = StringName()
	moving = null
	_preview_texture = null
	_preview_palisade = null
	if is_instance_valid(_preview_tower):
		_preview_tower.queue_free()
		_preview_tower = null
	set_process(false)
	if is_instance_valid(village_map):
		village_map.hide_placement_grid()
	placement_changed.emit(false, false)
	queue_redraw()


func set_placement_screen_position(screen_position: Vector2) -> void:
	var local_position := village_map.get_global_transform_with_canvas().affine_inverse() * screen_position
	placement_cell = village_map.world_to_cell(local_position)
	if placing_type == &"wall":
		_refresh_palisade_preview()
	_update_validity()
	queue_redraw()


func _refresh_palisade_preview() -> void:
	var mask := village_map.get_wall_connection_mask(placement_cell, moving)
	_preview_palisade = Palisade3DVisual.get_shared_visual(mask, true)
	if not is_instance_valid(_preview_palisade):
		_preview_texture = null
		return
	_preview_texture = _preview_palisade.get_texture()
	_preview_anchor = _preview_palisade.ground_anchor
	_preview_scale = _preview_palisade.draw_scale


func _update_validity() -> void:
	placement_valid = village_map.can_place_building(placing_type, placement_cell, moving)
	if moving == null:
		placement_valid = placement_valid and economy.get_build_error(placing_type).is_empty()
	placement_changed.emit(true, placement_valid)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_W:
			cancel_placement()
			select_building(null)
			# Leave W to the existing palisade controller.
			return
		if event.keycode == KEY_ESCAPE:
			if is_placing():
				cancel_placement()
			elif selected != null:
				select_building(null)
			else:
				return
			get_viewport().set_input_as_handled()
			return
		if is_placing() and event.keycode == KEY_ENTER:
			confirm_placement()
			get_viewport().set_input_as_handled()
			return
	if wall_placement.enabled and not (event is InputEventScreenTouch or event is InputEventScreenDrag):
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			if _active_touches.is_empty():
				_touch_start = event.position
				_touch_dragged = false
			_active_touches[event.index] = true
			if _active_touches.size() > 1:
				_touch_dragged = true
		else:
			if _active_touches.has(event.index) and not _touch_dragged:
				# Let the camera receive release too, so its touch state is cleared.
				_handle_map_click(event.position, false)
			_active_touches.erase(event.index)
	elif event is InputEventScreenDrag:
		if event.position.distance_to(_touch_start) > 12.0:
			_touch_dragged = true
		if is_placing() and _active_touches.size() == 1:
			set_placement_screen_position(event.position)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_handle_map_click(event.position)
	elif is_placing() and event is InputEventMouseMotion and event.button_mask == 0:
		# HUD controls consume their own pointer events; the preview stays on the map.
		set_placement_screen_position(event.position)


func _handle_map_click(screen_position: Vector2, consume: bool = true) -> void:
	if wall_placement.enabled:
		wall_placement.edit_at_screen_position(screen_position, wall_placement.erase_mode)
	elif is_placing():
		set_placement_screen_position(screen_position)
		confirm_placement()
	else:
		var world_position := get_canvas_transform().affine_inverse() * screen_position
		var hit: VillageBuilding
		# Check visible art as well as the footprint, from front to back.
		for child in buildings.get_children():
			if not child is VillageBuilding:
				continue
			var building := child as VillageBuilding
			var polygon := village_map.get_footprint_polygon(building.cell, building.get_footprint())
			var in_footprint := Geometry2D.is_point_in_polygon(village_map.to_local(world_position), polygon)
			var in_sprite := building.hit_test_visual(building.to_local(world_position))
			if (in_footprint or in_sprite) and (hit == null or building.global_position.y > hit.global_position.y):
				hit = building
		select_building(hit)
	if consume:
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	# Redraw when the camera pans or zooms while positioning a building.
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_active_touches.clear()
		_touch_dragged = false


func _draw() -> void:
	if not is_instance_valid(village_map):
		return
	if is_placing():
		var footprint := BuildingCatalog.get_footprint(placing_type)
		var polygon := village_map.get_footprint_polygon(placement_cell, footprint)
		var tint := Color("9ab96a") if placement_valid else Color("d76751")
		if _preview_texture != null:
			var center := village_map.get_footprint_center(placement_cell, footprint)
			var rect := Rect2(center - _preview_anchor * _preview_scale, Vector2(_preview_texture.get_size()) * _preview_scale)
			draw_texture_rect(_preview_texture, rect, false, Color(1, 1, 1, 0.7))
		# Keep placement validity visible above the building visual.
		draw_colored_polygon(polygon, Color(tint, 0.2))
		polygon.append(polygon[0])
		var canvas_scale := village_map.get_global_transform_with_canvas().get_scale().x
		draw_polyline(polygon, tint, 3.0 / canvas_scale, true)
	elif is_instance_valid(selected):
		var polygon := village_map.get_footprint_polygon(selected.cell, selected.get_footprint())
		polygon.append(polygon[0])
		draw_polyline(polygon, Color("f1dca0"), 3.0, true)
