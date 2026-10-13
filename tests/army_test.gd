extends SceneTree

var checks := 0
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var scene := load("res://scenes/main.tscn").instantiate() as Node2D
	root.add_child(scene)
	for frame in range(4):
		await process_frame
	var army: ArmyManager = scene.get_node("ArmyManager")
	var economy: VillageEconomy = scene.get_node("VillageEconomy")
	var map: VillageMap = scene.get_node("VillageMap")
	var hud: VillageHUD = scene.get_node("UI/VillageHUD")
	var camp: VillageBuilding = scene.get_node("Buildings/UnitCamp")
	var tent: VillageBuilding = scene.get_node("Buildings/WarTent")
	army.set_process(false)
	_check(army.soldiers.is_empty() and army.queued == 0, "Army starts empty")
	hud._show_army()
	for frame in range(4):
		await process_frame
	_check(not hud._train_button.disabled, "Completed tent and camp enable training")
	var bread_before := economy.bread
	var gold_before := economy.gold
	await _click(hud._train_button.get_global_rect().get_center())
	_check(economy.bread == bread_before - 100 and economy.gold == gold_before, "UI charges exactly 100 bread and preserves gold")
	_check(hud._resource_numbers["bread"].text == "1 100", "Bread HUD updates immediately")
	_check(army.queued == 1 and army.training_remaining == 10.0 and army.soldiers.is_empty(), "Training starts at ten seconds without spawning immediately")
	army.advance_training(9.0)
	_check(army.soldiers.is_empty() and is_equal_approx(army.training_remaining, 1.0), "No early completion")
	_check(army.train_militia(), "Second unit can be queued")
	army.advance_training(1.0)
	_check(army.soldiers.size() == 1 and army.queued == 1 and army.training_remaining == 10.0, "First completes at ten seconds; second starts its own timer")
	army.advance_training(10.0)
	_check(army.soldiers.size() == 2 and army.queued == 0, "Second completes after twenty total seconds")
	for soldier in army.soldiers:
		soldier.set_process(false)
		_check(soldier.home == camp and soldier.animation == &"walk", "Trained unit walks to its camp")
		for frame in range(30 * 50):
			soldier.advance_behavior(1.0 / 30.0)
			_check(map.is_walkable_cell(map.world_to_cell(map.to_local(soldier.global_position))), "Route stays clear of buildings, walls and campfire")
		_check(army.camp_cells(camp).has(soldier._cell), "Unit reaches and stays inside the camp")
		var origin := soldier.global_position
		for clip in [&"idle", &"walk", &"run", &"attack"]:
			soldier._path.clear()
			soldier._wait = 100.0
			soldier.set_animation(clip)
			var info: Dictionary = soldier._clips[String(clip)]
			_check(float(info["fps"]) >= 30, "Animation source uses 30 FPS")
			for direction in range(8):
				soldier.facing = direction
				for index in range(int(info["frames"])):
					soldier._animation_time = float(index) / 30.0
					soldier._update_frame()
					_check(soldier.sprite.frame_coords.y >= direction * 3 and soldier.sprite.frame_coords.y < (direction + 1) * 3, "Every frame stays in its direction's atlas rows")
		_check(soldier.global_position == origin, "Animation does not translate the world node")
	economy.bread = 99
	var soldier_count := army.soldiers.size()
	_check(not army.train_militia() and economy.bread == 99 and army.queued == 0 and army.soldiers.size() == soldier_count, "Insufficient bread changes nothing")
	hud._refresh_economy()
	_check(hud._train_button.disabled and hud._army_error.text.contains("Недостатньо"), "UI explains insufficient bread")
	economy.bread = 1000
	camp.start_construction(30.0)
	_check(not army.train_militia() and economy.bread == 1000, "Unfinished camp cannot receive units")
	camp.advance_construction(30.0)
	tent.start_construction(20.0)
	_check(not army.train_militia(), "Unfinished tent cannot train")
	tent.advance_construction(20.0)
	var entrance: Vector2i = camp.cell + BuildingCatalog.DEFINITIONS[&"unit_camp"]["entrance"]
	map.place_wall(entrance + Vector2i(0, 1))
	_check(not army.train_militia() and economy.bread == 1000, "Blocked camp entrance rejects training without charging")
	map.remove_wall(entrance + Vector2i(0, 1))
	_check(army.train_militia(), "Reopening entrance enables training")
	camp.start_construction(30.0)
	army.advance_training(10.0)
	_check(army.queued == 1 and army.training_remaining == 0.0 and army.soldiers.size() == soldier_count, "A ready unit waits if camp becomes unavailable")
	camp.advance_construction(30.0)
	army.advance_training(0.01)
	_check(army.queued == 0 and army.soldiers.size() == soldier_count + 1 and economy.bread == 900, "Waiting unit spawns when camp returns, without charging twice")
	_check(army.train_militia() and army.train_militia() and army.train_militia(), "Multiple orders accepted")
	army.advance_training(25.0)
	_check(army.queued == 1 and army.soldiers.size() == soldier_count + 3 and is_equal_approx(army.training_remaining, 5.0), "Large delta preserves serial training time")
	army.advance_training(-1.0)
	_check(army.training_remaining == 5.0, "Negative delta cannot rewind training")
	for dimensions in [Vector2i(1280, 720), Vector2i(960, 540), Vector2i(720, 1280)]:
		root.size = dimensions
		hud._show_army()
		for frame in range(4):
			await process_frame
		_check(Rect2(Vector2.ZERO, hud.get_viewport_rect().size).encloses(hud._modal_panel.get_global_rect()), "Army modal fits %s" % dimensions)
	print("Army checks: %d passed, %d failed" % [checks - failures, failures])
	quit(1 if failures else 0)


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)


func _click(at: Vector2) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = at
	press.pressed = true
	root.push_input(press)
	var release := press.duplicate() as InputEventMouseButton
	release.pressed = false
	root.push_input(release)
	for frame in range(4):
		await process_frame
