class_name VillageEconomy
extends Node

signal changed
signal build_rejected(reason: String)

# Initial prototype balances; construction prices live in BuildingCatalog.
@export var gold := 2500
@export var bread := 1200
const GOLD_CAPACITY := 5000
const BREAD_CAPACITY := 5000
const GEMS := 50

@onready var village_map: VillageMap = $"../VillageMap"
@onready var buildings: Node2D = $"../Buildings"


func _ready() -> void:
	for child in buildings.get_children():
		_track_building(child)
	buildings.child_entered_tree.connect(_track_building)
	buildings.child_exiting_tree.connect(func(_child: Node): changed.emit.call_deferred())


func _track_building(child: Node) -> void:
	if child is VillageBuilding:
		child.construction_finished.connect(func(): changed.emit())
	changed.emit.call_deferred()


func get_total_builders() -> int:
	var total := 0
	for child in buildings.get_children():
		if child is VillageBuilding and not child.is_queued_for_deletion() and child.building_type == "builder_hut" and not child.is_under_construction():
			total += 1
	return total


func get_busy_builders() -> int:
	var busy := 0
	for child in buildings.get_children():
		if child is VillageBuilding and not child.is_queued_for_deletion() and child.is_under_construction():
			busy += 1
	return busy


func get_free_builders() -> int:
	return maxi(0, get_total_builders() - get_busy_builders())


func get_build_error(building_type: StringName) -> String:
	var definition: Dictionary = BuildingCatalog.DEFINITIONS.get(building_type, {})
	if not definition.has("gold_cost"):
		return "Ця будівля ще недоступна"
	if gold < int(definition["gold_cost"]):
		return "Недостатньо золота: потрібно %d" % definition["gold_cost"]
	if get_free_builders() == 0:
		return "Усі будівельники зайняті — дочекайся завершення"
	return ""


func start_building(building_type: StringName, cell: Vector2i) -> VillageBuilding:
	# Validate everything before creating a node or charging the player.
	if not village_map.can_place_building(building_type, cell):
		build_rejected.emit("Місце зайняте або за межами поля")
		return null
	var error := get_build_error(building_type)
	if not error.is_empty():
		build_rejected.emit(error)
		return null
	var definition: Dictionary = BuildingCatalog.DEFINITIONS[building_type]
	var manager := get_node_or_null("../BuilderManager") as BuilderManager
	if float(definition["build_seconds"]) > 0.0 and manager != null and not manager.can_reach_construction(cell, BuildingCatalog.get_footprint(building_type)):
		build_rejected.emit("Будівельник не може дістатися сюди — залиш прохід")
		return null
	var building := VillageBuilding.new()
	building.building_type = String(building_type)
	building.cell = cell
	building.name = "%s_%d" % [building_type, building.get_instance_id()]
	building.start_construction(float(definition["build_seconds"]))
	gold -= int(definition["gold_cost"])
	buildings.add_child(building)
	changed.emit()
	return building


static func format_time(seconds: float) -> String:
	var remaining := maxi(0, ceili(seconds))
	return "%d:%02d" % [remaining / 60, remaining % 60]
