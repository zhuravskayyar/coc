@tool
class_name VillageBuilding
extends Node2D

signal construction_finished

const GRASS_GROUND_SHADER: Shader = preload("res://assets/shaders/building_grass.gdshader")
const PALISADE_SOIL_SHADER: Shader = preload("res://assets/shaders/palisade_soil.gdshader")
const CONSTRUCTION_VISUAL := preload("res://scripts/construction_visual.gd")

static var _source_ground_anchors: Dictionary[String, Vector2] = {}
static var _source_soil_colors: Dictionary[String, Color] = {}

@export_enum("temple", "builder_hut", "war_tent", "unit_camp", "gold_extractor", "gold_storage", "essence_extractor", "essence_storage", "defense_tower", "wall", "trap", "decor_small", "decor_large") var building_type: String = "temple":
	set(value):
		building_type = value
		_refresh_if_ready()
@export var cell := Vector2i.ZERO:
	set(value):
		cell = value
		_refresh_if_ready()
@export_range(1, 1) var level := 1

var _texture: Texture2D
var _tower_visual: Tower3DVisual
var _palisade_visual: Palisade3DVisual
var _sprite_rect := Rect2()
var _visible_sprite_top := 0.0
var _grass_ground: Polygon2D
var _campfire: Sprite2D
var _applying_grid_transform := false
var wall_connection_mask := 0
var construction_duration := 0.0
var construction_remaining := 0.0
var construction_animation_time := 0.0
var _completion_time := -1.0
var _construction_back: Node2D
var _construction_front: Node2D


func _ready() -> void:
	set_notify_local_transform(true)
	refresh_visuals()
	set_process(is_under_construction() and not Engine.is_editor_hint())
	var map := get_village_map()
	if map != null:
		map.register_building(self)


func _exit_tree() -> void:
	var map := get_village_map()
	if map != null:
		map.unregister_building(self)


func get_village_map() -> VillageMap:
	return get_node_or_null("../../VillageMap") as VillageMap


func get_footprint() -> Vector2i:
	return BuildingCatalog.get_footprint(StringName(building_type))


func is_under_construction() -> bool:
	return construction_remaining > 0.0


func get_construction_progress() -> float:
	return 1.0 - construction_remaining / construction_duration if construction_duration > 0.0 else 1.0


func start_construction(seconds: float) -> void:
	construction_duration = maxf(0.0, seconds)
	construction_remaining = construction_duration
	construction_animation_time = 0.0
	_completion_time = -1.0
	if is_node_ready():
		refresh_visuals()
		set_process(is_under_construction() and not Engine.is_editor_hint())
		var map := get_village_map()
		if map != null:
			map.rebuild_building_grid()


func advance_construction(delta: float) -> void:
	if not is_under_construction() or delta <= 0.0:
		return
	construction_remaining = maxf(0.0, construction_remaining - delta)
	construction_animation_time += delta
	if not is_under_construction():
		_completion_time = 0.0
		_refresh_construction_visuals()
		_refresh_campfire()
		_refresh_tower_archer()
		var map := get_village_map()
		if map != null:
			map.rebuild_building_grid()
		construction_finished.emit()
	queue_redraw()
	if is_instance_valid(_construction_front):
		_construction_front.queue_redraw()
		_construction_back.queue_redraw()


func _process(delta: float) -> void:
	if is_under_construction():
		advance_construction(delta)
	elif _completion_time >= 0.0:
		_completion_time += delta
		queue_redraw()
		if _completion_time >= 0.5:
			_completion_time = -1.0
			set_process(false)


func _refresh_construction_visuals() -> void:
	if is_under_construction() and not is_instance_valid(_construction_front):
		_construction_back = CONSTRUCTION_VISUAL.new()
		_construction_back.name = "ConstructionBack"
		_construction_back.show_behind_parent = true
		add_child(_construction_back)
		_construction_front = CONSTRUCTION_VISUAL.new()
		_construction_front.name = "ConstructionFront"
		_construction_front.front_layer = true
		add_child(_construction_front)
	if is_instance_valid(_construction_front):
		_construction_back.visible = is_under_construction()
		_construction_front.visible = is_under_construction()


