@tool
class_name VillageMap
extends Node2D

const BUILDABLE_SIZE := 44
const BORDER_SIZE := 3
const TOTAL_SIZE := BUILDABLE_SIZE + BORDER_SIZE * 2
const TILE_SIZE := Vector2(96.0, 72.0)

const GRASS_LIGHT: Texture2D = preload("res://assets/sprites/grass_light.png")
const GRASS_DARK: Texture2D = preload("res://assets/sprites/grass_dark.png")
const GRASS_FRAME: Texture2D = preload("res://assets/sprites/grass_frame.png")
const FRAME_TOP_Y := 112.0
const FRAME_BOTTOM_Y := 1088.0
const FRAME_SIDE_DEPTH := 52.0

@onready var grass_frame: GrassBorderTiles = $GrassFrame
@onready var playable_grass: GrassFieldTiles = $PlayableGrass
@onready var placement_grid: PlacementGridOverlay = $PlacementGridOverlay

var _buildings: Array[VillageBuilding] = []
var _occupied_cells: Dictionary[Vector2i, VillageBuilding] = {}
var _navigation := AStarGrid2D.new()


func _ready() -> void:
	var grass_material := playable_grass.material as ShaderMaterial
	grass_material.set_shader_parameter("grass_texture", GRASS_LIGHT)
	var border_material := grass_frame.material as ShaderMaterial
	border_material.set_shader_parameter("grass_texture", GRASS_LIGHT)
	border_material.set_shader_parameter("grass_tint", grass_material.get_shader_parameter("grass_tint"))
	border_material.set_shader_parameter("checker_darkening", grass_material.get_shader_parameter("checker_darkening"))
	grass_frame.queue_redraw()
	playable_grass.queue_redraw()
	placement_grid.queue_redraw()
	rebuild_building_grid()


func cell_to_world(cell: Vector2i) -> Vector2:
	return grid_to_world(Vector2(cell))


func grid_to_world(cell: Vector2) -> Vector2:
	return Vector2(
		(cell.x - cell.y) * TILE_SIZE.x * 0.5,
		(cell.x + cell.y - (BUILDABLE_SIZE - 1)) * TILE_SIZE.y * 0.5
	)


func world_to_cell(world_position: Vector2) -> Vector2i:
	var column_minus_row := world_position.x / (TILE_SIZE.x * 0.5)
	var column_plus_row := world_position.y / (TILE_SIZE.y * 0.5) + BUILDABLE_SIZE - 1
	return Vector2i(
		floori((column_plus_row + column_minus_row) * 0.5 + 0.5),
		floori((column_plus_row - column_minus_row) * 0.5 + 0.5)
	)


