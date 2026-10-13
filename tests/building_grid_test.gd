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
	var temple: VillageBuilding = scene.get_node("Buildings/Temple")
	var tent: VillageBuilding = scene.get_node("Buildings/WarTent")
	var camp: VillageBuilding = scene.get_node("Buildings/UnitCamp")
	var mine: VillageBuilding = scene.get_node("Buildings/GoldMine")
	var storage: VillageBuilding = scene.get_node("Buildings/GoldStorage")
	var hut1: VillageBuilding = scene.get_node("Buildings/BuilderHut1")
	var hut2: VillageBuilding = scene.get_node("Buildings/BuilderHut2")
	_check(scene.get_node("Buildings").get_child_count() == 7, "The seven Level 1 starting buildings are present")
	_check(map.get_occupied_cells().size() == 76, "Buildings reserve exactly 16 + 9 + 25 + 9 + 9 + 4 + 4 cells")
	var temple_center := map.grid_to_world(Vector2(temple.cell) + Vector2(temple.get_footprint() - Vector2i.ONE) * 0.5)
	_check(temple_center == Vector2.ZERO, "Temple ground footprint is centered on the map")
	_check(temple.get_footprint() == Vector2i(4, 4), "Temple is 4 by 4")
	_check(tent.get_footprint() == Vector2i(3, 3), "Tent is 3 by 3")
	_check(camp.get_footprint() == Vector2i(5, 5), "Camp is 5 by 5")
	for building in [mine, storage]:
		_check(building.get_footprint() == Vector2i(3, 3), "Gold buildings occupy 3 by 3 cells")
		_check(building.level == 1, "Gold buildings start at Level 1")
		_check(building._texture != null, "Gold buildings have imported sprites")
		_check(building._texture.get_image().get_pixel(0, 0).a == 0.0, "Gold sprites have transparent backgrounds")
	for hut in [hut1, hut2]:
		_check(hut.get_footprint() == Vector2i(2, 2) and hut.level == 1, "Builder huts start at Level 1 and occupy 2 by 2 cells")
		_check(hut._texture != null and hut._texture.get_image().get_pixel(0, 0).a == 0.0, "Builder huts have an imported transparent sprite")
		for row in range(2):
			for column in range(2):
				_check(not map.is_walkable_cell(hut.cell + Vector2i(column, row)), "Builder hut footprint blocks walking")
	var fire: Sprite2D = camp.get_node("Campfire")
	_check(fire.texture != null, "Camp uses a separate campfire sprite")
	var fire_definition: Dictionary = BuildingCatalog.DEFINITIONS[&"unit_camp"]
	var fire_anchor := VillageBuilding._get_source_ground_anchor(fire.texture, fire_definition["campfire_source_ground_width"])
	_check(fire.to_global(fire.offset + fire_anchor).is_equal_approx(map.to_global(map.cell_to_world(camp.cell + Vector2i(2, 2)))), "Fire ground anchor follows the camp's central grid cell")
	_check(fire.global_position.is_equal_approx(camp.global_position), "Fire depth sorting uses its ground center")
	_check(fire.scale.x == fire.scale.y, "Fire sprite scales uniformly")
	_check(temple.global_position == Vector2.ZERO, "Temple node uses the ground center as its origin")
	_check(tent.global_position == Vector2(336, 144), "Tent position follows the shared grid center")
	_check(camp.global_position == Vector2(-288, 252), "Camp position follows the shared grid center")
	_check(mine.global_position == Vector2(-336, -216), "Mine position follows the shared grid center")
	_check(storage.global_position == Vector2(96, 324), "Storage position follows the shared grid center")
	for building in [temple, tent, camp, mine, storage, hut1, hut2]:
		var locked_transform: Transform2D = building.global_transform
		building.position += Vector2(7.0, -11.0)
		_check(building.global_transform.is_equal_approx(locked_transform), "Arbitrary pixel translation cannot move a building off the grid")
		building.rotation = 0.15
		_check(building.global_transform.is_equal_approx(locked_transform), "Individual rotation cannot change the grid orientation")
		building.scale = Vector2(1.1, 0.9)
		_check(building.global_transform.is_equal_approx(locked_transform), "Individual scale cannot deform the footprint")
		var ground: Polygon2D = building.get_node("GrassGround")
		var ground_center := Vector2.ZERO
		for corner in ground.polygon:
			ground_center += corner
		_check((ground_center / 4.0).is_zero_approx(), "Grass and sprite share the same ground center")
		var footprint_polygon := map.get_footprint_polygon(building.cell, building.get_footprint())
		_check((footprint_polygon[1] - footprint_polygon[0]).normalized().is_equal_approx(Vector2(0.8, 0.6)), "All footprint edges share the same grid direction")
		var size: Vector2i = building.get_footprint()
		for row in range(size.y):
			for column in range(size.x):
				var cell: Vector2i = building.cell + Vector2i(column, row)
				_check(map.is_cell_occupied(cell), "All footprint cells are reserved: %s" % cell)
				_check(not map.can_place_building(&"wall", cell), "Another building cannot be placed inside: %s" % cell)
		_check(map.can_place_building(StringName(building.building_type), building.cell, building), "Placement can ignore the building being moved")
	for row in range(4):
		for column in range(4):
			_check(not map.is_walkable_cell(temple.cell + Vector2i(column, row)), "Temple blocks walking")
	for row in range(3):
		for column in range(3):
			_check(not map.is_walkable_cell(tent.cell + Vector2i(column, row)), "Tent blocks walking")
			_check(not map.is_walkable_cell(mine.cell + Vector2i(column, row)), "Mine blocks walking across its footprint")
			_check(not map.is_walkable_cell(storage.cell + Vector2i(column, row)), "Storage blocks walking across its footprint")
	for row in range(5):
		for column in range(5):
			var local := Vector2i(column, row)
			var cell := camp.cell + local
			var expected := (Rect2i(1, 1, 3, 3).has_point(local) and local != Vector2i(2, 2)) or local == Vector2i(2, 4)
			_check(map.is_walkable_cell(cell) == expected, "Camp keeps its center and entrance walkable: %s" % local)
			if expected:
				var path := map.find_cell_path(camp.cell + Vector2i(2, 5), cell)
				_check(not path.is_empty() and path[-1] == cell, "Every camp interior cell is reachable from outside")
				for point in path:
					_check(map.is_walkable_cell(point), "Route never crosses blocked decoration")
	_check(not map.is_walkable_cell(camp.cell + Vector2i(2, 2)), "The central fire blocks its own cell")
	_check(map.find_cell_path(camp.cell + Vector2i(2, 4), camp.cell + Vector2i(2, 2)).is_empty(), "Routes cannot enter the fire")
	var around_fire := map.find_cell_path(camp.cell + Vector2i(2, 1), camp.cell + Vector2i(2, 3))
	_check(around_fire.size() == 5, "A route crosses the camp by going around its central fire")
	for point in around_fire:
		_check(Rect2i(camp.cell + Vector2i.ONE, Vector2i(3, 3)).has_point(point), "Fire detour stays in the inner camp area")
	_check(map.can_place_building(&"wall", Vector2i(19, 20)), "Visual grass margin does not reserve an extra cell")
	_check(not map.can_place_building(&"temple", Vector2i(42, 42)), "Whole footprint must fit the map")
	_check(map.can_place_building(&"temple", Vector2i(40, 40)), "Footprint may touch the last buildable cell")
	_check(not map.can_place_building(&"wall", Vector2i(-1, 0)), "Border is excluded from placement")
	_check(not map.can_place_building(&"unknown", Vector2i(0, 0)), "Unknown building types are rejected")
	_check(map.find_cell_path(Vector2i(-1, 0), Vector2i(0, 0)).is_empty(), "Route rejects points outside the map")
	_check(map.find_cell_path(Vector2i(19, 20), temple.cell).is_empty(), "Route rejects a blocked destination")
	_check(BuildingCatalog.get_footprint(&"gold_extractor") == Vector2i(3, 3), "Level 1 gold mine occupies 3 by 3 cells")
	_check(BuildingCatalog.get_footprint(&"gold_storage") == Vector2i(3, 3), "Gold storage definition is ready")
	_check(BuildingCatalog.get_footprint(&"essence_extractor") == Vector2i(2, 2), "Essence extractor is 2 by 2")
	_check(BuildingCatalog.get_footprint(&"essence_storage") == Vector2i(3, 3), "Essence storage is 3 by 3")
	_check(BuildingCatalog.get_footprint(&"defense_tower") == Vector2i(2, 2), "Tower is 2 by 2")
	_check(BuildingCatalog.get_footprint(&"wall") == Vector2i.ONE, "Wall is 1 by 1")
	_check(BuildingCatalog.get_footprint(&"trap") == Vector2i.ONE, "Trap is 1 by 1")
	_check(BuildingCatalog.get_footprint(&"decor_small") == Vector2i.ONE, "Small decor is 1 by 1")
	_check(BuildingCatalog.get_footprint(&"decor_large") == Vector2i(2, 2), "Large decor is 2 by 2")
	_check(BuildingCatalog.is_local_cell_walkable(&"decor_large", Vector2i.ZERO), "Decor does not block movement")
	map.show_placement_grid()
	for cell in map.get_occupied_cells():
		_check(map.placement_grid.is_cell_blocked(cell), "Grid overlay includes every reserved cell")
	map.hide_placement_grid()
	var old_tent_cell := tent.cell
	tent.cell = Vector2i(30, 19)
	_check(not map.is_cell_occupied(old_tent_cell) and map.is_walkable_cell(old_tent_cell), "Moving a building frees placement and navigation")
	_check(map.is_cell_occupied(tent.cell) and not map.is_walkable_cell(tent.cell), "Moving a building blocks its new footprint")
	tent.cell = old_tent_cell
	var neighboring_tents: Array[VillageBuilding] = []
	for origin in [Vector2i(5, 5), Vector2i(8, 5)]:
		var neighbor := VillageBuilding.new()
		neighbor.building_type = "war_tent"
		neighbor.cell = origin
		scene.get_node("Buildings").add_child(neighbor)
		neighboring_tents.append(neighbor)
	_check(neighboring_tents[1].global_position - neighboring_tents[0].global_position == Vector2(144, 108), "Adjacent equal footprints differ by exactly three grid cells")
	_check(neighboring_tents[0]._sprite_rect == neighboring_tents[1]._sprite_rect, "Adjacent copies use identical sprite anchors and size")
	var first_polygon := map.get_footprint_polygon(Vector2i(5, 5), Vector2i(3, 3))
	var second_polygon := map.get_footprint_polygon(Vector2i(8, 5), Vector2i(3, 3))
	_check(first_polygon[1] == second_polygon[0] and first_polygon[2] == second_polygon[3], "Adjacent footprints share their complete edge without any pixel gap")
	for neighbor in neighboring_tents:
		neighbor.free()
	camp.free()
	_check(map.get_occupied_cells().size() == 51, "Removing camp frees all of its 25 cells")
	_check(map.is_walkable_cell(Vector2i(20, 26)), "Removing camp frees blocked edge cells")
	print("Building grid checks: %d passed, %d failed" % [checks - failures, failures])
	quit(1 if failures else 0)


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)