func get_construction_rect() -> Rect2:
	return _construction_front.get_scaffold_rect() if is_instance_valid(_construction_front) else _sprite_rect


func hit_test_visual(point: Vector2) -> bool:
	if is_instance_valid(_palisade_visual):
		return _palisade_visual.hit_test(point, _sprite_rect)
	if is_under_construction() and is_instance_valid(_construction_front) and _construction_front.hit_test_scaffold(point):
		return true
	if _texture == null or not _sprite_rect.has_point(point):
		return false
	var uv := (point - _sprite_rect.position) / _sprite_rect.size
	if is_under_construction() and uv.y < 1.0 - lerpf(0.16, 1.0, get_construction_progress()):
		return false
	var image := _texture.get_image()
	return image != null and image.get_pixelv(Vector2i(uv * Vector2(_texture.get_size()))).a > 0.5


func _notification(what: int) -> void:
	if what == NOTIFICATION_LOCAL_TRANSFORM_CHANGED and is_node_ready() and not _applying_grid_transform:
		_sync_grid_transform()


func _sync_grid_transform() -> void:
	var map := get_village_map()
	var footprint := get_footprint()
	if map == null or footprint == Vector2i.ZERO:
		return
	_applying_grid_transform = true
	# The origin of every building is the center of its footprint on the ground.
	# Position and orientation come from the map; editor pixel offsets cannot drift.
	global_transform = map.global_transform * Transform2D(0.0, map.get_footprint_center(cell, footprint))
	_applying_grid_transform = false


func _refresh_if_ready() -> void:
	if is_node_ready():
		refresh_visuals()
		var map := get_village_map()
		if map != null:
			map.rebuild_building_grid()


func refresh_visuals() -> void:
	var map := get_village_map()
	var footprint := get_footprint()
	if map == null or footprint == Vector2i.ZERO:
		return
	_sync_grid_transform()
	var definition := BuildingCatalog.get_visual_definition(StringName(building_type), wall_connection_mask)
	if building_type == "wall" and definition.has("model"):
		if is_instance_valid(_tower_visual):
			_tower_visual.queue_free()
			_tower_visual = null
		_palisade_visual = Palisade3DVisual.get_shared_visual(wall_connection_mask)
		_texture = _palisade_visual.get_texture()
		_sprite_rect = _palisade_visual.get_draw_rect()
		_visible_sprite_top = _palisade_visual.project_point(Vector3(0, 0.745, 0)).y
	elif definition.has("model"):
		_palisade_visual = null
		if not is_instance_valid(_tower_visual):
			_tower_visual = Tower3DVisual.new()
			_tower_visual.name = "Tower3DVisual"
			add_child(_tower_visual)
		_tower_visual.configure_ground_width(footprint.x * VillageMap.TILE_SIZE.x)
		_texture = _tower_visual.get_texture()
		_sprite_rect = _tower_visual.get_draw_rect()
		_visible_sprite_top = _tower_visual.project_point(Vector3(0, 1.0, 0)).y
	else:
		_palisade_visual = null
		if is_instance_valid(_tower_visual):
			_tower_visual.queue_free()
			_tower_visual = null
		_texture = load(definition["texture"]) as Texture2D if definition.has("texture") else null
	if _texture != null and not definition.has("model"):
		var source_ground_width := float(definition["source_ground_width"])
		# Retain the existing uniform size; the asset's source width is not an offset.
		var sprite_scale := footprint.x * VillageMap.TILE_SIZE.x / source_ground_width
		var ground_anchor := _get_source_ground_anchor(_texture, source_ground_width)
		_sprite_rect = Rect2(-ground_anchor * sprite_scale, Vector2(_texture.get_size()) * sprite_scale)
		_visible_sprite_top = _sprite_rect.position.y + _texture.get_image().get_used_rect().position.y * sprite_scale
	if building_type == "wall" and not definition.has("model"):
		if not material is ShaderMaterial or (material as ShaderMaterial).shader != PALISADE_SOIL_SHADER:
			var soil_material := ShaderMaterial.new()
			soil_material.shader = PALISADE_SOIL_SHADER
			material = soil_material
		(material as ShaderMaterial).set_shader_parameter("tile_size", VillageMap.TILE_SIZE)
	elif material is ShaderMaterial and (material as ShaderMaterial).shader == PALISADE_SOIL_SHADER:
		material = null
	_refresh_grass_ground()
	_refresh_campfire()
	_refresh_construction_visuals()
	_refresh_tower_archer()
	queue_redraw()


