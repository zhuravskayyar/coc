extends SceneTree

const FPS := 30
const FOLDER := "res://.godot/tower_3d_closeup"


func _initialize() -> void:
	root.hide()
	call_deferred("_run")


func _run() -> void:
	var tower := VillageBuilding.new()
	var visual := Tower3DVisual.new()
	tower.add_child(visual)
	root.add_child(tower)
	tower._tower_visual = visual
	visual.configure_ground_width(192.0)
	var unit := load("res://scenes/units/archer.tscn").instantiate() as ArcherUnit
	root.add_child(unit)
	unit.set_process(false)
	unit.station_at(tower)
	unit.arrow_fired.connect(func(projectile: ArrowProjectile) -> void: projectile.queue_free())
	DirAccess.make_dir_recursive_absolute(FOLDER)
	var index := 0
	for sample in range(30):
		await _capture(visual, unit, index, 1.0 / FPS)
		index += 1
	for slow in [false, true]:
		for facing in [1, 5]:
			var angle: float = facing * PI / 4.0
			unit.shoot_at(unit.global_position + Vector2(cos(angle), sin(angle) * 0.75) * 250.0)
			for sample in range(66 if slow else 36):
				await _capture(visual, unit, index, (0.5 if slow else 1.0) / FPS)
				index += 1
	visual.set_archer_enabled(false)
	await process_frame
	RenderingServer.force_draw(false)
	assert(visual.get_texture().get_image().save_png(FOLDER + "/tower-empty.png") == OK)
	print("3D tower closeup: %d frames at 30 FPS, two opposed shots at normal and half speed" % index)
	quit()


func _capture(visual: Tower3DVisual, unit: ArcherUnit, index: int, delta: float) -> void:
	unit.advance_behavior(delta)
	await process_frame
	RenderingServer.force_draw(false)
	assert(visual.get_texture().get_image().save_png("%s/frame_%04d.png" % [FOLDER, index]) == OK)
