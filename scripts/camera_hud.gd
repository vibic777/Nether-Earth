# Контрибьютор: vibic777
extends CanvasLayer

var _status: Label
var _hint: Label
var _net: Label
var _stock: Label
var _difficulty: Label
var _yard: HFlowContainer
var _deploy_btn: Button
var _toast_label: Label
var _toast_left := 0.0
var _yard_key := Vector2i(-99, -99)
var _orders: HBoxContainer
var _order_buttons: Array[Button] = []
var _weapon_bar: HBoxContainer
var _weapon_name: Label
var _tier_name: Label
var _camera: IsoCamera
var _grid: BattleGrid
var _panel: PanelContainer
var _info_title: Label
var _info_line: Label
var _hull_bar: ProgressBar
var _roster: GridContainer
var _roster_key := ""
var _group_buttons: Array[Button] = []
var _disband: Button
var _story_name: Label
var _story_text: Label
var _minimap: Minimap
const PANEL_H := 270.0
var _mode_bar: HBoxContainer
var _mode_buttons: Array[Button] = []
var _ability: Button
var _cheats: PanelContainer
var _spawn_unit: OptionButton
var _spawn_side: OptionButton
var _spawn_site: OptionButton
var _spawn_cell: OptionButton
var settings_menu: SettingsMenu
var help_window: HelpWindow
var _tip: PanelContainer
var _tip_title: Label
var _tip_text: Label
var _tip_id := ""
var _tip_left := 0.0
var _scale_tick := 0.0

func _ready() -> void:
	_camera = get_parent().get_node("CameraRig")
	_grid = get_parent().get_node("Grid")
	_build()
	var box := Control.new()
	box.set_script(load("res://scripts/select_box.gd"))
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	add_to_group("settings_listeners")
	_build_overlays()
	_tag_help()

func _process(_delta: float) -> void:
	var _pt := Prof.t()
	_process_inner(_delta)
	Prof.add("hud", _pt)

func _process_inner(_delta: float) -> void:
	var cell := ""
	if _grid.hovered.x >= 0:
		var kind: int = _grid.kind_at(_grid.hovered)
		cell = "   %d,%d · %s" % [_grid.hovered.x, _grid.hovered.y, _grid.kind_name(kind)]
	_status.text = "Nether Earth Reloaded    %s · %d%%%s" % [_camera.view_name(), _camera.zoom_percent(), cell]
	_hint.text = get_parent().selected_label()
	_net.text = get_parent().network_label()
	_stock.text = get_parent().stock_label()
	_difficulty.text = get_parent().difficulty_label()
	_sync_yard()
	_sync_orders()
	_sync_panel()
	_sync_modes()
	_tick_overlays(_delta)
	var unit := _armed_unit()
	_weapon_bar.visible = unit != null
	if unit != null:
		_weapon_name.text = WeaponRack.title(unit.weapon)
		_tier_name.text = "Сила %s · %d" % [WeaponRack.roman(unit.tier), WeaponRack.strike(unit.weapon, unit.tier)]

func _build() -> void:
	_status = Label.new()
	_status.position = Vector2(20, 16)
	_status.add_theme_font_size_override("font_size", 22)
	_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_status)
	_hint = Label.new()
	_hint.position = Vector2(20, 46)
	_hint.add_theme_font_size_override("font_size", 20)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hint)
	_net = Label.new()
	_net.position = Vector2(20, 74)
	_net.add_theme_font_size_override("font_size", 20)
	_net.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_net)
	_stock = Label.new()
	_stock.position = Vector2(20, 102)
	_stock.add_theme_font_size_override("font_size", 20)
	_stock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stock)
	var modes := HBoxContainer.new()
	modes.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	modes.offset_left = -560.0
	modes.offset_top = 12.0
	modes.offset_right = -16.0
	modes.offset_bottom = 64.0
	modes.alignment = BoxContainer.ALIGNMENT_END
	modes.add_theme_constant_override("separation", 8)
	add_child(modes)
	for lv in GameData.levels().size():
		modes.add_child(_mode_button(EnemyMind.level_title(lv), lv))
	modes.set_meta("help", "ui_difficulty")
	modes.visible = not MatchSetup.ai_sides().is_empty() and not NetGame.is_client()
	_difficulty = Label.new()
	_difficulty.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_difficulty.offset_left = -340.0
	_difficulty.offset_top = 68.0
	_difficulty.offset_right = -16.0
	_difficulty.offset_bottom = 98.0
	_difficulty.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_difficulty.add_theme_font_size_override("font_size", 18)
	_difficulty.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_difficulty)
	_build_panel()