func _refresh_tower_archer() -> void:
	if is_instance_valid(_tower_visual):
		_tower_visual.set_archer_enabled(building_type == "defense_tower" and not is_under_construction())


func refresh_wall_connections(mask: int) -> void:
	if building_type != "wall":
		return
	mask &= 15
	if wall_connection_mask == mask and _texture != null:
		return
	wall_connection_mask = mask
	refresh_visuals()


func _refresh_campfire() -> void:
	var definition: Dictionary = BuildingCatalog.DEFINITIONS.get(StringName(building_type), {})
	if not definition.has("campfire_texture"):
		if is_instance_valid(_campfire):
			_campfire.visible = false
		return
	if not is_instance_valid(_campfire):
		_campfire = Sprite2D.new()
		_campfire.name = "Campfire"
		_campfire.centered = false
		# Camp floor stays below future units; the separate fire can sort with them.
		_campfire.z_as_relative = false
		_campfire.z_index = 30
		add_child(_campfire)
	_campfire.texture = load(definition["campfire_texture"]) as Texture2D
	_campfire.visible = _campfire.texture != null and not is_under_construction()
	if _campfire.texture == null:
		return
	var map := get_village_map()
	var local_cell: Vector2i = definition["campfire_cell"]
	var source_width := float(definition["campfire_source_ground_width"])
	var visual_width := VillageMap.TILE_SIZE.x * 0.7
	var uniform_scale := visual_width / source_width
	var ground_anchor := _get_source_ground_anchor(_campfire.texture, source_width)
	var grid_point := map.cell_to_world(cell + local_cell) - map.get_footprint_center(cell, get_footprint())
	_campfire.scale = Vector2.ONE * uniform_scale
	# Keep the sorting origin on the ground; only the texture uses its source anchor.
	_campfire.position = grid_point
	_campfire.offset = -ground_anchor


static func _get_source_ground_anchor(texture: Texture2D, source_ground_width: float) -> Vector2:
	var key := "%s:%s" % [texture.resource_path, source_ground_width]
	if _source_ground_anchors.has(key):
		return _source_ground_anchors[key]
	var image := texture.get_image()
	var used := image.get_used_rect()
	var front_y := -1
	var x_sum := 0.0
	var samples := 0
	# Ignore faint alpha artifacts and average a narrow band at the front contact.
	# The same rule applies to every PNG, independently of transparent canvas padding.
	var band_height := maxi(2, roundi(source_ground_width * 0.005))
	for y in range(used.end.y - 1, used.position.y - 1, -1):
		if front_y >= 0 and front_y - y >= band_height:
			break
		for x in range(used.position.x, used.end.x):
			if image.get_pixel(x, y).a < 0.5:
				continue
			if front_y < 0:
				front_y = y
			x_sum += x + 0.5
			samples += 1
	var anchor := Vector2.ZERO
	if samples > 0:
		var half_ground_height := source_ground_width * VillageMap.TILE_SIZE.y / VillageMap.TILE_SIZE.x * 0.5
		anchor = Vector2(x_sum / samples, front_y + 0.5 - half_ground_height)
	_source_ground_anchors[key] = anchor
	return anchor


