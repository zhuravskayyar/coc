class_name ArcherUnit
extends VillageUnit

signal arrow_fired(projectile: ArrowProjectile)

const ARROW_PROJECTILE := preload("res://scenes/units/arrow_projectile.tscn")
const ARCHER_SHEETS := {
	&"idle": preload("res://assets/sprites/units/archer_idle_sheet.png"),
	&"walk": preload("res://assets/sprites/units/archer_walk_sheet.png"),
	&"run": preload("res://assets/sprites/units/archer_run_sheet.png"),
	&"attack": preload("res://assets/sprites/units/archer_attack_sheet.png"),
}
const ARCHER_METADATA: JSON = preload("res://assets/sprites/units/archer_animations.json")
const LOCOMOTION_BLEND_DURATION := 0.15
const LOCOMOTION_CLIPS := [&"idle", &"walk", &"run"]
const LOCOMOTION_BLEND_SHADER := """
shader_type canvas_item;
uniform sampler2D previous_sheet : source_color, filter_linear_mipmap;
uniform vec2 current_origin;
uniform vec2 current_size;
uniform vec2 previous_origin;
uniform vec2 previous_size;
uniform float blend_amount = 1.0;
varying vec4 sprite_tint;
void vertex() {
	sprite_tint = COLOR;
}
void fragment() {
	vec2 frame_uv = (UV - current_origin) / current_size;
	vec4 previous = texture(previous_sheet, previous_origin + frame_uv * previous_size);
	vec4 current = texture(TEXTURE, UV);
	vec4 mixed = mix(vec4(previous.rgb * previous.a, previous.a), vec4(current.rgb * current.a, current.a), blend_amount);
	COLOR = vec4(mixed.rgb / max(mixed.a, 0.000001), mixed.a) * sprite_tint;
}
"""

@export var projectile_speed := 320.0
@export var projectile_lifetime := 3.0
@export var muzzle_offset := Vector2.ZERO
var current_target_position := Vector2.ZERO
var _projectile_fired := false
var _blend_material: ShaderMaterial
var _previous_clip: StringName = &""
var _previous_time := 0.0
var _blend_elapsed := 0.0
var _previous_playback := 1.0

@onready var bow_muzzle: Marker2D = $BowMuzzle


func set_animation(clip: StringName) -> void:
	if animation == clip and sprite.texture == get_animation_sheets()[clip] and clip != &"attack":
		return
	var old_clip := animation
	var old_time := _animation_time
	var old_playback := get_locomotion_playback(RUN_SPEED if old_clip == &"run" else WALK_SPEED) if old_clip in [&"walk", &"run"] else 1.0
	var can_blend := old_clip in LOCOMOTION_CLIPS and clip in LOCOMOTION_CLIPS
	_finish_locomotion_blend()
	super.set_animation(clip)
	if old_clip in [&"walk", &"run"] and clip in [&"walk", &"run"]:
		# Both clips start at the same foot contact, so switching gait keeps that foot's phase.
		_animation_time = fposmod(old_time, _clip_duration(old_clip)) / _clip_duration(old_clip) * _clip_duration(clip)
	if can_blend:
		_previous_clip = old_clip
		_previous_time = old_time
		_previous_playback = old_playback
		_blend_elapsed = 0.0
		if _blend_material == null:
			var shader := Shader.new()
			shader.code = LOCOMOTION_BLEND_SHADER
			_blend_material = ShaderMaterial.new()
			_blend_material.shader = shader
		_blend_material.set_shader_parameter("previous_sheet", get_animation_sheets()[old_clip])
		sprite.material = _blend_material
	_update_frame()


func advance_behavior(delta: float) -> void:
	super.advance_behavior(delta)
	if delta <= 0.0 or _previous_clip == &"":
		return
	_blend_elapsed += delta
	if _blend_elapsed >= LOCOMOTION_BLEND_DURATION:
		_finish_locomotion_blend()
		return
	if _previous_clip in [&"walk", &"run"] and animation in [&"walk", &"run"]:
		_previous_time = fposmod(_animation_time, _clip_duration(animation)) / _clip_duration(animation) * _clip_duration(_previous_clip)
	else:
		_previous_time += delta * _previous_playback
	_update_locomotion_blend()


