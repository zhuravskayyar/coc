@tool
class_name BuildingCatalog
extends RefCounted

# Logical footprints stay independent of the PNG canvas and decorative grass.
const VISUAL_GRASS_MARGIN := 0.5
const DEFINITIONS := {
	&"temple": {
		"gold_cost": 1000, "build_seconds": 45.0,
		"footprint": Vector2i(4, 4),
		"texture": "res://assets/sprites/buildings/temple_lv1_grid_v2.png",
		"source_ground_width": 640.0,
	},
	&"builder_hut": {
		"gold_cost": 300, "build_seconds": 15.0,
		"footprint": Vector2i(2, 2),
		"texture": "res://assets/sprites/buildings/builder_hut_lv1_grid_v2.png",
		"source_ground_width": 1085.0,
	},
	&"war_tent": {
		"gold_cost": 400, "build_seconds": 20.0,
		"footprint": Vector2i(3, 3),
		"texture": "res://assets/sprites/buildings/war_tent_lv1_grid_v2.png",
		"source_ground_width": 1100.0,
	},
	&"unit_camp": {
		"gold_cost": 600, "build_seconds": 30.0,
		"footprint": Vector2i(5, 5),
		"texture": "res://assets/sprites/buildings/unit_camp_lv1_grid_v2.png",
		"source_ground_width": 1100.0,
		"walkable_area": Rect2i(1, 1, 3, 3),
		"campfire_cell": Vector2i(2, 2),
		"campfire_texture": "res://assets/sprites/buildings/campfire_lv1.png",
		"campfire_source_ground_width": 820.0,
		# A gap on the lower-left edge connects the inner area to the field.
		"entrance": Vector2i(2, 4),
	},
	&"gold_extractor": {
		"gold_cost": 250, "build_seconds": 15.0,
		"footprint": Vector2i(3, 3),
		"texture": "res://assets/sprites/buildings/gold_mine_lv1_grid_v2.png",
		"source_ground_width": 1132.0,
	},
	&"gold_storage": {
		"gold_cost": 350, "build_seconds": 20.0,
		"footprint": Vector2i(3, 3),
		"texture": "res://assets/sprites/buildings/gold_storage_lv1_grid_v1.png",
		"source_ground_width": 1111.0,
	},
	&"essence_extractor": {"footprint": Vector2i(2, 2)},
	&"essence_storage": {"footprint": Vector2i(3, 3)},
	&"defense_tower": {
		"gold_cost": 500, "build_seconds": 30.0,
		"footprint": Vector2i(2, 2),
		"texture": "res://assets/sprites/buildings/defense_tower_lv1_grid_v1.png",
		"source_ground_width": 1100.0,
	},
	&"wall": {"footprint": Vector2i(1, 1), "gold_cost": 25, "build_seconds": 0.0},
	&"trap": {"footprint": Vector2i(1, 1)},
	&"decor_small": {"footprint": Vector2i(1, 1), "blocks_movement": false},
	&"decor_large": {"footprint": Vector2i(2, 2), "blocks_movement": false},
}


const WALL_DIRECTIONS := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
const WALL_SPRITES := {
	0: {"texture": "res://assets/sprites/buildings/palisade_lv1_mask_00_v2.png", "source_ground_width": 989.0},
	1: {"texture": "res://assets/sprites/buildings/palisade_lv1_mask_01_v2.png", "source_ground_width": 962.0},
	2: {"texture": "res://assets/sprites/buildings/palisade_lv1_mask_02_v2.png", "source_ground_width": 971.0},
	3: {"texture": "res://assets/sprites/buildings/palisade_lv1_mask_03_v2.png", "source_ground_width": 1018.0},
	4: {"texture": "res://assets/sprites/buildings/palisade_lv1_mask_04_v2.png", "source_ground_width": 990.0},
	5: {"texture": "res://assets/sprites/buildings/palisade_lv1_mask_05_v2.png", "source_ground_width": 1040.0},
	6: {"texture": "res://assets/sprites/buildings/palisade_lv1_mask_06_v2.png", "source_ground_width": 1034.0},
	7: {"texture": "res://assets/sprites/buildings/palisade_lv1_mask_07_v2.png", "source_ground_width": 1060.0},
	8: {"texture": "res://assets/sprites/buildings/palisade_lv1_mask_08_v2.png", "source_ground_width": 951.0},
	9: {"texture": "res://assets/sprites/buildings/palisade_lv1_mask_09_v2.png", "source_ground_width": 1041.0},
	10: {"texture": "res://assets/sprites/buildings/palisade_lv1_mask_10_v2.png", "source_ground_width": 1051.0},
	11: {"texture": "res://assets/sprites/buildings/palisade_lv1_mask_11_v2.png", "source_ground_width": 1078.0},
	12: {"texture": "res://assets/sprites/buildings/palisade_lv1_mask_12_v2.png", "source_ground_width": 946.0},
	13: {"texture": "res://assets/sprites/buildings/palisade_lv1_mask_13_v2.png", "source_ground_width": 1046.0},
	14: {"texture": "res://assets/sprites/buildings/palisade_lv1_mask_14_v2.png", "source_ground_width": 1030.0},
	15: {"texture": "res://assets/sprites/buildings/palisade_lv1_mask_15_v2.png", "source_ground_width": 1046.0},
}


static func get_visual_definition(building_type: StringName, wall_connections: int = 0) -> Dictionary:
	if building_type == &"wall":
		return WALL_SPRITES[wall_connections & 15]
	return DEFINITIONS.get(building_type, {})


static func get_footprint(building_type: StringName) -> Vector2i:
	if not DEFINITIONS.has(building_type):
		return Vector2i.ZERO
	return DEFINITIONS[building_type]["footprint"]


static func is_local_cell_walkable(building_type: StringName, cell: Vector2i) -> bool:
	var definition: Dictionary = DEFINITIONS.get(building_type, {})
	if definition.is_empty():
		return false
	if not definition.get("blocks_movement", true):
		return true
	if definition.get("campfire_cell", Vector2i(-1, -1)) == cell:
		return false
	var area: Rect2i = definition.get("walkable_area", Rect2i())
	return area.has_point(cell) or cell == definition.get("entrance", Vector2i(-1, -1))
