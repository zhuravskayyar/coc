class_name BuilderUnit
extends Node2D

enum State { HOME, WANDERING, RETURNING, TO_SITE, HAMMERING, CHANGING_SIDE }

const WALK_SPEED := 72.0
const RUN_SPEED := 250.0
const HOME_WAIT := Vector2(28.0, 65.0)
const WALK_DURATION := Vector2(4.0, 8.0)
const WORK_DURATION := Vector2(2.5, 4.5)
const SHEETS := {
	&"idle": preload("res://assets/sprites/units/builder_idle_sheet.png"),
	&"walk": preload("res://assets/sprites/units/builder_walk_sheet.png"),
	&"run": preload("res://assets/sprites/units/builder_run_sheet.png"),
	&"hammer": preload("res://assets/sprites/units/builder_hammer_sheet.png"),
}
const ANIMATION_METADATA: JSON = preload("res://assets/sprites/units/builder_animations.json")

var home: VillageBuilding
var job: VillageBuilding
var village_map: VillageMap
var state := State.HOME
var animation: StringName = &"idle"
var facing := 2
var rng := RandomNumberGenerator.new()
var _wait := 0.0
var _outing_left := 0.0
var _work_left := 0.0
var _animation_time := 0.0
var _retry := 0.0
var _path: Array[Vector2i] = []
var _escape_cells: Array[Vector2i] = []
var _cell := Vector2i.ZERO
var _site_side := -1
var sides_worked: Array[int] = []

@onready var sprite: Sprite2D = $Sprite
@onready var _clips: Dictionary = ANIMATION_METADATA.data["clips"]


func setup(hut: VillageBuilding, map: VillageMap) -> void:
	home = hut
	village_map = map
	rng.randomize()
	_enter_home()


func is_available() -> bool:
	return not is_instance_valid(job)