# Нижняя панель управления: миникарта | выбор и группы | команды | портрет (сюжет).
func _build_panel() -> void:
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_panel.offset_top = -PANEL_H
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.1, 0.09, 0.93)
	style.border_color = Color("8a7a48")
	style.border_width_top = 3
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	_panel.add_child(row)

	# 1. Миникарта
	_minimap = Minimap.new()
	_minimap.grid = _grid
	_minimap.camera_rig = _camera
	_minimap.game = get_parent()
	var mk := minf(432.0 / float(BattleGrid.WIDTH), 140.0 / float(BattleGrid.HEIGHT))
	_minimap.custom_minimum_size = Vector2(BattleGrid.WIDTH * mk, BattleGrid.HEIGHT * mk)
	_minimap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_minimap)

	# 2. Выбор: группы, сведения, состав
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 6)
	row.add_child(mid)
	var groups := HBoxContainer.new()
	groups.add_theme_constant_override("separation", 4)
	mid.add_child(groups)
	for digit in [1, 2, 3, 4, 5, 6, 7, 8, 9, 0]:
		var d: int = digit
		var gb := Button.new()
		gb.custom_minimum_size = Vector2(50, 34)
		gb.add_theme_font_size_override("font_size", 15)
		gb.tooltip_text = "Группа %d: клик — выбрать, Ctrl+%d — записать, Alt+%d — расформировать" % [d, d, d]
		gb.pressed.connect(func() -> void:
			if Input.is_key_pressed(KEY_CTRL):
				get_parent()._store_group(d)
			else:
				get_parent().recall_group(d))
		groups.add_child(gb)
		_group_buttons.append(gb)
	_disband = Button.new()
	_disband.text = "✕ Расформировать"
	_disband.tooltip_text = "Расформировать выбранную группу (Backspace / Alt+номер)"
	_disband.custom_minimum_size = Vector2(170, 34)
	_disband.pressed.connect(func() -> void: get_parent().disband_group(get_parent().active_group))
	groups.add_child(_disband)
	_info_title = Label.new()
	_info_title.add_theme_font_size_override("font_size", 20)
	# «Портрет»: щелчок по названию выбранного — камера к нему.
	_info_title.mouse_filter = Control.MOUSE_FILTER_STOP
	_info_title.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_info_title.tooltip_text = "Щелчок — камера к выбранным (Backspace). Пробел — к базам по кругу, End — к последнему событию."
	_info_title.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			var g := get_tree().current_scene
			if g != null and g.has_method("center_selection"):
				g.center_selection())
	mid.add_child(_info_title)
	_hull_bar = ProgressBar.new()
	_hull_bar.custom_minimum_size = Vector2(260, 12)
	_hull_bar.show_percentage = false
	_hull_bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("5fd06a")
	_hull_bar.add_theme_stylebox_override("fill", fill)
	mid.add_child(_hull_bar)
	_info_line = Label.new()
	_info_line.add_theme_font_size_override("font_size", 16)
	_info_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mid.add_child(_info_line)
	_roster = GridContainer.new()
	_roster.columns = 8
	_roster.add_theme_constant_override("h_separation", 4)
	_roster.add_theme_constant_override("v_separation", 4)
	mid.add_child(_roster)
	_yard = HFlowContainer.new()
	_yard.add_theme_constant_override("h_separation", 6)
	_yard.add_theme_constant_override("v_separation", 6)
	_yard.custom_minimum_size = Vector2(560, 0)
	_yard.visible = false
	mid.add_child(_yard)

	# 3. Команды
	var cmd := VBoxContainer.new()
	cmd.add_theme_constant_override("separation", 6)
	row.add_child(cmd)
	_deploy_btn = _button("Развернуть (G)", func() -> void: get_parent().deploy_selected())
	_deploy_btn.visible = false
	cmd.add_child(_deploy_btn)
	_orders = HBoxContainer.new()
	_orders.add_theme_constant_override("separation", 6)
	cmd.add_child(_orders)
	_order_buttons = [
		_order_button("Марш", 0),
		_order_button("Захват", 1),
		_order_button("Охрана", 2),
	]
	for button in _order_buttons:
		button.custom_minimum_size = Vector2(96, 44)
		_orders.add_child(button)
	var flags := HBoxContainer.new()
	flags.add_theme_constant_override("separation", 6)
	cmd.add_child(flags)
	for b in [_button("Флаг F", func() -> void: get_parent().place_flag()), _button("Снять R", func() -> void: get_parent().remove_flag())]:
		b.custom_minimum_size = Vector2(145, 44)
		flags.add_child(b)
	_weapon_bar = HBoxContainer.new()
	_weapon_bar.add_theme_constant_override("separation", 4)
	_weapon_bar.visible = false
	cmd.add_child(_weapon_bar)
	_weapon_bar.add_child(_small("◀", func() -> void: _cycle_weapon(-1)))
	_weapon_name = Label.new()
	_weapon_name.custom_minimum_size = Vector2(96, 40)
	_weapon_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_weapon_name.add_theme_font_size_override("font_size", 15)
	_weapon_bar.add_child(_weapon_name)
	_weapon_bar.add_child(_small("▶", func() -> void: _cycle_weapon(1)))
	_weapon_bar.add_child(_small("−", func() -> void: _cycle_tier(-1)))
	_tier_name = Label.new()
	_tier_name.custom_minimum_size = Vector2(80, 40)
	_tier_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_tier_name.add_theme_font_size_override("font_size", 15)
	_weapon_bar.add_child(_tier_name)
	_weapon_bar.add_child(_small("+", func() -> void: _cycle_tier(1)))
	_mode_bar = HBoxContainer.new()
	_mode_bar.add_theme_constant_override("separation", 4)
	cmd.add_child(_mode_bar)
	var keys := ["Z", "X", "C"]
	for i in 3:
		var mi: int = i
		var mb := Button.new()
		mb.custom_minimum_size = Vector2(122, 40)
		mb.add_theme_font_size_override("font_size", 13)
		mb.clip_text = true
		mb.tooltip_text = "%s · %s" % [keys[i], Arsenal.mode_name(i)]
		mb.pressed.connect(func() -> void: get_parent().set_mode_selected(mi))
		_mode_bar.add_child(mb)
		_mode_buttons.append(mb)
	_ability = Button.new()
	_ability.custom_minimum_size = Vector2(110, 40)
	_ability.add_theme_font_size_override("font_size", 13)
	_ability.clip_text = true
	_ability.pressed.connect(func() -> void: get_parent().use_ability_selected())
	_mode_bar.add_child(_ability)
	var cam := HBoxContainer.new()
	cam.add_theme_constant_override("separation", 4)
	cmd.add_child(cam)
	cam.add_child(_small("⟲ Q", func() -> void: _camera.turn(1)))
	cam.add_child(_small("⟳ E", func() -> void: _camera.turn(-1)))
	cam.add_child(_small("+", func() -> void: _camera.zoom_by(-IsoCamera.ZOOM_STEP)))
	cam.add_child(_small("−", func() -> void: _camera.zoom_by(IsoCamera.ZOOM_STEP)))
	cam.add_child(_small("100%", func() -> void: _camera.normalize_zoom()))

	# 4. Портрет связи — место под персонажей кампании
	var story := PanelContainer.new()
	story.custom_minimum_size = Vector2(230, 0)
	var sst := StyleBoxFlat.new()
	sst.bg_color = Color(0.04, 0.06, 0.05, 1.0)
	sst.border_color = Color("3f8f58")
	sst.set_border_width_all(2)
	sst.set_content_margin_all(8)
	story.add_theme_stylebox_override("panel", sst)
	row.add_child(story)
	var sv := VBoxContainer.new()
	story.add_child(sv)
	var face := ColorRect.new()
	face.color = Color("12201a")
	face.custom_minimum_size = Vector2(0, 110)
	sv.add_child(face)
	_story_name = Label.new()
	_story_name.text = "Связь"
	_story_name.add_theme_font_size_override("font_size", 16)
	_story_name.add_theme_color_override("font_color", Color("7fe0a0"))
	sv.add_child(_story_name)
	_story_text = Label.new()
	_story_text.text = "— канал свободен —"
	_story_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_story_text.add_theme_font_size_override("font_size", 13)
	sv.add_child(_story_text)

