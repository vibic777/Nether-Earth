# Контрибьютор: vibic777
extends Node3D

enum Stance { MARCH, CAPTURE, GUARD }

const _SPREAD: Array[Vector2i] = [
	Vector2i(0, 0), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1),
]

var selected: BattleUnit
var selected_units: Array[BattleUnit] = []
var selected_site: CaptureSite
var stance := Stance.MARCH
var verdict := ""
var _flag_serial := 1
var _groups: Array[Array] = []
var active_group := -1
var _last_digit := -1
var _last_digit_ms := 0
var _dragging := false
var _drag_from := Vector2.ZERO
var _drag_to := Vector2.ZERO
var _cursors := {}
var _cursor_name := ""
var _cursor_hot := {}

var _grid: BattleGrid
var fog: FogOfWar
var place := {}   # чит-размещение: {"what": "unit"/"site"/"cell", ...}
var _failures := 0

var loaded := false

func _ready() -> void:
	_grid = $Grid
	var staged := BattleGrid.staged
	if staged:
		set_process(false)
		set_process_unhandled_input(false)
		var hud_node := get_node_or_null("Hud")
		if hud_node != null:
			hud_node.process_mode = Node.PROCESS_MODE_DISABLED
			hud_node.visible = false
		await LoadingScreen.step(get_tree(), 0.15, "Карта «%s»" % str(MapData.current().get("name", MatchSetup.map_id)))
		await WorldArt.build_staged(_grid, 0.15, 0.7)
		_grid.finish_staged()
		await LoadingScreen.step(get_tree(), 0.72, "Штабы, заводы и ресурсные зоны…")
	Settings.load_all()
	Settings.apply.call_deferred(get_tree())
	for _slot in 10:
		_groups.append([])
	_light_world()
	_build_cursors()
	MatchSetup.ensure()
	for side in MatchSetup.active_sides():
		var stock := Stockpile.new()
		stock.name = "Stock" if side == SitePlan.OWNER_PLAYER else "Stock_%d" % side
		stock.side = side
		add_child(stock)
	_spawn_sites()
	var testing := OS.get_cmdline_user_args().has("--test")
	if testing:
		_check_routes()
		_check_network()
		_check_weapons()
		_check_economy()
		_check_zones()
		_check_confirm()
		_check_log()
		_check_cheat_option()
		_check_camera_nav()
		_check_build()
	if staged:
		await LoadingScreen.step(get_tree(), 0.82, "Стартовые отряды…")
	if not NetGame.is_client():
		_spawn_roster()
	_spawn_hostiles()
	var hub := NetGame.hub()
	if hub != null and NetGame.in_match:
		hub.game = self
	fog = FogOfWar.new()
	fog.name = "Fog"
	add_child(fog)
	fog.setup(_grid)
	if testing:
		fog.set_enabled(false)
	if testing:
		_check_combat()
	if staged:
		await LoadingScreen.step(get_tree(), 0.92, "Туман войны и компьютерные противники…")
	_spawn_minds()
	if staged:
		BattleGrid.staged = false
		var hud_node2 := get_node_or_null("Hud")
		if hud_node2 != null:
			hud_node2.process_mode = Node.PROCESS_MODE_INHERIT
			hud_node2.visible = true
		set_process(true)
		set_process_unhandled_input(true)
		LoadingScreen.close()
	loaded = true
	var zone_view := BuildZone.new()
	zone_view.game = self
	add_child(zone_view)
	if testing:
		_check_ai()
		_check_match()
		_check_orders()
		_check_bands()
		_check_arsenal()
		_check_data_help()
		_check_skirmish()
		_check_jet()
		call_deferred("_finish_test")
		return
	print("Nether Earth Reloaded: match")

func _light_world() -> void:
	pass # Небо, свет и тонмаппинг задаёт WorldArt (scripts/world_art.gd).

func _process(_delta: float) -> void:
	var _pt := Prof.t()
	_process_inner(_delta)
	Prof.add("boot", _pt)

func _process_inner(_delta: float) -> void:
	_apply_cursor()
	if verdict != "":
		return
	verdict = outcome()
	if verdict == "":
		return
	var layer := CanvasLayer.new()
	var label := Label.new()
	label.text = verdict
	label.add_theme_font_size_override("font_size", 72)
	label.position = Vector2(72, 160)
	layer.add_child(label)
	var back := Button.new()
	back.text = "В лобби"
	back.position = Vector2(80, 270)
	back.custom_minimum_size = Vector2(200, 52)
	back.pressed.connect(func() -> void: to_lobby())
	layer.add_child(back)
	add_child(layer)
	for mind in minds():
		mind.set_process(false)

func outcome() -> String:
	if _eliminated(SitePlan.OWNER_PLAYER):
		return "Поражение"
	var foes := 0
	for side in MatchSetup.active_sides():
		if MatchSetup.hostile(side, SitePlan.OWNER_PLAYER) and not _eliminated(side):
			foes += 1
	if foes == 0 and _has_foes():
		return "Победа"
	return ""

func _has_foes() -> bool:
	for side in MatchSetup.active_sides():
		if MatchSetup.hostile(side, SitePlan.OWNER_PLAYER):
			return true
	return false

# Сторона выбыла: штаб разрушен или захвачен врагом.
func _eliminated(side: int) -> bool:
	var hq := _home_hq(side)
	if hq == null:
		return false
	return hq.hull <= 0.0 or MatchSetup.hostile(hq.team, side)

# ИИ на каждый компьютерный слот. Первый — узел "Mind" (тесты, HUD).
func _spawn_minds() -> void:
	var first := true
	for side in MatchSetup.ai_sides():
		if NetGame.is_client():
			break
		var mind := EnemyMind.new()
		mind.name = "Mind" if first else "Mind_%d" % side
		mind.side = side
		mind.level = MatchSetup.level_of(side)
		first = false
		add_child(mind)

# Сеть: сторону отключившегося игрока ведёт компьютер.
func spawn_mind_for(side: int) -> void:
	for mind in minds():
		if mind.side == side:
			return
	var mind := EnemyMind.new()
	mind.name = "Mind_%d" % side
	mind.side = side
	mind.level = int(GameData.skirmish("default_level", 2))
	add_child(mind)

func minds() -> Array[EnemyMind]:
	var out: Array[EnemyMind] = []
	for c in get_children():
		if c is EnemyMind:
			out.append(c)
	return out

func _home_hq(side: int) -> CaptureSite:
	for node in get_tree().get_nodes_in_group("sites"):
		var site := node as CaptureSite
		if site.kind == SitePlan.KIND_HQ and site.home == side:
			return site
	return null

func _finish_test() -> void:
	if _failures > 0:
		print("TESTS FAILED %d" % _failures)
		get_tree().quit(1)
		return
	print("TESTS OK")
	get_tree().quit(0)

func _fail(message: String) -> void:
	_failures += 1
	push_error(message)

func selected_label() -> String:
	if selected_site != null:
		return selected_site.order_line()
	if selected_units.is_empty():
		return "Стрелка выбирает. Зажмите ЛКМ — рамка. Ctrl+0–9 — группа, 0–9 — выбрать (дважды — камера), Alt+0–9 — расформировать."
	if selected_units.size() > 1:
		return "Группа %d    %s" % [selected_units.size(), stance_hint()]
	return "%s    %s" % [selected.status_line(), stance_hint()]

func stance_hint() -> String:
	match stance:
		Stance.CAPTURE:
			return "Захват: ПКМ по плите или узлу, это делает инженер."
		Stance.GUARD:
			return "Охрана: ПКМ по клетке, флагу или объекту."
		_:
			return "Марш: ПКМ — идти или бить врага. Инженер по чужому узлу захватывает."

func set_stance(mode: int) -> void:
	stance = mode

func stock_label() -> String:
	return (get_node("Stock") as Stockpile).line()

