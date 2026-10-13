extends SceneTree

const FPS := 30
const SECONDS := 46


func _initialize() -> void:
	root.hide()
	call_deferred("_run")


func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(960, 540)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var scene := load("res://scenes/main.tscn").instantiate() as Node2D
	viewport.add_child(scene)
	for frame in range(5):
		await process_frame
	var army: ArmyManager = scene.get_node("ArmyManager")
	var hud: VillageHUD = scene.get_node("UI/VillageHUD")
	var camera: Camera2D = scene.get_node("MapCamera")
	var map: VillageMap = scene.get_node("VillageMap")
	var camp: VillageBuilding = scene.get_node("Buildings/UnitCamp")
	army.set_process(false)
	for worker in scene.get_node("BuilderManager").workers:
		worker.set_process(false)
	if "--motion-review" in OS.get_cmdline_user_args():
		await _capture_motion(viewport, scene)
		quit()
		return
	camera.zoom = Vector2.ONE * 0.95
	camera.global_position = Vector2(40, 195)
	camera.force_update_scroll()
	hud._show_army()
	var folder := "res://.godot/militia_game_preview"
	DirAccess.make_dir_recursive_absolute(folder)
	for index in range(FPS * SECONDS):
		if index == 30:
			hud._train_button.pressed.emit()
		if index == 90:
			hud._train_button.pressed.emit()
		if index == 150:
			hud.close_modal()
			camera.global_position = Vector2(0, 230)
			camera.force_update_scroll()
		army.advance_training(1.0 / FPS)
		for soldier in army.soldiers:
			soldier.set_process(false)
			soldier.advance_behavior(1.0 / FPS)
		if index == 27 * FPS:
			camera.global_position = map.get_footprint_center(camp.cell, camp.get_footprint())
			camera.zoom = Vector2.ONE * 1.3
			camera.force_update_scroll()
		if index == 40 * FPS:
			hud._show_army()
		hud._refresh_army()
		await process_frame
		RenderingServer.force_draw(false)
		viewport.get_texture().get_image().save_png("%s/frame_%04d.png" % [folder, index])
	assert(army.soldiers.size() == 2 and army.queued == 0)
	assert(scene.get_node("VillageEconomy").bread == 1000)
	print("Militia game capture: %d frames, two ten-second orders, bread 1200 -> 1000" % (FPS * SECONDS))
	quit()


func _capture_motion(viewport: SubViewport, scene: Node2D) -> void:
	var army: ArmyManager = scene.get_node("ArmyManager")
	var map: VillageMap = scene.get_node("VillageMap")
	var camera: Camera2D = scene.get_node("MapCamera")
	scene.get_node("UI").hide()
	assert(army.train_militia())
	army.advance_training(10.0)
	var soldier := army.soldiers[0]
	soldier.set_process(false)
	soldier._cell = Vector2i(32, 14)
	soldier.global_position = soldier._world(soldier._cell)
	camera.zoom = Vector2.ONE * 1.8
	var overlay := CanvasLayer.new()
	viewport.add_child(overlay)
	var label := Label.new()
	label.position = Vector2(18, 16)
	label.add_theme_font_override("font", VillageHUD.UI.BODY)
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	overlay.add_child(label)
	var folder := "res://.godot/militia_game_motion"
	DirAccess.make_dir_recursive_absolute(folder)
	for index in range(360):
		if index in [0, 60, 120]:
			var target: Vector2i = [Vector2i(32, 18), Vector2i(28, 18), Vector2i(28, 14)][index / 60]
			soldier.follow_path(map.find_cell_path(soldier._cell, target), true)
			label.text = "Ополченець · Перевірка бігу · 30 FPS"
		if index in [180, 240, 300]:
			soldier._path.clear()
			soldier._wait = 100.0
			soldier.facing = [1, 3, 5][(index - 180) / 60]
			soldier.set_animation(&"attack")
			label.text = "Ополченець · Перевірка удару · 30 FPS"
		soldier.advance_behavior(1.0 / FPS)
		camera.global_position = soldier.global_position + Vector2(0, -35)
		camera.force_update_scroll()
		await process_frame
		RenderingServer.force_draw(false)
		viewport.get_texture().get_image().save_png("%s/frame_%04d.png" % [folder, index])
	print("In-game motion review: 360 frames, three run directions, three attack views")
