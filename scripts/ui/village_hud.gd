class_name VillageHUD
extends Control

const UI := preload("res://scripts/ui/parchment_theme.gd")
const BUILDINGS := {
	&"temple": {"title": "Храм", "category": "Інше", "icon": "village", "description": "Серце поселення. Тут починається розвиток твоєї бази."},
	&"builder_hut": {"title": "Будиночок будівельника", "category": "Інше", "icon": "hammer", "description": "Домівка й майстерня будівельника. Тут він зберігає інструменти для роботи в поселенні."},
	&"war_tent": {"title": "Військовий намет", "category": "Армія", "icon": "army", "description": "Тренує ополченців: 100 хліба та 10 секунд за одного воїна."},
	&"unit_camp": {"title": "Армійський табір", "category": "Армія", "icon": "flag", "description": "Місце збору армії. Вільний простір усередині табору призначений для військ."},
	&"defense_tower": {"title": "Башта лучниці", "category": "Оборона", "icon": "shield", "description": "На платформі є власна анімована лучниця. Вона не входить до армії."},
	&"gold_extractor": {"title": "Золота копальня", "category": "Ресурси", "icon": "gold", "description": "Добуває золото для будівництва та покращень поселення."},
	&"gold_storage": {"title": "Сховище золота", "category": "Ресурси", "icon": "shop", "description": "Зберігає золото, зібране в копальнях і здобуте в боях."},
	&"wall": {"title": "Частокіл", "category": "Оборона", "icon": "shield", "description": "Дерев’яна огорожа. Сусідні секції автоматично з’єднуються між собою."},
}

@onready var interaction: VillageInteraction = $"../../VillageInteraction"
@onready var village_map: VillageMap = $"../../VillageMap"
@onready var camera: Camera2D = $"../../MapCamera"
@onready var economy: VillageEconomy = $"../../VillageEconomy"
@onready var army: ArmyManager = $"../../ArmyManager"

var _canvas: Control
var _profile: PanelContainer
var _builder: Button
var _resources: VBoxContainer
var _utility: HBoxContainer
var _navigation: HBoxContainer
var _attack: Button
var _build: Button
var _fullscreen_button: Button
var _fullscreen_check_button: CheckButton
var _fullscreen_state := false
var _selection_panel: PanelContainer
var _selection_content: VBoxContainer
var _placement_panel: PanelContainer
var _placement_title: Label
var _placement_status: Label
var _confirm: Button
var _wall_panel: PanelContainer
var _wall_status: Label
var _wall_place: Button
var _wall_erase: Button
var _wall_done: Button
var _modal_layer: Control
var _modal_panel: PanelContainer
var _modal_content: VBoxContainer
var _catalog_grid: GridContainer
var _category_buttons: Array[Button] = []
var _category := "Армія"
var _selected: VillageBuilding
var _resource_numbers: Dictionary[String, Label] = {}
var _resource_bars: Dictionary[String, ProgressBar] = {}
var _catalog_buttons: Dictionary[StringName, Button] = {}
var _construction_status: Label
var _construction_progress: ProgressBar
var _selection_was_constructing := false
var _builders_status: Label
var _builders_jobs: Label
var _army_status: Label
var _army_queue: Label
var _army_error: Label
var _train_button: Button
var _archer_train_button: Button
var _army_refresh_left := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UI.create_theme()
	_canvas = Control.new()
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_canvas)
	_create_hud()
	_create_selection_panel()
	_create_placement_panel()
	_create_wall_panel()
	_create_modal_layer()
	var wall_hint := village_map.get_parent().get_node_or_null("UI/WallPlacementHint") as Label
	if wall_hint != null:
		wall_hint.position = Vector2(24, 174)
		wall_hint.add_theme_font_override("font", UI.BODY)
		wall_hint.add_theme_font_size_override("font_size", 20)
	interaction.selection_changed.connect(_on_selection_changed)
	interaction.placement_changed.connect(_on_placement_changed)
	village_map.get_node("WallPlacement").mode_changed.connect(_on_wall_mode_changed)
	economy.changed.connect(_refresh_economy)
	economy.build_rejected.connect(_on_build_rejected)
	army.changed.connect(_refresh_army)
	get_viewport().size_changed.connect(_layout)
	_refresh_economy()
	_fullscreen_state = _is_fullscreen()
	_layout()