func _unhandled_input(event: InputEvent) -> void:
	if verdict != "":
		return
	if event is InputEventKey and event.pressed and not event.echo and event.is_action_pressed("camera_base"):
		jump_base()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.is_action_pressed("camera_alert"):
		jump_alert()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.is_action_pressed("camera_selection"):
		center_selection()
		return
	if false:
		if not selected_units.is_empty():
			focus_camera(group_center(selected_units))
		elif selected_site != null:
			focus_camera(selected_site.global_position)
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var digit := _key_digit(event.keycode)
		if digit >= 0:
			if event.ctrl_pressed or event.meta_pressed:
				_store_group(digit)
			elif event.alt_pressed:
				disband_group(digit)
			else:
				recall_group(digit)
			return
		match event.keycode:
			KEY_Z:
				set_mode_selected(Arsenal.MODE_DEFAULT)
			KEY_X:
				set_mode_selected(Arsenal.MODE_HEAVY)
			KEY_C:
				set_mode_selected(Arsenal.MODE_SPECIAL)
			KEY_T:
				use_ability_selected()
			KEY_ESCAPE:
				var hud0 := get_node_or_null("Hud")
				if not place.is_empty():
					place = {}
				elif hud0 != null and hud0.any_window_open():
					hud0.close_windows()
				elif hud0 != null:
					hud0.open_settings()
			KEY_F10:
				var hud1 := get_node_or_null("Hud")
				if hud1 != null:
					hud1.open_settings()
			KEY_F9:
				var hud := get_node_or_null("Hud")
				if not MatchSetup.allow_cheats:
					toast("Читы запрещены настройками хоста")
				elif hud != null and hud.has_method("toggle_cheats"):
					hud.toggle_cheats()
			KEY_DELETE:
				if active_group >= 0:
					disband_group(active_group)
			KEY_G:
				deploy_selected()
			KEY_O:
				for u in selected_units:
					if u.mover == BattleGrid.Mover.GATE:
						u.cycle_gate()
			KEY_F:
				place_flag()
			KEY_R:
				remove_flag()
		return
	if event is InputEventMouseMotion and _dragging:
		_drag_to = event.position
		return
	if not (event is InputEventMouseButton):
		return
	var button := event as InputEventMouseButton
	if button.button_index == MOUSE_BUTTON_LEFT and button.pressed and not place.is_empty():
		_place_here(_grid.hovered)
		return
	if button.button_index == MOUSE_BUTTON_RIGHT and button.pressed and not place.is_empty():
		place = {}
		return
	if button.button_index == MOUSE_BUTTON_LEFT:
		if button.pressed:
			_dragging = true
			_drag_from = button.position
			_drag_to = button.position
		elif _dragging:
			_drag_to = button.position
			_finish_drag(button.shift_pressed, button.ctrl_pressed or button.meta_pressed)
			_dragging = false
		return
	if button.pressed and button.button_index == MOUSE_BUTTON_RIGHT and not selected_units.is_empty() and _grid.hovered.x >= 0:
		if button.ctrl_pressed or button.meta_pressed:
			force_fire(_ground_point(button.position))
		else:
			_mark_order(_grid.hovered, button.position)
			_order_at(_grid.hovered, button.position)

func difficulty_label() -> String:
	var mind := get_node_or_null("Mind") as EnemyMind
	if mind == null:
		return "ИИ нет"
	return "Сложность: %s" % mind.level_name()

func set_difficulty(level: int) -> void:
	for mind in minds():
		mind.set_level(level)

func place_flag() -> void:
	if _grid.hovered.x < 0:
		return
	if _flag_at(_grid.hovered) != null:
		return
	var flag := MapFlag.new()
	flag.setup(_grid, _grid.hovered, str(_flag_serial))
	_flag_serial += 1
	add_child(flag)
	flag.add_to_group("flags")

func remove_flag() -> void:
	if _grid.hovered.x < 0:
		return
	var flag := _flag_at(_grid.hovered)
	if flag != null:
		flag.remove_from_group("flags")
		flag.queue_free()

func _flag_at(cell: Vector2i) -> MapFlag:
	for node in get_tree().get_nodes_in_group("flags"):
		var flag := node as MapFlag
		if flag != null and flag.cell == cell:
			return flag
	return null

func _order_at(cell: Vector2i, screen: Vector2) -> void:
	if stance == Stance.GUARD:
		var label := "%d,%d" % [cell.x, cell.y]
		var goal := cell
		var flag := _flag_at(cell)
		if flag != null:
			goal = flag.cell
			label = "флаг %s" % flag.mark
		else:
			var post := _site_at(cell)
			if post != null:
				goal = post.terminal
				label = post.title
		var index := 0
		for unit in selected_units:
			unit.order_guard(_spread(goal, index), label)
			index += 1
		return
	if stance == Stance.CAPTURE:
		var site := _site_at(cell)
		if site == null or site.team == SitePlan.OWNER_PLAYER:
			return
		for unit in selected_units:
			if unit.mover == BattleGrid.Mover.ENGINEER:
				unit.order_capture(site)
		return
	var foe := _unit_near(screen)
	if foe != null and MatchSetup.hostile(foe.side, SitePlan.OWNER_PLAYER):
		for unit in selected_units:
			if unit.mover == BattleGrid.Mover.ENGINEER:
				unit.order_to(_spread(cell, 0))
			else:
				unit.order_attack(foe)
		return
	var site := _site_at(cell)
	var index := 0
	for unit in selected_units:
		var step := _spread(cell, index)
		if site != null and site.is_hostile_hq(unit.side) and unit.mover != BattleGrid.Mover.ENGINEER:
			unit.order_attack_site(site)
		elif unit.mover == BattleGrid.Mover.ENGINEER and site != null and not MatchSetup.allied(site.team, SitePlan.OWNER_PLAYER):
			unit.order_capture(site)
		else:
			unit.order_to(step)
		index += 1

func network_label() -> String:
	var owned := 0
	var total := 0
	for node in get_tree().get_nodes_in_group("sites"):
		var site := node as CaptureSite
		if site.kind != SitePlan.KIND_RELAY:
			continue
		total += 1
		if site.team == SitePlan.OWNER_PLAYER:
			owned += 1
	return "Вышки %d/%d · инженер берёт жёлтую плиту" % [owned, total]

func _spawn_sites() -> void:
	var index := 0
	for def in SitePlan.defs():
		var site := CaptureSite.new()
		site.setup(_grid, def)
		index += 1
		site.net_id = index
		add_child(site)
	for z in MapData.current().get("zones", []):
		var zone := FlagZone.new()
		zone.setup(_grid, z)
		add_child(zone)

# Стартовые отряды: из карты (roster) или общий список skirmish.start_roster вокруг штаба.
func _spawn_roster() -> void:
	var m := MapData.current()
	var starts: Array = m.get("starts", [])
	for i in starts.size():
		var st: Dictionary = starts[i]
		var side := MatchSetup.side_at_start(int(st.get("index", i)))
		if side <= 0:
			continue
		if st.has("roster"):
			for entry in st["roster"]:
				_spawn_unit(MapData.mover_kind(str(entry[0])), Vector2i(int(entry[1]), int(entry[2])), side)
			continue
		var taken: Array[Vector2i] = []
		for key in GameData.skirmish("start_roster", ["TRACK", "ENGINEER"]):
			var mover := MapData.mover_kind(str(key))
			var cell := _free_near(MapData.cell(st["terminal"]), mover, taken)
			taken.append(cell)
			_spawn_unit(mover, cell, side)

func _free_near(origin: Vector2i, mover: int, taken: Array[Vector2i]) -> Vector2i:
	for r in range(1, 8):
		for dz in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dz)) != r:
					continue
				var c := origin + Vector2i(dx, dz)
				if _grid.can_enter(c, mover) and _grid.kind_at(c) != BattleGrid.CellKind.LINK and not taken.has(c):
					return c
	return origin

func dragging() -> bool:
	return _dragging

func drag_rect() -> Rect2:
	return Rect2(_drag_from, _drag_to - _drag_from).abs()

func _finish_drag(shift: bool, ctrl: bool) -> void:
	var rect := drag_rect()
	if rect.size.x < 8.0 and rect.size.y < 8.0:
		_pick_click(_drag_from, shift, ctrl)
		return
	var found := _units_in_rect(rect)
	if shift or ctrl:
		for unit in selected_units:
			if not found.has(unit):
				found.append(unit)
	_set_selection(found)

