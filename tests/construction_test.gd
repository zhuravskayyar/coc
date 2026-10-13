extends SceneTree

var checks := 0
var failures := 0
var completions := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := load("res://scenes/main.tscn").instantiate() as Node2D
	root.add_child(scene)
	await _settle()
	var economy: VillageEconomy = scene.get_node("VillageEconomy")
	var interaction: VillageInteraction = scene.get_node("VillageInteraction")
	var map: VillageMap = scene.get_node("VillageMap")
	var hud: VillageHUD = scene.get_node("UI/VillageHUD")
	var buildings := scene.get_node("Buildings")
	_check(economy.gold == 2500 and economy.get_free_builders() == 2, "Initial balances and two completed huts drive the actual HUD")
	_check(hud._builder.text == "2/2" and hud._resource_numbers["gold"].text == "2 500", "HUD reflects the initial economy")
	var balance := economy.gold
	var count := buildings.get_child_count()
	interaction.begin_placement(&"gold_storage")
	interaction.cancel_placement()
	_check(economy.gold == balance and economy.get_free_builders() == 2 and buildings.get_child_count() == count, "Canceling a preview never charges or occupies a builder")
	_check(economy.start_building(&"gold_storage", Vector2i(20, 20)) == null, "Occupied cells reject construction")
	_check(economy.start_building(&"gold_storage", Vector2i(43, 43)) == null, "Footprints outside the field reject construction")
	_check(economy.start_building(&"unknown", Vector2i(5, 5)) == null, "Unknown buildings cannot be constructed")
	_check(economy.gold == balance and buildings.get_child_count() == count, "Rejected placement leaves resources and nodes intact")
	interaction.begin_placement(&"gold_storage")
	interaction.set_placement_screen_position(map.get_global_transform_with_canvas() * map.cell_to_world(Vector2i(30, 14)))
	_check(interaction.confirm_placement(), "Confirmation starts construction through the existing input controller")
	var storage := interaction.selected
	storage.set_process(false)
	_check(storage.is_under_construction() and economy.gold == 2150 and economy.get_free_builders() == 1, "Starting a storage charges 350 gold and reserves one builder")
	_check(hud._resource_numbers["gold"].text == "2 150" and hud._builder.text == "1/2", "Resource labels and builder counts update immediately")
	_check(map.is_cell_occupied(storage.cell) and not map.is_walkable_cell(storage.cell), "Construction immediately reserves its grid cells")
	_check(storage._construction_back.visible and storage._construction_front.visible, "Both scaffold layers appear during construction")
	_check(storage._construction_front._scaffold != null, "Construction uses the real imported scaffold PNG")
	_check(storage.get_construction_rect().has_area(), "Scaffold occupies a visible rectangle")
	_check(hud._construction_status != null and hud._construction_progress != null, "Selected construction exposes a countdown and progress")
	for node in hud._selection_content.find_children("*", "Button", true, false):
		if node.text == "Перемістити":
			_check(node.disabled, "Moving unfinished construction is disabled")
	interaction.begin_placement(&"gold_storage", storage)
	_check(not interaction.is_placing(), "The controller also rejects moving unfinished construction")
	var camp := economy.start_building(&"unit_camp", Vector2i(5, 5))
	_check(camp != null, "A second builder starts work independently")
	if camp == null:
		quit(1)
		return
	camp.set_process(false)
	hud._show_builders()
	await _settle()
	_check(hud._builders_status.text == "Вільні: 0 із 2" and hud._builders_jobs.text.contains("Армійський табір"), "Builder window displays the active jobs and current availability")
	hud.close_modal()
	_check(economy.get_busy_builders() == 2 and economy.get_free_builders() == 0 and hud._builder.text == "0/2", "Two construction jobs occupy both builders")
	_check(not map.is_walkable_cell(camp.cell + Vector2i.ONE), "The future walkable camp center is blocked while being built")
	_check(not camp._campfire.visible, "Campfire is hidden until the camp is ready")
	balance = economy.gold
	count = buildings.get_child_count()
	_check(economy.start_building(&"gold_extractor", Vector2i(10, 10)) == null, "A third construction is rejected when all builders are occupied")
	_check(economy.start_building(&"wall", Vector2i(10, 10)) == null, "Instant wall placement also requires a free builder")
	_check(economy.gold == balance and buildings.get_child_count() == count, "Busy-builder rejection never charges gold")
	hud.show_catalog()
	hud._select_category("Ресурси")
	for button in hud._catalog_buttons.values():
		_check(button.disabled and not button.tooltip_text.is_empty(), "Catalog disables unaffordable or unavailable construction with an explanation")
	hud.close_modal()
	interaction.begin_placement(&"gold_extractor")
	interaction.set_placement_screen_position(map.get_global_transform_with_canvas() * map.cell_to_world(Vector2i(10, 10)))
	_check(not interaction.placement_valid and hud._confirm.disabled, "Placement preview cannot bypass the builder limit")
	storage.construction_finished.connect(func(): completions += 1)
	storage.advance_construction(10.0)
	_check(is_equal_approx(storage.get_construction_progress(), 0.5), "Countdown advances to half complete")
	storage.advance_construction(15.0)
	await _settle()
	_check(not storage.is_under_construction() and storage.construction_remaining == 0.0, "Finishing clamps the countdown at zero")
	_check(completions == 1 and economy.get_free_builders() == 1 and hud._builder.text == "1/2", "Completion emits once and releases its builder")
	_check(not storage._construction_front.visible and not storage._construction_back.visible, "Completion removes the scaffolding")
	_check(interaction.placement_valid and not hud._confirm.disabled, "A pending preview becomes valid as soon as a builder is free")
	storage.advance_construction(100.0)
	_check(completions == 1 and economy.gold == balance, "A finished building cannot complete twice or charge again")
	interaction.cancel_placement()
	interaction.select_building(storage)
	_check(hud._construction_status == null, "Completed selection returns to the normal building action panel")
	var wall := economy.start_building(&"wall", Vector2i(10, 10))
	_check(wall != null and not wall.is_under_construction(), "Walls finish immediately")
	_check(economy.gold == balance - 25 and economy.get_free_builders() == 1, "A wall charges 25 gold without leaving its builder occupied")
	map.remove_wall(wall.cell)
	_check(economy.gold == balance - 25, "Removing a wall does not create a gold refund exploit")
	var tent: VillageBuilding = scene.get_node("Buildings/WarTent")
	balance = economy.gold
	interaction.begin_placement(&"war_tent", tent)
	interaction.set_placement_screen_position(map.get_global_transform_with_canvas() * map.cell_to_world(Vector2i(35, 19)))
	_check(interaction.confirm_placement() and tent.cell == Vector2i(35, 19), "Finished buildings retain their existing move behavior")
	_check(economy.gold == balance and economy.get_free_builders() == 1 and not tent.is_under_construction(), "Moving completed buildings never charges or starts a timer")
	economy.gold = 249
	economy.changed.emit()
	count = buildings.get_child_count()
	_check(economy.start_building(&"gold_extractor", Vector2i(10, 10)) == null, "Insufficient gold rejects a valid empty footprint")
	_check(economy.gold == 249 and buildings.get_child_count() == count, "A failed payment leaves the balance and scene intact")
	interaction.begin_placement(&"gold_extractor")
	interaction.set_placement_screen_position(map.get_global_transform_with_canvas() * map.cell_to_world(Vector2i(10, 10)))
	_check(not interaction.placement_valid and hud._placement_status.text.contains("золота"), "Insufficient gold is explained in the placement panel")
	economy.gold = 250
	economy.changed.emit()
	_check(interaction.confirm_placement() and economy.gold == 0, "An exact-price balance succeeds without becoming negative")
	var mine := interaction.selected
	mine.set_process(false)
	mine.advance_construction(15.0)
	camp.advance_construction(30.0)
	_check(map.is_walkable_cell(camp.cell + Vector2i.ONE) and not map.is_walkable_cell(camp.cell + Vector2i(2, 2)), "Finishing camp restores its navigable interior and solid campfire")
	_check(camp._campfire.visible and economy.get_free_builders() == 2, "Finishing every job shows the campfire and frees every builder")
	economy.gold = 300
	var hut := economy.start_building(&"builder_hut", Vector2i(10, 14))
	hut.set_process(false)
	_check(economy.get_total_builders() == 2 and economy.get_free_builders() == 1, "A hut being built cannot supply its own worker")
	hut.advance_construction(15.0)
	_check(economy.get_total_builders() == 3 and economy.get_free_builders() == 3, "A completed hut adds exactly one builder")
	hud._show_builders()
	await _settle()
	_check(hud._builders_status.text == "Вільні: 3 із 3" and hud._builders_jobs.text == "Усі роботи завершено.", "Builder window returns to a completed state")
	_check(VillageEconomy.format_time(60.1) == "1:01" and VillageEconomy.format_time(0.1) == "0:01", "Displayed countdown rounds up to avoid showing zero before completion")
	# Verify a short job actually advances through SceneTree processing too.
	economy.gold = 250
	var timed_mine := economy.start_building(&"gold_extractor", Vector2i(15, 10))
	timed_mine.start_construction(0.05)
	await process_frame
	_check(hud._builders_jobs.text.contains("Золота копальня"), "An already-open builder window picks up a newly started job")
	await create_timer(0.15).timeout
	await _settle()
	_check(not timed_mine.is_under_construction() and economy.get_free_builders() == 3, "Normal frame processing completes the countdown and releases the builder")
	_check(hud._builders_jobs.text == "Усі роботи завершено.", "An open builder window updates when a timer completes")
	print("Construction checks: %d passed, %d failed" % [checks - failures, failures])
	quit(1 if failures else 0)


func _settle() -> void:
	for frame in range(4):
		await process_frame


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)