func _refresh_economy() -> void:
	_builder.text = "%d/%d" % [economy.get_free_builders(), economy.get_total_builders()]
	_resource_numbers["gold"].text = _format_amount(economy.gold)
	_resource_bars["gold"].value = float(economy.gold) / economy.GOLD_CAPACITY * 100.0
	_resource_numbers["bread"].text = _format_amount(economy.bread)
	_resource_bars["bread"].value = float(economy.bread) / economy.BREAD_CAPACITY * 100.0
	_refresh_army()
	for type: StringName in _catalog_buttons:
		var button := _catalog_buttons[type]
		if is_instance_valid(button):
			var error := economy.get_build_error(type)
			button.disabled = not error.is_empty()
			button.tooltip_text = error
	if _wall_panel.visible:
		_update_wall_status()


static func _format_amount(value: int) -> String:
	var digits := str(value)
	var result := ""
	for i in range(digits.length()):
		if i > 0 and (digits.length() - i) % 3 == 0:
			result += " "
		result += digits[i]
	return result


func _on_build_rejected(reason: String) -> void:
	if _placement_panel.visible:
		_placement_status.text = reason
	elif _wall_panel.visible:
		_wall_status.text = reason


func _process(_delta: float) -> void:
	var fullscreen_active := _is_fullscreen()
	if fullscreen_active != _fullscreen_state:
		_fullscreen_state = fullscreen_active
		_sync_fullscreen_controls(fullscreen_active)
	_army_refresh_left -= _delta
	if is_instance_valid(_army_queue) and has_modal() and _army_refresh_left <= 0.0:
		_army_refresh_left = 0.25
		_refresh_army()
	if has_modal() and is_instance_valid(_builders_status):
		_update_builders_message()
	if not is_instance_valid(_selected):
		return
	if _selection_was_constructing != _selected.is_under_construction():
		_on_selection_changed(_selected)
	if _selected.is_under_construction() and is_instance_valid(_construction_status):
		_construction_status.text = "Будується · залишилось %s" % VillageEconomy.format_time(_selected.construction_remaining)
		_construction_progress.value = _selected.get_construction_progress() * 100.0


func _create_hud() -> void:
	_profile = PanelContainer.new()
	_profile.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_profile.tooltip_text = "Рівень і досвід — демонстраційні дані UI."
	_canvas.add_child(_profile)
	var profile_row := HBoxContainer.new()
	_profile.add_child(profile_row)
	profile_row.add_theme_constant_override("separation", 9)
	var badge := PanelContainer.new()
	badge.custom_minimum_size = Vector2(62, 65)
	badge.add_theme_stylebox_override("panel", UI.hud_panel("bronze", 3))
	profile_row.add_child(badge)
	var level := UI.hud_label("1", 34)
	level.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_child(level)
	var identity := VBoxContainer.new()
	identity.add_theme_constant_override("separation", 1)
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	profile_row.add_child(identity)
	var village_name := UI.hud_label("Моє поселення", 27)
	village_name.add_theme_font_override("font", UI.DISPLAY)
	identity.add_child(village_name)
	var xp := UI.hud_bar("blue", 20)
	xp.value = 0
	identity.add_child(xp)
	var xp_label := UI.hud_label("0 / 100", 12)
	xp_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	xp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	xp_label.add_theme_constant_override("outline_size", 2)
	xp.add_child(xp_label)
	_builder = UI.hud_button("2/2", "hammer", "wood")
	_builder.add_theme_font_override("font", UI.hud_font())
	_builder.add_theme_font_size_override("font_size", 28)
	_builder.tooltip_text = "Будівельники · вільні / всього"
	_builder.pressed.connect(_show_builders)
	_canvas.add_child(_builder)
	_resources = VBoxContainer.new()
	_resources.add_theme_constant_override("separation", 5)
	_canvas.add_child(_resources)
	_resources.add_child(_resource("Золото", _format_amount(economy.gold), "gold", float(economy.gold) / economy.GOLD_CAPACITY))
	_resources.add_child(_resource("Хліб", _format_amount(economy.bread), "bread", float(economy.bread) / economy.BREAD_CAPACITY))
	_resources.add_child(_resource("Самоцвіти", str(economy.GEMS), "gem", -1))
	_utility = HBoxContainer.new()
	_utility.add_theme_constant_override("separation", 7)
	_canvas.add_child(_utility)
	var mail := UI.hud_button("", "mail")
	mail.tooltip_text = "Пошта"
	mail.custom_minimum_size = Vector2(52, 52)
	mail.pressed.connect(func(): _show_message("Пошта", "Тут з’являтимуться повідомлення та звіти про напади.\n\nПоки що листів немає.", "mail"))
	_utility.add_child(mail)
	var settings := UI.hud_button("", "gear")
	settings.tooltip_text = "Налаштування"
	settings.custom_minimum_size = Vector2(52, 52)
	settings.pressed.connect(_show_settings)
	_utility.add_child(settings)
	_fullscreen_button = UI.hud_button("", "", "wood", 30)
	_fullscreen_button.icon = _create_fullscreen_icon()
	_fullscreen_button.expand_icon = true
	_fullscreen_button.custom_minimum_size = Vector2(52, 52)
	_fullscreen_button.tooltip_text = "На весь екран"
	_fullscreen_button.pressed.connect(_toggle_fullscreen)
	_utility.add_child(_fullscreen_button)
	_attack = _navigation_button("Атака!", "sword", "bronze", true)
	_attack.pressed.connect(_show_attack)
	_canvas.add_child(_attack)
	_build = _navigation_button("Будувати", "hammer", "bronze", true)
	_build.pressed.connect(show_catalog)
	_canvas.add_child(_build)
	_navigation = HBoxContainer.new()
	_navigation.add_theme_constant_override("separation", 6)
	_canvas.add_child(_navigation)
	var village := _navigation_button("Поселення", "village", "wood")
	village.pressed.connect(_focus_village)
	_navigation.add_child(village)
	var army := _navigation_button("Армія", "army")
	army.pressed.connect(_show_army)
	_navigation.add_child(army)
	var clan := _navigation_button("Клан", "flag")
	clan.disabled = true
	clan.modulate = Color(1, 1, 1, 0.65)
	clan.tooltip_text = "Клани будуть доступні після підключення мережевої гри."
	_navigation.add_child(clan)
	var shop := _navigation_button("Магазин", "shop")
	shop.pressed.connect(show_catalog)
	_navigation.add_child(shop)


