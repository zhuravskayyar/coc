@tool
extends EditorScenePostImport


func _post_import(scene: Node) -> Object:
	configure_scene(scene)
	return scene


static func configure_scene(scene: Node) -> void:
	for node in scene.find_children("*", "AnimationPlayer", true, false):
		var player := node as AnimationPlayer
		for clip in player.get_animation_list():
			player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR if String(clip).get_file() in ["Idle", "Walk", "Run", "Hammer"] else Animation.LOOP_NONE
		if player.has_animation("Idle"):
			player.autoplay = "Idle"
