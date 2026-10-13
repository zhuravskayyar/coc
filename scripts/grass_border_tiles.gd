@tool
class_name GrassBorderTiles
extends Node2D

func _ready() -> void:
	var border_material := material as ShaderMaterial
	border_material.set_shader_parameter("tile_size", VillageMap.TILE_SIZE)
	border_material.set_shader_parameter("total_size", float(VillageMap.TOTAL_SIZE))
	border_material.set_shader_parameter("border_size", float(VillageMap.BORDER_SIZE))
	queue_redraw()


func _draw() -> void:
	var map := get_parent() as VillageMap
	if map == null:
		return
	var last_cell := VillageMap.BUILDABLE_SIZE + VillageMap.BORDER_SIZE - 1
	# Continue the field with light grass before the separate decor clusters.
	for row in range(-VillageMap.BORDER_SIZE, VillageMap.BUILDABLE_SIZE + VillageMap.BORDER_SIZE):
		for column in range(-VillageMap.BORDER_SIZE, VillageMap.BUILDABLE_SIZE + VillageMap.BORDER_SIZE):
			var cell := Vector2i(column, row)
			if not map.is_buildable_cell(cell):
				var points := map.get_cell_polygon(cell)
				draw_colored_polygon(points, Color.BLACK)
				if column == last_cell:
					_draw_outer_edge(points[1], points[2])
				if row == last_cell:
					_draw_outer_edge(points[2], points[3])


func _draw_outer_edge(first: Vector2, second: Vector2) -> void:
	var depth := Vector2(0.0, VillageMap.FRAME_SIDE_DEPTH * VillageMap.TILE_SIZE.y / (VillageMap.FRAME_BOTTOM_Y - VillageMap.FRAME_TOP_Y))
	draw_colored_polygon(
		PackedVector2Array([first, second, second + depth, first + depth]),
		Color.WHITE
	)


func get_tile_count() -> int:
	return VillageMap.TOTAL_SIZE * VillageMap.TOTAL_SIZE - VillageMap.BUILDABLE_SIZE * VillageMap.BUILDABLE_SIZE


func contains_cell(cell: Vector2i) -> bool:
	var map := get_parent() as VillageMap
	var lower := -VillageMap.BORDER_SIZE
	var upper := VillageMap.BUILDABLE_SIZE + VillageMap.BORDER_SIZE
	return cell.x >= lower and cell.y >= lower and cell.x < upper and cell.y < upper and not map.is_buildable_cell(cell)
