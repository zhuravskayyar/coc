extends SceneTree

const FOLDER := "res://.godot/unit_motion/review"
var composite: SubViewport
var cells: Array[Dictionary] = []
var heading: Label


func _initialize() -> void:
	root.hide()
	call_deferred("_run")


func _run() -> void:
	composite = SubViewport.new()
	composite.size = Vector2i(1120, 1008)
	composite.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(composite)
	var background := ColorRect.new()
	background.size = Vector2(composite.size)
	background.color = Color("232a35")
	composite.add_child(background)
	heading = _label("UNIT MOTION / 30 FPS", Vector2(16, 12), 23)
	var row := 0
	for kind in ["archer", "militia", "builder"]:
		var column := 0
		var names: Array = ["Idle", "Walk", "Run", "archer_shoot" if kind == "archer" else "Attack" if kind == "militia" else "Hammer"]
		for clip in names:
			var viewport := SubViewport.new()
			viewport.size = Vector2i(256, 256)
			viewport.own_world_3d = true
			viewport.transparent_bg = true
			viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			root.add_child(viewport)
			var stage := Node3D.new()
			viewport.add_child(stage)
			var environment := Environment.new()
			environment.background_mode = Environment.BG_COLOR
			environment.background_color = Color(0, 0, 0, 0)
			environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
			environment.ambient_light_color = Color(0.83, 0.89, 1)
			environment.ambient_light_energy = 0.75
			var world := WorldEnvironment.new()
			world.environment = environment
			stage.add_child(world)
			for settings in [[Vector3(-38, -35, 0), 1.3, Color(1, 0.93, 0.84)], [Vector3(-15, 140, 0), 0.8, Color(0.78, 0.87, 1)]]:
				var light := DirectionalLight3D.new()
				light.rotation_degrees = settings[0]
				light.light_energy = settings[1]
				light.light_color = settings[2]
				stage.add_child(light)
			var model := load("res://assets/units/%s/%s_animated.glb" % [kind, kind]).instantiate() as Node3D
			stage.add_child(model)
			var camera := Camera3D.new()
			camera.projection = Camera3D.PROJECTION_ORTHOGONAL
			camera.size = 1.4
			stage.add_child(camera)
			var player := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
			player.speed_scale = 0
			var skeleton := model.find_child("Skeleton3D", true, false) as Skeleton3D
			var sprite := Sprite2D.new()
			sprite.centered = false
			sprite.position = Vector2(8 + column * 280, 98 + row * 304)
			sprite.texture = viewport.get_texture()
			composite.add_child(sprite)
			_label(kind.to_upper() + " / " + String(clip).replace("archer_shoot", "Shoot"), Vector2(16 + column * 280, 68 + row * 304), 18)
			cells.append({"player": player, "skeleton": skeleton, "camera": camera, "clip": String(clip), "model": model})
			column += 1
		row += 1
	DirAccess.make_dir_recursive_absolute(FOLDER)
	for frame in range(540):
		var section := frame / 90
		var view := section / 2
		var slow := section % 2 == 1
		var time := float(frame % 90) / 30.0 * (0.5 if slow else 1.0)
		heading.text = "UNIT MOTION / %s / %s / 30 FPS" % [["FRONT", "SIDE", "GAME VIEW"][view], "HALF SPEED" if slow else "NORMAL SPEED"]
		for cell in cells:
			var camera: Camera3D = cell["camera"]
			camera.position = [Vector3(0, 2.44, 4), Vector3(4, 2.44, 0), Vector3(3, 4.44, 4)][view]
			camera.look_at(Vector3(0, 0.44, 0))
			var player: AnimationPlayer = cell["player"]
			var clip: String = cell["clip"]
			var duration := player.get_animation(clip).length
			player.play(clip)
			player.seek(fposmod(time, duration), true)
			var skeleton: Skeleton3D = cell["skeleton"]
			skeleton.force_update_all_bone_transforms()
			for attachment in skeleton.find_children("*", "BoneAttachment3D", true, false):
				attachment.on_skeleton_update()
		await process_frame
		RenderingServer.force_draw(false)
		assert(composite.get_texture().get_image().save_png("%s/frame_%04d.png" % [FOLDER, frame]) == OK)
		if frame % 90 == 89:
			print("Motion review section %d complete" % section)
	print("Studio review: 540 real frames, front/side/game, normal and half speed")
	quit()


func _label(text: String, position: Vector2, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.position = position
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color("e8e5da"))
	composite.add_child(label)
	return label
