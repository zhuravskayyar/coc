extends SceneTree

var checks := 0
var failures := 0
var fired: Array[ArrowProjectile] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_exported_rig()
	_check_native_blend_arrow_visibility()
	var scene := load("res://scenes/main.tscn").instantiate() as Node2D
	root.add_child(scene)
	for frame in range(4):
		await process_frame
	var army: ArmyManager = scene.get_node("ArmyManager")
	army.set_process(false)
	_check(army.train_archer(), "Existing settlement can train the archer")
	army.advance_training(10.0)
	_check(army.archers.size() == 1, "Training uses the existing archer scene")
	var archer := army.archers[0]
	archer.set_process(false)
	archer._path.clear()
	archer._wait = 1000.0
	archer.set_animation(&"idle")
	archer.arrow_fired.connect(_on_arrow_fired)
	var original_scale := archer.sprite.scale
	var original_position := archer.global_position
	for clip in [&"idle", &"walk", &"run"]:
		archer.set_animation(clip)
		_check(not archer.is_held_arrow_visible(), "%s has no held arrow" % clip)
		var info: Dictionary = archer._clips[String(clip)]
		var visibility: Array = info.get("held_arrow_visible", [])
		_check(visibility.size() == int(info["frames"]) and visibility.all(func(value: Variant) -> bool: return not bool(value)), "%s metadata hides the held arrow in every baked frame" % clip)
	archer.set_animation(&"idle")
	var attack: Dictionary = archer._clips["attack"]
	var release_time := float(attack["release_frame"]) / float(attack["fps"])
	var duration := float(attack["duration"])
	archer.fire_arrow()
	archer.shoot_at(archer.global_position)
	_check(fired.is_empty() and not archer._attack_active, "No projectile outside a valid shooting animation")
	for view in range(8):
		var angle := view * PI / 4.0
		var target := original_position + Vector2(cos(angle), sin(angle) * 0.75) * 300.0
		var count_before := fired.size()
		archer.shoot_at(target)
		archer.shoot_at(target + Vector2(100, 0))
		_check(archer.current_target_position == target, "A second request cannot interrupt the current draw")
		archer.advance_behavior(release_time - 0.0001)
		_check(fired.size() == count_before and archer.is_held_arrow_visible(), "Held arrow remains visible before release")
		archer.advance_behavior(0.0002)
		_check(fired.size() == count_before + 1 and not archer.is_held_arrow_visible(), "Exactly one projectile and hidden held arrow at release")
		var projectile := fired[-1]
		_check(projectile.get_parent() == archer.get_parent(), "Projectile is independent of the archer")
		_check(projectile.global_position.is_equal_approx(archer.bow_muzzle.global_position), "Projectile spawns at the projected BowMuzzle")
		_check(projectile.direction.is_equal_approx(projectile.global_position.direction_to(target)), "Projectile points at the target from the muzzle")
		_check(is_equal_approx(projectile.direction.length(), 1.0), "Flight direction is normalized")
		var projectile_origin := projectile.global_position
		projectile.advance_flight(0.1)
		_check(projectile.global_position.is_equal_approx(projectile_origin + projectile.direction * archer.projectile_speed * 0.1), "Flight uses configurable speed")
		archer.fire_arrow()
		_check(fired.size() == count_before + 1, "Repeated fire_arrow calls cannot double-fire")
		archer.advance_behavior(duration - release_time)
		archer.reset_held_arrow()
		_check(not archer._attack_active and archer.animation == &"idle" and not archer.is_held_arrow_visible(), "Recovery returns to idle without a held arrow")
		_check(archer.sprite.scale == original_scale and archer.global_position == original_position, "Shooting preserves character scale and position")
		projectile.advance_flight(archer.projectile_lifetime)
		_check(projectile.is_queued_for_deletion(), "Projectile expires at its configured lifetime")
	# A slow frame can cross both release and recovery; the event must still fire once.
	var count_before := fired.size()
	archer.shoot_at(original_position + Vector2(250, 50))
	archer.advance_behavior(duration + 0.1)
	_check(fired.size() == count_before + 1 and archer.animation == &"idle" and not archer.is_held_arrow_visible(), "A large delta preserves release and recovery without a held arrow")
	for projectile in fired:
		if is_instance_valid(projectile) and not projectile.is_queued_for_deletion():
			projectile.queue_free()
	print("Archer shooting: %d passed, %d failed" % [checks - failures, failures])
	quit(1 if failures else 0)


func _on_arrow_fired(projectile: ArrowProjectile) -> void:
	projectile.set_physics_process(false)
	fired.append(projectile)


