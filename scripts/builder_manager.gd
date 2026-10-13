class_name BuilderManager
extends Node

const BUILDER_SCENE := preload("res://scenes/units/builder.tscn")

var workers: Array[BuilderUnit] = []
var _syncing := false

@onready var village_map: VillageMap = $"../VillageMap"
@onready var buildings: Node2D = $"../Buildings"
@onready var units: Node2D = $"../Units"
@onready var economy: VillageEconomy = $"../VillageEconomy"


func _ready() -> void:
	economy.changed.connect(sync_workers)
	sync_workers()


func sync_workers() -> void:
	if _syncing or not is_node_ready():
		return
	_syncing = true
	for worker in workers.duplicate():
		if not is_instance_valid(worker.home) or worker.home.is_queued_for_deletion():
			workers.erase(worker)
			worker.queue_free()
		elif is_instance_valid(worker.job) and (worker.job.is_queued_for_deletion() or not worker.job.is_under_construction()):
			worker.finish_job()
	for child in buildings.get_children():
		if not child is VillageBuilding or child.is_queued_for_deletion():
			continue
		if child.building_type == "builder_hut" and not child.is_under_construction():
			var exists := false
			for worker in workers:
				if worker.home == child:
					exists = true
					break
			if not exists:
				var worker := BUILDER_SCENE.instantiate() as BuilderUnit
				worker.name = "Builder_%s" % child.name
				units.add_child(worker)
				worker.setup(child, village_map)
				workers.append(worker)
	for child in buildings.get_children():
		if not child is VillageBuilding or child.is_queued_for_deletion() or not child.is_under_construction():
			continue
		if worker_for(child) != null:
			continue
		var available: Array[BuilderUnit] = []
		for worker in workers:
			if worker.is_available():
				available.append(worker)
		available.sort_custom(func(a: BuilderUnit, b: BuilderUnit): return a.global_position.distance_squared_to(child.global_position) < b.global_position.distance_squared_to(child.global_position))
		for worker in available:
			if worker.assign_job(child):
				break
	_syncing = false


func worker_for(building: VillageBuilding) -> BuilderUnit:
	for worker in workers:
		if worker.job == building:
			return worker
	return null


func can_reach_construction(origin: Vector2i, size: Vector2i) -> bool:
	var blocked: Array[Vector2i] = []
	for y in range(size.y):
		for x in range(size.x):
			blocked.append(origin + Vector2i(x, y))
	for worker in workers:
		if worker.is_available() and not worker.find_site_path(origin, size, blocked).is_empty():
			return true
	return false