func _pick_click(screen: Vector2, shift: bool, ctrl: bool) -> void:
	var best := _unit_along(screen, true)
	if best != null:
		if ctrl and selected_units.has(best):
			var kept: Array[BattleUnit] = []
			for unit in selected_units:
				if unit != best:
					kept.append(unit)
			_set_selection(kept)
			return
		if shift or ctrl:
			var added: Array[BattleUnit] = []
			for unit in selected_units:
				added.append(unit)
			if not added.has(best):
				added.append(best)
			_set_selection(added)
			return
		_set_selection([best])
		return
	if shift or ctrl:
		return
	_set_selection([])
	var site := _site_at(_grid.hovered)
	if site != null and site.team == SitePlan.OWNER_PLAYER and not Yard.catalog(site.kind).is_empty():
		selected_site = site
	else:
		selected_site = null

func _units_in_rect(rect: Rect2) -> Array[BattleUnit]:
	var found: Array[BattleUnit] = []
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return found
	for node in get_tree().get_nodes_in_group("units"):
		var unit := node as BattleUnit
		if unit.side != SitePlan.OWNER_PLAYER or unit.hull <= 0.0:
			continue
		var point := unit.global_position + Vector3(0.0, 0.6, 0.0)
		if not unit.pick_points().is_empty():
			point = unit.pick_points()[0]
		if rect.has_point(camera.unproject_position(point)):
			found.append(unit)
	return found

func _set_selection(units: Array[BattleUnit]) -> void:
	for unit in selected_units:
		if is_instance_valid(unit):
			unit.set_selected(false)
	selected_units = []
	for unit in units:
		if unit == null or not is_instance_valid(unit) or unit.side != SitePlan.OWNER_PLAYER:
			continue
		if selected_units.has(unit):
			continue
		selected_units.append(unit)
		unit.set_selected(true)
	selected = selected_units[0] if not selected_units.is_empty() else null
	if selected != null:
		selected_site = null
	active_group = -1

func release_unit(unit: BattleUnit) -> void:
	selected_units.erase(unit)
	if selected == unit:
		selected = selected_units[0] if not selected_units.is_empty() else null
	for index in _groups.size():
		var group: Array = _groups[index]
		group.erase(unit)
	if is_instance_valid(unit):
		unit.set_selected(false)

func _store_group(digit: int) -> void:
	var copy: Array = []
	for unit in selected_units:
		if is_instance_valid(unit) and unit.hull > 0.0:
			copy.append(unit)
	_groups[digit] = copy
	active_group = digit if not copy.is_empty() else -1

func _recall_group(digit: int) -> void:
	var live: Array[BattleUnit] = []
	for item in _groups[digit]:
		var unit := item as BattleUnit
		if unit != null and is_instance_valid(unit) and unit.hull > 0.0 and unit.side == SitePlan.OWNER_PLAYER:
			live.append(unit)
	_groups[digit] = live
	if live.is_empty():
		return
	_set_selection(live)
	active_group = digit

# Номер группы: выбрать; повторное нажатие за 0,4 с — камера к группе.
func recall_group(digit: int) -> void:
	var now := Time.get_ticks_msec()
	var twice := digit == _last_digit and now - _last_digit_ms < 400
	_last_digit = digit
	_last_digit_ms = now
	_recall_group(digit)
	if twice and not selected_units.is_empty():
		focus_camera(group_center(selected_units))

func disband_group(digit: int) -> void:
	if digit < 0 or digit >= _groups.size():
		return
	_groups[digit] = []
	if active_group == digit:
		active_group = -1

func group_size(digit: int) -> int:
	var count := 0
	for item in _groups[digit]:
		var unit := item as BattleUnit
		if unit != null and is_instance_valid(unit) and unit.hull > 0.0:
			count += 1
	return count

func group_center(units: Array) -> Vector3:
	var sum := Vector3.ZERO
	var n := 0
	for unit in units:
		if unit != null and is_instance_valid(unit):
			sum += unit.global_position
			n += 1
	return sum / float(maxi(n, 1))

func focus_camera(world: Vector3) -> void:
	var rig := get_node_or_null("CameraRig") as Node3D
	if rig != null:
		rig.position = Vector3(world.x, 0.0, world.z)

func select_only(unit: BattleUnit) -> void:
	_set_selection([unit])

func _spread(cell: Vector2i, index: int) -> Vector2i:
	return cell + _SPREAD[index % _SPREAD.size()]

func _key_digit(code: Key) -> int:
	if code >= KEY_0 and code <= KEY_9:
		return code - KEY_0
	if code >= KEY_KP_0 and code <= KEY_KP_9:
		return code - KEY_KP_0
	return -1

func _check_routes() -> void:
	_expect_clear(_route(BattleGrid.Mover.WALKER, Vector2i(2, 2), Vector2i(46, 7)), "шагоход через брод")
	_expect_plain(_route(BattleGrid.Mover.TRACK, Vector2i(2, 8), Vector2i(46, 7)), "гусеницы только по равнине")
	_expect_plain(_route(BattleGrid.Mover.BIKE, Vector2i(2, 10), Vector2i(25, 2)), "мото обходит камни")
	var trees := _route(BattleGrid.Mover.TROOPER, Vector2i(2, 6), Vector2i(9, 2))
	if trees.is_empty() or _grid.kind_at(trees[trees.size() - 1]) != BattleGrid.CellKind.TREE:
		_fail("пехота не дошла до деревьев")
	var uav := _route(BattleGrid.Mover.UAV, Vector2i(2, 4), Vector2i(35, 2))
	if not _has_kind(uav, BattleGrid.CellKind.MOUNTAIN):
		_fail("БПЛА не перелетел гору")
	var rotor := _route(BattleGrid.Mover.ROTOR, Vector2i(2, 4), Vector2i(35, 2))
	if rotor.is_empty() or _has_kind(rotor, BattleGrid.CellKind.MOUNTAIN) or _has_kind(rotor, BattleGrid.CellKind.BUILDING):
		_fail("ротор не обошёл гору")
	var over_water := _route(BattleGrid.Mover.ROTOR, Vector2i(14, 1), Vector2i(20, 1))
	if not _has_kind(over_water, BattleGrid.CellKind.WATER):
		_fail("ротор не пересёк воду")
	var around_water := _route(BattleGrid.Mover.WALKER, Vector2i(14, 1), Vector2i(20, 1))
	if around_water.is_empty() or _has_kind(around_water, BattleGrid.CellKind.WATER):
		_fail("шагоход пошёл по воде")

func _check_network() -> void:
	var squad := _grid.cell_center(Vector2i(2, 2))
	var first_pad := _grid.cell_center(Vector2i(19, 7))
	var factory := _grid.cell_center(Vector2i(31, 7))
	if not RelayNet.covers(get_tree(), squad):
		_fail("штаб не покрывает отряд")
	if not RelayNet.covers(get_tree(), first_pad):
		_fail("первая плита вне штаба")
	if RelayNet.covers(get_tree(), factory):
		_fail("завод уже в сети")
	var relay := _site_at(Vector2i(19, 7))
	relay.hack_step(CaptureSite.HACK_TIME, true)
	if relay.team != SitePlan.OWNER_PLAYER or not RelayNet.covers(get_tree(), factory):
		_fail("захват вышки не расширил сеть")
	relay.set_team(SitePlan.OWNER_NEUTRAL)
	if RelayNet.covers(get_tree(), factory):
		_fail("сеть не сбросилась")
	var walk := Pathfinder.route(_grid, Vector2i(4, 7), Vector2i(19, 7), BattleGrid.Mover.ENGINEER)
	if walk.is_empty():
		_fail("инженер не доходит до плиты")

func _spawn_hostiles() -> void:
	pass # отряды всех сторон ставит _spawn_roster()

func _spawn_unit(mover: int, cell: Vector2i, owner_side: int) -> BattleUnit:
	var unit := BattleUnit.new()
	unit.setup(_grid, mover, cell, owner_side)
	add_child(unit)
	return unit

func _unit_near(screen: Vector2) -> BattleUnit:
	return _unit_along(screen, false)

