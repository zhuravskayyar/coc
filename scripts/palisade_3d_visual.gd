@tool
class_name Palisade3DVisual
extends Node

const POST_MODEL := preload("res://assets/buildings/palisade/fence_post.glb")
const BEAM_MODEL := preload("res://assets/buildings/palisade/fence_beam.glb")
const VIEW_SIZE := Vector2i(256, 256)
const MODEL_HALF_LENGTH := 0.49

static var _shared_visuals: Dictionary = {}
static var _shared_root: Node

var viewport: SubViewport
var camera: Camera3D
var model_root: Node3D
var models: Array[Node3D] = []
var connection_mask := -1
var include_all_connections := false
var draw_scale := 1.0
var ground_anchor := Vector2.ZERO
var source_edge_length := 1.0
var alpha_image: Image


static func get_shared_visual(mask: int, preview: bool = false) -> Palisade3DVisual:
	mask &= 15
	var cache_key := mask + (16 if preview else 0)
	var cached := _shared_visuals.get(cache_key) as Palisade3DVisual
	if is_instance_valid(cached):
		return cached
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	if not is_instance_valid(_shared_root):
		_shared_root = tree.root.get_node_or_null("PalisadeVisualCache")
		if not is_instance_valid(_shared_root):
			_shared_root = Node.new()
			_shared_root.name = "PalisadeVisualCache"
			tree.root.add_child(_shared_root)
	var node_name := "Mask%02d%s" % [mask, "Preview" if preview else ""]
	var existing := _shared_root.get_node_or_null(node_name) as Palisade3DVisual
	if is_instance_valid(existing):
		_shared_visuals[cache_key] = existing
		return existing
	var visual := Palisade3DVisual.new()
	visual.name = node_name
	visual.connection_mask = mask
	visual.include_all_connections = preview
	_shared_root.add_child(visual)
	visual.configure_ground_edge_size()
	_shared_visuals[cache_key] = visual
	return visual


func _ready() -> void:
	viewport = SubViewport.new()
	viewport.name = "PalisadeViewport"
	viewport.size = VIEW_SIZE
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(viewport)

	model_root = Node3D.new()
	model_root.name = "PalisadeModels"
	viewport.add_child(model_root)

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
	var target := Vector3(0, 0.37, 0)
	var elevation := asin(VillageMap.TILE_SIZE.y / VillageMap.TILE_SIZE.x)
	camera.position = target + Vector3(4, sqrt(32.0) * tan(elevation), 4)
	camera.look_at(target)
	camera.current = true
	ground_anchor = camera.unproject_position(Vector3.ZERO)
	var left := camera.unproject_position(Vector3(-MODEL_HALF_LENGTH, 0, 0))
	var right := camera.unproject_position(Vector3(MODEL_HALF_LENGTH, 0, 0))
	source_edge_length = left.distance_to(right)
	configure_connection_mask(maxi(connection_mask, 0), include_all_connections)


func configure_connection_mask(mask: int, preview: bool = false) -> void:
	mask &= 15
	if connection_mask == mask and include_all_connections == preview and not models.is_empty():
		return
	connection_mask = mask
	include_all_connections = preview
	if not is_instance_valid(model_root):
		return
	for model in models:
		if is_instance_valid(model):
			model.queue_free()
	models.clear()

	var post := POST_MODEL.instantiate() as Node3D
	if post == null:
		push_error("Could not instantiate Fence_Post")
		return
	post.name = "Fence_Post"
	model_root.add_child(post)
	models.append(post)

	# Runtime walls own only east/south edges, so every beam between two posts is drawn once.
	# The placement preview includes all four directions because adjacent walls are not rebuilt yet.
	if (mask & 2) != 0:
		_add_beam("Fence_Beam_E", Vector3(MODEL_HALF_LENGTH, 0.0, 0.0), 0.0)
	if (mask & 4) != 0:
		_add_beam("Fence_Beam_S", Vector3(0.0, 0.0, MODEL_HALF_LENGTH), -PI * 0.5)
	if preview and (mask & 8) != 0:
		_add_beam("Fence_Beam_W", Vector3(-MODEL_HALF_LENGTH, 0.0, 0.0), 0.0)
	if preview and (mask & 1) != 0:
		_add_beam("Fence_Beam_N", Vector3(0.0, 0.0, -MODEL_HALF_LENGTH), -PI * 0.5)

	alpha_image = null
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	call_deferred("_cache_alpha_image")


func _add_beam(node_name: String, position: Vector3, rotation_y: float) -> void:
	var beam := BEAM_MODEL.instantiate() as Node3D
	if beam == null:
		push_error("Could not instantiate Fence_Beam")
		return
	beam.name = node_name
	beam.position = position
	beam.rotation.y = rotation_y
	model_root.add_child(beam)
	models.append(beam)


func configure_ground_edge_size(size: Vector2 = Vector2(VillageMap.TILE_SIZE.x * 0.5, VillageMap.TILE_SIZE.y * 0.5)) -> void:
	if source_edge_length <= 0.0:
		return
	draw_scale = size.length() / source_edge_length


func get_texture() -> Texture2D:
	return viewport.get_texture() if is_instance_valid(viewport) else null


func get_draw_rect() -> Rect2:
	return Rect2(-ground_anchor * draw_scale, Vector2(VIEW_SIZE) * draw_scale)


func project_point(point: Vector3) -> Vector2:
	if not is_instance_valid(camera) or not camera.is_inside_tree():
		return Vector2.ZERO
	return (camera.unproject_position(point) - ground_anchor) * draw_scale


func hit_test(point: Vector2, draw_rect: Rect2) -> bool:
	if alpha_image == null or not draw_rect.has_point(point):
		return false
	var uv := (point - draw_rect.position) / draw_rect.size
	var pixel := Vector2i(uv * Vector2(alpha_image.get_size()))
	pixel.x = clampi(pixel.x, 0, alpha_image.get_width() - 1)
	pixel.y = clampi(pixel.y, 0, alpha_image.get_height() - 1)
	return alpha_image.get_pixelv(pixel).a > 0.5


func _cache_alpha_image() -> void:
	await RenderingServer.frame_post_draw
	if is_instance_valid(viewport):
		var texture := viewport.get_texture()
		if texture != null:
			alpha_image = texture.get_image()