# Для кампании: показать реплику персонажа в окне связи.
func show_story(speaker: String, text: String) -> void:
	_story_name.text = speaker
	_story_text.text = text

func _small(text: String, callback: Callable) -> Button:
	var button := _button(text, callback)
	button.custom_minimum_size = Vector2(52, 40)
	return button

func show_toast(text: String) -> void:
	if _toast_label == null:
		_toast_label = Label.new()
		_toast_label.add_theme_font_size_override("font_size", 22)
		_toast_label.add_theme_color_override("font_color", Color("ffd27a"))
		_toast_label.add_theme_color_override("font_outline_color", Color.BLACK)
		_toast_label.add_theme_constant_override("outline_size", 6)
		_toast_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
		_toast_label.position = Vector2(-300, 90)
		_toast_label.size = Vector2(600, 40)
		_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(_toast_label)
	_toast_label.text = text
	_toast_label.visible = true
	_toast_left = 2.5

func _sync_panel() -> void:
	var game := get_parent()
	if _toast_label != null and _toast_left > 0.0:
		_toast_left -= get_process_delta_time()
		_toast_label.visible = _toast_left > 0.0
	var can_deploy := false
	for u in game.selected_units:
		if str(GameData.unit(u.mover, "deploys", "")) != "":
			can_deploy = true
	_deploy_btn.visible = can_deploy
	for i in _group_buttons.size():
		var digit := (i + 1) % 10
		var n: int = game.group_size(digit)
		var gb := _group_buttons[i]
		gb.text = "%d·%d" % [digit, n] if n > 0 else str(digit)
		gb.modulate = Color("f0d48a") if game.active_group == digit else (Color.WHITE if n > 0 else Color(1, 1, 1, 0.45))
	_disband.visible = game.active_group >= 0
	var units: Array = game.selected_units
	var site: CaptureSite = game.selected_site
	_hull_bar.visible = false
	if site != null:
		_info_title.text = site.title
		_info_line.text = site.order_line()
	elif units.is_empty():
		_info_title.text = "Нет выбора"
		_info_line.text = "ЛКМ — выбрать, рамка — несколько, ПКМ — приказ. Ctrl+1…9 — группа."
	elif units.size() == 1:
		var u: BattleUnit = units[0]
		_info_title.text = u._name
		_hull_bar.visible = true
		_hull_bar.max_value = u.hull_max
		_hull_bar.value = u.hull
		_info_line.text = u.status_line()
	else:
		var group_txt := "  · группа %d" % game.active_group if game.active_group >= 0 else ""
		_info_title.text = "Выбрано: %d%s" % [units.size(), group_txt]
		_info_line.text = game.stance_hint()
	var key := ""
	if units.size() > 1:
		for u in units:
			key += str(u.get_instance_id()) + ","
	if key != _roster_key:
		_roster_key = key
		for child in _roster.get_children():
			child.queue_free()
		if units.size() > 1:
			for u in units:
				var unit: BattleUnit = u
				var rb := Button.new()
				rb.text = unit._name.left(6)
				rb.custom_minimum_size = Vector2(78, 30)
				rb.add_theme_font_size_override("font_size", 13)
				rb.tooltip_text = "Выбрать только этого"
				rb.pressed.connect(func() -> void: get_parent().select_only(unit))
				_roster.add_child(rb)
	var i2 := 0
	for child in _roster.get_children():
		if i2 < units.size() and is_instance_valid(units[i2]):
			var ratio: float = units[i2].hull / maxf(units[i2].hull_max, 1.0)
			(child as Button).modulate = Color(1, 1, 1).lerp(Color("ff6a5a"), 1.0 - ratio)
		i2 += 1

