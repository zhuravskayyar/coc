extends SceneTree

const FOLDER := "res://.godot/unit_motion"
const SETTINGS := {
	"archer": {"Idle": [60, 30], "Walk": [40, 30], "Run": [56, 60], "archer_shoot": [27, 30]},
	"militia": {"Idle": [60, 30], "Walk": [80, 60], "Run": [56, 60], "Attack": [60, 60]},
	"builder": {"Idle": [60, 30], "Walk": [80, 60], "Run": [56, 60], "Hammer": [72, 60]},
}
var viewport: SubViewport
var stage: Node3D
var camera: Camera3D


func _initialize() -> void:
	root.hide()
	call_deferred("_run")


func _run() -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(256, 256)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	stage = Node3D.new()
	viewport.add_child(stage)
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0, 0, 0, 0)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.83, 0.89, 1)
	environment.ambient_light_energy = 0.75
	world.environment = environment
	stage.add_child(world)
	for settings in [[Vector3(-38, -35, 0), 1.3, Color(1, 0.93, 0.84)], [Vector3(-15, 140, 0), 0.8, Color(0.78, 0.87, 1)]]:
		var light := DirectionalLight3D.new()
		light.rotation_degrees = settings[0]
		light.light_energy = settings[1]
		light.light_color = settings[2]
		stage.add_child(light)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 1.52
	camera.position = Vector3(3, 4, 4) + Vector3(0, 0.44, 0)
	stage.add_child(camera)
	camera.look_at(Vector3(0, 0.44, 0))
	for kind in SETTINGS:
		if not OS.get_cmdline_user_args().is_empty() and kind != OS.get_cmdline_user_args()[0]:
			continue
		var model := load("res://assets/units/%s/%s_animated.glb" % [kind, kind]).instantiate() as Node3D
		stage.add_child(model)
		var player := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
		assert(player != null)
		player.set_process(false)
		player.set_physics_process(false)
		player.speed_scale = 0.0
		var skeleton := model.find_child("Skeleton3D", true, false) as Skeleton3D
		assert(skeleton != null and skeleton.get_bone_count() == 65)
		var anchor := camera.unproject_position(Vector3.ZERO)
		var metadata := {"frame_size": [256, 256], "ground_anchor": [anchor.x, anchor.y], "world_scale": 0.5, "directions": 8, "pixels_per_metre": 256.0 / camera.size, "ground_projection_y": 0.624695, "source": "assets/units/%s/%s_animated.glb" % [kind, kind], "skeleton_bones": 65, "direction_order": "E, SE, S, SW, W, NW, N, NE", "direction_yaws": [], "direction_ground_projection": [], "clips": {}}
		var folder: String = FOLDER + "/" + kind
		DirAccess.make_dir_recursive_absolute(folder)
		for direction in range(8):
			var angle := direction * PI / 4.0
			var target := Vector2(cos(angle), sin(angle) * 0.75)
			# Find the ground-space forward vector whose projection is the requested diamond direction.
			var bx := camera.unproject_position(Vector3(1, 0, 0)) - anchor
			var bz := camera.unproject_position(Vector3(0, 0, 1)) - anchor
			var ground := Transform2D(bx, bz, Vector2.ZERO).basis_xform_inv(target).normalized()
			var yaw := atan2(ground.x, ground.y)
			model.rotation.y = yaw
			metadata["direction_yaws"].append(yaw)
			var projection := (camera.unproject_position(Vector3(ground.x, 0, ground.y)) - anchor).length() / (256.0 / camera.size)
			metadata["direction_ground_projection"].append(projection)
			for source_clip in SETTINGS[kind]:
				var config: Array = SETTINGS[kind][source_clip]
				var count := int(config[0])
				var fps := int(config[1])
				var clip := "attack" if source_clip in ["Attack", "archer_shoot"] else String(source_clip).to_lower()
				player.play(source_clip)
				var columns := ceili(float(count) / 3.0)
				var info := {"frames": count, "fps": fps, "duration": float(count) / fps, "columns": columns, "rows_per_direction": 3, "texture": "res://assets/sprites/units/%s_%s_sheet.png" % [kind, clip], "source_animation": source_clip}
				if clip in ["walk", "run"]:
					var bone := skeleton.find_bone("mixamorig_LeftToeBase")
					if bone < 0:
						bone = skeleton.find_bone("mixamorig:LeftToeBase")
					assert(bone >= 0)
					info["ground_speed_mps"] = _ground_speed(player, skeleton, bone, source_clip, count, fps)
				if clip == "hammer":
					info["impact_phase"] = 0.60
					info["impact_positions"] = [] if direction == 0 else metadata["clips"][clip]["impact_positions"]
					_seek(player, skeleton, source_clip, float(count) / fps * 0.60)
					var marker := model.find_child("HammerImpact", true, false) as Node3D
					assert(marker != null)
					var impact := camera.unproject_position(marker.global_position)
					info["impact_positions"].append([impact.x, impact.y])
				if kind == "archer":
					info["held_arrow_visible"] = []
					if clip == "attack":
						info["release_frame"] = 15
						info["muzzle_positions"] = [] if direction == 0 else metadata["clips"][clip]["muzzle_positions"]
						info["muzzle_positions"].append([])
				for frame in range(count):
					_seek(player, skeleton, source_clip, float(frame) / fps)
					if kind == "archer":
						info["held_arrow_visible"].append(clip == "attack" and frame < 15)
						if clip == "attack":
							var marker := model.find_child("BowMuzzle", true, false) as Node3D
							var point := camera.unproject_position(marker.global_position)
							info["muzzle_positions"][direction].append([point.x, point.y])
					await process_frame
					RenderingServer.force_draw(false)
					assert(viewport.get_texture().get_image().save_png("%s/%s_%d_%03d.png" % [folder, clip, direction, frame]) == OK)
				metadata["clips"][clip] = info
			if kind == "archer":
				if direction == 0:
					metadata["projectile"] = {"texture": "res://assets/sprites/units/archer_arrow_sheet.png", "frame_size": [256, 256], "pivots": [], "angles": []}
				_seek(player, skeleton, "archer_shoot", 0.4)
				var held := model.find_child("HeldArrow", true, false) as MeshInstance3D
				for mesh in model.find_children("*", "MeshInstance3D", true, false):
					mesh.visible = mesh == held
				var nock := model.find_child("ArrowNock", true, false) as Node3D
				var tip := model.find_child("ArrowTip", true, false) as Node3D
				var pivot := camera.unproject_position(nock.global_position)
				var arrow_angle := (camera.unproject_position(tip.global_position) - pivot).angle()
				metadata["projectile"]["pivots"].append([pivot.x, pivot.y])
				metadata["projectile"]["angles"].append(arrow_angle)
				await process_frame
				RenderingServer.force_draw(false)
				assert(viewport.get_texture().get_image().save_png("%s/arrow_%d.png" % [folder, direction]) == OK)
				for mesh in model.find_children("*", "MeshInstance3D", true, false):
					mesh.visible = mesh != held
			print("Unit frames %s direction %d" % [kind, direction])
		var file := FileAccess.open(folder + "/metadata.json", FileAccess.WRITE)
		file.store_string(JSON.stringify(metadata, "\t"))
		model.free()
	print("All unit source frames rendered")
	quit()


func _seek(player: AnimationPlayer, skeleton: Skeleton3D, clip: String, time: float) -> void:
	player.play(clip)
	player.seek(time, true)
	skeleton.force_update_all_bone_transforms()
	for attachment in skeleton.find_children("*", "BoneAttachment3D", true, false):
		attachment.on_skeleton_update()


func _ground_speed(player: AnimationPlayer, skeleton: Skeleton3D, bone: int, clip: String, count: int, fps: int) -> float:
	var samples: Array[Vector3] = []
	var floor_y := INF
	for i in range(count):
		_seek(player, skeleton, clip, float(i) / fps)
		var point := skeleton.get_bone_global_pose(bone).origin
		samples.append(point)
		floor_y = minf(floor_y, point.y)
	var velocities: Array[float] = []
	for i in range(count - 1):
		if maxf(samples[i].y, samples[i + 1].y) < floor_y + 0.008:
			var speed := (samples[i].z - samples[i + 1].z) * fps
			if speed > 0.05:
				velocities.append(speed)
	velocities.sort()
	assert(not velocities.is_empty(), "No planted stance in " + clip)
	return velocities[velocities.size() / 2]
