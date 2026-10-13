extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void:
	root.hide()
	call_deferred("_run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(256, 256)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var unit := load("res://scenes/units/archer.tscn").instantiate() as ArcherUnit
	viewport.add_child(unit)
	unit.set_process(false)
	unit.position = Vector2(64, 64)
	unit._wait = 1000.0
	var map := VillageMap.new()
	unit.village_map = map
	var metadata := unit.get_animation_metadata()
	var projections: Array = metadata.get("direction_ground_projection", [])
	check(projections.size() == 8, "Metadata supplies all eight measured facing projections")
	if projections.size() != 8:
		map.free()
		quit(1)
		return
	for clip in [&"idle", &"walk", &"run"]:
		unit.set_animation(clip)
		check(not unit.is_held_arrow_visible(), "%s has no held arrow" % clip)
		var info: Dictionary = unit._clips[String(clip)]
		var visibility: Array = info.get("held_arrow_visible", [])
		check(visibility.size() == int(info["frames"]) and visibility.all(func(value: Variant) -> bool: return not bool(value)), "%s metadata hides the arrow across the whole locomotion cycle" % clip)
	for clip in [&"walk", &"run"]:
		unit.set_animation(clip)
		var speed := VillageUnit.RUN_SPEED if clip == &"run" else VillageUnit.WALK_SPEED
		var clip_info: Dictionary = unit._clips[String(clip)]
		var minimum_pose_fps := INF
		for view in range(8):
			unit.facing = view
			var effective_pose_fps := float(clip_info["fps"]) * unit.get_locomotion_playback(speed)
			minimum_pose_fps = minf(minimum_pose_fps, effective_pose_fps)
			check(effective_pose_fps >= 30.0, "%s facing %s supplies at least 30 distinct poses/s at actual gameplay speed (%s)" % [clip, view, effective_pose_fps])
		print("Archer %s minimum effective pose rate: %.3f FPS" % [clip, minimum_pose_fps])
	unit.set_animation(&"walk")
	var walk_duration := unit._clip_duration(&"walk")
	unit._animation_time = walk_duration * 0.375
	unit._update_frame()
	unit.set_animation(&"run")
	var run_duration := unit._clip_duration(&"run")
	check(is_equal_approx(unit._animation_time / run_duration, 0.375), "Walk to Run preserves foot phase")
	check(unit.sprite.material != null and unit._previous_clip == &"walk", "Locomotion starts a sprite blend")
	var info: Dictionary = unit._clips["run"]
	for view in range(8):
		unit.facing = view
		var expected := VillageUnit.RUN_SPEED / (float(info["ground_speed_mps"]) * unit.sprite.scale.x * float(metadata["pixels_per_metre"]) * float(projections[view]))
		check(is_equal_approx(unit.get_locomotion_playback(VillageUnit.RUN_SPEED), expected), "Playback uses the measured projection for facing %s" % view)
	var old_time := unit._previous_time
	unit.advance_behavior(0.05)
	check(unit._previous_time != old_time, "Previous locomotion pose keeps moving during blend")
	check(is_equal_approx(unit._previous_time / walk_duration, fposmod(unit._animation_time, run_duration) / run_duration), "Both gaits share phase throughout blend")
	check(float(unit._blend_material.get_shader_parameter("blend_amount")) > 0.0, "Blend progresses")
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	var painted := image.get_used_rect()
	check(painted.has_area(), "Transition shader renders nontransparent pixels")
	var max_alpha := 0.0
	for y in range(painted.position.y, painted.end.y):
		for x in range(painted.position.x, painted.end.x):
			max_alpha = maxf(max_alpha, image.get_pixel(x, y).a)
	check(max_alpha > 0.9, "Overlapping body remains opaque during the crossfade")
	image.save_png("res://.godot/archer_locomotion_blend_test.png")
	unit.advance_behavior(0.11)
	check(unit.sprite.material == null and unit._previous_clip == &"", "Blend ends after 0.15 seconds")
	unit.set_animation(&"idle")
	unit.advance_behavior(0.05)
	check(unit.sprite.material != null and unit._previous_time > 0.0, "Walk/Run to Idle blends an advancing previous pose")
	check(not unit.is_held_arrow_visible(), "Run to Idle stays without a held arrow during blending")
	unit.set_animation(&"walk")
	check(unit.sprite.material != null, "Idle to Walk blends")
	check(not unit.is_held_arrow_visible(), "Idle to Walk stays without a held arrow during blending")
	unit.shoot_at(unit.global_position + Vector2(250, 0))
	check(unit.animation == &"attack" and unit.sprite.material == null and unit._previous_clip == &"", "Attack immediately clears locomotion blending")
	var target := unit.current_target_position
	unit.shoot_at(unit.global_position + Vector2(0, 250))
	check(unit.current_target_position == target, "Locomotion changes preserve the shooting interruption guard")
	check(unit.is_held_arrow_visible(), "Attack starts with the held arrow visible")
	unit.advance_behavior(float(metadata["clips"]["attack"]["duration"]))
	check(unit.animation == &"idle" and not unit._attack_active and not unit.is_held_arrow_visible(), "Attack recovery returns to idle without a held arrow")
	map.free()
	print("Archer locomotion: %s checks, %s failures" % [checks, failures])
	quit(1 if failures else 0)