func _sync_orders() -> void:
	var mode: int = get_parent().stance
	for index in 3:
		var button := _order_buttons[index]
		button.modulate = Color("f0d48a") if mode == index else Color.WHITE

func _order_button(text: String, mode: int) -> Button:
	return _button(text, func() -> void: get_parent().set_stance(mode))

func _sync_yard() -> void:
	var site: CaptureSite = get_parent().selected_site
	if site == null:
		_yard.visible = false
		_yard_key = Vector2i(-99, -99)
		return
	_yard.visible = true
	if _yard_key != site.terminal:
		_yard_key = site.terminal
		for child in _yard.get_children():
			child.queue_free()
		for mover in Yard.catalog(site.kind):
			var choice := mover
			var button := Button.new()
			button.text = Yard.price_text(choice)
			button.custom_minimum_size = Vector2(104, 52)
			button.pressed.connect(func() -> void:
				var current: CaptureSite = get_parent().selected_site
				var pile := get_parent().get_node("Stock") as Stockpile
				if current != null:
					current.enqueue(choice, pile)
			)
			_yard.add_child(button)
		if BuildRules.is_anchor(site.kind) and site.team == SitePlan.OWNER_PLAYER:
			for key in BuildRules.catalog():
				var k: String = key
				var bb := Button.new()
				bb.text = "🔨 %s\n$%d" % [BuildRules.title(k), BuildRules.price(k)]
				bb.custom_minimum_size = Vector2(104, 52)
				bb.modulate = Color("d8e8ff")
				bb.tooltip_text = "Построить в радиусе базы (ЛКМ — поставить, Shift — несколько, ПКМ — отмена)"
				bb.pressed.connect(func() -> void: get_parent().begin_build(k))
				_yard.add_child(bb)
			if site.kind == SitePlan.KIND_HQ:
				_yard.add_child(_button("Газопровод", func() -> void: get_parent().lay_pipeline_from_hq()))
			if SitePlan.is_deployed(site.kind):
				_yard.add_child(_button("Свернуть (G)", func() -> void: get_parent().deploy_selected()))
		return
	var pile := get_parent().get_node("Stock") as Stockpile
	var offers := Yard.catalog(site.kind)
	for index in offers.size():
		var button := _yard.get_child(index) as Button
		if button == null:
			continue
		button.disabled = site.queue.size() >= 5 or not pile.can_pay(Yard.cost(offers[index]))