func _refresh_grass_ground() -> void:
	var definition := BuildingCatalog.get_visual_definition(StringName(building_type), wall_connection_mask)
	if building_type == "wall" and definition.has("model"):
		if is_instance_valid(_grass_ground):
			_grass_ground.visible = false
		return
	if not is_instance_valid(_grass_ground):
		_grass_ground = Polygon2D.new()
		_grass_ground.name = "GrassGround"
		# Keep every ground patch below all buildings and the placement overlay.
		_grass_ground.z_as_relative = false
		_grass_ground.z_index = 15
		_grass_ground.texture = VillageMap.GRASS_LIGHT
		var ground_material := ShaderMaterial.new()
		ground_material.shader = GRASS_GROUND_SHADER
		ground_material.set_shader_parameter("grass_texture", VillageMap.GRASS_LIGHT)
		ground_material.set_shader_parameter("grass_tint", Color(0.49, 0.68, 0.40, 1.0))
		_grass_ground.material = ground_material
		add_child(_grass_ground)
	_grass_ground.visible = _texture != null
	var map := get_village_map()
	var footprint := Vector2(get_footprint())
	var patch_size := footprint + Vector2.ONE * BuildingCatalog.VISUAL_GRASS_MARGIN * 2.0
	var center := map.get_footprint_center(cell, get_footprint())
	var polygon := PackedVector2Array()
	for corner in map.get_footprint_polygon(cell, get_footprint(), BuildingCatalog.VISUAL_GRASS_MARGIN):
		polygon.append(corner - center)
	_grass_ground.polygon = polygon
	var texture_size := Vector2(VillageMap.GRASS_LIGHT.get_size())
	_grass_ground.uv = PackedVector2Array([
		Vector2.ZERO,
		Vector2(texture_size.x, 0.0),
		texture_size,
		Vector2(0.0, texture_size.y),
	])
	(_grass_ground.material as ShaderMaterial).set_shader_parameter("patch_size_in_cells", patch_size)
	var ground_material := _grass_ground.material as ShaderMaterial
	# Bare palisade soil blends outwards; raised wooden/stone foundations keep their rims.
	var has_soil := building_type == "wall" and _texture != null
	ground_material.set_shader_parameter("soil_enabled", has_soil)
	if has_soil:
		var soil_color := Color(0.9, 0.67, 0.36)
		soil_color = _get_source_soil_color(_texture, float(definition["source_ground_width"]))
		ground_material.set_shader_parameter("soil_color", soil_color)


static func _get_source_soil_color(texture: Texture2D, source_width: float) -> Color:
	var key := "%s:%s" % [texture.resource_path, source_width]
	if _source_soil_colors.has(key):
		return _source_soil_colors[key]
	var image := texture.get_image()
	var anchor := _get_source_ground_anchor(texture, source_width)
	# Sample the bare soil just inside the front corner, away from poles and the outline.
	var sample_center := anchor + Vector2(0.0, source_width * 0.29)
	var color_sum := Color(0.0, 0.0, 0.0, 0.0)
	var samples := 0
	for y in [-1, 0, 1]:
		for x in [-1, 0, 1]:
			var point := Vector2i(sample_center + Vector2(x, y) * source_width * 0.015)
			if not Rect2i(Vector2i.ZERO, image.get_size()).has_point(point):
				continue
			var pixel := image.get_pixelv(point)
			if pixel.a < 0.5:
				continue
			color_sum += pixel
			samples += 1
	var soil_color := color_sum / float(samples) if samples > 0 else Color(0.9, 0.67, 0.36)
	soil_color.a = 1.0
	_source_soil_colors[key] = soil_color
	return soil_color


func _draw() -> void:
	var footprint := get_footprint()
	if footprint == Vector2i.ZERO:
		return
	if _texture != null:
		if is_under_construction():
			# Reveal the finished sprite from the foundation upward as work advances.
			var progress := get_construction_progress()
			var fraction := lerpf(0.16, 1.0, progress)
			var source_size := Vector2(_texture.get_size())
			var source := Rect2(Vector2(0, source_size.y * (1.0 - fraction)), Vector2(source_size.x, source_size.y * fraction))
			var target := Rect2(_sprite_rect.position + Vector2(0, _sprite_rect.size.y * (1.0 - fraction)), Vector2(_sprite_rect.size.x, _sprite_rect.size.y * fraction))
			draw_texture_rect_region(_texture, target, source, Color(0.90, 0.83, 0.68, lerpf(0.45, 1.0, progress)))
		else:
			if _completion_time >= 0.0:
				var pulse := sin(_completion_time / 0.5 * PI) * 0.035
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * (1.0 + pulse))
			draw_texture_rect(_texture, _sprite_rect, false)
			draw_set_transform(Vector2.ZERO)
