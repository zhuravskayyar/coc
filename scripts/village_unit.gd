class_name VillageUnit
extends Node2D

signal ranged_attack_released(origin: Vector2, direction: Vector2)

const WALK_SPEED := 42.0
const RUN_SPEED := 130.0
const MILITIA_SHEETS := {
	&"idle": preload("res://assets/sprites/units/militia_idle_sheet.png"),
	&"walk": preload("res://assets/sprites/units/militia_walk_sheet.png"),
	&"run": preload("res://assets/sprites/units/militia_run_sheet.png"),
	&"attack": preload("res://assets/sprites/units/militia_attack_sheet.png"),
}
const MILITIA_METADATA: JSON = preload("res://assets/sprites/units/militia_animations.json")

var home: VillageBuilding
var village_map: VillageMap
var manager: ArmyManager
var animation: StringName = &"idle"
var facing := 2
var _cell := Vector2i.ZERO
var _path: Array[Vector2i] = []
var _animation_time := 0.0
var _wait := 0.0
var _destination := Vector2i.ZERO
var _rng := RandomNumberGenerator.new()
var stationed_building: VillageBuilding
var _station_offset := Vector2.ZERO
var _attack_active := false
var _attack_released := false
var _attack_direction := Vector2.RIGHT

@onready var sprite: Sprite2D = $Sprite
var _clips: Dictionary:
	get:
		return get_animation_metadata()["clips"]


func get_animation_sheets() -> Dictionary:
	return MILITIA_SHEETS


func get_animation_metadata() -> Dictionary:
	return MILITIA_METADATA.data


func _ready() -> void:
	_rng.randomize()
	var metadata := get_animation_metadata()
	sprite.scale = Vector2.ONE * float(metadata["world_scale"])
	sprite.offset = -Vector2(float(metadata["ground_anchor"][0]), float(metadata["ground_anchor"][1]))
	var info: Dictionary = _clips[String(animation)]
	sprite.texture = get_animation_sheets()[animation]
	sprite.hframes = int(info["columns"])
	sprite.vframes = int(info["rows_per_direction"]) * 8
	if animation == &"idle":
		_animation_time = _rng.randf() * float(info["frames"]) / float(info["fps"])
	_update_frame()


func setup(camp: VillageBuilding, map: VillageMap, route: Array[Vector2i], army: ArmyManager) -> void:
	home = camp
	village_map = map
	manager = army
	_rng.randomize()
	_cell = route[0]
	global_position = _world(_cell)
	follow_path(route)


func follow_path(route: Array[Vector2i], running: bool = false) -> void:
	_path = route.duplicate()
	if not _path.is_empty():
		_destination = _path[-1]
		if global_position.distance_to(_world(_path[0])) < 0.1:
			_path.pop_front()
	set_animation((&"run" if running else &"walk") if not _path.is_empty() else &"idle")


func attack_toward(world_target: Vector2) -> void:
	var delta := world_target - global_position
	if delta.length_squared() < 0.0001:
		return
	_attack_direction = delta.normalized()
	facing = posmod(roundi(Vector2(delta.x, delta.y / 0.75).angle() / (PI / 4.0)), 8)
	_path.clear()
	_attack_active = true
	_attack_released = false
	set_animation(&"attack")


func station_at(building: VillageBuilding, screen_offset: Vector2 = Vector2(0, -52)) -> void:
	stationed_building = building
	_station_offset = screen_offset
	_path.clear()
	global_position = building.global_position + _station_offset
	_attack_active = false
	facing = 2
	z_as_relative = false
	z_index = 31
	set_animation(&"idle")


func return_to_camp(camp: VillageBuilding, route: Array[Vector2i]) -> void:
	stationed_building = null
	home = camp
	z_as_relative = true
	z_index = 0
	follow_path(route)


func set_animation(clip: StringName) -> void:
	if animation == clip and sprite.texture == get_animation_sheets()[clip] and clip != &"attack":
		return
	var old_clip := animation
	var old_time := _animation_time
	animation = clip
	_animation_time = 0.0
	if old_clip in [&"walk", &"run"] and clip in [&"walk", &"run"]:
		var previous: Dictionary = _clips[String(old_clip)]
		var following: Dictionary = _clips[String(clip)]
		var duration := float(previous["frames"]) / float(previous["fps"])
		_animation_time = fposmod(old_time, duration) / duration * float(following["frames"]) / float(following["fps"])
	sprite.texture = get_animation_sheets()[clip]
	var info: Dictionary = _clips[String(clip)]
	sprite.hframes = int(info["columns"])
	sprite.vframes = int(info["rows_per_direction"]) * 8
	_update_frame()