static func perimeter(origin: Vector2i, size: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	# Front edges first, then back edges, in clockwise order.
	for x in range(size.x - 1, -1, -1):
		result.append(origin + Vector2i(x, size.y))
	for y in range(size.y - 1, -1, -1):
		result.append(origin + Vector2i(-1, y))
	for x in range(size.x):
		result.append(origin + Vector2i(x, -1))
	for y in range(size.y):
		result.append(origin + Vector2i(size.x, y))
	return result


func find_site_path(origin: Vector2i, size: Vector2i, future_footprint: Array[Vector2i] = []) -> Array[Vector2i]:
	var starts: Array[Vector2i] = [_cell]
	if state == State.HOME:
		starts = perimeter(home.cell, home.get_footprint())
	var best: Array[Vector2i] = []
	for start in starts:
		if not village_map.is_walkable_cell(start) or future_footprint.has(start):
			continue
		for target in perimeter(origin, size):
			if not village_map.is_walkable_cell(target):
				continue
			var path := village_map.find_cell_path_avoiding(start, target, future_footprint)
			if not path.is_empty() and (best.is_empty() or path.size() < best.size()):
				best = path
	return best


func assign_job(building: VillageBuilding) -> bool:
	var route := find_site_path(building.cell, building.get_footprint())
	if route.is_empty():
		return false
	job = building
	sides_worked.clear()
	if state == State.HOME:
		_cell = route[0]
		global_position = _world(_cell)
	visible = true
	state = State.TO_SITE
	_site_side = _side_of(route[-1], building)
	_follow(route)
	_set_animation(&"run")
	return true


func finish_job() -> void:
	job = null
	_return_home()


func _process(delta: float) -> void:
	advance_behavior(delta)


func advance_behavior(delta: float) -> void:
	if village_map == null or not is_instance_valid(home) or delta <= 0.0:
		return
	if state in [State.TO_SITE, State.HAMMERING, State.CHANGING_SIDE] and (not is_instance_valid(job) or job.is_queued_for_deletion() or not job.is_under_construction()):
		finish_job()
	if state != State.HOME and _escape_cells.is_empty() and not village_map.is_walkable_cell(_cell):
		_escape_new_obstacle()
	_retry = maxf(0.0, _retry - delta)
	match state:
		State.HOME:
			_wait -= delta
			if _wait <= 0.0:
				begin_wander()
		State.WANDERING:
			_outing_left -= delta
			if _outing_left <= 0.0:
				_return_home()
			elif _path.is_empty():
				if not _pick_wander_path():
					_return_home()
		State.HAMMERING:
			_face(job.global_position - global_position)
			_work_left -= delta
			# Finish a full hammer swing before going to another edge.
			if _work_left <= 0.0 and fmod(_animation_time, float(_clips["hammer"]["duration"])) < delta:
				_change_work_side()
		State.RETURNING:
			if _path.is_empty() and _retry <= 0.0:
				_return_home()
		State.TO_SITE, State.CHANGING_SIDE:
			if _path.is_empty() and _retry <= 0.0:
				_retry_job_path()
	if not _path.is_empty():
		_move(delta)
	# Match the planted foot's backward travel to movement across the map.
	# The projection shortens north/south strides, so their cadence differs.
	var playback := 1.0
	if animation in [&"walk", &"run"]:
		var angle := facing * PI / 4.0
		var projection := Vector2(cos(angle), sin(angle) * float(ANIMATION_METADATA.data["ground_projection_y"])).length()
		var pixels_per_metre := sprite.scale.x * float(ANIMATION_METADATA.data["pixels_per_metre"]) * projection
		var speed := RUN_SPEED if animation == &"run" else WALK_SPEED
		playback = speed / (float(_clips[String(animation)]["ground_speed_mps"]) * pixels_per_metre)
	_animation_time += delta * playback
	_update_animation_frame()
	if state == State.HAMMERING:
		queue_redraw()


func begin_wander() -> bool:
	if not is_available() or not is_instance_valid(home):
		return false
	if state == State.HOME:
		var entrances := perimeter(home.cell, home.get_footprint())
		var found := false
		for cell in entrances:
			if village_map.is_walkable_cell(cell):
				_cell = cell
				global_position = _world(cell)
				found = true
				break
		if not found:
			_wait = 8.0
			return false
	state = State.WANDERING
	_outing_left = rng.randf_range(WALK_DURATION.x, WALK_DURATION.y)
	if not _pick_wander_path():
		_enter_home()
		return false
	visible = true
	_set_animation(&"walk")
	return true


func _pick_wander_path() -> bool:
	for attempt in range(16):
		var goal := home.cell + Vector2i(rng.randi_range(-3, 4), rng.randi_range(-3, 4))
		var path := village_map.find_cell_path(_cell, goal)
		if path.size() >= 2 and path.size() <= 7:
			_follow(path)
			return true
	return false


func _return_home() -> void:
	state = State.RETURNING
	# Finish stepping out of a newly overlapping footprint before routing home.
	if not _escape_cells.is_empty():
		_set_animation(&"walk")
		return
	_path.clear()
	var best: Array[Vector2i] = []
	for target in perimeter(home.cell, home.get_footprint()):
		var path := village_map.find_cell_path(_cell, target)
		if not path.is_empty() and (best.is_empty() or path.size() < best.size()):
			best = path
	if best.is_empty():
		_set_animation(&"idle")
		_retry = 1.0
		return
	_follow(best)
	_set_animation(&"walk")
	if _path.is_empty():
		_enter_home()


func _enter_home() -> void:
	visible = false
	state = State.HOME
	_path.clear()
	_wait = rng.randf_range(HOME_WAIT.x, HOME_WAIT.y)
	_set_animation(&"idle")
	var entrances := perimeter(home.cell, home.get_footprint())
	for cell in entrances:
		if village_map.is_walkable_cell(cell):
			_cell = cell
			global_position = _world(cell)
			break


func _retry_job_path() -> void:
	var path := find_site_path(job.cell, job.get_footprint())
	if path.is_empty():
		_set_animation(&"idle")
		_retry = 1.0
		return
	_site_side = _side_of(path[-1], job)
	_follow(path)
	if _path.is_empty():
		_start_hammering()
	else:
		_set_animation(&"run" if state == State.TO_SITE else &"walk")


func _change_work_side() -> void:
	var candidates := perimeter(job.cell, job.get_footprint())
	var start := rng.randi_range(0, candidates.size() - 1)
	for offset in range(candidates.size()):
		var goal: Vector2i = candidates[(start + offset) % candidates.size()]
		if _side_of(goal, job) == _site_side:
			continue
		var path := village_map.find_cell_path(_cell, goal)
		if path.is_empty():
			continue
		_site_side = _side_of(goal, job)
		state = State.CHANGING_SIDE
		_follow(path)
		_set_animation(&"walk")
		return
	# An enclosed edge may be the only reachable one; keep working there.
	_work_left = rng.randf_range(WORK_DURATION.x, WORK_DURATION.y)


func _start_hammering() -> void:
	state = State.HAMMERING
	_work_left = rng.randf_range(WORK_DURATION.x, WORK_DURATION.y)
	if not sides_worked.has(_site_side):
		sides_worked.append(_site_side)
	_face(job.global_position - global_position)
	_set_animation(&"hammer")


func _side_of(cell: Vector2i, building: VillageBuilding) -> int:
	if cell.y >= building.cell.y + building.get_footprint().y:
		return 0
	if cell.x < building.cell.x:
		return 1
	if cell.y < building.cell.y:
		return 2
	return 3


func _follow(path: Array[Vector2i]) -> void:
	_path = path.duplicate()
	if global_position.distance_to(_world(_path[0])) < 0.1:
		_path.pop_front()
	if not _path.is_empty():
		_face(_world(_path[0]) - global_position)


func _move(delta: float) -> void:
	var budget := (RUN_SPEED if state == State.TO_SITE else WALK_SPEED) * delta
	while budget > 0.0 and not _path.is_empty():
		var next: Vector2i = _path[0]
		if not village_map.is_walkable_cell(next) and not _escape_cells.has(next):
			# New walls/buildings can invalidate a route while the worker is moving.
			_path.clear()
			_set_animation(&"idle")
			_retry = 0.25
			return
		var target := _world(next)
		var displacement := target - global_position
		var distance := displacement.length()
		if distance > 0.01:
			_face(displacement)
		var step := minf(budget, distance)
		global_position = global_position.move_toward(target, step)
		budget -= step
		if step < distance:
			return
		_cell = next
		_path.pop_front()
	if not _path.is_empty():
		return
	if not _escape_cells.is_empty():
		_escape_cells.clear()
		if is_instance_valid(job) and job.is_under_construction():
			state = State.TO_SITE
			_retry_job_path()
		else:
			_return_home()
		return
	match state:
		State.TO_SITE, State.CHANGING_SIDE:
			_start_hammering()
		State.RETURNING:
			# Replan if the user moved the home hut while its worker was outside.
			if perimeter(home.cell, home.get_footprint()).has(_cell):
				_enter_home()
			else:
				_return_home()


func _escape_new_obstacle() -> void:
	var obstacle := village_map.get_building_at(_cell)
	if not is_instance_valid(obstacle):
		return
	var footprint := Rect2i(obstacle.cell, obstacle.get_footprint())
	var frontier: Array[Vector2i] = [_cell]
	var previous: Dictionary[Vector2i, Vector2i] = {_cell: _cell}
	var exit_cell := _cell
	while not frontier.is_empty():
		var current: Vector2i = frontier.pop_front()
		if village_map.is_walkable_cell(current):
			exit_cell = current
			break
		for step in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]:
			var neighbor: Vector2i = current + step
			if previous.has(neighbor):
				continue
			if village_map.is_walkable_cell(neighbor) or footprint.has_point(neighbor):
				previous[neighbor] = current
				frontier.append(neighbor)
	if exit_cell == _cell:
		_path.clear()
		_set_animation(&"idle")
		return
	var path: Array[Vector2i] = [exit_cell]
	while path[0] != _cell:
		path.push_front(previous[path[0]])
	_escape_cells = path.duplicate()
	state = State.TO_SITE if is_instance_valid(job) else State.RETURNING
	_follow(path)
	_set_animation(&"run" if is_instance_valid(job) else &"walk")


