class_name ParchmentTheme
extends RefCounted

const INK := Color("352b20")
const MUTED := Color("746044")
const IVORY := Color("f0dfbc")
const BRONZE := Color("bf965b")
const DISPLAY: Font = preload("res://assets/ui/fonts/Neucha-Regular.ttf")
const BODY: Font = preload("res://assets/ui/fonts/AlegreyaSans-Regular.ttf")
const HUD_FONT: Font = preload("res://assets/ui/fonts/Rubik-Variable.ttf")
static var _hud_font: FontVariation
static var _hud_bar_textures: Dictionary[String, Texture2D] = {}


static func panel_style(skin: String = "paper", padding: float = 18.0) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = load("res://assets/ui/panels/%s.svg" % skin)
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_texture_margin(side, 16.0)
		style.set_content_margin(side, padding)
	return style


static func create_theme() -> Theme:
	var result := Theme.new()
	result.default_font = BODY
	result.default_font_size = 20
	result.set_color("font_color", "Label", INK)
	result.set_font("font", "Button", DISPLAY)
	result.set_font_size("font_size", "Button", 22)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		result.set_color(state, "Button", IVORY)
	result.set_color("font_outline_color", "Button", Color("291c12"))
	result.set_constant("outline_size", "Button", 1)
	result.set_color("font_disabled_color", "Button", Color("b29c78"))
	result.set_color("icon_disabled_color", "Button", Color(1, 1, 1, 0.35))
	result.set_constant("h_separation", "Button", 8)
	result.set_stylebox("normal", "Button", panel_style("wood", 12))
	var hover := panel_style("wood", 12)
	hover.modulate_color = Color(1.12, 1.10, 1.06)
	result.set_stylebox("hover", "Button", hover)
	var pressed := panel_style("wood", 12)
	pressed.modulate_color = Color(0.84, 0.82, 0.78)
	result.set_stylebox("pressed", "Button", pressed)
	var disabled := panel_style("wood", 12)
	disabled.modulate_color = Color(0.72, 0.70, 0.66)
	result.set_stylebox("disabled", "Button", disabled)
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	focus.border_color = BRONZE
	focus.set_border_width_all(1)
	focus.set_corner_radius_all(3)
	result.set_stylebox("focus", "Button", focus)
	result.set_stylebox("panel", "PanelContainer", panel_style())
	result.set_stylebox("panel", "TooltipPanel", panel_style("wood_dark", 12))
	result.set_font("font", "TooltipLabel", BODY)
	result.set_font_size("font_size", "TooltipLabel", 18)
	result.set_color("font_color", "TooltipLabel", Color("f1ddb6"))
	result.set_stylebox("background", "ProgressBar", _bar(Color("655a42")))
	result.set_stylebox("fill", "ProgressBar", _bar(Color("82935f")))
	result.set_constant("separation", "HBoxContainer", 10)
	result.set_constant("separation", "VBoxContainer", 8)
	return result


static func _bar(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = INK
	style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	return style


static func icon(name: String) -> Texture2D:
	return load("res://assets/ui/icons/raster/%s.png" % name) as Texture2D


static func label(text: String, font_size: int = 20, heading: bool = false) -> Label:
	var result := Label.new()
	result.text = text
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result.add_theme_font_override("font", DISPLAY if heading else BODY)
	result.add_theme_font_size_override("font_size", font_size)
	return result


static func image(texture: Texture2D, dimensions: Vector2) -> TextureRect:
	var result := TextureRect.new()
	result.texture = texture
	result.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	result.custom_minimum_size = dimensions
	result.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	result.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return result


static func button(text: String, icon_name: String = "", skin: String = "wood") -> Button:
	var result := Button.new()
	result.text = text
	result.custom_minimum_size = Vector2(0, 48)
	result.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if not icon_name.is_empty():
		result.icon = icon(icon_name)
		result.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		result.expand_icon = true
		result.add_theme_constant_override("icon_max_width", 28)
	if skin != "wood":
		result.add_theme_stylebox_override("normal", panel_style(skin, 12))
		var hover := panel_style(skin, 12)
		hover.modulate_color = Color(1.10, 1.10, 1.06)
		result.add_theme_stylebox_override("hover", hover)
		var pressed := panel_style(skin, 12)
		pressed.modulate_color = Color(0.9, 0.9, 0.9)
		result.add_theme_stylebox_override("pressed", pressed)
	return result


static func hud_font() -> FontVariation:
	if _hud_font == null:
		_hud_font = FontVariation.new()
		_hud_font.base_font = HUD_FONT
		var text_server := TextServerManager.get_primary_interface()
		_hud_font.variation_opentype = {text_server.name_to_tag("wght"): 600.0}
	return _hud_font


static func hud_panel(skin: String = "wood", padding: float = 10.0) -> StyleBoxTexture:
	return panel_style(skin, padding)


static func hud_bar(skin: String, height: int) -> ProgressBar:
	var result := ProgressBar.new()
	result.custom_minimum_size.y = height
	result.show_percentage = false
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result.add_theme_stylebox_override("background", _hud_bar_style("dark", height))
	result.add_theme_stylebox_override("fill", _hud_bar_style(skin, height))
	return result


static func _hud_bar_style(skin: String, height: int) -> StyleBoxTexture:
	var style := panel_style("hud_%s" % skin, 0)
	var texture_scale := float(height) / style.texture.get_height()
	var key := "%s:%d" % [skin, height]
	if not _hud_bar_textures.has(key):
		var image := style.texture.get_image()
		image.resize(maxi(1, roundi(image.get_width() * texture_scale)), height, Image.INTERPOLATE_LANCZOS)
		_hud_bar_textures[key] = ImageTexture.create_from_image(image)
	style.texture = _hud_bar_textures[key]
	# Scale the artwork AND its fixed edges to the bar height. Zero content
	# margins keep ProgressBar's fill width proportional even near 0%.
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_texture_margin(side, 16.0 * texture_scale)
	return style


static func hud_label(text: String, font_size: int = 22) -> Label:
	var result := label(text, font_size)
	result.add_theme_font_override("font", hud_font())
	result.add_theme_color_override("font_color", IVORY)
	result.add_theme_color_override("font_outline_color", Color("291c12"))
	result.add_theme_constant_override("outline_size", 2)
	result.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.35))
	result.add_theme_constant_override("shadow_offset_y", 1)
	return result


static func hud_button(text: String, icon_name: String = "", skin: String = "wood", font_size: int = 24) -> Button:
	var result := button(text, icon_name)
	result.add_theme_font_override("font", DISPLAY)
	result.add_theme_font_size_override("font_size", font_size)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		result.add_theme_color_override(state, IVORY)
	result.add_theme_color_override("font_outline_color", Color("291c12"))
	result.add_theme_constant_override("outline_size", 1)
	result.add_theme_color_override("font_disabled_color", Color("b29c78"))
	result.add_theme_constant_override("icon_max_width", 36)
	result.add_theme_stylebox_override("normal", hud_panel(skin))
	var hover := hud_panel(skin)
	hover.modulate_color = Color(1.12, 1.10, 1.06)
	result.add_theme_stylebox_override("hover", hover)
	var pressed := hud_panel(skin)
	pressed.modulate_color = Color(0.84, 0.82, 0.78)
	result.add_theme_stylebox_override("pressed", pressed)
	var disabled := hud_panel(skin)
	disabled.modulate_color = Color(0.72, 0.70, 0.66)
	result.add_theme_stylebox_override("disabled", disabled)
	return result