func _resource(title: String, value: String, icon_name: String, fill: float) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(246, 46)
	panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	panel.tooltip_text = title if icon_name == "gold" else "%s · ще не використовується" % title
	var content := Control.new()
	content.custom_minimum_size = Vector2(246, 46)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(content)
	if fill >= 0.0:
		var bar := UI.hud_bar(icon_name, 38)
		bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bar.offset_right = -24
		bar.offset_top = 4
		bar.offset_bottom = -4
		bar.value = fill * 100
		bar.fill_mode = ProgressBar.FILL_END_TO_BEGIN
		content.add_child(bar)
		_resource_bars[icon_name] = bar
	var number := UI.hud_label(value, 25)
	number.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	number.offset_left = 12
	number.offset_right = -56
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	content.add_child(number)
	_resource_numbers[icon_name] = number
	var resource_icon := UI.image(UI.icon(icon_name), Vector2(50, 46))
	resource_icon.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	resource_icon.offset_left = -50
	resource_icon.offset_right = 0
	resource_icon.offset_top = 0
	resource_icon.offset_bottom = 46
	content.add_child(resource_icon)
	return panel


func _navigation_button(title: String, icon_name: String, skin: String = "wood", primary: bool = false) -> Button:
	var result := UI.hud_button("", "", skin)
	result.custom_minimum_size = Vector2(156, 96) if primary else Vector2(92, 80)
	result.tooltip_text = title
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 6
	column.offset_right = -6
	column.offset_top = 4
	column.offset_bottom = -10
	column.add_theme_constant_override("separation", 0)
	result.add_child(column)
	column.add_child(UI.image(UI.icon(icon_name), Vector2(58, 53) if primary else Vector2(44, 43)))
	var label := UI.hud_label(title, 26 if primary else 17)
	label.add_theme_font_override("font", UI.DISPLAY)
	label.add_theme_constant_override("outline_size", 1)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(label)
	return result


func _create_selection_panel() -> void:
	_selection_panel = PanelContainer.new()
	_selection_panel.add_theme_stylebox_override("panel", UI.hud_panel("wood", 16))
	_selection_panel.hide()
	_canvas.add_child(_selection_panel)
	_selection_content = VBoxContainer.new()
	_selection_panel.add_child(_selection_content)