func is_buildable_cell(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < BUILDABLE_SIZE and cell.y < BUILDABLE_SIZE


func get_cell_polygon(cell: Vector2i) -> PackedVector2Array:
	return get_footprint_polygon(cell, Vector2i.ONE)


func get_footprint_center(origin: Vector2i, footprint: Vector2i) -> Vector2:
	return grid_to_world(Vector2(origin) + Vector2(footprint - Vector2i.ONE) * 0.5)


func get_footprint_polygon(origin: Vector2i, footprint: Vector2i, margin: float = 0.0) -> PackedVector2Array:
	var first := Vector2(origin) - Vector2.ONE * (0.5 + margin)
	var last := Vector2(origin + footprint) - Vector2.ONE * (0.5 - margin)
	return PackedVector2Array([
		grid_to_world(first),
		grid_to_world(Vector2(last.x, first.y)),
		grid_to_world(last),
		grid_to_world(Vector2(first.x, last.y)),
	])


func get_playable_polygon() -> PackedVector2Array:
	var half_size := TILE_SIZE * BUILDABLE_SIZE * 0.5
	return PackedVector2Array([
		Vector2(0.0, -half_size.y),
		Vector2(half_size.x, 0.0),
		Vector2(0.0, half_size.y),
		Vector2(-half_size.x, 0.0),
	])


func show_placement_grid(blocked_cells: Array[Vector2i] = []) -> void:
	var occupied := get_occupied_cells()
	occupied.append_array(blocked_cells)
	placement_grid.set_blocked_cells(occupied)
	placement_grid.show()


func hide_placement_grid() -> void:
	placement_grid.hide()


func get_map_rect() -> Rect2:
	var surface_size := TILE_SIZE * TOTAL_SIZE
	var side_depth := FRAME_SIDE_DEPTH * surface_size.y / (FRAME_BOTTOM_Y - FRAME_TOP_Y)
	return Rect2(-surface_size * 0.5, surface_size + Vector2(0.0, side_depth))


func register_building(building: VillageBuilding) -> void:
	if not _buildings.has(building):
		_buildings.append(building)
	rebuild_building_grid()


func unregister_building(building: VillageBuilding) -> void:
	_buildings.erase(building)
	if is_node_ready() and not is_queued_for_deletion():
		rebuild_building_grid()


func rebuild_building_grid() -> void:
	_occupied_cells.clear()
	_navigation.region = Rect2i(0, 0, BUILDABLE_SIZE, BUILDABLE_SIZE)
	_navigation.cell_size = Vector2.ONE
	_navigation.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	_navigation.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	_navigation.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	_navigation.update()
	# update() only resets solids when grid settings change.
	_navigation.fill_solid_region(_navigation.region, false)
	for building in _buildings:
		if not is_instance_valid(building):
			continue
		if not can_place_building(StringName(building.building_type), building.cell):
			push_error("Building %s is outside the grid or overlaps another building." % building.name)
			continue
		var footprint := building.get_footprint()
		for row in range(footprint.y):
			for column in range(footprint.x):
				var local_cell := Vector2i(column, row)
				var map_cell := building.cell + local_cell
				_occupied_cells[map_cell] = building
				_navigation.set_point_solid(map_cell, building.is_under_construction() or not BuildingCatalog.is_local_cell_walkable(StringName(building.building_type), local_cell))
	# Resolve connections only after all occupied cells have been rebuilt.
	for building in _buildings:
		if is_instance_valid(building) and building.building_type == "wall":
			building.refresh_wall_connections(get_wall_connection_mask(building.cell))
	if is_instance_valid(placement_grid) and placement_grid.visible:
		placement_grid.set_blocked_cells(get_occupied_cells())


func get_occupied_cells() -> Array[Vector2i]:
	return _occupied_cells.keys()


func get_wall_connection_mask(cell: Vector2i) -> int:
	var mask := 0
	for i in range(BuildingCatalog.WALL_DIRECTIONS.size()):
		var neighbor: VillageBuilding = _occupied_cells.get(cell + BuildingCatalog.WALL_DIRECTIONS[i])
		if is_instance_valid(neighbor) and neighbor.building_type == "wall":
			mask |= 1 << i
	return mask


func place_wall(cell: Vector2i) -> VillageBuilding:
	if not can_place_building(&"wall", cell):
		return null
	var buildings := get_parent().get_node_or_null("Buildings")
	if buildings == null:
		return null
	var wall := VillageBuilding.new()
	wall.name = "Wall_%d_%d" % [cell.x, cell.y]
	wall.building_type = "wall"
	wall.cell = cell
	buildings.add_child(wall)
	return wall


func remove_wall(cell: Vector2i) -> bool:
	var wall: VillageBuilding = _occupied_cells.get(cell)
	if not is_instance_valid(wall) or wall.building_type != "wall":
		return false
	unregister_building(wall)
	wall.queue_free()
	return true


func is_cell_occupied(cell: Vector2i) -> bool:
	return _occupied_cells.has(cell)


func get_building_at(cell: Vector2i) -> VillageBuilding:
	return _occupied_cells.get(cell)


func can_place_building(building_type: StringName, origin: Vector2i, ignored_building: VillageBuilding = null) -> bool:
	var footprint := BuildingCatalog.get_footprint(building_type)
	if footprint == Vector2i.ZERO:
		return false
	for row in range(footprint.y):
		for column in range(footprint.x):
			var cell := origin + Vector2i(column, row)
			if not is_buildable_cell(cell):
				return false
			if is_cell_occupied(cell) and _occupied_cells[cell] != ignored_building:
				return false
	return true


func is_walkable_cell(cell: Vector2i) -> bool:
	return is_buildable_cell(cell) and not _navigation.is_point_solid(cell)


func find_cell_path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	if not is_walkable_cell(from) or not is_walkable_cell(to):
		return []
	return _navigation.get_id_path(from, to)


func find_cell_path_avoiding(from: Vector2i, to: Vector2i, blocked: Array[Vector2i]) -> Array[Vector2i]:
	# Placement preflight: route around the future footprint without reserving it.
	var restored: Array[Vector2i] = []
	for cell in blocked:
		if is_walkable_cell(cell):
			restored.append(cell)
			_navigation.set_point_solid(cell, true)
	var path := find_cell_path(from, to)
	for cell in restored:
		_navigation.set_point_solid(cell, false)
	return path
