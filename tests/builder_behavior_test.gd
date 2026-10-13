extends SceneTree

var checks := 0
var failures := 0
var manager: BuilderManager
var map: VillageMap
var economy: VillageEconomy


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := load("res://scenes/main.tscn").instantiate() as Node2D
	root.add_child(scene)
	for frame in range(4):
		await process_frame
	manager = scene.get_node("BuilderManager")
	map = scene.get_node("VillageMap")
	economy = scene.get_node("VillageEconomy")
	_freeze_workers()
	_check_3d_rig()
	_check(manager.workers.size() == 2, "Each completed hut has exactly one worker")
	for worker in manager.workers:
		_check(worker.state == BuilderUnit.State.HOME and not worker.visible, "Workers start hidden at home")
		_check(worker._wait >= 28.0 and worker._wait <= 65.0, "Long randomized home intervals dominate idle time")
		_check(worker.sprite.texture != null and worker.sprite.hframes == 20 and worker.sprite.vframes == 24, "Idle atlas contains sixty poses in eight directions")
		_check((worker.sprite.offset + Vector2(128, 193.401)).is_zero_approx(), "Every animation shares the model's foot anchor")
	var walker := manager.workers[0]
	walker._animation_time = 20.0 / 30.0
	walker._update_animation_frame()
	_check(walker.sprite.frame_coords == Vector2i(0, walker.facing * 3 + 1), "The atlas continues on the next row without switching direction")
	walker._animation_time = 59.0 / 30.0
	walker._update_animation_frame()
	_check(walker.sprite.frame_coords == Vector2i(19, walker.facing * 3 + 2), "The last idle pose uses the final row of the same direction")
	walker._animation_time = 2.0
	walker._update_animation_frame()
	_check(walker.sprite.frame_coords == Vector2i(0, walker.facing * 3), "The sprite wraps to its own direction after the complete loop")
	walker.rng.seed = 121
	_check(walker.begin_wander(), "A free worker can leave its hut for a short walk")
	_check(walker.visible and walker.animation == &"walk" and walker._outing_left <= 8.0, "The outing uses the walk clip and a bounded duration")
	var before := walker.global_position
	var frame_before := walker.sprite.frame_coords
	walker.advance_behavior(0.15)
	_check(walker.global_position != before and walker.sprite.frame_coords != frame_before, "Walking advances both position and skeletal animation frames")
	_tick(22.0)
	_check(walker.state == BuilderUnit.State.HOME and not walker.visible, "The brief outing ends with a return to the hut")
	walker._wait = 0.01
	walker.advance_behavior(0.02)
	_check(walker.state == BuilderUnit.State.WANDERING, "Random home countdown starts the next outing")
	var storage := economy.start_building(&"gold_storage", Vector2i(18, 17))
	_check(storage != null, "A nearby construction is accepted")
	if storage == null:
		quit(1)
		return
	storage.set_process(false)
	var worker := manager.worker_for(storage)
	_check(worker != null, "The construction immediately owns a worker")
	_check(_workers_on(storage) == 1 and economy.get_busy_builders() == 1, "One site reserves exactly one worker")
	_check(worker.visible and worker.state == BuilderUnit.State.TO_SITE and worker.animation == &"run", "Starting construction interrupts a walk or home stay with a run")
	for tick in range(100):
		worker.advance_behavior(0.05)
		if worker.state == BuilderUnit.State.HAMMERING:
			break
	_check(worker.state == BuilderUnit.State.HAMMERING and worker.animation == &"hammer", "On arrival the worker hammers outside the footprint")
	_check(map.is_walkable_cell(worker._cell), "The worker never stands inside the blocked construction footprint")
	var hammer_frame := worker.sprite.frame_coords.x
	worker.advance_behavior(0.16)
	_check(worker.sprite.frame_coords.x != hammer_frame, "Hammer swings visibly advance while the worker stays at the site")
	worker._work_left = 0.0
	worker._animation_time = 0.50
	worker.advance_behavior(1.0 / 60.0)
	_check(worker.state == BuilderUnit.State.HAMMERING, "Changing sides cannot cut a swing halfway through")
	worker._animation_time = 1.20
	worker.advance_behavior(1.0 / 60.0)
	_check(worker.state == BuilderUnit.State.CHANGING_SIDE, "Changing sides waits for the actual 1.2-second hammer loop")
	_tick(35.0)
	_check(worker.sides_worked.size() >= 2, "The worker reaches and hammers from several different sides")
	_check(worker.job == storage and storage.is_under_construction(), "Work continues while the construction timer remains unfinished")
	_check(_workers_on(storage) == 1, "Changing work sides cannot assign a duplicate worker")
	var mine := economy.start_building(&"gold_extractor", Vector2i(25, 15))
	_check(mine != null, "The second hut supplies an independent worker")
	mine.set_process(false)
	_check(manager.worker_for(mine) != null and manager.worker_for(mine) != worker, "Simultaneous sites own different workers")
	_check(economy.start_building(&"gold_storage", Vector2i(32, 10)) == null, "A third site cannot bypass the two-worker limit")
	storage.advance_construction(100.0)
	_check(worker.is_available() and worker.state in [BuilderUnit.State.RETURNING, BuilderUnit.State.HOME], "Completion immediately stops work and sends the worker home")
	_tick(25.0)
	_check(worker.state == BuilderUnit.State.HOME and not worker.visible, "The completed worker disappears into its own hut")
	# Free workers remain assignable while returning from the previous site.
	mine.advance_construction(100.0)
	var returning := manager.workers[1]
	var next := economy.start_building(&"gold_storage", Vector2i(24, 10))
	next.set_process(false)
	_check(manager.worker_for(next) != null, "A new site can immediately use a worker who is returning home")
	next.queue_free()
	await process_frame
	_tick(0.2)
	_check(manager.workers.all(func(unit: BuilderUnit): return unit.is_available()), "Deleting a construction releases its worker without accessing a freed node")
	_tick(25.0)
	# New huts contribute a worker only after construction finishes.
	economy.gold = 2000
	var hut := economy.start_building(&"builder_hut", Vector2i(30, 16))
	hut.set_process(false)
	_check(manager.workers.size() == 2, "An unfinished hut does not create its own builder")
	hut.advance_construction(100.0)
	_check(manager.workers.size() == 3 and economy.get_total_builders() == 3, "A completed hut creates exactly one new builder")
	_freeze_workers()
	var new_worker := manager.workers[-1]
	_check(new_worker.home == hut and new_worker.state == BuilderUnit.State.HOME and not new_worker.visible, "The new worker starts hidden in the new hut")
	# Moving a hut updates its worker's actual departure and return locations.
	new_worker.rng.seed = 84
	hut.cell = Vector2i(35, 16)
	_check(new_worker.begin_wander(), "Moving a hut preserves its worker")
	_check(BuilderUnit.perimeter(hut.cell, hut.get_footprint()).has(new_worker._cell), "The worker departs from the relocated hut")
	_tick(25.0)
	_check(new_worker.state == BuilderUnit.State.HOME and BuilderUnit.perimeter(hut.cell, hut.get_footprint()).has(new_worker._cell), "The worker returns to the relocated hut")
	# Enclosed construction must fail before charging or reserving a builder.
	var enclosure: Array[VillageBuilding] = []
	for cell in BuilderUnit.perimeter(Vector2i(5, 30), Vector2i(3, 3)):
		enclosure.append(map.place_wall(cell))
	var gold_before := economy.gold
	_check(economy.start_building(&"gold_storage", Vector2i(5, 30)) == null, "Construction without a reachable edge is rejected")
	_check(economy.gold == gold_before and economy.get_busy_builders() == 0, "Unreachable construction neither charges gold nor occupies a worker")
	for wall in enclosure:
		map.remove_wall(wall.cell)
	# Invalidate the next waypoint while moving: find an alternative route.
	var reroute_site := economy.start_building(&"gold_storage", Vector2i(31, 28))
	reroute_site.set_process(false)
	var rerouted := manager.worker_for(reroute_site)
	_check(rerouted != null and not rerouted._path.is_empty(), "Distant construction has an actual grid route")
	var blocked := rerouted._path[0]
	var wall := map.place_wall(blocked)
	_check(wall != null, "A new wall can block the planned route")
	_tick(16.0)
	_check(rerouted.state == BuilderUnit.State.HAMMERING or rerouted.state == BuilderUnit.State.CHANGING_SIDE, "The worker replans around a newly placed obstacle and reaches its site")
	_check(rerouted._cell != blocked and map.is_walkable_cell(rerouted._cell), "The rerouted worker stays outside the blocking wall")
	var underfoot := map.place_wall(rerouted._cell)
	_check(underfoot != null, "The test places a wall directly under the active worker")
	_tick(8.0)
	_check(rerouted._cell != underfoot.cell and map.is_walkable_cell(rerouted._cell), "The active worker steps out of an overlapping wall and resumes its route")
	map.remove_wall(underfoot.cell)
	reroute_site.advance_construction(100.0)
	map.remove_wall(blocked)
	for unit in manager.workers:
		if unit.state == BuilderUnit.State.HOME:
			unit._wait = 60.0
	_tick(25.0)
	_check(manager.workers.all(func(unit: BuilderUnit): return unit.state == BuilderUnit.State.HOME and not unit.visible), "All builders eventually return home after every job finishes")
	# A walking worker can also be caught in the center of a new large footprint.
	new_worker._wait = 100.0
	_check(new_worker.begin_wander(), "The new hut's worker can walk before another construction")
	new_worker._follow(map.find_cell_path(new_worker._cell, Vector2i(38, 19)))
	new_worker._move(20.0)
	var overlapping := economy.start_building(&"gold_storage", Vector2i(37, 18))
	overlapping.set_process(false)
	_check(manager.worker_for(overlapping) != new_worker, "A reachable free worker handles construction overlapping another unit's location")
	_tick(3.0)
	_check(map.is_walkable_cell(new_worker._cell), "A worker caught inside a large new footprint walks to a free edge without teleporting")
	overlapping.advance_construction(100.0)
	print("Builder behavior checks: %d passed, %d failed" % [checks - failures, failures])
	quit(1 if failures else 0)