func _on_selection_changed(building: VillageBuilding) -> void:
	_selected = building
	_construction_status = null
	_construction_progress = null
	_selection_was_constructing = is_instance_valid(building) and building.is_under_construction()
	_clear(_selection_content)
	_selection_panel.visible = is_instance_valid(building) and not interaction.is_placing()
	if not is_instance_valid(building):
		return
	var data: Dictionary = BUILDINGS.get(StringName(building.building_type), {})
	var header := HBoxContainer.new()
	_selection_content.add_child(header)
	var heading := UI.hud_label(data.get("title", "Будівля"), 28)
	heading.add_theme_font_override("font", UI.DISPLAY)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	var close := UI.hud_button("", "close", "wood", 18)
	close.custom_minimum_size = Vector2(38, 36)
	close.tooltip_text = "Зняти вибір"
	close.pressed.connect(func(): interaction.select_building(null))
	header.add_child(close)
	var dimensions := building.get_footprint()
	_selection_content.add_child(UI.hud_label("Рівень %d   ·   Площа %d × %d" % [building.level, dimensions.x, dimensions.y], 15))
	if building.is_under_construction():
		_construction_status = UI.hud_label("Будується · залишилось %s" % VillageEconomy.format_time(building.construction_remaining), 17)
		_selection_content.add_child(_construction_status)
		_construction_progress = UI.hud_bar("green", 12)
		_construction_progress.value = building.get_construction_progress() * 100.0
		_selection_content.add_child(_construction_progress)
	var actions := HBoxContainer.new()
	_selection_content.add_child(actions)
	var info := UI.hud_button("Інфо", "info", "wood", 20)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.pressed.connect(_show_building_info)
	actions.add_child(info)
	var move := UI.hud_button("Перемістити", "move", "bronze", 20)
	move.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	move.pressed.connect(func(): interaction.begin_placement(StringName(building.building_type), building))
	move.disabled = building.is_under_construction()
	move.tooltip_text = "Переміщення буде доступне після завершення будівництва" if move.disabled else ""
	actions.add_child(move)
	var upgrade := UI.hud_button("Покращити", "arrow", "wood", 20)
	upgrade.disabled = true
	upgrade.tooltip_text = "Поки є лише рівень 1. Покращення під’єднаємо до економіки."
	actions.add_child(upgrade)
	if not building.is_under_construction() and building.building_type in ["war_tent", "unit_camp"]:
		var army_button := UI.hud_button("Тренувати" if building.building_type == "war_tent" else "Переглянути армію", "army", "wood", 20)
		army_button.pressed.connect(_show_army)
		_selection_content.add_child(army_button)
	if not building.is_under_construction() and building.building_type == "defense_tower":
		_selection_content.add_child(UI.hud_label("Власна лучниця башти · поза армією", 17))
	_layout()


func _create_placement_panel() -> void:
	_placement_panel = PanelContainer.new()
	_placement_panel.add_theme_stylebox_override("panel", UI.hud_panel("wood", 16))
	_placement_panel.hide()
	_canvas.add_child(_placement_panel)
	var column := VBoxContainer.new()
	_placement_panel.add_child(column)
	_placement_title = UI.hud_label("Розміщення", 21)
	column.add_child(_placement_title)
	_placement_status = UI.hud_label("Вибери місце на карті", 15)
	column.add_child(_placement_status)
	var actions := HBoxContainer.new()
	column.add_child(actions)
	var cancel := UI.hud_button("Скасувати", "close", "wood", 20)
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel.pressed.connect(interaction.cancel_placement)
	actions.add_child(cancel)
	_confirm = UI.hud_button("Поставити", "check", "bronze", 20)
	_confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_confirm.pressed.connect(interaction.confirm_placement)
	actions.add_child(_confirm)


func _on_placement_changed(active: bool, valid: bool) -> void:
	_placement_panel.visible = active
	_selection_panel.visible = not active and is_instance_valid(_selected)
	if active:
		var data: Dictionary = BUILDINGS.get(interaction.placing_type, {})
		_placement_title.text = data.get("title", "Будівля") + " · розміщення"
		var error := economy.get_build_error(interaction.placing_type) if interaction.moving == null else ""
		_placement_status.text = "Лівий клік — почати будівництво" if valid and interaction.moving == null else "Лівий клік — перемістити" if valid else error if not error.is_empty() else "Місце зайняте або за межами поля"
		_placement_status.add_theme_color_override("font_color", Color("e9ffc5") if valid else Color("ffc5ae"))
		_confirm.disabled = not valid
	_layout()


