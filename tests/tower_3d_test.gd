extends SceneTree

var checks := 0
var failures := 0
var fired: Array[ArrowProjectile] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := load("res://scenes/main.tscn").instantiate() as Node2D
	root.add_child(scene)
	for frame in range(4):
		await process_frame
	var army: ArmyManager = scene.get_node("ArmyManager")
	var map: VillageMap = scene.get_node("VillageMap")
	army.set_process(false)
	_check(army.train_archer(), "The existing training logic still creates an archer")
	army.advance_training(10.0)
	var unit := army.archers[0]
	unit.set_process(false)
	unit._path.clear()
	unit._wait = 1000.0
	unit.arrow_fired.connect(_on_arrow_fired)
	_test_shots(unit, null)
	var tower := VillageBuilding.new()
	tower.building_type = "defense_tower"
	tower.cell = Vector2i(18, 24)
	scene.get_node("Buildings").add_child(tower)
	var visual := tower._tower_visual
	_check(visual != null and tower._texture is ViewportTexture, "The world tower uses a live GLB viewport")
	_check(visual.viewport.own_world_3d and visual.viewport.transparent_bg, "Each tower has an isolated transparent 3D world")
	_check(is_equal_approx(visual.ground_source_width * visual.draw_scale, 192.0), "The supplied foundation fits the existing 2x2 ground footprint")
	var axis_x := visual.project_point(Vector3.RIGHT)
	var axis_z := visual.project_point(Vector3.BACK)
	_check(is_equal_approx(absf(axis_x.y / axis_x.x), 0.75) and is_equal_approx(absf(axis_z.y / axis_z.x), 0.75), "Both rendered ground axes match the village grid")
	_check(map.is_cell_occupied(tower.cell) and not map.is_walkable_cell(tower.cell), "The 3D tower still reserves and blocks its ground cells")
	tower.start_construction(30.0)
	_check(not army.station_archer(tower), "An unfinished tower cannot receive an archer")
	tower.advance_construction(30.0)
	_check(army.station_archer(tower), "The existing station button logic mounts the trained archer")
	_check(not army.station_archer(tower), "A second assignment cannot duplicate the stationed archer")
	_check(not unit.sprite.visible and not unit.get_node("GroundShadow").visible, "The stationed character has no duplicate 2D sprite or ground shadow")
	_check(visual.archer.visible and visual.archer.position.is_equal_approx(Tower3DVisual.PLATFORM_POSITION), "The live character stands on the model's wooden platform")
	_check(unit.global_position.is_equal_approx(tower.to_global(visual.get_station_offset())), "The unit's 2D origin follows the projected platform")
	_check(visual.player.has_animation("Idle") and visual.player.has_animation("archer_shoot"), "The mounted model uses the existing Idle and shooting animations")
	_check(not visual.held_arrow.visible, "Idle has no held arrow in the live model")
	if DisplayServer.get_name() != "headless":
		await process_frame
		RenderingServer.force_draw(false)
		var image := visual.get_texture().get_image()
		_check(image != null and image.get_used_rect().has_area(), "The live viewport actually renders the supplied model")
		_check(image.get_pixel(0, 0).a == 0.0, "The rendered model has a transparent background")
		_check(tower.hit_test_visual(visual.project_point(Vector3(0.0, 0.08, 0.0))), "A rendered foundation pixel selects the 3D tower")
		_check(not tower.hit_test_visual(tower._sprite_rect.position + Vector2.ONE), "Transparent viewport padding does not select the tower")
	var right_hand := visual.skeleton.find_bone("mixamorig_RightHand")
	var idle_pose := visual.skeleton.get_bone_pose_rotation(right_hand)
	unit.shoot_at(unit.global_position + Vector2(250, 0))
	unit.advance_behavior(13.0 / 30.0)
	_check(not visual.skeleton.get_bone_pose_rotation(right_hand).is_equal_approx(idle_pose), "The existing attack clock actually animates the mounted draw hand")
	_check(visual.held_arrow.visible, "The live model has a held arrow at full draw")
	unit.advance_behavior(0.9 - 13.0 / 30.0)
	_test_shots(unit, tower)
	var old_cell := tower.cell
	tower.cell += Vector2i(1, 0)
	unit.advance_behavior(1.0 / 30.0)
	_check(unit.global_position.is_equal_approx(tower.to_global(visual.get_station_offset())), "Moving the tower carries its stationed archer")
	_check(not map.is_cell_occupied(old_cell), "Moving the tower releases its previous footprint")
	var interaction: VillageInteraction = scene.get_node("VillageInteraction")
	interaction.begin_placement(&"defense_tower")
	_check(interaction._preview_texture is ViewportTexture, "Placement previews use the same supplied 3D tower")
	interaction.cancel_placement()
	unit.shoot_at(unit.global_position + Vector2(250, 0))
	unit.advance_behavior(0.2)
	var count_before := fired.size()
	_check(army.return_archer_from_tower(tower), "The existing return button still finds a route to camp")
	_check(unit.sprite.visible and unit.get_node("GroundShadow").visible and not visual.archer.visible, "Returning restores the ground sprite and removes the mounted model")
	_check(not unit._attack_active and map.is_walkable_cell(unit._cell), "Returning cancels a pending draw and starts on a walkable ground cell")
	unit._path.clear()
	unit._wait = 1000.0
	unit.advance_behavior(0.9)
	_check(fired.size() == count_before, "Returning before release cannot fire a stale tower shot")
	_check(army.station_archer(tower), "The same archer can be stationed again")
	tower.queue_free()
	await process_frame
	unit.advance_behavior(1.0 / 30.0)
	_check(unit._mounted_visual == null and unit.sprite.visible, "Removing the tower clears the mounted render safely")
	for projectile in fired:
		if is_instance_valid(projectile) and not projectile.is_queued_for_deletion():
			projectile.queue_free()
	print("3D tower: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _test_shots(unit: ArcherUnit, tower: VillageBuilding) -> void:
	var attack: Dictionary = unit._clips["attack"]
	var release_time := float(attack["release_frame"]) / float(attack["fps"])
	var duration := float(attack["duration"])
	for facing in range(8):
		var angle := facing * PI / 4.0
		var target := unit.global_position + Vector2(cos(angle), sin(angle) * 0.75) * 300.0
		var count_before := fired.size()
		unit.shoot_at(target)
		unit.shoot_at(target + Vector2(70, 0))
		_check(unit.current_target_position == target, "Repeated requests preserve the current draw")
		unit.advance_behavior(release_time - 0.0001)
		_check(fired.size() == count_before and unit.is_held_arrow_visible(), "No projectile appears before the existing release marker")
		if tower != null:
			_check(tower._tower_visual.held_arrow.visible, "The live held arrow remains visible before release")
			var visual := tower._tower_visual
			var tip := visual.archer.find_child("ArrowTip", true, false) as Node3D
			var nock := visual.archer.find_child("ArrowNock", true, false) as Node3D
			var bow_direction := (visual.project_point(tip.global_position) - visual.project_point(nock.global_position)).normalized()
			_check(bow_direction.dot(unit._attack_direction) > 0.95, "The live bow faces the same direction as the requested shot")
		unit.advance_behavior(0.0002)
		_check(fired.size() == count_before + 1 and not unit.is_held_arrow_visible(), "Exactly one arrow releases at 0.5 seconds")
		var projectile := fired[-1]
		_check(projectile.get_parent() == unit.get_parent(), "The existing projectile moves independently of the tower")
		_check(projectile.direction.is_equal_approx(projectile.global_position.direction_to(target)), "The projectile aims from the muzzle at the requested target")
		if tower != null:
			var visual := tower._tower_visual
			_check(not visual.held_arrow.visible, "The live held arrow disappears on the same release marker")
			_check(projectile.global_position.distance_to(tower.to_global(visual.get_muzzle_position())) < 0.05, "The projectile starts at the actual animated 3D bow")
		unit.fire_arrow()
		_check(fired.size() == count_before + 1, "The existing guard prevents a duplicate projectile")
		unit.advance_behavior(duration - release_time)
		_check(unit.animation == &"idle" and not unit._attack_active, "Attack recovery returns to Idle")
		var origin := projectile.global_position
		projectile.advance_flight(0.1)
		_check(projectile.global_position.is_equal_approx(origin + projectile.direction * unit.projectile_speed * 0.1), "The existing arrow speed still controls flight")
	var count_before := fired.size()
	unit.shoot_at(unit.global_position + Vector2(240, 50))
	unit.advance_behavior(duration + 0.1)
	_check(fired.size() == count_before + 1 and unit.animation == &"idle", "A slow frame crossing release and recovery fires once")


func _on_arrow_fired(projectile: ArrowProjectile) -> void:
	projectile.set_physics_process(false)
	fired.append(projectile)


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)
