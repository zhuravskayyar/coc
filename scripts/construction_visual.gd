@tool
extends Node2D

const SCAFFOLD_PATH := "res://assets/sprites/buildings/construction_scaffold_v1.png"
const HAMMER: Texture2D = preload("res://assets/ui/icons/raster/hammer.png")
const FONT: Font = preload("res://assets/ui/fonts/Rubik-Variable.ttf")

static var _scaffold: Texture2D
static var _anchor := Vector2.ZERO
static var _source_width := 1.0
static var _source_top := 0.0
var front_layer := false
var _badge_style: StyleBoxFlat


func _ready() -> void:
	if _scaffold == null and ResourceLoader.exists(SCAFFOLD_PATH):
		_scaffold = load(SCAFFOLD_PATH) as Texture2D
		_source_width = float(_scaffold.get_image().get_used_rect().size.x)
		_source_top = float(_scaffold.get_image().get_used_rect().position.y)
		_anchor = VillageBuilding._get_source_ground_anchor(_scaffold, _source_width)
	_badge_style = StyleBoxFlat.new()
	_badge_style.bg_color = Color("39291d")
	_badge_style.border_color = Color("af8751")
	_badge_style.set_border_width_all(2)
	_badge_style.set_corner_radius_all(2)


func get_scaffold_rect() -> Rect2:
	var building := get_parent() as VillageBuilding
	var sprite_scale := building.get_footprint().x * VillageMap.TILE_SIZE.x / _source_width
	return Rect2(-_anchor * sprite_scale, Vector2(_scaffold.get_size()) * sprite_scale) if _scaffold != null else building._sprite_rect


func hit_test_scaffold(point: Vector2) -> bool:
	var rect := get_scaffold_rect()
	if _scaffold == null or not rect.has_point(point):
		return false
	var uv := (point - rect.position) / rect.size
	return _scaffold.get_image().get_pixelv(Vector2i(uv * Vector2(_scaffold.get_size()))).a > 0.5


func _draw() -> void:
	var building := get_parent() as VillageBuilding
	if building == null or not building.is_under_construction():
		return
	var rect := get_scaffold_rect()
	if _scaffold != null:
		var source_size := Vector2(_scaffold.get_size())
		# Back timbers sort behind the emerging building; the front rail stays above it.
		var cut := clampf((_anchor.y - _source_width * 0.10) / source_size.y, 0.0, 1.0)
		var from_y := cut if front_layer else 0.0
		var height := 1.0 - cut if front_layer else cut
		var source := Rect2(Vector2(0, source_size.y * from_y), Vector2(source_size.x, source_size.y * height))
		var target := Rect2(rect.position + Vector2(0, rect.size.y * from_y), Vector2(rect.size.x, rect.size.y * height))
		draw_texture_rect_region(_scaffold, target, source)
	if not front_layer:
		return
	var width := building.get_footprint().x * VillageMap.TILE_SIZE.x
	var time := building.construction_animation_time
	var work_point := Vector2(width * 0.23, width * 0.13)
	var manager := building.get_node_or_null("../../BuilderManager")
	# The physical worker now carries the hammer and its strike dust.
	# Retain the old visual for standalone construction previews without workers.
	if manager == null or manager.call("worker_for", building) == null:
		var phase := fmod(time * 1.7, 1.0)
		var swing := lerpf(-0.65, 0.65, sin(phase * PI))
		var hammer_size := clampf(width * 0.15, 30.0, 52.0)
		draw_set_transform(work_point + Vector2(0, -16), swing)
		draw_texture_rect(HAMMER, Rect2(Vector2(-hammer_size * 0.3, -hammer_size), Vector2.ONE * hammer_size), false)
		draw_set_transform(Vector2.ZERO)
		for i in range(6):
			var age := fmod(phase + i * 0.12, 1.0)
			var spread := (float(i) - 2.5) * 7.0
			var puff := work_point + Vector2(spread * age, -age * 30.0)
			draw_circle(puff, 2.0 + age * 4.0, Color(0.89, 0.78, 0.56, (1.0 - age) * 0.55))
	var scale_on_screen := maxf(get_global_transform_with_canvas().get_scale().x, 0.01)
	var scaffold_top := rect.position.y + _source_top * width / _source_width
	var badge_y := minf(scaffold_top, building._visible_sprite_top) - 12.0
	draw_set_transform(Vector2(0, badge_y), 0.0, Vector2.ONE / scale_on_screen)
	draw_style_box(_badge_style, Rect2(-59, -34, 118, 37))
	var label := VillageEconomy.format_time(building.construction_remaining)
	var text_width := FONT.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
	draw_string(FONT, Vector2(-text_width * 0.5, -13), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("f0dfbc"))
	draw_rect(Rect2(-49, -7, 98, 4), Color("211910"))
	draw_rect(Rect2(-49, -7, 98 * building.get_construction_progress(), 4), Color("b5b77c"))
	draw_set_transform(Vector2.ZERO)