func _create_wall_panel() -> void:
	_wall_panel = PanelContainer.new()
	_wall_panel.add_theme_stylebox_override("panel", UI.hud_panel("wood", 16))
	_wall_panel.hide()
	_canvas.add_child(_wall_panel)
	var column := VBoxContainer.new()
	_wall_panel.add_child(column)
	column.add_child(UI.hud_label("Частокіл", 21))
	_wall_status = UI.hud_label("Лівий клік — поставити секцію", 15)
	column.add_child(_wall_status)
	var actions := HBoxContainer.new()
	column.add_child(actions)
	_wall_place = UI.hud_button("Ставити", "hammer", "wood", 20)
	_wall_place.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_wall_place.pressed.connect(func(): village_map.get_node("WallPlacement").set_erase_mode(false))
	actions.add_child(_wall_place)
	_wall_erase = UI.hud_button("Прибирати", "close", "wood", 20)
	_wall_erase.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_wall_erase.pressed.connect(func(): village_map.get_node("WallPlacement").set_erase_mode(true))
	actions.add_child(_wall_erase)
	_wall_done = UI.hud_button("Готово", "check", "bronze", 20)
	_wall_done.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_wall_done.pressed.connect(func(): village_map.get_node("WallPlacement").set_enabled(false))
	actions.add_child(_wall_done)


func _on_wall_mode_changed(active: bool, erasing: bool) -> void:
	_wall_panel.visible = active
	if active:
		interaction.select_building(null)
		var wall_hint := village_map.get_parent().get_node_or_null("UI/WallPlacementHint") as Label
		if wall_hint != null:
			wall_hint.hide()
		_update_wall_status()
		_wall_place.add_theme_stylebox_override("normal", UI.hud_panel("wood" if erasing else "bronze"))
		_wall_erase.add_theme_stylebox_override("normal", UI.hud_panel("bronze" if erasing else "wood"))
	_layout()


func _update_wall_status() -> void:
	if village_map.get_node("WallPlacement").erase_mode:
		_wall_status.text = "Лівий клік — прибрати секцію"
	else:
		var error := economy.get_build_error(&"wall")
		_wall_status.text = "Лівий клік — секція за %d золота" % BuildingCatalog.DEFINITIONS[&"wall"]["gold_cost"] if error.is_empty() else error


func _create_modal_layer() -> void:
	_modal_layer = Control.new()
	_modal_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	_canvas.add_child(_modal_layer)
	var shade := ColorRect.new()
	shade.color = Color(0.08, 0.07, 0.045, 0.65)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			close_modal()
		elif event is InputEventScreenTouch and event.pressed:
			close_modal()
	)
	_modal_layer.add_child(shade)
	_modal_panel = PanelContainer.new()
	_modal_layer.add_child(_modal_panel)
	_modal_content = VBoxContainer.new()
	_modal_content.add_theme_constant_override("separation", 12)
	_modal_panel.add_child(_modal_content)
	_modal_layer.hide()


func _open_modal(title: String, subtitle: String = "") -> void:
	interaction.cancel_placement()
	village_map.get_node("WallPlacement").set_enabled(false)
	_clear(_modal_content)
	_catalog_grid = null
	_catalog_buttons.clear()
	_builders_status = null
	_builders_jobs = null
	_army_status = null
	_army_queue = null
	_army_error = null
	_train_button = null
	var header := HBoxContainer.new()
	_modal_content.add_child(header)
	var heading := UI.label(title, 34, true)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	var close := UI.button("", "close", "wood")
	close.name = "CloseModal"
	close.custom_minimum_size = Vector2(42, 42)
	close.tooltip_text = "Закрити · Esc"
	close.pressed.connect(close_modal)
	header.add_child(close)
	if not subtitle.is_empty():
		var label := UI.label(subtitle, 19)
		label.add_theme_color_override("font_color", UI.MUTED)
		_modal_content.add_child(label)
	var line := HSeparator.new()
	var line_style := StyleBoxLine.new()
	line_style.color = UI.BRONZE
	line.add_theme_stylebox_override("separator", line_style)
	_modal_content.add_child(line)
	_modal_layer.show()
	close.grab_focus()
	_layout()


func close_modal() -> void:
	_modal_layer.hide()
	_catalog_grid = null
	_catalog_buttons.clear()


func has_modal() -> bool:
	return is_instance_valid(_modal_layer) and _modal_layer.visible


func show_catalog() -> void:
	_open_modal("Будівництво", "Ціна в золоті · 1 будівельник на споруду")
	var tabs := HBoxContainer.new()
	_modal_content.add_child(tabs)
	_category_buttons.clear()
	for category in ["Армія", "Оборона", "Ресурси", "Інше"]:
		var tab := UI.button(category)
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.pressed.connect(_select_category.bind(category))
		tabs.add_child(tab)
		_category_buttons.append(tab)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size.y = 308
	_modal_content.add_child(scroll)
	_catalog_grid = GridContainer.new()
	_catalog_grid.columns = 3
	_catalog_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_catalog_grid.add_theme_constant_override("h_separation", 10)
	_catalog_grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(_catalog_grid)
	_select_category(_category)


