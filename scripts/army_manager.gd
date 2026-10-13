class_name ArmyManager
extends Node

signal changed

const MILITIA_SCENE := preload("res://scenes/units/militia.tscn")
const ARCHER_SCENE := preload("res://scenes/units/archer.tscn")

var soldiers: Array[MilitiaUnit] = []
var archers: Array[ArcherUnit] = []
var queued := 0
var archer_queued := 0
var training_remaining := 0.0
var _training_queue: Array[StringName] = []

@onready var village_map: VillageMap = $"../VillageMap"
@onready var buildings: Node2D = $"../Buildings"
@onready var units: Node2D = $"../Units"
@onready var economy: VillageEconomy = $"../VillageEconomy"


func completed_buildings(type: String) -> Array[VillageBuilding]:
	var result: Array[VillageBuilding] = []
	for child in buildings.get_children():
		if child is VillageBuilding and not child.is_queued_for_deletion() and child.building_type == type and not child.is_under_construction():
			result.append(child)
	return result


func camp_cells(camp: VillageBuilding) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var area: Rect2i = BuildingCatalog.DEFINITIONS[&"unit_camp"]["walkable_area"]
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			var cell := camp.cell + Vector2i(x, y)
			if village_map.is_walkable_cell(cell):
				result.append(cell)
	return result


func find_spawn_route() -> Dictionary:
	# Use the existing navigation grid, including the camp entrance and campfire.
	var best: Dictionary = {}
	for tent in completed_buildings("war_tent"):
		for camp in completed_buildings("unit_camp"):
			var targets := camp_cells(camp)
			for start in BuilderUnit.perimeter(tent.cell, tent.get_footprint()):
				for target in targets:
					var path := village_map.find_cell_path(start, target)
					if not path.is_empty() and (best.is_empty() or path.size() < best["path"].size()):
						best = {"camp": camp, "path": path}
	return best


func get_train_error() -> String:
	if completed_buildings("war_tent").is_empty():
		return "Потрібен готовий військовий намет"
	if completed_buildings("unit_camp").is_empty():
		return "Потрібен готовий армійський табір"
	if economy.bread < int(UnitCatalog.MILITIA["bread_cost"]):
		return "Недостатньо хліба: потрібно 100"
	if find_spawn_route().is_empty():
		return "Немає проходу від намету до табору"
	return ""


func get_archer_train_error() -> String:
	if completed_buildings("war_tent").is_empty():
		return "Потрібен готовий військовий намет"
	if completed_buildings("unit_camp").is_empty():
		return "Потрібен готовий армійський табір"
	if economy.bread < int(UnitCatalog.ARCHER["bread_cost"]):
		return "Недостатньо хліба: потрібно 125"
	if find_spawn_route().is_empty():
		return "Немає проходу від намету до табору"
	return ""


func train_militia() -> bool:
	if not get_train_error().is_empty():
		return false
	economy.bread -= int(UnitCatalog.MILITIA["bread_cost"])
	queued += 1
	_training_queue.append(&"militia")
	if _training_queue.size() == 1:
		training_remaining = float(UnitCatalog.MILITIA["train_seconds"])
	economy.changed.emit()
	changed.emit()
	return true


func train_archer() -> bool:
	if not get_archer_train_error().is_empty():
		return false
	economy.bread -= int(UnitCatalog.ARCHER["bread_cost"])
	archer_queued += 1
	_training_queue.append(&"archer")
	if _training_queue.size() == 1:
		training_remaining = float(UnitCatalog.ARCHER["train_seconds"])
	economy.changed.emit()
	changed.emit()
	return true


func training_status() -> String:
	if _training_queue.is_empty():
		return "Черга тренування порожня."
	if completed_buildings("war_tent").is_empty():
		return "Тренування призупинено: потрібен військовий намет."
	if training_remaining <= 0.0:
		return "Воїн готовий — очікує проходу до табору."
	var unit_name := "лучниця" if _training_queue[0] == &"archer" else "ополченець"
	return "Тренується %s: %d с · у черзі: ополчення %d, лучниць %d" % [unit_name, ceili(training_remaining), queued, archer_queued]