func _freeze_workers() -> void:
	for worker in manager.workers:
		worker.set_process(false)


func _check_3d_rig() -> void:
	var model := load("res://assets/units/builder/builder_animated.glb").instantiate() as Node3D
	root.add_child(model)
	var skeletons := model.find_children("*", "Skeleton3D", true, false)
	var players := model.find_children("*", "AnimationPlayer", true, false)
	_check(skeletons.size() == 1 and (skeletons[0] as Skeleton3D).get_bone_count() == 18, "The exported 3D model contains the actual 18-bone skeleton")
	_check(players.size() == 1, "The skeletal export includes an AnimationPlayer")
	var skeleton: Skeleton3D = skeletons[0]
	var player: AnimationPlayer = players[0]
	for clip in ["Idle", "Walk", "Run", "Hammer"]:
		_check(player.has_animation(clip), "The skeletal export contains %s" % clip)
		if player.has_animation(clip):
			_check(player.get_animation(clip).length > 0.0, "%s has a nonzero animation duration" % clip)
			_check(player.get_animation(clip).loop_mode == Animation.LOOP_LINEAR, "%s loops in the native 3D asset" % clip)
			var info: Dictionary = BuilderUnit.ANIMATION_METADATA.data["clips"][clip.to_lower()]
			_check(is_equal_approx(player.get_animation(clip).length, float(info["duration"])), "%s has the same duration in 3D and the sprite animation" % clip)
			_check(float(info["fps"]) >= 30.0, "%s meets the required animation sample rate" % clip)
	var thigh := skeleton.find_bone("Thigh.L")
	player.play("Walk")
	player.seek(0.0, true)
	var rest := skeleton.get_bone_pose_rotation(thigh)
	player.seek(0.25, true)
	_check(not skeleton.get_bone_pose_rotation(thigh).is_equal_approx(rest), "Playing the exported walk clip actually moves the leg bone")
	var skinned := 0
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		if mesh.skin != null:
			skinned += 1
	_check(skinned == 25, "All 25 material meshes are bound to the skeleton")
	model.queue_free()


func _tick(seconds: float) -> void:
	for tick in range(ceili(seconds / 0.05)):
		for worker in manager.workers:
			worker.advance_behavior(0.05)


func _workers_on(building: VillageBuilding) -> int:
	var count := 0
	for worker in manager.workers:
		if worker.job == building:
			count += 1
	return count


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)