func _select_category(category: String) -> void:
	_category = category
	for tab in _category_buttons:
		tab.add_theme_stylebox_override("normal", UI.panel_style("bronze" if tab.text == category else "wood", 12))
	_clear(_catalog_grid)
	_catalog_buttons.clear()
	for type: StringName in BUILDINGS:
		if BUILDINGS[type]["category"] != category:
			continue
		_catalog_grid.add_child(_building_card(type))
	_layout()


func _building_card(type: StringName) -> PanelContainer:
	var data: Dictionary = BUILDINGS[type]
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(202, 262)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", UI.panel_style("paper", 12))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	card.add_child(column)
	var title := UI.label(data["title"], 23, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(title)
	var definition := BuildingCatalog.get_visual_definition(type)
	var sprite := load(definition["texture"]) as Texture2D
	var preview := UI.image(sprite, Vector2(148, 116))
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(preview)
	var dimensions := BuildingCatalog.get_footprint(type)
	var footprint := UI.label("Рівень 1  ·  Площа %d × %d" % [dimensions.x, dimensions.y], 18)
	footprint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(footprint)
	var build_data: Dictionary = BuildingCatalog.DEFINITIONS[type]
	var price := UI.label("%d золота · %s" % [build_data["gold_cost"], VillageEconomy.format_time(build_data["build_seconds"]) if build_data["build_seconds"] > 0 else "миттєво"], 18)
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(price)
	var button := UI.button("Розмістити", "hammer", "bronze")
	button.pressed.connect(_start_building.bind(type))
	var error := economy.get_build_error(type)
	button.disabled = not error.is_empty()
	button.tooltip_text = error
	_catalog_buttons[type] = button
	column.add_child(button)
	return card


func _start_building(type: StringName) -> void:
	var error := economy.get_build_error(type)
	if not error.is_empty():
		_refresh_economy()
		return
	close_modal()
	if type == &"wall":
		interaction.cancel_placement()
		var wall_controller := village_map.get_node("WallPlacement")
		wall_controller.set_erase_mode(false)
		wall_controller.set_enabled(true)
	else:
		interaction.begin_placement(type)


func _show_building_info() -> void:
	if not is_instance_valid(_selected):
		return
	var data: Dictionary = BUILDINGS.get(StringName(_selected.building_type), {})
	_open_modal(data.get("title", "Будівля"), "Рівень %d" % _selected.level)
	var definition := BuildingCatalog.get_visual_definition(StringName(_selected.building_type), _selected.wall_connection_mask)
	_modal_content.add_child(UI.image(load(definition["texture"]), Vector2(260, 180)))
	_add_paragraph(data.get("description", ""))
	var footprint := _selected.get_footprint()
	if _selected.is_under_construction():
		_add_paragraph("Будується · залишилось %s. Будівельник звільниться після завершення." % VillageEconomy.format_time(_selected.construction_remaining))
	else:
		_add_paragraph("Займає %d × %d клітинки. Будівлю можна перемістити на вільну ділянку поселення." % [footprint.x, footprint.y])
	_layout()


func _show_builders() -> void:
	_open_modal("Будівельники")
	_add_paragraph("Кожен готовий будиночок дає одного будівельника. Одна споруда займає одного будівельника до завершення таймера.")
	_builders_status = UI.label("", 23)
	_modal_content.add_child(_builders_status)
	_builders_jobs = UI.label("", 23)
	_builders_jobs.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_modal_content.add_child(_builders_jobs)
	_update_builders_message()
	_layout()


func _update_builders_message() -> void:
	_builders_status.text = "Вільні: %d із %d" % [economy.get_free_builders(), economy.get_total_builders()]
	var jobs := PackedStringArray()
	for child in economy.buildings.get_children():
		if child is VillageBuilding and child.is_under_construction():
			var data: Dictionary = BUILDINGS.get(StringName(child.building_type), {})
			jobs.append("%s · %s" % [data.get("title", "Будівля"), VillageEconomy.format_time(child.construction_remaining)])
	_builders_jobs.text = "\n".join(jobs) if not jobs.is_empty() else "Усі роботи завершено."


func _show_army() -> void:
	_open_modal("Армія")
	_army_status = UI.label("", 19)
	_modal_content.add_child(_army_status)
	var card := HBoxContainer.new()
	card.add_theme_constant_override("separation", 14)
	_modal_content.add_child(card)
	var portrait := UI.image(preload("res://assets/sprites/units/militia_portrait.png"), Vector2(128, 128))
	portrait.material = preload("res://assets/units/militia/militia_color.tres")
	card.add_child(portrait)
	var details := VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_child(details)
	details.add_child(UI.label(UnitCatalog.MILITIA["title"], 27, true))
	details.add_child(UI.label("Універсальний юніт", 19))
	details.add_child(UI.label("100 хліба · 10 секунд", 19))
	_train_button = UI.button("Тренувати ополченця · 100", "bread", "bronze")
	_train_button.name = "TrainMilitia"
	_train_button.pressed.connect(func(): army.train_militia(); _refresh_army())
	_modal_content.add_child(_train_button)
	var archer_card := HBoxContainer.new()
	archer_card.add_theme_constant_override("separation", 14)
	_modal_content.add_child(archer_card)
	archer_card.add_child(UI.image(preload("res://assets/sprites/units/archer_portrait.png"), Vector2(128, 128)))
	var archer_details := VBoxContainer.new()
	archer_details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	archer_card.add_child(archer_details)
	archer_details.add_child(UI.label(UnitCatalog.ARCHER["title"], 27, true))
	archer_details.add_child(UI.label("Дальній бій · поповнює армію", 19))
	archer_details.add_child(UI.label("125 хліба · 10 секунд", 19))
	_archer_train_button = UI.button("Тренувати лучницю · 125", "bread", "bronze")
	_archer_train_button.name = "TrainArcher"
	_archer_train_button.pressed.connect(func(): army.train_archer(); _refresh_army())
	_modal_content.add_child(_archer_train_button)
	_army_queue = UI.label("", 19)
	_army_queue.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_modal_content.add_child(_army_queue)
	_army_error = UI.label("", 17)
	_army_error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_army_error.add_theme_color_override("font_color", UI.MUTED)
	_modal_content.add_child(_army_error)
	_refresh_army()
	_layout()


func _refresh_army() -> void:
	if not is_instance_valid(_train_button):
		return
	_army_status.text = "Готових воїнів: ополченці %d · лучниці %d" % [army.soldiers.size(), army.archers.size()]
	_army_queue.text = army.training_status()
	var militia_error := army.get_train_error()
	var archer_error := army.get_archer_train_error()
	_train_button.disabled = not militia_error.is_empty()
	_train_button.tooltip_text = militia_error
	_archer_train_button.disabled = not archer_error.is_empty()
	_archer_train_button.tooltip_text = archer_error
	var errors := PackedStringArray()
	if not militia_error.is_empty():
		errors.append("Ополченець: " + militia_error)
	if not archer_error.is_empty():
		errors.append("Лучниця: " + archer_error)
	_army_error.text = "\n".join(errors) if not errors.is_empty() else "Готові воїни виходять із намету до табору. Вбудовані лучниці башт до армії не входять."


func _show_attack() -> void:
	_show_message("Готовність до атаки", "Спочатку підготуй армію у військовому наметі.\n\nПісля цього тут буде вибір суперника та перехід до бою.", "sword")
	var army := UI.button("До армії", "army", "bronze")
	army.pressed.connect(_show_army)
	_modal_content.add_child(army)
	_layout()


func _show_settings() -> void:
	_open_modal("Налаштування", "Керування поселенням")
	_add_paragraph("Лівий клік — вибрати або поставити будівлю\nКолесо миші — наблизити або віддалити\nПрава кнопка + рух миші — пересунути карту\n«Скасувати» — скасувати розміщення\n«Прибирати» — видаляти секції частоколу\n«Готово» — завершити роботу з частоколом\n× — закрити вікно")
	var fullscreen := CheckButton.new()
	fullscreen.text = "Повноекранний режим"
	_fullscreen_check_button = fullscreen
	fullscreen.button_pressed = _is_fullscreen()
	fullscreen.toggled.connect(_set_fullscreen)
	_modal_content.add_child(fullscreen)
	_layout()


static func _create_fullscreen_icon() -> Texture2D:
	var icon_image := Image.new()
	var svg := """
	<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64">
		<path d="M23 8H8V23 M41 8H56V23 M56 41V56H41 M23 56H8V41" fill="none" stroke="#291c12" stroke-width="9" stroke-linecap="round" stroke-linejoin="round"/>
		<path d="M23 8H8V23 M41 8H56V23 M56 41V56H41 M23 56H8V41" fill="none" stroke="#f0dfbc" stroke-width="5" stroke-linecap="round" stroke-linejoin="round"/>
	</svg>
	"""
	if icon_image.load_svg_from_string(svg) != OK:
		return null
	return ImageTexture.create_from_image(icon_image)


func _toggle_fullscreen() -> void:
	_set_fullscreen(not _is_fullscreen())


func _set_fullscreen(enabled: bool) -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED)
	_fullscreen_state = _is_fullscreen()
	_sync_fullscreen_controls(_fullscreen_state)


