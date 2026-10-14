extends SceneTree

const POST_MODEL := preload("res://assets/buildings/palisade/fence_post.glb")
const BEAM_MODEL := preload("res://assets/buildings/palisade/fence_beam.glb")
const OUTPUT := "res://assets/sprites/buildings/palisade_3d_thumbnail.png"
const HALF_BEAM_LENGTH := 0.49


func _initialize() -> void:
	root.hide()
	call_deferred("_render_thumbnail")


func _render_thumbnail() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(768, 768)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)

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

	var fence := Node3D.new()
	viewport.add_child(fence)
	var beam := BEAM_MODEL.instantiate() as Node3D
	beam.name = "Fence_Beam"
	fence.add_child(beam)
	for x in [-HALF_BEAM_LENGTH, HALF_BEAM_LENGTH]:
		var post := POST_MODEL.instantiate() as Node3D
		post.name = "Fence_Post"
		post.position.x = x
		fence.add_child(post)

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 1.8
	camera.near = 0.01
	camera.far = 30.0
	viewport.add_child(camera)
	var target := Vector3(0, 0.37, 0)
	var elevation := asin(72.0 / 96.0)
	camera.position = target + Vector3(4, sqrt(32.0) * tan(elevation), 4)
	camera.look_at(target)
	camera.current = true

	for frame in range(4):
		await process_frame
	RenderingServer.force_draw(false)
	var image := viewport.get_texture().get_image()
	if image == null or image.is_empty():
		push_error("No image was rendered for the palisade thumbnail")
		quit(1)
		return
	var result := image.save_png(ProjectSettings.globalize_path(OUTPUT))
	print("Palisade thumbnail: ", result)
	quit(0 if result == OK else 1)
