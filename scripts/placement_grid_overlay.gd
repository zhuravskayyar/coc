@tool
class_name PlacementGridOverlay
extends Node2D

const FREE_COLOR := Color(0.35, 0.95, 0.45, 0.07)
const BLOCKED_COLOR := Color(1.0, 0.12, 0.12, 0.45)
const BLOCKED_OUTLINE := Color(1.0, 0.12, 0.12, 0.75)
const LINE_COLOR := Color(0.7, 1.0, 0.75, 0.20)

var _blocked_cells: Dictionary[Vector2i, bool] = {}


func set_blocked_cells(cells: Array[Vector2i]) -> void:
	var map := get_parent() as VillageMap
	_blocked_cells.clear()
	for cell in cells:
		if map.is_buildable_cell(cell):
			_blocked_cells[cell] = true
	queue_redraw()


func is_cell_blocked(cell: Vector2i) -> bool:
	return _blocked_cells.has(cell)


func _draw() -> void:
	var map := get_parent() as VillageMap
	if map == null:
		return
	# The grid uses the same cell coordinates as future buildings.
	for row in range(VillageMap.BUILDABLE_SIZE):
		for column in range(VillageMap.BUILDABLE_SIZE):
			var cell := Vector2i(column, row)
			var color := BLOCKED_COLOR if is_cell_blocked(cell) else FREE_COLOR
			draw_colored_polygon(map.get_cell_polygon(cell), color)

	var top_offset := Vector2(0.0, -VillageMap.TILE_SIZE.y * 0.5)
	for boundary in range(VillageMap.BUILDABLE_SIZE + 1):
		draw_line(
			map.cell_to_world(Vector2i(boundary, 0)) + top_offset,
			map.cell_to_world(Vector2i(boundary, VillageMap.BUILDABLE_SIZE)) + top_offset,
			LINE_COLOR, 1.0, true
		)
		draw_line(
			map.cell_to_world(Vector2i(0, boundary)) + top_offset,
			map.cell_to_world(Vector2i(VillageMap.BUILDABLE_SIZE, boundary)) + top_offset,
			LINE_COLOR, 1.0, true
		)
	for cell in _blocked_cells:
		var outline := map.get_cell_polygon(cell)
		outline.append(outline[0])
		draw_polyline(outline, BLOCKED_OUTLINE, 1.5, true)