func _mode_button(text: String, level: int) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(98, 44)
	button.set_meta("help", "ui_difficulty")
	button.pressed.connect(func() -> void: get_parent().set_difficulty(level))
	return button

func _armed_unit() -> BattleUnit:
	for unit in get_parent().selected_units:
		if unit != null and unit.has_weapon():
			return unit
	return null

func _cycle_weapon(step: int) -> void:
	for unit in get_parent().selected_units:
		if unit != null and unit.has_weapon():
			unit.cycle_weapon(step)

func _cycle_tier(step: int) -> void:
	for unit in get_parent().selected_units:
		if unit != null and unit.has_weapon():
			unit.cycle_tier(step)

func _button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(84, 52)
	button.pressed.connect(callback)
	return button


func _sync_modes() -> void:
	var unit: BattleUnit = null
	for u in get_parent().selected_units:
		if u != null and is_instance_valid(u) and not u.weapon_modes().is_empty() and u.has_weapon():
			unit = u
			break
	var abil: BattleUnit = null
	for u in get_parent().selected_units:
		if u != null and is_instance_valid(u) and not u.ability_info().is_empty():
			abil = u
			break
	_mode_bar.visible = unit != null or abil != null
	for i in 3:
		var mb := _mode_buttons[i]
		mb.visible = unit != null
		if unit == null:
			continue
		var m: Dictionary = unit.weapon_modes()[i]
		var label: String = m["title"]
		if i == 0 and int(m["kind"]) < 0:
			label = WeaponRack.title(unit.weapon)
		if i == 2:
			label += " %d%%" % int(unit.charge_ratio() * 100.0) if not unit.special_ready() else " ✓"
		mb.text = "%s %s" % [["Z", "X", "C"][i], label]
		mb.modulate = Color("f0d48a") if unit.mode == i else Color.WHITE
	_ability.visible = abil != null
	if abil != null:
		var info := abil.ability_info()
		_ability.text = "T %s" % info["title"] if abil.ability_ready() else "T %d с" % int(ceil(abil.ability_cd))
		_ability.disabled = not abil.ability_ready()

