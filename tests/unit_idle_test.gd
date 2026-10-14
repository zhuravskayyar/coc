extends SceneTree

var checks := 0
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for kind in ["archer", "militia", "builder"]:
		var unit = load("res://scenes/units/%s.tscn" % kind).instantiate()
		root.add_child(unit)
		unit.set_process(false)
		unit.visible = true
		var metadata: Dictionary = unit.ANIMATION_METADATA.data if kind == "builder" else unit.get_animation_metadata()
		var clip: Dictionary = metadata["clips"]["idle"]
		_check(float(clip["fps"]) >= 30.0, "%s idle source has at least 30 FPS" % kind)
		_check(unit.sprite.offset.is_equal_approx(-Vector2(metadata["ground_anchor"][0], metadata["ground_anchor"][1])), "%s has its ground anchor before AI setup" % kind)
		var origin: Vector2 = unit.position
		for direction in range(8):
			unit.facing = direction
			unit._animation_time = 0.0
			_update(unit, kind)
			var first: Vector2i = unit.sprite.frame_coords
			unit.advance_behavior(1.0 / float(clip["fps"]))
			_check(unit.sprite.frame_coords != first, "%s direction %d advances without a map/home" % [kind, direction])
			unit.advance_behavior((float(clip["frames"]) - 1.0) / float(clip["fps"]))
			_check(unit.sprite.frame_coords == first, "%s direction %d loops after exactly one cycle" % [kind, direction])
			var phase: float = unit._animation_time
			unit.advance_behavior(-1.0)
			_check(unit._animation_time == phase, "%s rejects negative animation time" % kind)
		_check(unit.position == origin and unit.animation == &"idle", "%s idle keeps the world position" % kind)
		unit.free()
	print("Continuous idle checks: %d passed, %d failed" % [checks - failures, failures])
	quit(1 if failures else 0)


func _update(unit, kind: String) -> void:
	if kind == "builder":
		unit._update_animation_frame()
	else:
		unit._update_frame()


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