func _unit_along(screen: Vector2, player_only: bool) -> BattleUnit:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return null
	var origin := camera.project_ray_origin(screen)
	var dir := camera.project_ray_normal(screen)
	var best: BattleUnit = null
	var best_gap := 999.0
	for node in get_tree().get_nodes_in_group("units"):
		var unit := node as BattleUnit
		if player_only and unit.side != SitePlan.OWNER_PLAYER:
			continue
		if unit.side != SitePlan.OWNER_PLAYER and not unit.visible:
			continue
		var gap := unit.ray_gap(origin, dir)
		if gap < unit.pick_reach() and gap < best_gap:
			best_gap = gap
			best = unit
	return best

func _check_combat() -> void:
	if WeaponRack.range_of(WeaponRack.Kind.FLAME) >= WeaponRack.range_of(WeaponRack.Kind.SHELL):
		_fail("огнемёт бьёт дальше снаряда")
	if WeaponRack.chains_of(WeaponRack.Kind.TESLA) < 2:
		_fail("тесла не перескакивает")
	if WeaponRack.stun_of(WeaponRack.Kind.ION) <= 0.0:
		_fail("ионная пушка не глушит")
	if WeaponRack.splash_of(WeaponRack.Kind.BOMB) <= WeaponRack.splash_of(WeaponRack.Kind.SHELL):
		_fail("бомба не шире снаряда")
	var foe := _spawn_unit(BattleGrid.Mover.TROOPER, Vector2i(6, 7), SitePlan.OWNER_ENEMY)
	var before := foe.hull
	foe.take_hit(6.0, 1.5, SitePlan.OWNER_PLAYER)
	if foe.hull >= before or foe._stun <= 0.0:
		_fail("попадание не задело пехоту")
	var engineer := _spawn_unit(BattleGrid.Mover.ENGINEER, Vector2i(4, 7), SitePlan.OWNER_PLAYER)
	engineer.order_capture(_site_at(Vector2i(12, 7)))
	if engineer._site == null:
		_fail("инженер не начал взлом")
	engineer.take_hit(4.0, 0.0, SitePlan.OWNER_ENEMY)
	if engineer._site != null:
		_fail("удар не сорвал взлом")
	foe.queue_free()
	engineer.queue_free()

func _check_ai() -> void:
	var mind := get_node("Mind") as EnemyMind
	var pad := _grid.cell_center(Vector2i(38, 7))
	if not RelayNet.covers_side(get_tree(), pad, SitePlan.OWNER_ENEMY):
		_fail("вражеская база не достаёт до вышки")
	var engineer := _enemy_engineer()
	mind.level = EnemyMind.Level.EASY
	mind.decide()
	if engineer._site != null:
		_fail("лёгкий противник полез захватывать")
	mind.level = EnemyMind.Level.HARD
	mind.decide()
	if engineer._site == null or engineer._site.kind != SitePlan.KIND_RELAY:
		_fail("хард не послал инженера резать вышку")
	engineer.order_to(_grid.cell_from_world(engineer.global_position))
	for node in get_tree().get_nodes_in_group("units"):
		var unit := node as BattleUnit
		if unit.side == SitePlan.OWNER_ENEMY and unit.mover != BattleGrid.Mover.ENGINEER:
			unit.attack_target = null
			unit.attack_site = null
	mind.level = EnemyMind.Level.NORMAL

func _check_match() -> void:
	var theirs := _home_hq(SitePlan.OWNER_ENEMY)
	var ours := _home_hq(SitePlan.OWNER_PLAYER)
	if theirs == null or ours == null or theirs.hull_max <= 0.0:
		_fail("у штаба нет корпуса")
		return
	theirs.take_hit(1000.0, SitePlan.OWNER_PLAYER)
	if outcome() != "Победа":
		_fail("разрушение вражеского штаба не даёт победу")
	theirs.restore_hq()
	if outcome() != "":
		_fail("штаб не восстановился после проверки")
	theirs.set_team(SitePlan.OWNER_PLAYER)
	if outcome() != "Победа":
		_fail("захват вражеского штаба не даёт победу")
	theirs.set_team(SitePlan.OWNER_ENEMY)
	ours.take_hit(1000.0, SitePlan.OWNER_ENEMY)
	if outcome() != "Поражение":
		_fail("потеря своего штаба не даёт поражение")
	ours.restore_hq()
	if outcome() != "":
		_fail("матч не вернулся к игре")

func _check_orders() -> void:
	var engineer := _enemy_engineer()
	for node in get_tree().get_nodes_in_group("units"):
		var unit := node as BattleUnit
		if unit.side == SitePlan.OWNER_PLAYER and unit.mover == BattleGrid.Mover.ENGINEER:
			engineer = unit
			break
	if engineer == null or engineer.side != SitePlan.OWNER_PLAYER:
		_fail("нет инженера для приказа охраны")
		return
	engineer.order_guard(Vector2i(5, 7), "флаг 1")
	if engineer._post != Vector2i(5, 7) or engineer._post_name != "флаг 1":
		_fail("охрана не запомнила пост")
	engineer.order_to(Vector2i(4, 7))
	if engineer._post.x >= 0:
		_fail("марш не снял охрану")
	_grid.hovered = Vector2i(6, 7)
	place_flag()
	var flag := _flag_at(Vector2i(6, 7))
	if flag == null or flag.mark != "1":
		_fail("флаг не встал на клетку")
	remove_flag()
	if _flag_at(Vector2i(6, 7)) != null:
		_fail("флаг не снялся")
	_grid.hovered = Vector2i(-1, -1)

func _check_bands() -> void:
	var walker: BattleUnit = null
	var trooper: BattleUnit = null
	for node in get_tree().get_nodes_in_group("units"):
		var unit := node as BattleUnit
		if unit.side != SitePlan.OWNER_PLAYER:
			continue
		if unit.mover == BattleGrid.Mover.WALKER:
			walker = unit
		elif unit.mover == BattleGrid.Mover.TROOPER:
			trooper = unit
	if walker == null or trooper == null:
		_fail("нет машин для рамки")
		return
	_set_selection([walker, trooper])
	_store_group(4)
	_set_selection([])
	_recall_group(4)
	if selected_units.size() != 2 or selected != walker:
		_fail("группа 4 не вернулась")
	_set_selection([])
	_recall_group(8)
	if not selected_units.is_empty():
		_fail("пустая группа что-то выбрала")
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		_fail("нет камеры для рамки")
		return
	var first := camera.unproject_position(walker.pick_points()[0])
	var second := camera.unproject_position(trooper.pick_points()[0])
	var rect := Rect2(first, Vector2.ZERO).expand(second).grow(24.0)
	var picked := _units_in_rect(rect)
	if not picked.has(walker) or not picked.has(trooper):
		_fail("рамка не захватила обе машины")
	_set_selection([])

func _build_cursors() -> void:
	for name in ["arrow", "march", "capture", "guard", "attack", "force", "place"]:
		var art := CursorArt.make(name)
		_cursors[name] = art["tex"]
		_cursor_hot[name] = art["hot"]
	_apply_cursor()

func _cursor_texture(fill: Color) -> ImageTexture:
	var image := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var arrow := PackedVector2Array([
		Vector2(1, 1), Vector2(1, 22), Vector2(6, 16),
		Vector2(11, 26), Vector2(15, 24), Vector2(10, 15), Vector2(18, 14),
	])
	_fill_polygon(image, arrow, Color(0.05, 0.06, 0.07, 1.0))
	_grow_outline(image)
	_fill_polygon(image, arrow, fill)
	return ImageTexture.create_from_image(image)

func _fill_polygon(image: Image, polygon: PackedVector2Array, color: Color) -> void:
	var min_y := 31
	var max_y := 0
	for point in polygon:
		min_y = mini(min_y, int(floor(point.y)))
		max_y = maxi(max_y, int(ceil(point.y)))
	min_y = clampi(min_y, 0, 31)
	max_y = clampi(max_y, 0, 31)
	for y in range(min_y, max_y + 1):
		var cuts: Array[float] = []
		for index in polygon.size():
			var a: Vector2 = polygon[index]
			var b: Vector2 = polygon[(index + 1) % polygon.size()]
			if a.y > b.y:
				var swap := a
				a = b
				b = swap
			if y < a.y or y >= b.y or is_equal_approx(a.y, b.y):
				continue
			var t := (float(y) - a.y) / (b.y - a.y)
			cuts.append(lerpf(a.x, b.x, t))
		cuts.sort()
		var pair := 0
		while pair + 1 < cuts.size():
			var left := clampi(int(ceil(cuts[pair])), 0, 31)
			var right := clampi(int(floor(cuts[pair + 1])), 0, 31)
			for x in range(left, right + 1):
				image.set_pixel(x, y, color)
			pair += 2