func _process(delta: float) -> void:
	advance_behavior(delta)


func advance_behavior(delta: float) -> void:
	if delta <= 0.0:
		return
	if is_instance_valid(stationed_building):
		global_position = stationed_building.global_position + _station_offset
		if not _attack_active:
			if animation != &"idle":
				set_animation(&"idle")
			_animation_time += delta
			_update_frame()
			return
	elif stationed_building != null:
		stationed_building = null
		z_as_relative = true
		z_index = 0
	if _attack_active:
		var attack: Dictionary = _clips["attack"]
		_animation_time += delta
		var duration := float(attack["frames"]) / float(attack["fps"])
		var release_time := float(attack.get("release_frame", float(attack["frames"]) * 0.66)) / float(attack["fps"])
		if not _attack_released and _animation_time + 0.000001 >= release_time:
			_attack_released = true
			_release_attack()
		if _animation_time + 0.000001 >= duration:
			_attack_active = false
			set_animation(&"idle")
		else:
			_update_frame()
		return
	if village_map == null:
		_animation_time += delta
		_update_frame()
		return
	if not _path.is_empty():
		_move(delta)
	elif animation != &"attack":
		_wait -= delta
		if _wait <= 0.0:
			_pick_camp_path()
	var playback := 1.0
	if animation in [&"walk", &"run"]:
		var speed := RUN_SPEED if animation == &"run" else WALK_SPEED
		playback = get_locomotion_playback(speed)
	_animation_time += delta * playback
	_update_frame()


func get_locomotion_playback(speed: float) -> float:
	var angle := facing * PI / 4.0
	var metadata := get_animation_metadata()
	var projections: Array = metadata.get("direction_ground_projection", [])
	var projection := float(projections[facing]) if projections.size() == 8 else Vector2(cos(angle), sin(angle) * float(metadata["ground_projection_y"])).length()
	return speed / (float(_clips[String(animation)]["ground_speed_mps"]) * sprite.scale.x * float(get_animation_metadata()["pixels_per_metre"]) * projection)


func _release_attack() -> void:
	ranged_attack_released.emit(global_position, _attack_direction)


func _pick_camp_path() -> void:
	_wait = _rng.randf_range(2.0, 5.0)
	if not is_instance_valid(home) or home.is_queued_for_deletion():
		return
	var cells := manager.camp_cells(home)
	cells.shuffle()
	for target in cells:
		if target == _cell:
			continue
		var route := village_map.find_cell_path(_cell, target)
		if route.size() > 1:
			follow_path(route)
			return


func _move(delta: float) -> void:
	var budget := (RUN_SPEED if animation == &"run" else WALK_SPEED) * delta
	while budget > 0.0 and not _path.is_empty():
		var next := _path[0]
		if not village_map.is_walkable_cell(next):
			var route := village_map.find_cell_path(_cell, _destination)
			follow_path(route, animation == &"run")
			_wait = 1.0
			return
		var displacement := _world(next) - global_position
		if displacement.length_squared() > 0.01:
			facing = posmod(roundi(Vector2(displacement.x, displacement.y / 0.75).angle() / (PI / 4.0)), 8)
		var step := minf(budget, displacement.length())
		global_position = global_position.move_toward(_world(next), step)
		budget -= step
		if step < displacement.length():
			return
		_cell = next
		_path.pop_front()
	if _path.is_empty():
		set_animation(&"idle")
		_wait = _rng.randf_range(2.0, 5.0)


func _world(cell: Vector2i) -> Vector2:
	return village_map.to_global(village_map.cell_to_world(cell))


func _update_frame() -> void:
	var info: Dictionary = _clips[String(animation)]
	var frame := int(_animation_time * float(info["fps"]) + 0.000001) % int(info["frames"])
	var columns := int(info["columns"])
	sprite.frame_coords = Vector2i(frame % columns, facing * int(info["rows_per_direction"]) + frame / columns)
