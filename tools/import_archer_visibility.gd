@tool
extends EditorScenePostImport

# glTF carries arrow visibility as a valid, nonzero scale. In Godot it becomes
# a discrete visibility property, so neither hidden geometry nor zero bases remain.
func _post_import(scene: Node) -> Object:
	var held_arrow := scene.find_child("HeldArrow", true, false) as Node3D
	if held_arrow == null:
		push_error("Archer import is missing HeldArrow: %s" % get_source_file())
		return scene
	var converted_tracks := 0
	var visibility_clips := 0
	for node in scene.find_children("*", "AnimationPlayer", true, false):
		var player := node as AnimationPlayer
		var animation_root := player.get_node(player.root_node)
		var arrow_path := NodePath(String(animation_root.get_path_to(held_arrow)) + ":visible")
		for clip in player.get_animation_list():
			var animation := player.get_animation(clip)
			var samples: Array[Dictionary] = []
			for track in range(animation.get_track_count() - 1, -1, -1):
				if animation.track_get_type(track) != Animation.TYPE_SCALE_3D:
					continue
				var path := animation.track_get_path(track)
				if animation_root.get_node_or_null(NodePath(path.get_concatenated_names())) != held_arrow:
					continue
				for key in range(animation.track_get_key_count(track)):
					var scale: Vector3 = animation.track_get_key_value(track, key)
					samples.append({"time": animation.track_get_key_time(track, key), "visible": scale.x > 0.5})
				animation.remove_track(track)
				converted_tracks += 1
			if samples.is_empty():
				# Import optimization removes constant scales equal to the rest value.
				if String(clip).get_file() in ["Idle", "Walk", "Run"]:
					samples.append({"time": 0.0, "visible": false})
				elif get_source_file().ends_with(".blend"):
					# Godot's native Blender conversion can omit the prop's action slot.
					# Use the same baked release marker rather than inventing a second timing.
					samples = _visibility_samples_from_metadata(String(clip).get_file(), animation)
				if samples.is_empty():
					continue
			samples.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["time"]) < float(b["time"]))
			var visibility_track := animation.add_track(Animation.TYPE_VALUE)
			animation.track_set_path(visibility_track, arrow_path)
			animation.value_track_set_update_mode(visibility_track, Animation.UPDATE_DISCRETE)
			animation.track_set_interpolation_type(visibility_track, Animation.INTERPOLATION_NEAREST)
			animation.track_set_interpolation_loop_wrap(visibility_track, false)
			animation.track_set_imported(visibility_track, true)
			for sample in samples:
				animation.track_insert_key(visibility_track, float(sample["time"]), bool(sample["visible"]))
			visibility_clips += 1
	held_arrow.scale = Vector3.ONE
	held_arrow.visible = false
	print("ARCHER_VISIBILITY_POST_IMPORT %s: %s scale tracks converted, %s visibility clips" % [get_source_file(), converted_tracks, visibility_clips])
	return scene


func _visibility_samples_from_metadata(clip: String, animation: Animation) -> Array[Dictionary]:
	var metadata: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/sprites/units/archer_animations.json"))
	if not metadata is Dictionary:
		push_error("Archer import needs valid animation metadata")
		return []
	var attack: Dictionary = metadata["clips"]["attack"]
	if clip != String(attack["source_animation"]):
		return []
	var flags: Array = attack["held_arrow_visible"]
	var fps := float(attack["fps"])
	var samples: Array[Dictionary] = []
	# Native .blend import keeps the source's first frame (currently +1/30s),
	# whereas the canonical GLB and game frames start at zero.
	var time_offset := maxf(animation.length - float(attack["duration"]), 0.0)
	if time_offset > 0.0:
		samples.append({"time": 0.0, "visible": false})
	for frame in range(flags.size()):
		if frame == 0 or bool(flags[frame]) != bool(flags[frame - 1]):
			samples.append({"time": time_offset + float(frame) / fps, "visible": bool(flags[frame])})
	samples.append({"time": time_offset + float(flags.size()) / fps, "visible": false})
	print("ARCHER_NATIVE_BLEND_ARROW_FALLBACK %s: metadata visibility only, source-frame offset %.6fs; native bone/morph tracks unchanged" % [clip, time_offset])
	return samples