func _grow_outline(image: Image) -> void:
	var ink: Array[Vector2i] = []
	for y in 32:
		for x in 32:
			if image.get_pixel(x, y).a > 0.1:
				ink.append(Vector2i(x, y))
	var shade := Color(0.05, 0.06, 0.07, 1.0)
	for pixel in ink:
		for step in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var next: Vector2i = pixel + step
			if next.x < 0 or next.y < 0 or next.x > 31 or next.y > 31:
				continue
			if image.get_pixel(next.x, next.y).a < 0.1:
				image.set_pixel(next.x, next.y, shade)

func _apply_cursor() -> void:
	var name := cursor_context()
	if name == _cursor_name or not _cursors.has(name):
		return
	_cursor_name = name
	var hot: Vector2 = _cursor_hot.get(name, Vector2.ZERO)
	Input.set_custom_mouse_cursor(_cursors[name], Input.CURSOR_ARROW, hot)

# Что сделает ПКМ под курсором: arrow (ничего не выбрано), march, attack, capture, guard, force, place.
func cursor_context() -> String:
	if not place.is_empty():
		return "place"
	if selected_units.is_empty():
		return "arrow"
	if Input.is_key_pressed(KEY_CTRL):
		return "force"
	if stance == Stance.GUARD:
		return "guard"
	var foe := _unit_along(get_viewport().get_mouse_position(), false)
	if foe != null and MatchSetup.hostile(foe.side, SitePlan.OWNER_PLAYER):
		return "attack"
	var site := _site_at(_grid.hovered) if _grid.hovered.x >= 0 else null
	if site != null and not MatchSetup.allied(site.team, SitePlan.OWNER_PLAYER):
		for unit in selected_units:
			if unit.mover == BattleGrid.Mover.ENGINEER:
				return "capture"
		if site.is_hostile_hq(SitePlan.OWNER_PLAYER):
			return "attack"
	if stance == Stance.CAPTURE:
		return "capture"
	return "march"

func _enemy_engineer() -> BattleUnit:
	for node in get_tree().get_nodes_in_group("units"):
		var unit := node as BattleUnit
		if unit.side == SitePlan.OWNER_ENEMY and unit.mover == BattleGrid.Mover.ENGINEER:
			return unit
	return null

func _check_economy() -> void:
	var stock := get_node("Stock") as Stockpile
	var mine := _site_at(Vector2i(12, 7))
	mine.set_team(SitePlan.OWNER_PLAYER)
	var before := stock.money
	stock.apply_income(1.0)
	if stock.money <= before:
		_fail("жила не приносит $")
	mine.set_team(SitePlan.OWNER_NEUTRAL)
	stock.reset_start()
	var heavy := _site_at(Vector2i(31, 7))
	heavy.set_team(SitePlan.OWNER_PLAYER)
	stock.money = 5000
	if heavy.enqueue(BattleGrid.Mover.UAV, stock):
		_fail("тяжёлый завод принял БПЛА")
	if not heavy.enqueue(BattleGrid.Mover.WALKER, stock):
		_fail("тяжёлый завод не принял шагоход")
	if stock.money != 5000 - Yard.usd(BattleGrid.Mover.WALKER):
		_fail("цена шагохода не списана в $")
	var born := heavy.debug_finish(stock)
	if born == null or born.mover != BattleGrid.Mover.WALKER:
		_fail("шагоход не выехал с завода")
	else:
		born.queue_free()
	var air := _site_at(Vector2i(23, 7))
	air.set_team(SitePlan.OWNER_PLAYER)
	if not air.enqueue(BattleGrid.Mover.UAV, stock):
		_fail("аэродром не принял БПЛА")
	air.cancel_all(stock)
	air.set_team(SitePlan.OWNER_NEUTRAL)
	heavy.set_team(SitePlan.OWNER_NEUTRAL)
	# Сырьё без станции продаётся за $
	var m0 := stock.money
	stock.deliver("oil", 10.0)
	if stock.money <= m0:
		_fail("нефть не продалась за $")
	if stock.drive_factor("fuel") < 1.0 and stock.fuel > 0.0:
		_fail("топливо есть, а техника тормозит")
	stock.fuel = 0.0
	if stock.drive_factor("fuel") >= 1.0:
		_fail("без топлива топливная техника не замедлилась")
	stock.reset_start()

func _check_weapons() -> void:
	if WeaponRack.allowed(BattleGrid.Mover.WALKER, WeaponRack.Kind.BOMB):
		_fail("бомбы стоят на шагоходе")
	if WeaponRack.allowed(BattleGrid.Mover.TRACK, WeaponRack.Kind.BOMB):
		_fail("бомбы стоят на гусеницах")
	if not WeaponRack.allowed(BattleGrid.Mover.UAV, WeaponRack.Kind.BOMB):
		_fail("у БПЛА нет бомб")
	if not WeaponRack.allowed(BattleGrid.Mover.ROTOR, WeaponRack.Kind.BOMB):
		_fail("у ротора нет бомб")
	if WeaponRack.allowed(BattleGrid.Mover.BIKE, WeaponRack.Kind.PLASMA):
		_fail("плазма стоит на мото")
	if WeaponRack.allowed(BattleGrid.Mover.UAV, WeaponRack.Kind.FLAME):
		_fail("огнемёт стоит на БПЛА")
	if not WeaponRack.options(BattleGrid.Mover.ENGINEER).is_empty():
		_fail("у инженера есть оружие")
	var armed: Array[int] = [
		BattleGrid.Mover.WALKER,
		BattleGrid.Mover.UAV,
		BattleGrid.Mover.ROTOR,
		BattleGrid.Mover.TRACK,
		BattleGrid.Mover.BIKE,
		BattleGrid.Mover.TROOPER,
	]
	for mover in armed:
		var kind := WeaponRack.default_kind(mover)
		if not WeaponRack.allowed(mover, kind):
			_fail("штатный комплект недоступен")

func _site_at(cell: Vector2i) -> CaptureSite:
	for node in get_tree().get_nodes_in_group("sites"):
		var site := node as CaptureSite
		if site.claims(cell):
			return site
	return null