# --- Чит-панель (F9) ---
func toggle_cheats() -> void:
	if NetGame.online:
		return
	if _cheats == null:
		_build_cheats()
		return
	_cheats.visible = not _cheats.visible

func _build_cheats() -> void:
	var game := get_parent()
	_cheats = PanelContainer.new()
	_cheats.position = Vector2(16, 150)
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.08, 0.05, 0.1, 0.94)
	st.border_color = Color("b06ae0")
	st.set_border_width_all(2)
	st.set_content_margin_all(10)
	_cheats.add_theme_stylebox_override("panel", st)
	add_child(_cheats)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	_cheats.add_child(v)
	var title := Label.new()
	title.text = "🧪 Читы (F9)"
	title.add_theme_font_size_override("font_size", 18)
	v.add_child(title)
	_row(v, [
		_cb("Бессмертие всем", func(on: bool) -> void: game.cheat_god(false, on)),
		_btn("…выбранным", func() -> void: game.cheat_god(true, true)),
	])
	_row(v, [
		_cb("Мгновенные особые/способности всем", func(on: bool) -> void: game.cheat_instant(false, on)),
		_btn("…выбранным", func() -> void: game.cheat_instant(true, true)),
	])
	_row(v, [
		_btn("+500 ресурсов", func() -> void: game.cheat_money()),
		_cb("Бесконечные ресурсы", func(on: bool) -> void: game.cheat_infinite(on)),
		_cb("Без тумана", func(on: bool) -> void: game.fog.set_enabled(not on)),
	])
	_spawn_unit = OptionButton.new()
	for pair in [["Шагоход", BattleGrid.Mover.WALKER], ["БПЛА", BattleGrid.Mover.UAV], ["Штурмовик", BattleGrid.Mover.JET], ["Ротор", BattleGrid.Mover.ROTOR], ["Гусеницы", BattleGrid.Mover.TRACK], ["Мото", BattleGrid.Mover.BIKE], ["Пехота", BattleGrid.Mover.TROOPER], ["Инженер", BattleGrid.Mover.ENGINEER]]:
		_spawn_unit.add_item(pair[0], pair[1])
	_spawn_side = OptionButton.new()
	for sd in MatchSetup.active_sides():
		_spawn_side.add_item("наш" if sd == SitePlan.OWNER_PLAYER else MatchSetup.name_of(sd), sd)
	_row(v, [_lbl("Юнит"), _spawn_unit, _spawn_side, _btn("Ставить ЛКМ", func() -> void:
		game.place = {"what": "unit", "mover": _spawn_unit.get_selected_id(), "side": _spawn_side.get_selected_id()})])
	_spawn_site = OptionButton.new()
	for pair in [["Штаб", SitePlan.KIND_HQ], ["Вышка", SitePlan.KIND_RELAY], ["Тяжёлый завод", SitePlan.KIND_FACTORY], ["Аэродром", SitePlan.KIND_AIR], ["Цех", SitePlan.KIND_ROBOT], ["Добыча", SitePlan.KIND_EXTRACTOR]]:
		_spawn_site.add_item(pair[0], pair[1])
	_row(v, [_lbl("Здание"), _spawn_site, _btn("Ставить ЛКМ", func() -> void:
		game.place = {"what": "site", "kind": _spawn_site.get_selected_id(), "side": _spawn_side.get_selected_id()})])
	_spawn_cell = OptionButton.new()
	for pair in [["Деревья", BattleGrid.CellKind.TREE], ["Камни", BattleGrid.CellKind.STONE], ["Гора", BattleGrid.CellKind.MOUNTAIN], ["Вода", BattleGrid.CellKind.WATER], ["Дом", BattleGrid.CellKind.BUILDING], ["Равнина (ластик)", BattleGrid.CellKind.PLAIN]]:
		_spawn_cell.add_item(pair[0], pair[1])
	_row(v, [_lbl("Ландшафт"), _spawn_cell, _btn("Рисовать ЛКМ", func() -> void:
		game.place = {"what": "cell", "kind": _spawn_cell.get_selected_id()})])
	var hint := Label.new()
	hint.text = "Размещение: ЛКМ по карте (можно много раз), ПКМ или Esc — закончить.\nСторона из списка «наш/враг/нейтрал» действует и на здания."
	hint.add_theme_font_size_override("font_size", 13)
	v.add_child(hint)