func _check_exported_rig() -> void:
	var model := load("res://assets/units/archer/archer_animated.glb").instantiate() as Node3D
	root.add_child(model)
	var skeletons := model.find_children("*", "Skeleton3D", true, false)
	var players := model.find_children("*", "AnimationPlayer", true, false)
	_check(skeletons.size() == 1 and (skeletons[0] as Skeleton3D).get_bone_count() == 65, "Export retains the supplied 65-bone skeleton")
	_check(players.size() == 1, "Export includes an AnimationPlayer")
	var skeleton: Skeleton3D = skeletons[0]
	var player: AnimationPlayer = players[0]
	_check(player.get_animation_list().size() == 4, "Export imports four merged animation clips")
	var default_held_arrow := model.find_child("HeldArrow", true, false) as MeshInstance3D
	_check(default_held_arrow != null and not default_held_arrow.visible and default_held_arrow.scale.is_equal_approx(Vector3.ONE), "The imported default rig hides the held arrow with valid scale before AnimationPlayer playback")
	# These exact imported names were listed from Skeleton3D, not guessed.
	var left := skeleton.find_bone("mixamorig_LeftHand")
	var right := skeleton.find_bone("mixamorig_RightHand")
	_check(left >= 0 and right >= 0, "Both actual imported hand bones exist")
	_check(model.find_children("*", "BoneAttachment3D", true, false).size() == 2, "Godot imports separate hand attachments for the two props")
	_check(player.has_animation("archer_shoot"), "Source contains the named shooting animation")
	_check(is_equal_approx(player.get_animation("archer_shoot").length, float(ArcherUnit.ARCHER_METADATA.data["clips"]["attack"]["duration"])), "Skeletal and sprite shooting durations match")
	player.play("archer_shoot")
	player.seek(0.0, true)
	var ready_pose := skeleton.get_bone_pose_rotation(right)
	player.seek(0.45, true)
	_check(not skeleton.get_bone_pose_rotation(right).is_equal_approx(ready_pose), "Playing the exported shot actually moves the draw hand")
	_check_imported_bow_string(model, skeleton, player, left)
	_check_imported_held_arrow_visibility(model, player)
	model.queue_free()


func _check_imported_bow_string(model: Node3D, skeleton: Skeleton3D, player: AnimationPlayer, left_hand: int) -> void:
	var bow := model.find_child("Bow", true, false) as MeshInstance3D
	var string_shape := bow.find_blend_shape_by_name(&"StringDraw") if bow != null else -1
	_check(string_shape >= 0, "The imported bow retains the StringDraw morph")
	if string_shape < 0:
		return
	var ancestor: Node = bow.get_parent()
	while ancestor != null and not ancestor is BoneAttachment3D:
		ancestor = ancestor.get_parent()
	var attachment := ancestor as BoneAttachment3D
	_check(attachment != null and skeleton.find_bone(attachment.bone_name) == left_hand, "The morphed bow remains attached to the imported left hand")
	var full_draw := true
	var bow_visible := true
	var string_values: Array[float] = []
	for frame in [12, 13, 14]:
		player.seek(float(frame) / 30.0, true)
		var string_value := bow.get_blend_shape_value(string_shape)
		string_values.append(string_value)
		full_draw = full_draw and string_value > 0.9
		bow_visible = bow_visible and bow.is_visible_in_tree()
	_check(full_draw, "The imported shooting animation actually draws the string at full draw: %s" % [string_values])
	player.seek(18.0 / 30.0, true)
	_check(absf(bow.get_blend_shape_value(string_shape)) < 0.001, "The imported string returns to rest after the release snap")
	_check(bow_visible and bow.is_visible_in_tree(), "The bow remains visible through full draw and release")