func _route(mover: int, start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	return Pathfinder.route(_grid, start, goal, mover)

func _expect_clear(path: Array[Vector2i], title: String) -> void:
	if path.is_empty():
		_fail(title + ": пустой путь")
		return
	for cell in path:
		var kind := _grid.kind_at(cell)
		if kind == BattleGrid.CellKind.WATER or kind == BattleGrid.CellKind.TREE or kind == BattleGrid.CellKind.MOUNTAIN or kind == BattleGrid.CellKind.BUILDING:
			_fail(title + ": лишнее препятствие")
			return

func _expect_plain(path: Array[Vector2i], title: String) -> void:
	if path.is_empty():
		_fail(title + ": пустой путь")
		return
	for cell in path:
		if _grid.kind_at(cell) != BattleGrid.CellKind.PLAIN:
			_fail(title + ": сошёл с равнины")
			return

func _has_kind(path: Array[Vector2i], kind: int) -> bool:
	for cell in path:
		if _grid.kind_at(cell) == kind:
			return true
	return false

func order_from_minimap(cell: Vector2i) -> void:
	if selected_units.is_empty() or verdict != "":
		return
	_order_at(cell, Vector2(-100000.0, -100000.0))


# Классический RTS-курсор: кольцо со стрелками (ход) или прицел (атака).
func _ring_cursor(fill: Color, cross: bool) -> ImageTexture:
	var image := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var ink := Color(0.04, 0.05, 0.06, 1.0)
	var c := Vector2(15.5, 15.5)
	for y in 32:
		for x in 32:
			var d := Vector2(x, y).distance_to(c)
			if cross:
				if absf(d - 10.0) < 1.0:
					image.set_pixel(x, y, fill)
				elif absf(d - 10.0) < 2.0:
					image.set_pixel(x, y, ink)
				var onx := absi(y - 15) <= 0 and (x < 9 or x > 22)
				var ony := absi(x - 15) <= 0 and (y < 9 or y > 22)
				if onx or ony:
					image.set_pixel(x, y, fill)
				elif (absi(y - 15) == 1 and (x < 9 or x > 22)) or (absi(x - 15) == 1 and (y < 9 or y > 22)):
					image.set_pixel(x, y, ink)
				if d < 1.6:
					image.set_pixel(x, y, fill)
			else:
				if absf(d - 7.0) < 1.0:
					image.set_pixel(x, y, fill)
				elif absf(d - 7.0) < 2.0:
					image.set_pixel(x, y, ink)
				for k in 4:
					var dir := Vector2.from_angle(k * PI * 0.5)
					var rel := Vector2(x, y) - c
					var along := rel.dot(dir)
					var side := absf(rel.dot(dir.orthogonal()))
					if along > 10.0 and along < 15.0 and side < (15.0 - along) * 0.6:
						image.set_pixel(x, y, fill)
	return ImageTexture.create_from_image(image)

func _ground_point(screen: Vector2) -> Vector3:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return Vector3.ZERO
	var o := camera.project_ray_origin(screen)
	var d := camera.project_ray_normal(screen)
	var t := 0.0
	var y := 0.3
	for _i in 4:
		t = (y - o.y) / d.y if absf(d.y) > 0.001 else 0.0
		var p := o + d * t
		y = _grid.terrain_y(p.x, p.z)
	return o + d * t

func force_fire(point: Vector3) -> void:
	var any := false
	for unit in selected_units:
		if unit.has_weapon():
			unit.order_fire_at(point)
			any = true
	if any:
		OrderMarker.spawn(self, point, "atk_point", Color("ff9a2a"))

func _mark_order(cell: Vector2i, screen: Vector2) -> void:
	var context := cursor_context()
	var target := _grid.cell_center(cell)
	target.y = _grid.terrain_y(target.x, target.z) + 0.02
	if context == "attack":
		var foe := _unit_near(screen)
		var at := target
		if foe != null:
			at = foe.global_position
		var icons := {}
		for unit in selected_units:
			if unit.has_weapon():
				icons[unit.current_icon()] = WeaponRack.color_of(unit.current_kind())
		var i := 0
		for icon in icons.keys():
			var m := OrderMarker.spawn(self, at + Vector3(0.0, i * 0.5, 0.0), "atk_" + icon, Color(icons[icon]).lerp(Color("ff5a4a"), 0.4))
			i += 1
		return
	var color := Color("7ef08a")
	if context == "capture":
		color = Color("e2b15a")
	elif context == "guard":
		color = Color("7eb6e8")
	var center := group_center(selected_units)
	var yaw := atan2(target.x - center.x, target.z - center.z)
	var styles := {}
	for unit in selected_units:
		styles[OrderMarker.style_for(unit.mover)] = true
	var k := 0
	for st in styles.keys():
		var off := Vector3(cos(k * 2.1), 0.0, sin(k * 2.1)) * (0.0 if k == 0 else 0.6)
		var p := target + off
		p.y = _grid.terrain_y(p.x, p.z) + 0.02
		OrderMarker.spawn(self, p, st, color, yaw)
		k += 1

func set_mode_selected(value: int) -> void:
	for unit in selected_units:
		unit.set_mode(value)

func use_ability_selected() -> void:
	for unit in selected_units:
		var info := unit.use_ability()
		if info.is_empty():
			continue
		match unit.mover:
			BattleGrid.Mover.UAV:
				fog.reveal(unit.global_position, int(info["radius"]), float(info["time"]))
				OrderMarker.spawn(self, Vector3(unit.global_position.x, 0.4, unit.global_position.z), "air", Color("8cf0ff"))
			BattleGrid.Mover.ROTOR:
				var at := _ground_point(get_viewport().get_mouse_position())
				fog.reveal(at, int(info["radius"]), float(info["time"]))
				OrderMarker.spawn(self, at, "atk_point", Color("fff0a0"))
			BattleGrid.Mover.ENGINEER:
				for node in get_tree().get_nodes_in_group("units"):
					var other := node as BattleUnit
					if other.side == unit.side and other.global_position.distance_to(unit.global_position) <= float(info["radius"]) * BattleGrid.TILE:
						other.hull = minf(other.hull_max, other.hull + other.hull_max * 0.4)

# --- Читы (F9) ---
func cheat_god(only_selected: bool, on: bool) -> void:
	for unit in _cheat_targets(only_selected):
		unit.god = on

func cheat_instant(only_selected: bool, on: bool) -> void:
	for unit in _cheat_targets(only_selected):
		unit.instant = on
		unit.charge = 999.0
		unit.ability_cd = 0.0

func cheat_money() -> void:
	var pile := get_node("Stock") as Stockpile
	pile.money += 5000
	pile.fuel += 500.0

func cheat_infinite(on: bool) -> void:
	(get_node("Stock") as Stockpile).infinite = on

func _cheat_targets(only_selected: bool) -> Array[BattleUnit]:
	var list: Array[BattleUnit] = []
	if only_selected:
		for unit in selected_units:
			list.append(unit)
		return list
	for node in get_tree().get_nodes_in_group("units"):
		var unit := node as BattleUnit
		if unit.side == SitePlan.OWNER_PLAYER:
			list.append(unit)
	return list

func _place_here(cell: Vector2i) -> void:
	if not _grid.contains(cell):
		return
	match str(place.get("what", "")):
		"build":
			var why := BuildRules.check(_grid, get_tree(), int(place["side"]), str(place["key"]), cell)
			if why != "":
				toast(why)
				return
			if NetGame.is_client() and NetGame.in_match:
				NetGame.hub().send_command("b", 0, str(place["key"]), [cell.x, cell.y])
			else:
				BuildRules.place(self, _grid, int(place["side"]), str(place["key"]), cell)
			if not Input.is_key_pressed(KEY_SHIFT):
				place = {}
			return
		"unit":
			var unit := _spawn_unit(int(place["mover"]), cell, int(place["side"]))
			if unit != null and int(place["side"]) == SitePlan.OWNER_PLAYER:
				unit.god = bool(place.get("god", false))
		"site":
			var kind := int(place["kind"])
			var titles := {SitePlan.KIND_HQ: "Штаб", SitePlan.KIND_RELAY: "Вышка", SitePlan.KIND_FACTORY: "Тяжёлый", SitePlan.KIND_EXTRACTOR: "Жила", SitePlan.KIND_AIR: "Аэродром", SitePlan.KIND_ROBOT: "Цех"}
			var term := cell + Vector2i(0, -1) if cell.y > 0 else cell + Vector2i(0, 1)
			var cells: Array[Vector2i] = [cell]
			var radius := 30.0 if kind == SitePlan.KIND_RELAY or kind == SitePlan.KIND_HQ else 0.0
			_grid.set_cell(cell, BattleGrid.CellKind.LINK, false)
			_grid.set_cell(term, BattleGrid.CellKind.PLAIN)
			var site := CaptureSite.new()
			site.setup(_grid, SitePlan._site(kind, int(place["side"]), titles.get(kind, "Узел"), cells, term, radius, 1 if kind == SitePlan.KIND_EXTRACTOR else 0))
			add_child(site)
		"cell":
			_grid.set_cell(cell, int(place["kind"]))
	var hud := get_node_or_null("Hud")
	if hud != null and hud.get("_minimap") != null:
		hud._minimap.rebake()


func _check_arsenal() -> void:
	for mover in [BattleGrid.Mover.WALKER, BattleGrid.Mover.UAV, BattleGrid.Mover.ROTOR, BattleGrid.Mover.TRACK, BattleGrid.Mover.BIKE, BattleGrid.Mover.TROOPER]:
		if Arsenal.modes(mover).size() != 3:
			_fail("у машины нет трёх режимов оружия")
	var tank := _spawn_unit(BattleGrid.Mover.TRACK, Vector2i(6, 3), SitePlan.OWNER_PLAYER)
	tank.set_mode(Arsenal.MODE_SPECIAL)
	if tank.special_ready():
		_fail("миномёт готов без заряда")
	if tank.current_kind() != tank.weapon:
		_fail("без заряда особый режим не откатился на основной")
	tank.instant = true
	if not tank.special_ready() or tank.current_kind() != WeaponRack.Kind.SHELL:
		_fail("мгновенный заряд не включил миномёт")
	if tank.fire_range() <= WeaponRack.range_of(WeaponRack.Kind.SHELL):
		_fail("миномёт бьёт не дальше пушки")
	tank.order_fire_at(_grid.cell_center(Vector2i(9, 3)))
	if not tank.has_point:
		_fail("огонь по земле не принят")
	tank.god = true
	tank.take_hit(999.0, 0.0, SitePlan.OWNER_ENEMY)
	if tank.hull <= 0.0:
		_fail("бессмертие не сработало")
	var pile := get_node("Stock") as Stockpile
	pile.infinite = true
	var before := pile.money
	if not pile.pay(Vector3i(999999, 0, 0)) or pile.money != before:
		_fail("бесконечные ресурсы списались")
	pile.infinite = false
	release_unit(tank)
	tank.queue_free()


func _check_data_help() -> void:
	assert(GameData.UNIT_KEYS.size() == BattleGrid.Mover.size())
	for e in HelpDB.index():
		if HelpDB.body(e["id"]).length() == 0:
			_fail("пустая статья " + str(e["id"]))
	assert(Settings.DEFAULTS["ui"]["tooltip_seconds"] == 5)
	Settings.apply_preset("low")
	assert(int(Settings.get_value("graphics", "msaa")) == 0 or Settings.get_value("graphics", "preset") == "low")
	Settings.reset_defaults()


func to_lobby() -> void:
	ConfirmBox.ask(get_tree(), "Точно покинуть матч?\nПрогресс боя будет потерян.", leave_match_now, "Покинуть", "Остаться")

# Экран выгрузки: реальные этапы — сеть, машины (долями), постройки, переход в лобби.
func leave_match_now() -> void:
	var tree := get_tree()
	LoadingScreen.open(tree, "Выгрузка матча")
	await LoadingScreen.step(tree, 0.05, "Отключение от сети")
	NetGame.leave_match(tree)
	var units := tree.get_nodes_in_group("units")
	var n := units.size()
	for i in n:
		var u = units[i]
		if is_instance_valid(u):
			u.queue_free()
		if i % 150 == 149:
			await LoadingScreen.step(tree, 0.1 + 0.6 * float(i) / maxf(n, 1), "Выгрузка техники: %d / %d" % [i + 1, n])
	await LoadingScreen.step(tree, 0.75, "Снос построек и эффектов")
	for node in tree.get_nodes_in_group("sites"):
		node.queue_free()
	await LoadingScreen.step(tree, 0.9, "Сохранение настроек")
	Settings.save_all()
	await LoadingScreen.step(tree, 1.0, "Переход в лобби")
	tree.change_scene_to_file("res://scenes/lobby.tscn")
	await tree.process_frame
	await tree.process_frame
	LoadingScreen.close()

func _check_skirmish() -> void:
	var counts := {}
	for id in MapData.ids():
		var m := MapData.load_map(str(id))
		var dims := MapData.size_of(m)
		var starts: Array = m.get("starts", [])
		if starts.size() != int(m.get("players", 0)):
			_fail("карта %s: стартов %d" % [id, starts.size()])
		counts[starts.size()] = true
		for st in starts:
			var t := MapData.cell(st["terminal"])
			if t.x < 0 or t.y < 0 or t.x >= dims.x or t.y >= dims.y or MapData.kind_at(m, t.x, t.y) != BattleGrid.CellKind.PLAIN:
				_fail("карта %s: терминал старта вне равнины %s" % [id, t])
	for need in [2, 4, 6, 8]:
		if not counts.has(need):
			_fail("нет карты на %d игроков" % need)
	if not MatchSetup.hostile(1, 2) or MatchSetup.hostile(1, 1) or MatchSetup.hostile(0, 1):
		_fail("неверная враждебность сторон")
	if GameData.levels().size() != 5 or EnemyMind.level_title(0) != "Новичок" or EnemyMind.level_title(4) != "Эксперт":
		_fail("уровни сложности не те")
	var keep: Array = MatchSetup.slots.duplicate(true)
	MatchSetup.slots[1]["team"] = 1
	if MatchSetup.hostile(1, 2):
		_fail("союзники одной команды враждуют")
	MatchSetup.slots = keep

func _check_jet() -> void:
	var jet := _spawn_unit(BattleGrid.Mover.JET, Vector2i(5, 3), SitePlan.OWNER_PLAYER)
	if jet.ammo <= 0 or not BattleGrid.fixed_wing(jet.mover) or not Yard.builds(SitePlan.KIND_AIR, BattleGrid.Mover.JET):
		_fail("штурмовик: нет боезапаса или не строится на аэродроме")
	var heli := _spawn_unit(BattleGrid.Mover.ROTOR, Vector2i(6, 3), SitePlan.OWNER_ENEMY)
	jet.mode = Arsenal.MODE_SPECIAL
	if jet.can_target(heli):
		_fail("управляемые бомбы бьют по воздуху")
	jet.mode = Arsenal.MODE_DEFAULT
	if not jet.can_target(heli):
		_fail("пушка штурмовика не бьёт по воздуху")
	jet.ammo = 1
	jet._cooldown = 0.0
	jet._fire(heli.global_position, heli, null, 0.1)
	if jet.ammo != 0:
		_fail("выстрел не тратит боезапас")
	jet.queue_free()
	heli.queue_free()


# Зона: берёт только инженер, держит любой свой юнит, без своих — откат к нейтралу.
func _check_zones() -> void:
	var zone := FlagZone.new()
	zone.setup(_grid, {"id": 900, "resource": "OIL", "title": "тест", "center": [6, 3], "radius": 2})
	add_child(zone)
	var tank := _spawn_unit(BattleGrid.Mover.TRACK, Vector2i(6, 3), SitePlan.OWNER_PLAYER)
	for i in 12:
		zone.step(1.0)
	if zone.owner_side != 0:
		_fail("зону взял не инженер")
	var eng := _spawn_unit(BattleGrid.Mover.ENGINEER, Vector2i(7, 3), SitePlan.OWNER_PLAYER)
	for i in 9:
		zone.step(1.0)
	if zone.owner_side != SitePlan.OWNER_PLAYER:
		_fail("инженер не взял зону: %d%%" % int(zone.control))
	eng.free()
	for i in 10:
		zone.step(1.0)
	if zone.owner_side != SitePlan.OWNER_PLAYER or zone.control < 99.0:
		_fail("танк не удержал зону")
	tank.free()
	for i in 30:
		zone.step(1.0)
	if zone.owner_side != 0:
		_fail("пустая зона не вернулась к нейтралу")
	zone.free()
	# Взрыв урановоза ранит соседей
	var truck := _spawn_unit(BattleGrid.Mover.URANIUM_TRUCK, Vector2i(6, 3), SitePlan.OWNER_PLAYER)
	var near := _spawn_unit(BattleGrid.Mover.TRACK, Vector2i(7, 3), SitePlan.OWNER_PLAYER)
	var hull0 := near.hull
	truck.take_hit(9999.0, 0.0, 2)
	if near.hull >= hull0:
		_fail("взрыв урановоза не задел соседа")
	near.free()
	for node in get_children():
		if node is Blast or node is FireSpill:
			node.free()
	if not is_instance_valid(truck) or truck.is_queued_for_deletion():
		pass
	elif truck.get_parent() != null:
		truck.free()


var _toast := ""
var _toast_left := 0.0

func toast(text: String) -> void:
	_toast = text
	_toast_left = 2.5
	var hud := get_node_or_null("Hud")
	if hud != null and hud.has_method("show_toast"):
		hud.show_toast(text)

# G: развернуть выбранные машины-базы или свернуть выбранную базу.
func deploy_selected() -> void:
	if selected_site != null and SitePlan.is_deployed(selected_site.kind) and selected_site.team == SitePlan.OWNER_PLAYER:
		var site := selected_site
		selected_site = null
		var unit := site.undeploy()
		if unit != null:
			select_only(unit)
		return
	for u in selected_units.duplicate():
		if str(GameData.unit(u.mover, "deploys", "")) == "":
			continue
		var why: String = u.deploy_check()
		if why != "":
			toast(why)
			continue
		release_unit(u)
		u.deploy()

func begin_build(key: String) -> void:
	place = {"what": "build", "key": key, "side": SitePlan.OWNER_PLAYER}

func lay_pipeline_from_hq() -> void:
	for node in get_tree().get_nodes_in_group("sites"):
		var s := node as CaptureSite
		if s.team == SitePlan.OWNER_PLAYER and s.kind == SitePlan.KIND_GAS_WELL:
			if BuildRules.lay_pipeline(self, _grid, SitePlan.OWNER_PLAYER, s) != null:
				toast("Газопровод проложен: %s" % s.title)
				return
	toast("Нет своей газовой скважины без трубы (или не хватает $)")


func _free_cell_near(origin: Vector2i, reach: int) -> Vector2i:
	for r in range(2, reach):
		for dx in range(-r, r + 1):
			for dz in [-r, r]:
				var c := origin + Vector2i(dx, dz)
				if BuildRules._free(_grid, get_tree(), c) and BuildRules._free(_grid, get_tree(), c + Vector2i(0, 1)):
					return c
	return Vector2i(-1, -1)

# Постройка только в радиусе базы; автобус → казарма; свёртка продаёт турели.
func _check_build() -> void:
	var stock := get_node("Stock") as Stockpile
	stock.money = 99999
	var hq := _home_hq(SitePlan.OWNER_PLAYER)
	if hq == null:
		_fail("нет штаба игрока")
		return
	var near := _free_cell_near(hq.footprint[0], 6)
	if BuildRules.check(_grid, get_tree(), SitePlan.OWNER_PLAYER, "T_MG", near) != "":
		_fail("турель у штаба не ставится: %s" % BuildRules.check(_grid, get_tree(), SitePlan.OWNER_PLAYER, "T_MG", near))
	var far := Vector2i(BattleGrid.WIDTH - 3, BattleGrid.HEIGHT / 2)
	if BuildRules.check(_grid, get_tree(), SitePlan.OWNER_PLAYER, "T_MG", far) == "":
		_fail("турель встала вне радиуса")
	var t := BuildRules.place(self, _grid, SitePlan.OWNER_PLAYER, "T_MG", near)
	if not (t is BattleUnit):
		_fail("турель не построена")
	else:
		t.free()
	var spot := _free_cell_near(Vector2i(BattleGrid.WIDTH / 2, BattleGrid.HEIGHT / 2), 8)
	var bus := _spawn_unit(BattleGrid.Mover.BUS, spot, SitePlan.OWNER_PLAYER)
	if bus.deploy_check() != "":
		_fail("автобус не разворачивается: %s" % bus.deploy_check())
		bus.free()
		return
	var camp := bus.deploy()
	bus.free()
	if camp == null or camp.kind != SitePlan.KIND_BARRACKS:
		_fail("казарма не развернулась")
		return
	var tc := _free_cell_near(spot, 5)
	var tur := BuildRules.place(self, _grid, SitePlan.OWNER_PLAYER, "T_LASER", tc) as BattleUnit
	if tur == null or tur.built_by != camp:
		_fail("турель не привязана к казарме")
	var before := stock.money
	var back := camp.undeploy()
	if back == null or back.mover != BattleGrid.Mover.BUS:
		_fail("казарма не свернулась в автобус")
	if stock.money <= before:
		_fail("турели при свёртке не вернули $")
	camp.free()
	if back != null:
		back.free()
	if tur != null and is_instance_valid(tur):
		tur.free()
	stock.reset_start()


# Пробел: после тревоги — к месту события, иначе по кругу между своими базами.
var _alert_at := Vector3.ZERO
var _alert_ms := -100000
var _base_index := 0

var _last_alert_at := Vector3.INF

func note_alert(world: Vector3) -> void:
	_alert_at = world
	_last_alert_at = world
	_alert_ms = Time.get_ticks_msec()

# Конец: к последнему событию (атака, захват, потеря) — без ограничения по времени.
func jump_alert() -> bool:
	if _alert_ms < 0 and _last_alert_at == Vector3.INF:
		toast("Событий пока не было")
		return false
	focus_camera(_last_alert_at if _last_alert_at != Vector3.INF else _alert_at)
	return true

# Backspace или щелчок по портрету в панели — к выбранным.
func center_selection() -> void:
	if not selected_units.is_empty():
		focus_camera(group_center(selected_units))
	elif selected_site != null:
		focus_camera(selected_site.global_position)

func jump_base() -> void:
	if Time.get_ticks_msec() - _alert_ms < 6000:
		_alert_ms = -100000
		focus_camera(_alert_at)
		return
	var bases := BuildRules.anchors(get_tree(), SitePlan.OWNER_PLAYER)
	if bases.is_empty():
		return
	_base_index = (_base_index + 1) % bases.size()
	focus_camera(bases[_base_index].global_position)


# Крестик окна в бою: подтверждение и выход через экран выгрузки.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		ConfirmBox.ask(get_tree(), "Выйти из игры?\nТекущий бой будет потерян.", func() -> void:
			LoadingScreen.open(get_tree(), "Выход из игры")
			await LoadingScreen.step(get_tree(), 0.5, "Сохранение настроек")
			Settings.save_all()
			NetGame.leave_match(get_tree())
			await LoadingScreen.step(get_tree(), 1.0, "До встречи, командир")
			get_tree().quit(), "Выйти", "Отмена")

