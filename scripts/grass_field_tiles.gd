@tool
class_name GrassFieldTiles
extends Node2D

var _variants := PackedByteArray()


func _ready() -> void:
	_variants.resize(VillageMap.BUILDABLE_SIZE * VillageMap.BUILDABLE_SIZE)
	for row in range(VillageMap.BUILDABLE_SIZE):
		for column in range(VillageMap.BUILDABLE_SIZE):
			_variants[row * VillageMap.BUILDABLE_SIZE + column] = (row + column) % 2
	queue_redraw()


func _draw() -> void:
	var map := get_parent() as VillageMap
	if map == null or _variants.is_empty():
		return
	var uvs := PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(1.0, 0.0),
		Vector2(1.0, 1.0), Vector2(0.0, 1.0),
	])
	for variant in range(2):
		# Both variants use the first sprite; the shader darkens variant zero.
		var variant_color := Color(float(variant), 1.0, 1.0, 1.0)
		for row in range(VillageMap.BUILDABLE_SIZE):
			for column in range(VillageMap.BUILDABLE_SIZE):
				if _variants[row * VillageMap.BUILDABLE_SIZE + column] != variant:
					continue
				draw_colored_polygon(map.get_cell_polygon(Vector2i(column, row)), variant_color, uvs, VillageMap.GRASS_LIGHT)


func get_tile_count() -> int:
	return _variants.size()


func get_variant_count(variant: int) -> int:
	return _variants.count(variant)