func _row(parent: Control, items: Array) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	for it in items:
		h.add_child(it)
	parent.add_child(h)

func _btn(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(cb)
	return b

func _cb(text: String, cb: Callable) -> CheckBox:
	var c := CheckBox.new()
	c.text = text
	c.toggled.connect(cb)
	return c

func _lbl(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.custom_minimum_size = Vector2(80, 0)
	return l


# --- Настройки, справка, подсказка F1 ---
func _build_overlays() -> void:
	var corner := HBoxContainer.new()
	corner.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	corner.offset_left = -340.0
	corner.offset_top = 100.0
	corner.offset_right = -16.0
	corner.alignment = BoxContainer.ALIGNMENT_END
	corner.add_theme_constant_override("separation", 6)
	add_child(corner)
	var help_btn := _button("? Справка", func() -> void: open_help("controls"))
	help_btn.set_meta("help", "controls")
	help_btn.custom_minimum_size = Vector2(120, 40)
	corner.add_child(help_btn)
	var set_btn := _button("⚙ Настройки", func() -> void: open_settings())
	set_btn.set_meta("help", "ui_settings")
	set_btn.custom_minimum_size = Vector2(140, 40)
	corner.add_child(set_btn)
	settings_menu = SettingsMenu.new()
	settings_menu.visible = false
	add_child(settings_menu)
	help_window = HelpWindow.new()
	help_window.visible = false
	add_child(help_window)
	_tip = PanelContainer.new()
	_tip.visible = false
	_tip.mouse_filter = Control.MOUSE_FILTER_STOP
	_tip.custom_minimum_size = Vector2(360, 0)
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.05, 0.06, 0.06, 0.96)
	st.border_color = Color("f0d48a")
	st.set_border_width_all(1)
	st.set_corner_radius_all(4)
	st.set_content_margin_all(10)
	_tip.add_theme_stylebox_override("panel", st)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip.add_child(v)
	_tip_title = Label.new()
	_tip_title.add_theme_font_size_override("font_size", 18)
	_tip_title.add_theme_color_override("font_color", Color("f0d48a"))
	v.add_child(_tip_title)
	_tip_text = Label.new()
	_tip_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip_text.custom_minimum_size = Vector2(340, 0)
	_tip_text.add_theme_font_size_override("font_size", 15)
	v.add_child(_tip_text)
	var more := Label.new()
	more.text = "Клик — открыть статью"
	more.add_theme_font_size_override("font_size", 13)
	more.modulate = Color(1, 1, 1, 0.6)
	v.add_child(more)
	for c in v.get_children():
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			_tip.visible = false
			open_help(_tip_id))
	add_child(_tip)