func _check_imported_held_arrow_visibility(model: Node3D, player: AnimationPlayer) -> void:
	var held_arrow := model.find_child("HeldArrow", true, false) as MeshInstance3D
	_check(held_arrow != null, "The imported rig retains the held arrow mesh")
	if held_arrow == null:
		return
	for clip in ["Idle", "Walk", "Run"]:
		_check(player.has_animation(clip), "The exported %s animation exists" % clip)
		if not player.has_animation(clip):
			continue
		player.play(clip)
		var duration := player.get_animation(clip).length
		_check_imported_arrow_track(player, clip, held_arrow)
		for time in [0.0, duration * 0.5, maxf(duration - 0.0001, 0.0)]:
			player.seek(time, true)
			_check(not held_arrow.visible and not held_arrow.is_visible_in_tree() and held_arrow.scale.is_equal_approx(Vector3.ONE), "Imported %s hides the held arrow with valid scale at %.4fs" % [clip, time])
	var attack: Dictionary = ArcherUnit.ARCHER_METADATA.data["clips"]["attack"]
	var fps := float(attack["fps"])
	var release_time := float(attack["release_frame"]) / fps
	player.play("archer_shoot")
	_check_imported_arrow_track(player, "archer_shoot", held_arrow)
	for time in [0.0, 13.0 / fps, release_time - 0.0001]:
		player.seek(time, true)
		_check(held_arrow.scale.is_equal_approx(Vector3.ONE) and held_arrow.visible and held_arrow.is_visible_in_tree(), "Imported shot shows a full-size held arrow until release at %.4fs" % time)
	for time in [release_time, 18.0 / fps, float(attack["duration"]) - 0.0001]:
		player.seek(time, true)
		_check(not held_arrow.visible and not held_arrow.is_visible_in_tree() and held_arrow.scale.is_equal_approx(Vector3.ONE), "Imported shot hides the held arrow from release through recovery at %.4fs" % time)
	player.play("Idle")
	player.seek(0.0, true)
	_check(not held_arrow.visible and held_arrow.scale.is_equal_approx(Vector3.ONE), "Returning to imported Idle keeps the held arrow hidden with valid scale")
	for clip in ["Idle", "Walk", "Run"]:
		player.play("archer_shoot")
		player.seek(13.0 / fps, true)
		player.play(clip)
		player.seek(0.0, true)
		_check(not held_arrow.visible and held_arrow.scale.is_equal_approx(Vector3.ONE), "Interrupting imported full draw with %s removes the held arrow" % clip)


func _check_imported_arrow_track(player: AnimationPlayer, clip: String, held_arrow: Node3D) -> void:
	var animation_root := player.get_node(player.root_node)
	var path := animation_root.get_path_to(held_arrow)
	var animation := player.get_animation(clip)
	var visibility_track := animation.find_track(NodePath(String(path) + ":visible"), Animation.TYPE_VALUE)
	_check(visibility_track >= 0 and animation.value_track_get_update_mode(visibility_track) == Animation.UPDATE_DISCRETE, "Imported %s uses a discrete arrow visibility track" % clip)
	_check(animation.find_track(path, Animation.TYPE_SCALE_3D) == -1, "Imported %s has no arrow scale animation" % clip)


func _check_native_blend_arrow_visibility() -> void:
	var model := load("res://assets/units/archer/archer_animated.blend").instantiate() as Node3D
	root.add_child(model)
	var players := model.find_children("*", "AnimationPlayer", true, false)
	var held_arrow := model.find_child("HeldArrow", true, false) as Node3D
	_check(players.size() == 1 and held_arrow != null, "Native Blender import retains an animation player and HeldArrow")
	if players.size() != 1 or held_arrow == null:
		model.queue_free()
		return
	var player: AnimationPlayer = players[0]
	_check(not held_arrow.visible and held_arrow.scale.is_equal_approx(Vector3.ONE), "Native Blender default hides HeldArrow with valid scale")
	_check(player.has_animation("archer_shoot"), "Native Blender import retains the shooting clip")
	if player.has_animation("archer_shoot"):
		var attack: Dictionary = ArcherUnit.ARCHER_METADATA.data["clips"]["attack"]
		var fps := float(attack["fps"])
		var native_duration := player.get_animation("archer_shoot").length
		var offset := maxf(native_duration - float(attack["duration"]), 0.0)
		var release_time := float(attack["release_frame"]) / fps + offset
		print("Native Blender clips: %s; shooting duration %.6fs; arrow marker offset %.6fs" % [player.get_animation_list(), native_duration, offset])
		_check_imported_arrow_track(player, "archer_shoot", held_arrow)
		player.play("archer_shoot")
		player.seek(13.0 / fps + offset, true)
		_check(held_arrow.visible and held_arrow.scale.is_equal_approx(Vector3.ONE), "Native Blender aim shows a full-size held arrow")
		player.seek(release_time - 0.0001, true)
		_check(held_arrow.visible and held_arrow.scale.is_equal_approx(Vector3.ONE), "Native Blender keeps the held arrow until its shifted release marker")
		player.seek(release_time, true)
		_check(not held_arrow.visible and held_arrow.scale.is_equal_approx(Vector3.ONE), "Native Blender release strictly hides the held arrow")
		player.seek(maxf(native_duration - 0.0001, release_time), true)
		_check(not held_arrow.visible, "Native Blender recovery keeps the held arrow hidden")
		player.play("archer_shoot")
		player.seek(13.0 / fps + offset, true)
		player.play("Idle")
		player.seek(0.0, true)
		_check(not held_arrow.visible, "Native Blender aim to Idle also hides the held arrow")
	model.queue_free()


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)