func get_locomotion_playback(speed: float) -> float:
	var metadata := get_animation_metadata()
	var projections: Array = metadata.get("direction_ground_projection", [])
	if projections.size() != 8:
		return super.get_locomotion_playback(speed)
	var info: Dictionary = _clips[String(animation)] if animation in [&"walk", &"run"] else _clips["walk"]
	var rendered_speed := float(info["ground_speed_mps"]) * absf(sprite.scale.x) * float(metadata["pixels_per_metre"]) * float(projections[facing])
	return speed / maxf(rendered_speed, 0.000001)


func _clip_duration(clip: StringName) -> float:
	var info: Dictionary = _clips[String(clip)]
	return float(info["frames"]) / float(info["fps"])


func _finish_locomotion_blend() -> void:
	_previous_clip = &""
	_blend_elapsed = 0.0
	if is_instance_valid(sprite):
		sprite.material = null


func _update_locomotion_blend() -> void:
	if _previous_clip == &"":
		return
	var previous: Dictionary = _clips[String(_previous_clip)]
	var columns := int(previous["columns"])
	var rows := int(previous["rows_per_direction"]) * 8
	var frame := int(_previous_time * float(previous["fps"]) + 0.000001) % int(previous["frames"])
	var previous_coords := Vector2(frame % columns, facing * int(previous["rows_per_direction"]) + frame / columns)
	_blend_material.set_shader_parameter("current_origin", Vector2(sprite.frame_coords) / Vector2(sprite.hframes, sprite.vframes))
	_blend_material.set_shader_parameter("current_size", Vector2.ONE / Vector2(sprite.hframes, sprite.vframes))
	_blend_material.set_shader_parameter("previous_origin", previous_coords / Vector2(columns, rows))
	_blend_material.set_shader_parameter("previous_size", Vector2.ONE / Vector2(columns, rows))
	_blend_material.set_shader_parameter("blend_amount", smoothstep(0.0, LOCOMOTION_BLEND_DURATION, _blend_elapsed))


func shoot_at(target_position: Vector2) -> void:
	attack_toward(target_position)


func attack_toward(world_target: Vector2) -> void:
	if _attack_active or world_target.distance_squared_to(global_position) < 0.0001:
		return
	current_target_position = world_target
	_projectile_fired = false
	super.attack_toward(world_target)


func _release_attack() -> void:
	fire_arrow()


func fire_arrow() -> void:
	if not _attack_active or not _attack_released or _projectile_fired:
		return
	_projectile_fired = true
	var release_frame := int(_clips["attack"]["release_frame"])
	bow_muzzle.position = _muzzle_position(release_frame)
	var origin := bow_muzzle.global_position
	var direction := origin.direction_to(current_target_position)
	if direction.is_zero_approx():
		direction = _attack_direction
	var projectile := ARROW_PROJECTILE.instantiate() as ArrowProjectile
	# A sibling lives in world coordinates and keeps moving if the archer turns.
	get_parent().add_child(projectile)
	projectile.global_position = origin
	projectile.launch(direction, facing, projectile_speed, projectile_lifetime, sprite.scale.x)
	ranged_attack_released.emit(origin, direction)
	arrow_fired.emit(projectile)


func reset_held_arrow() -> void:
	# Visibility is baked: idle has no arrow; the next attack supplies it again.
	if not _attack_active:
		set_animation(&"idle")


func is_held_arrow_visible() -> bool:
	if animation != &"attack":
		return false
	var info: Dictionary = _clips["attack"]
	var frame := mini(int(_animation_time * float(info["fps"]) + 0.000001), int(info["frames"]) - 1)
	return bool(info["held_arrow_visible"][frame])


func _update_frame() -> void:
	super._update_frame()
	_update_locomotion_blend()
	if animation == &"attack" and is_instance_valid(bow_muzzle):
		var frame := mini(int(_animation_time * float(_clips["attack"]["fps"]) + 0.000001), int(_clips["attack"]["frames"]) - 1)
		bow_muzzle.position = _muzzle_position(frame)


func _muzzle_position(frame: int) -> Vector2:
	var point: Array = _clips["attack"]["muzzle_positions"][facing][frame]
	return sprite.position + (Vector2(float(point[0]), float(point[1])) + sprite.offset) * sprite.scale + muzzle_offset


func get_animation_sheets() -> Dictionary:
	return ARCHER_SHEETS


func get_animation_metadata() -> Dictionary:
	return ARCHER_METADATA.data
