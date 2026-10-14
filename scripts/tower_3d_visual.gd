@tool
class_name Tower3DVisual
extends Node

const TOWER_MODEL := preload("res://assets/buildings/defense_tower/wooden_tower.glb")
const ARCHER_MODEL := preload("res://assets/units/archer/archer_animated.glb")
const ARCHER_METADATA: JSON = preload("res://assets/sprites/units/archer_animations.json")
const VIEW_SIZE := Vector2i(512, 640)
# The supplied model's wooden platform is at Y=0.735; its ground is at Y=0.
const PLATFORM_POSITION := Vector3(0.02, 0.737, -0.015)
const CLIPS := {&"idle": &"Idle", &"attack": &"archer_shoot"}

var viewport: SubViewport
var camera: Camera3D
var tower: Node3D
var archer: Node3D
var player: AnimationPlayer
var skeleton: Skeleton3D
var bow_muzzle: Node3D
var held_arrow: Node3D
var hand_attachments: Array[BoneAttachment3D] = []
var draw_scale := 1.0
var ground_anchor := Vector2.ZERO
var ground_source_width := 1.0


func _ready() -> void:
	viewport = SubViewport.new()
	viewport.name = "TowerViewport"
	viewport.size = VIEW_SIZE
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(viewport)
	tower = TOWER_MODEL.instantiate() as Node3D
	viewport.add_child(tower)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.82, 0.88, 0.95)
	environment.environment.ambient_light_energy = 0.8
	viewport.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -40, 0)
	sun.light_color = Color(1.0, 0.94, 0.84)
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	viewport.add_child(sun)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.0
	camera.near = 0.01
	camera.far = 30.0
	viewport.add_child(camera)
	var target := Vector3(0, 0.45, 0)
	# sin(elevation)=72/96, matching the village's two ground axes.
	var elevation := asin(VillageMap.TILE_SIZE.y / VillageMap.TILE_SIZE.x)
	camera.position = target + Vector3(4, sqrt(32.0) * tan(elevation), 4)
	camera.look_at(target)
	camera.current = true
	ground_anchor = camera.unproject_position(Vector3.ZERO)
	var foundation := tower.find_child("tripo_part_0", true, false) as MeshInstance3D
	var bounds := foundation.get_aabb()
	var left := INF
	var right := -INF
	for x in [bounds.position.x, bounds.end.x]:
		for z in [bounds.position.z, bounds.end.z]:
			var point := camera.unproject_position(foundation.to_global(Vector3(x, -foundation.position.y, z)))
			left = minf(left, point.x)
			right = maxf(right, point.x)
	ground_source_width = right - left


func configure_ground_width(width: float) -> void:
	draw_scale = width / ground_source_width
	if is_instance_valid(archer):
		_scale_archer()


func get_texture() -> Texture2D:
	return viewport.get_texture()


func get_draw_rect() -> Rect2:
	return Rect2(-ground_anchor * draw_scale, Vector2(VIEW_SIZE) * draw_scale)


func project_point(point: Vector3) -> Vector2:
	return (camera.unproject_position(point) - ground_anchor) * draw_scale


func get_station_offset() -> Vector2:
	return project_point(PLATFORM_POSITION)


func set_archer_enabled(enabled: bool) -> void:
	if enabled and not is_instance_valid(archer):
		archer = ARCHER_MODEL.instantiate() as Node3D
		archer.name = "StationedArcher"
		viewport.add_child(archer)
		archer.position = PLATFORM_POSITION
		_scale_archer()
		player = archer.find_child("AnimationPlayer", true, false) as AnimationPlayer
		skeleton = archer.find_child("Skeleton3D", true, false) as Skeleton3D
		bow_muzzle = archer.find_child("BowMuzzle", true, false) as Node3D
		held_arrow = archer.find_child("HeldArrow", true, false) as Node3D
		for node in archer.find_children("*", "BoneAttachment3D", true, false):
			hand_attachments.append(node as BoneAttachment3D)
		# The existing unit clock drives both the pose and the projectile release.
		player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	if is_instance_valid(archer):
		archer.visible = enabled
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if enabled else SubViewport.UPDATE_ONCE


func _scale_archer() -> void:
	var pixels_per_metre := float(VIEW_SIZE.y) / camera.size * draw_scale
	var metadata: Dictionary = ARCHER_METADATA.data
	archer.scale = Vector3.ONE * float(metadata["world_scale"]) * float(metadata["pixels_per_metre"]) / pixels_per_metre


func sync_archer(clip: StringName, time: float, facing: int) -> void:
	if not is_instance_valid(archer) or not archer.visible:
		return
	var angle := facing * PI / 4.0
	var camera_right := camera.global_basis.x
	var camera_out := Vector3(camera.position.x, 0, camera.position.z).normalized()
	var forward := camera_right * cos(angle) + camera_out * sin(angle)
	# The exported character and bow face +Z in Godot.
	archer.rotation.y = atan2(forward.x, forward.z)
	var source_clip: StringName = CLIPS.get(clip, &"Idle")
	if player.current_animation != source_clip:
		player.play(source_clip)
	var duration := player.get_animation(source_clip).length
	var sample := clampf(time, 0.0, duration - 0.000001) if clip == &"attack" else fposmod(time, duration)
	player.seek(sample, true)
	# BoneAttachment3D must follow the sampled hand before projecting BowMuzzle.
	skeleton.force_update_all_bone_transforms()
	# skeleton_updated normally arrives at frame end; release needs these transforms now.
	for attachment in hand_attachments:
		attachment.on_skeleton_update()


func get_muzzle_position() -> Vector2:
	return project_point(bow_muzzle.global_position)