func _check_camera_nav() -> void:
	note_alert(Vector3(30, 0, 40))
	if not jump_alert():
		_fail("End не перешёл к событию")
	var rig := get_node_or_null("CameraRig") as Node3D
	if rig != null and Vector2(rig.position.x, rig.position.z).distance_to(Vector2(30, 40)) > 0.1:
		_fail("камера не у события")
	if not InputMap.has_action("camera_alert"):
		_fail("нет действия camera_alert")

func _check_log() -> void:
	if GameLog.enabled or bool(Settings.DEFAULTS["log"]["enabled"]) or bool(Settings.DEFAULTS["log"]["crash_capture"]):
		_fail("журнал или запись при падении включены по умолчанию")
	var r := GameLog.parse_spec("info,error")
	if not r[0] or r[1] != ((1 << GameLog.Level.INFO) | (1 << GameLog.Level.ERROR)):
		_fail("разбор --log=info,error")
	if GameLog.parse_spec("off")[0] or GameLog.parse_spec("all")[1] != 63:
		_fail("разбор off/all")
	# Включить на время теста, записать, проверить файл и маркер, выключить.
	Settings.set_value("log", "enabled", true)
	Settings.set_value("log", "crash_capture", true)
	GameLog.configure()
	GameLog.info("тест журнала")
	var p := GameLog.path()
	var marker := GameLog.dir().path_join(GameLog.MARKER)
	if p == "" or not FileAccess.get_file_as_string(p).contains("[INFO] тест журнала"):
		_fail("журнал не записал строку")
	if not FileAccess.file_exists(marker):
		_fail("нет маркера сессии")
	Settings.set_value("log", "enabled", false)
	Settings.set_value("log", "crash_capture", false)
	GameLog.configure()
	if FileAccess.file_exists(marker):
		_fail("маркер не снят при выключении")

func _check_cheat_option() -> void:
	var keep := MatchSetup.allow_cheats
	var conf := MatchSetup.configured
	MatchSetup.allow_cheats = false
	var d := MatchSetup.to_dict()
	MatchSetup.allow_cheats = true
	MatchSetup.from_dict(d)
	if MatchSetup.allow_cheats:
		_fail("опция «Разрешить читы» не передаётся в настройках матча")
	MatchSetup.allow_cheats = keep
	MatchSetup.configured = conf

func _check_confirm() -> void:
	var hit := [0]
	var box := ConfirmBox.ask(get_tree(), "тест", func() -> void: hit[0] += 1)
	box.cancel()
	if hit[0] != 0 or ConfirmBox.is_open():
		_fail("отмена подтверждения сработала как «Да»")
	box = ConfirmBox.ask(get_tree(), "тест", func() -> void: hit[0] += 1)
	box.confirm()
	if hit[0] != 1:
		_fail("подтверждение не вызвало действие")
