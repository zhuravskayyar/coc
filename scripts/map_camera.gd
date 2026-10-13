extends Camera2D

const ZOOM_STEP := 1.15
const MIN_ZOOM := 0.30
const MAX_ZOOM := 1.8

@onready var village_map: VillageMap = $"../VillageMap"

var min_zoom := MIN_ZOOM
var _touches: Dictionary[int, Vector2] = {}


func _ready() -> void:
	ignore_rotation = true
	rotation = 0.0
	get_viewport().size_changed.connect(_on_viewport_resized)
	_update_min_zoom()
	zoom = Vector2.ONE * min_zoom
	global_position = village_map.get_map_rect().get_center()
	force_update_scroll()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = event.position
		else:
			_touches.erase(event.index)
	elif event is InputEventScreenDrag:
		_handle_touch_drag(event)
	elif event is InputEventMouseButton and _touches.is_empty():
		if not event.pressed:
			return
		var step := pow(ZOOM_STEP, event.factor if event.factor > 0.0 else 1.0)
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_at(zoom.x * step, event.position)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_at(zoom.x / step, event.position)
	elif event is InputEventMouseMotion and _touches.is_empty():
		if (event.button_mask & MOUSE_BUTTON_MASK_RIGHT) != 0:
			_pan_by(event.relative)
	elif event is InputEventMagnifyGesture and _touches.is_empty():
		_zoom_at(zoom.x * event.factor, event.position)
	elif event is InputEventPanGesture and _touches.is_empty():
		_pan_by(-event.delta * 24.0)


func _handle_touch_drag(event: InputEventScreenDrag) -> void:
	if not _touches.has(event.index):
		return
	if _touches.size() == 1:
		var previous: Vector2 = _touches[event.index]
		_touches[event.index] = event.position
		_pan_by(event.position - previous)
		return
	if _touches.size() != 2:
		_touches[event.index] = event.position
		return

	var indices := _touches.keys()
	var old_first: Vector2 = _touches[indices[0]]
	var old_second: Vector2 = _touches[indices[1]]
	var old_midpoint := (old_first + old_second) * 0.5
	var old_distance := old_first.distance_to(old_second)
	var anchored_world := _world_at_screen(old_midpoint)

	_touches[event.index] = event.position
	var new_first: Vector2 = _touches[indices[0]]
	var new_second: Vector2 = _touches[indices[1]]
	var new_midpoint := (new_first + new_second) * 0.5
	var new_distance := new_first.distance_to(new_second)
	if old_distance > 1.0 and new_distance > 1.0:
		zoom = Vector2.ONE * clampf(zoom.x * new_distance / old_distance, min_zoom, MAX_ZOOM)
	global_position = anchored_world - _screen_to_world_offset(new_midpoint)
	_clamp_position()
	force_update_scroll()


func _zoom_at(new_zoom: float, screen_anchor: Vector2) -> void:
	var anchored_world := _world_at_screen(screen_anchor)
	zoom = Vector2.ONE * clampf(new_zoom, min_zoom, MAX_ZOOM)
	global_position = anchored_world - _screen_to_world_offset(screen_anchor)
	_clamp_position()
	force_update_scroll()


func _pan_by(screen_delta: Vector2) -> void:
	global_position -= screen_delta / zoom.x
	_clamp_position()
	force_update_scroll()


func _world_at_screen(screen_position: Vector2) -> Vector2:
	return global_position + _screen_to_world_offset(screen_position)


func _screen_to_world_offset(screen_position: Vector2) -> Vector2:
	return (screen_position - _viewport_size() * 0.5) / zoom.x


func _clamp_position() -> void:
	var map_rect := village_map.get_map_rect()
	var view_size := _viewport_size() / zoom.x
	var travel := ((map_rect.size - view_size) * 0.5).max(Vector2.ZERO)
	travel += VillageMap.TILE_SIZE
	var center := map_rect.get_center()
	global_position = global_position.clamp(center - travel, center + travel)


func _update_min_zoom() -> void:
	# The farthest view matches the user's reference, not the whole map.
	min_zoom = MIN_ZOOM


func _on_viewport_resized() -> void:
	var was_fully_zoomed_out := is_equal_approx(zoom.x, min_zoom)
	_update_min_zoom()
	zoom = Vector2.ONE * (min_zoom if was_fully_zoomed_out else clampf(zoom.x, min_zoom, MAX_ZOOM))
	_clamp_position()
	force_update_scroll()


func _viewport_size() -> Vector2:
	return get_viewport_rect().size


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_touches.clear()