func _sync_fullscreen_controls(enabled: bool) -> void:
	if is_instance_valid(_fullscreen_button):
		_fullscreen_button.tooltip_text = "Вийти з повного екрана" if enabled else "На весь екран"
	if is_instance_valid(_fullscreen_check_button):
		_fullscreen_check_button.set_pressed_no_signal(enabled)


func _is_fullscreen() -> bool:
	return DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN


func _show_message(title: String, text: String, icon_name: String) -> void:
	_open_modal(title)
	_modal_content.add_child(UI.image(UI.icon(icon_name), Vector2(76, 76)))
	_add_paragraph(text)
	_layout()


func _add_paragraph(text: String) -> void:
	var label := UI.label(text, 23)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_modal_content.add_child(label)


func _focus_village() -> void:
	close_modal()
	interaction.cancel_placement()
	village_map.get_node("WallPlacement").set_enabled(false)
	interaction.select_building(null)
	camera.global_position = Vector2(0, 90)
	camera.zoom = Vector2.ONE * maxf(camera.min_zoom, 0.65)
	camera.force_update_scroll()


func _layout() -> void:
	if not is_instance_valid(_canvas):
		return
	var viewport_size := get_viewport_rect().size
	# Keep readable game controls on narrow screens with usable tap targets.
	# Godot stretches portrait viewports to the original 1280px width. Use the
	# physical window width too, so buttons don't become tiny on a phone.
	var design_width := clampf(float(get_window().size.x), 880.0, 1280.0)
	var ui_scale := viewport_size.x / design_width
	_canvas.scale = Vector2.ONE * ui_scale
	_canvas.size = viewport_size / ui_scale
	var width := _canvas.size.x
	var height := _canvas.size.y
	var margin := 18.0
	_place(_profile, Vector2(margin, margin), Vector2(280, 68))
	_place(_builder, Vector2((width - 138) * 0.5, margin + 2), Vector2(138, 60))
	_place(_resources, Vector2(width - 264, margin), Vector2(246, 148))
	_place(_utility, Vector2(margin, 98), Vector2(170, 52))
	_place(_attack, Vector2(margin, height - 114), Vector2(156, 96))
	_place(_build, Vector2(width - 174, height - 114), Vector2(156, 96))
	_place(_navigation, Vector2((width - 386) * 0.5, height - 98), Vector2(386, 80))
	_place(_selection_panel, Vector2((width - 548) * 0.5, height - 298), Vector2(548, 0))
	_place(_placement_panel, Vector2((width - 490) * 0.5, height - 279), Vector2(490, 0))
	_modal_layer.size = _canvas.size
	var modal_width := minf(742.0 if is_instance_valid(_catalog_grid) else 580.0, width - 60.0)
	_modal_panel.size.x = modal_width
	_modal_panel.size.y = 0
	# Container minimum size settles after content has been added.
	_layout_modal.call_deferred()
	_layout_action_panels.call_deferred()


func _layout_action_panels() -> void:
	for panel in [_selection_panel, _placement_panel, _wall_panel]:
		if not panel.visible:
			continue
		panel.reset_size()
		panel.size.x = 548 if panel == _selection_panel else 490
		panel.position = Vector2((_canvas.size.x - panel.size.x) * 0.5, _canvas.size.y - 126 - panel.size.y)


func _layout_modal() -> void:
	if not is_instance_valid(_modal_panel) or not _modal_layer.visible:
		return
	_modal_panel.reset_size()
	_modal_panel.size.x = minf(742.0 if is_instance_valid(_catalog_grid) else 580.0, _canvas.size.x - 60.0)
	_modal_panel.position = (_canvas.size - _modal_panel.size) * 0.5


func _place(control: Control, at: Vector2, dimensions: Vector2) -> void:
	control.position = at
	control.size = dimensions


func _clear(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()


func _input(event: InputEvent) -> void:
	if has_modal() and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			close_modal()
			get_viewport().set_input_as_handled()
		elif event.physical_keycode == KEY_W:
			get_viewport().set_input_as_handled()