func _tag_help() -> void:
	_minimap.set_meta("help", "ui_minimap")
	for gb in _group_buttons:
		gb.set_meta("help", "ui_groups")
	_disband.set_meta("help", "ui_groups")
	_panel.set_meta("help", "ui_panel")
	_roster.set_meta("help", "ui_selection")
	_orders.set_meta("help", "ui_orders")
	for b in _order_buttons:
		b.set_meta("help", "ui_orders")
	_weapon_bar.set_meta("help", "ui_weapons")
	_mode_bar.set_meta("help", "ui_weapons")
	_story_name.get_parent().get_parent().set_meta("help", "ui_story")

func open_settings() -> void:
	help_window.visible = false
	settings_menu.open()

func open_help(id: String) -> void:
	settings_menu.visible = false
	help_window.open(id if id != "" else "controls")

func any_window_open() -> bool:
	return settings_menu.visible or help_window.visible

func close_windows() -> void:
	settings_menu.visible = false
	help_window.visible = false
	_tip.visible = false

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F1:
		if event.shift_pressed:
			open_help("controls")
		else:
			show_tip_at(get_viewport().get_mouse_position())
		get_viewport().set_input_as_handled()

# Что под курсором: элемент интерфейса (meta "help"), юнит, здание или клетка ландшафта.
func help_id_at(screen: Vector2) -> String:
	var hovered := get_viewport().gui_get_hovered_control()
	var node: Node = hovered
	while node != null:
		if node.has_meta("help"):
			return str(node.get_meta("help"))
		node = node.get_parent()
	if hovered != null and hovered != _tip:
		return "ui_panel"
	var game := get_parent()
	var unit: BattleUnit = game._unit_along(screen, false)
	if unit != null:
		return HelpDB.unit_id(unit.mover)
	if _grid.hovered.x >= 0:
		var site: CaptureSite = game._site_at(_grid.hovered)
		if site != null:
			return HelpDB.site_id(site.kind)
		return HelpDB.terrain_id(_grid.kind_at(_grid.hovered))
	return "controls"

func show_tip_at(screen: Vector2) -> void:
	var id := help_id_at(screen)
	var secs := int(Settings.get_value("ui", "tooltip_seconds"))
	if secs <= 0:
		open_help(id)
		return
	_tip_id = id
	_tip_title.text = HelpDB.title(id) + "   (F1)"
	_tip_text.text = HelpDB.short(id)
	_tip.visible = true
	_tip.reset_size()
	var vp := get_viewport().get_visible_rect().size
	var pos := screen + Vector2(18, 18)
	pos.x = minf(pos.x, vp.x - _tip.size.x - 8.0)
	pos.y = minf(pos.y, vp.y - _tip.size.y - 8.0)
	_tip.position = pos
	_tip_left = float(secs)

func _tick_overlays(delta: float) -> void:
	if _tip.visible:
		_tip_left -= delta
		if _tip_left <= 0.0:
			_tip.visible = false
	_scale_tick -= delta
	if _scale_tick <= 0.0:
		_scale_tick = 0.5
		_apply_text_scale(self)

func on_settings_changed() -> void:
	_scale_tick = 0.0

# Размер текста: все переопределённые размеры шрифтов × коэффициент (база хранится в meta).
func _apply_text_scale(node: Node) -> void:
	var k := float(Settings.get_value("ui", "text_scale"))
	for child in node.get_children():
		if child is Control:
			var c := child as Control
			for prop: String in ["font_size", "normal_font_size", "bold_font_size"]:
				var meta: String = "base_" + prop
				if not c.has_meta(meta):
					var base := 16
					if c.has_theme_font_size_override(prop):
						base = c.get_theme_font_size(prop)
					elif prop != "font_size":
						continue
					c.set_meta(meta, base)
				var want := int(round(float(c.get_meta(meta)) * k))
				if c.get_theme_font_size(prop) != want:
					c.add_theme_font_size_override(prop, want)
		_apply_text_scale(child)
