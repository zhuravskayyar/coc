extends SceneTree

const UI = preload("res://scripts/ui/parchment_theme.gd")
const ICONS := {
	"gold": "Золото", "bread": "Провіант", "gem": "Кристали",
	"hammer": "Будувати", "sword": "Атака", "shield": "Захист",
	"village": "Поселення", "army": "Армія", "flag": "Клан",
	"shop": "Магазин", "mail": "Пошта", "gear": "Налаштування",
	"info": "Інформація", "move": "Перемістити", "arrow": "Покращити",
	"check": "Підтвердити", "close": "Скасувати",
}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for icon_name in ICONS:
		var source := Image.load_from_file(ProjectSettings.globalize_path("res://assets/ui/icons/raster/%s.png" % icon_name))
		if source == null or source.is_empty() or source.detect_alpha() == Image.ALPHA_NONE:
			push_error("PNG must contain alpha: %s" % icon_name)
			quit(1)
			return
		for corner in [Vector2i.ZERO, Vector2i(source.get_width() - 1, 0),
			Vector2i(0, source.get_height() - 1), source.get_size() - Vector2i.ONE]:
			if source.get_pixelv(corner).a > 0.0:
				push_error("PNG background corner is opaque: %s" % icon_name)
				quit(1)
				return
		var imported := UI.icon(icon_name)
		print("Icon %s: source %s, imported %s, transparent corners" % [icon_name, source.get_size(), imported.get_size()])

	var background := ColorRect.new()
	background.color = Color("302d27")
	root.add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	margin.theme = UI.create_theme()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 24)
	root.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	margin.add_child(column)
	var title := UI.label("Растрові іконки · повний набір", 30, true)
	title.add_theme_color_override("font_color", Color("f1ddb6"))
	column.add_child(title)
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	column.add_child(grid)
	for icon_name in ICONS:
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(232, 138)
		card.add_theme_stylebox_override("panel", UI.panel_style("paper", 12))
		grid.add_child(card)
		var content := VBoxContainer.new()
		card.add_child(content)
		content.add_child(UI.label(ICONS[icon_name], 21, true))
		var samples := HBoxContainer.new()
		samples.alignment = BoxContainer.ALIGNMENT_CENTER
		samples.add_theme_constant_override("separation", 12)
		content.add_child(samples)
		for dimension in [84, 40, 28]:
			var sample := UI.image(UI.icon(icon_name), Vector2(dimension, dimension))
			sample.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			samples.add_child(sample)
	var caption := UI.label("PNG із прозорим фоном · зліва направо: 84 / 40 / 28 px · фактичний рендер Godot", 20)
	caption.add_theme_color_override("font_color", Color("f1ddb6"))
	column.add_child(caption)
	for frame in range(8):
		await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png("res://docs/ui-icons-preview.png")
	if error != OK:
		push_error("Could not save icon preview")
	quit(0 if error == OK else 1)