func _world(cell: Vector2i) -> Vector2:
	return village_map.to_global(village_map.cell_to_world(cell))


func _face(direction: Vector2) -> void:
	if direction.length_squared() < 0.01:
		return
	# Undo the 96:72 diamond compression before choosing the 8-way view.
	facing = posmod(roundi(Vector2(direction.x, direction.y / 0.75).angle() / (PI / 4.0)), 8)


func _set_animation(clip: StringName) -> void:
	if sprite == null:
		return
	if animation == clip and sprite.texture == SHEETS[clip]:
		return
	animation = clip
	_animation_time = 0.0
	sprite.texture = SHEETS[clip]
	var info: Dictionary = _clips[String(clip)]
	sprite.hframes = int(info["columns"])
	sprite.vframes = int(info["rows_per_direction"]) * 8
	_update_animation_frame()
	queue_redraw()


func _update_animation_frame() -> void:
	var info: Dictionary = _clips[String(animation)]
	var frame := int(_animation_time * float(info["fps"]) + 0.000001) % int(info["frames"])
	var columns := int(info["columns"])
	sprite.frame_coords = Vector2i(frame % columns, facing * int(info["rows_per_direction"]) + frame / columns)


func _draw() -> void:
	if state != State.HAMMERING:
		return
	var info: Dictionary = _clips["hammer"]
	var age := (fmod(_animation_time, float(info["duration"])) - float(info["impact_phase"]) * float(info["duration"])) / 0.32
	if age < 0.0 or age > 1.0:
		return
	var angle := facing * PI / 4.0
	var contact: Array = info["impact_local_m"]
	var projection_y := float(ANIMATION_METADATA.data["ground_projection_y"])
	var pixels_per_metre := sprite.scale.x * float(ANIMATION_METADATA.data["pixels_per_metre"])
	var forward := Vector2(cos(angle), sin(angle) * projection_y)
	var right := Vector2(cos(angle - PI / 2.0), sin(angle - PI / 2.0) * projection_y)
	var impact := (forward * float(contact[1]) + right * float(contact[0]) + Vector2(0, -float(contact[2]) * sqrt(1.0 - projection_y * projection_y))) * pixels_per_metre
	for i in range(5):
		var spread := (float(i) - 2.0) * 4.0
		var puff := impact + Vector2(spread * age, -age * 15.0)
		draw_circle(puff, 1.0 + age * 2.0, Color(0.89, 0.78, 0.56, (1.0 - age) * 0.5))