func archer_on_tower(tower: VillageBuilding) -> ArcherUnit:
	for archer in archers:
		if is_instance_valid(archer) and archer.stationed_building == tower:
			return archer
	return null


func get_tower_station_error(tower: VillageBuilding) -> String:
	if not is_instance_valid(tower) or tower.is_under_construction():
		return "Потрібна готова башта лучниці"
	if archer_on_tower(tower) != null:
		return "Башта вже укомплектована"
	for archer in archers:
		if is_instance_valid(archer) and archer.stationed_building == null:
			return ""
	return "Спершу натренуй лучницю у військовому наметі"


func station_archer(tower: VillageBuilding) -> bool:
	if not get_tower_station_error(tower).is_empty():
		return false
	for archer in archers:
		if is_instance_valid(archer) and archer.stationed_building == null:
			archer.station_at(tower)
			changed.emit()
			return true
	return false


func return_archer_from_tower(tower: VillageBuilding) -> bool:
	var archer := archer_on_tower(tower)
	if archer == null:
		return false
	var route := _find_camp_return_route(tower)
	if route.is_empty():
		return false
	archer.return_to_camp(route["camp"], route["path"])
	changed.emit()
	return true


func _find_camp_return_route(tower: VillageBuilding) -> Dictionary:
	var best: Dictionary = {}
	for camp in completed_buildings("unit_camp"):
		for start in BuilderUnit.perimeter(tower.cell, tower.get_footprint()):
			for target in camp_cells(camp):
				var path := village_map.find_cell_path(start, target)
				if not path.is_empty() and (best.is_empty() or path.size() < best["path"].size()):
					best = {"camp": camp, "path": path}
	return best


func _process(delta: float) -> void:
	advance_training(delta)
	for soldier in soldiers:
		if soldier.stationed_building == null and (not is_instance_valid(soldier.home) or soldier.home.is_queued_for_deletion()):
			var camps := completed_buildings("unit_camp")
			if not camps.is_empty():
				soldier.home = camps[0]
	for archer in archers:
		if archer.stationed_building == null and (not is_instance_valid(archer.home) or archer.home.is_queued_for_deletion()):
			var camps := completed_buildings("unit_camp")
			if not camps.is_empty():
				archer.home = camps[0]


func advance_training(delta: float) -> void:
	if delta <= 0.0 or _training_queue.is_empty() or completed_buildings("war_tent").is_empty():
		return
	var budget := delta
	while not _training_queue.is_empty():
		var step := minf(budget, training_remaining)
		training_remaining -= step
		budget -= step
		if training_remaining > 0.000001:
			break
		var route := find_spawn_route()
		if route.is_empty():
			training_remaining = 0.0
			break
		var unit_type: StringName = _training_queue.pop_front()
		if unit_type == &"archer":
			var archer := ARCHER_SCENE.instantiate() as ArcherUnit
			archer.name = "Archer_%d" % (archers.size() + 1)
			units.add_child(archer)
			archer.setup(route["camp"], village_map, route["path"], self)
			archers.append(archer)
			archer_queued -= 1
		else:
			var soldier := MILITIA_SCENE.instantiate() as MilitiaUnit
			soldier.name = "Militia_%d" % (soldiers.size() + 1)
			units.add_child(soldier)
			soldier.setup(route["camp"], village_map, route["path"], self)
			soldiers.append(soldier)
			queued -= 1
		training_remaining = _seconds_for(_training_queue[0]) if not _training_queue.is_empty() else 0.0
		changed.emit()
		if budget <= 0.0:
			break


func _seconds_for(unit_type: StringName) -> float:
	return float(UnitCatalog.ARCHER["train_seconds"] if unit_type == &"archer" else UnitCatalog.MILITIA["train_seconds"])
