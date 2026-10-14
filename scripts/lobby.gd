# Контрибьютор: vibic777
# Лобби схватки: карта, 8 слотов (человек / компьютер / закрыт), команда, цвет, старт.
# В сетевой игре хост правит всё, клиент — только имя и цвет своего слота (см. NetLobby).
class_name Lobby
extends Control

const KIND_TITLES := {MatchSetup.KIND_HUMAN: "Человек", MatchSetup.KIND_AI: "Компьютер", MatchSetup.KIND_CLOSED: "Закрыт"}
const KIND_ORDER := [MatchSetup.KIND_HUMAN, MatchSetup.KIND_AI, MatchSetup.KIND_CLOSED]

var _maps: ItemList
var _map_info: Label
var _preview: TextureRect
var _rows: Array = []        # [{kind, name, level, team, color, start}]
var _status: Label
var _start_btn: Button
var _net_box: VBoxContainer
var _syncing := false
static var _booted := false
var settings_menu: SettingsMenu
var help_window: HelpWindow
var _cheats_box: CheckBox
var net: Node                # автозагрузка Net (scripts/net_hub.gd)
var _net_status: Label
var _servers: ItemList
var _server_keys: Array = []
var _addr: LineEdit
var _port: SpinBox
var _pname: LineEdit
var _gname: LineEdit
var _host_btn: Button
var _find_btn: Button
var _leave_btn: Button

func _ready() -> void:
	Settings.load_all()
	Settings.apply.call_deferred(get_tree())
	if OS.get_cmdline_user_args().has("--test") or OS.get_environment("NE_SKIP_LOBBY") != "":
		get_tree().change_scene_to_file.call_deferred("res://scenes/main.tscn")
		return
	if not _booted:
		_booted = true
		LoadingScreen.open(get_tree(), "Запуск")
		await LoadingScreen.step(get_tree(), 0.1, "Загрузка данных игры (data/game.json)…")
		GameData.unit(0, "name", "")
		var ids := MapData.ids()
		for i in ids.size():
			await LoadingScreen.step(get_tree(), 0.2 + 0.6 * i / maxf(1.0, ids.size()), "Карты: %s…" % ids[i])
			MapData.load_map(str(ids[i]))
		await LoadingScreen.step(get_tree(), 0.9, "Интерфейс лобби…")
		LoadingScreen.close()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.06, 0.06)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)
	var head := HBoxContainer.new()
	root.add_child(head)
	var title := Label.new()
	title.text = "Nether Earth Reloaded — схватка"
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color("f0d48a"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(_btn("? Справка", func() -> void: _open_help("lobby"), "lobby"))
	head.add_child(_btn("⚙ Настройки", func() -> void: help_window.visible = false; settings_menu.open(), "ui_settings"))
	head.add_child(_btn("Выход", ask_quit, "lobby"))

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 18)
	root.add_child(body)
	# Слева: карты и превью
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(330, 0)
	body.add_child(left)
	left.add_child(_caption("Карта"))
	_maps = ItemList.new()
	_maps.custom_minimum_size = Vector2(330, 170)
	_maps.set_meta("help", "maps")
	for id in MapData.ids():
		var m := MapData.load_map(str(id))
		_maps.add_item("%s · до %d игроков · %d×%d" % [m.get("name", id), int(m.get("players", 2)), int(m.get("width", 0)), int(m.get("height", 0))])
	_maps.item_selected.connect(func(i: int) -> void: _pick_map(str(MapData.ids()[i]), true))
	left.add_child(_maps)
	_preview = TextureRect.new()
	_preview.custom_minimum_size = Vector2(330, 260)
	_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_preview.set_meta("help", "maps")
	left.add_child(_preview)
	_map_info = Label.new()
	_map_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_map_info.custom_minimum_size = Vector2(330, 0)
	left.add_child(_map_info)
	# Справа: слоты
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 6)
	body.add_child(right)
	right.add_child(_caption("Игроки"))
	var grid := GridContainer.new()
	grid.columns = 7
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 6)
	grid.set_meta("help", "lobby")
	right.add_child(grid)
	for h in ["№", "Слот", "Имя", "Уровень ИИ", "Команда", "Цвет", "Старт"]:
		var l := Label.new()
		l.text = h
		l.modulate = Color(1, 1, 1, 0.6)
		grid.add_child(l)
	for i in MatchSetup.MAX_SLOTS:
		_rows.append(_slot_row(grid, i))
	_net_box = VBoxContainer.new()
	right.add_child(_net_box)
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 12)
	root.add_child(foot)
	_status = Label.new()
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	foot.add_child(_status)
	_cheats_box = CheckBox.new()
	_cheats_box.text = "Разрешить читы"
	_cheats_box.tooltip_text = "Опция хоста: чит-панель F9 в этом бою. В сетевой игре решает создатель сервера."
	_cheats_box.button_pressed = MatchSetup.allow_cheats
	_cheats_box.toggled.connect(func(on: bool) -> void:
		MatchSetup.allow_cheats = on
		if net != null and net.has_method("broadcast_setup"):
			net.broadcast_setup())
	foot.add_child(_cheats_box)
	_start_btn = _btn("▶ Начать бой", func() -> void: start_match(), "lobby")
	_start_btn.custom_minimum_size = Vector2(220, 52)
	_start_btn.add_theme_font_size_override("font_size", 22)
	foot.add_child(_start_btn)

	settings_menu = SettingsMenu.new()
	settings_menu.visible = false
	add_child(settings_menu)
	help_window = HelpWindow.new()
	help_window.visible = false
	add_child(help_window)

	if MatchSetup.slots.is_empty():
		MatchSetup.map_id = str(GameData.skirmish("default_map", "classic"))
		MatchSetup.slots = MatchSetup.default_slots(int(MapData.load_map(MatchSetup.map_id).get("players", 2)))
	net = get_node_or_null("/root/Net")
	if net != null:
		net.setup_changed.connect(refresh)
		net.status_changed.connect(func(t: String) -> void: _net_status.text = t)
		net.servers_changed.connect(_fill_servers)
		_build_net_panel()
	refresh()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE and (settings_menu.visible or help_window.visible):
			settings_menu.visible = false
			help_window.visible = false
		elif event.keycode == KEY_F1:
			_open_help("lobby")

func _open_help(id: String) -> void:
	settings_menu.visible = false
	help_window.open(id)

func _caption(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 20)
	l.add_theme_color_override("font_color", Color("c9b06a"))
	return l

func _btn(text: String, cb: Callable, help: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(120, 40)
	b.pressed.connect(cb)
	b.set_meta("help", help)
	return b

func _slot_row(grid: GridContainer, i: int) -> Dictionary:
	var num := Label.new()
	num.text = str(i + 1)
	grid.add_child(num)
	var kind := OptionButton.new()
	for k in KIND_ORDER:
		kind.add_item(KIND_TITLES[k])
	kind.custom_minimum_size = Vector2(140, 0)
	kind.item_selected.connect(func(idx: int) -> void: _edit(i, "kind", KIND_ORDER[idx]))
	grid.add_child(kind)
	var name := LineEdit.new()
	name.custom_minimum_size = Vector2(170, 0)
	name.max_length = 20
	name.text_submitted.connect(func(t: String) -> void: _edit(i, "name", t))
	name.focus_exited.connect(func() -> void: _edit(i, "name", name.text))
	grid.add_child(name)
	var level := OptionButton.new()
	for lv in GameData.levels().size():
		level.add_item(EnemyMind.level_title(lv))
	level.item_selected.connect(func(idx: int) -> void: _edit(i, "level", idx))
	grid.add_child(level)
	var team := OptionButton.new()
	for t in MatchSetup.MAX_SLOTS:
		team.add_item("Команда %d" % (t + 1))
	team.item_selected.connect(func(idx: int) -> void: _edit(i, "team", idx + 1))
	grid.add_child(team)
	var color := OptionButton.new()
	var pal := MatchSetup.palette()
	for c in pal.size():
		var img := Image.create(14, 14, false, Image.FORMAT_RGB8)
		img.fill(Color(str(pal[c]["color"])))
		color.add_icon_item(ImageTexture.create_from_image(img), str(pal[c]["name"]))
	color.item_selected.connect(func(idx: int) -> void: _edit(i, "color", idx))
	grid.add_child(color)
	var start := OptionButton.new()
	start.item_selected.connect(func(idx: int) -> void: _edit(i, "start", -1 if start.get_item_id(idx) == 99 else start.get_item_id(idx)))
	grid.add_child(start)
	for w in [kind, name, level, team, color, start]:
		w.set_meta("help", "lobby")
	return {"kind": kind, "name": name, "level": level, "team": team, "color": color, "start": start}

# Может ли этот компьютер менять поле слота.
func can_edit(i: int, field: String) -> bool:
	if net == null or not NetGame.online:
		return true
	if NetGame.hosting:
		return true
	var s: Dictionary = MatchSetup.slots[i]
	return int(s.get("peer", 0)) == net.my_peer() and (field == "name" or field == "color" or field == "team")

func _edit(i: int, field: String, value) -> void:
	if _syncing:
		return
	var s: Dictionary = MatchSetup.slots[i]
	if not can_edit(i, field):
		refresh()
		return
	if field == "name":
		value = str(value).replace(" (вы)", "").strip_edges()
		if value == "" or str(value).begins_with("(свободно"):
			return
		if value == str(s["name"]):
			return
	if field == "kind" and value == MatchSetup.KIND_HUMAN and NetGame.online and int(s.get("peer", 0)) == 0:
		# Человеческий слот без подключённого игрока остаётся открытым для входа.
		pass
	if field == "start" and int(value) >= 0:
		for other in MatchSetup.slots:
			if other != s and int(other["start"]) == int(value):
				other["start"] = int(s["start"])
	s[field] = value
	if field == "kind":
		if value == MatchSetup.KIND_CLOSED:
			s["start"] = -1
		elif int(s["start"]) < 0:
			s["start"] = _free_start()
		if value == MatchSetup.KIND_AI:
			s["name"] = "Компьютер %d" % (i + 1)
			s["peer"] = 0
		elif value == MatchSetup.KIND_HUMAN and i > 0:
			s["name"] = "(свободно)"
			s["peer"] = 0
	if net != null and NetGame.online and not NetGame.hosting:
		net.request_edit(i, field, value)
	changed()

func _free_start() -> int:
	var players := int(MapData.current().get("players", 2))
	for st in players:
		var used := false
		for s in MatchSetup.slots:
			if int(s["start"]) == st:
				used = true
		if not used:
			return st
	return -1

func _pick_map(id: String, from_user: bool) -> void:
	if from_user and NetGame.online and not NetGame.hosting:
		refresh()
		return
	if MatchSetup.map_id == id and not MatchSetup.slots.is_empty():
		return
	MatchSetup.map_id = id
	var players := int(MapData.current().get("players", 2))
	var old: Array = MatchSetup.slots
	var fresh := MatchSetup.default_slots(players)
	for i in fresh.size():
		if i < old.size() and i < players:
			fresh[i]["kind"] = old[i]["kind"] if old[i]["kind"] != MatchSetup.KIND_CLOSED else MatchSetup.KIND_AI
			for f in ["name", "team", "color", "level", "peer"]:
				fresh[i][f] = old[i][f]
		elif i < old.size() and int(old[i].get("peer", 0)) > 1:
			fresh[i]["peer"] = 0   # игрок не помещается на карту
	MatchSetup.slots = fresh
	changed()

func changed() -> void:
	refresh()
	if net != null and NetGame.hosting:
		net.broadcast_setup()

func refresh() -> void:
	if _maps == null:
		return
	_syncing = true
	var ids := MapData.ids()
	var mi := ids.find(MatchSetup.map_id)
	if mi >= 0:
		_maps.select(mi)
	var m := MapData.current()
	var players := int(m.get("players", 2))
	_map_info.text = "%s\n%s\nСимметрия: %s" % [m.get("name", ""), m.get("description", ""), m.get("symmetry", "—")]
	_preview.texture = preview_texture(m)
	for i in _rows.size():
		var r: Dictionary = _rows[i]
		var s: Dictionary = MatchSetup.slots[i]
		var fits := i < players
		(r["kind"] as OptionButton).select(KIND_ORDER.find(s["kind"]))
		(r["kind"] as OptionButton).disabled = not fits or not can_edit(i, "kind") or (i == 0 and not NetGame.online)
		var nm := r["name"] as LineEdit
		if not nm.has_focus():
			nm.text = str(s["name"])
			if NetGame.online and s["kind"] == MatchSetup.KIND_HUMAN and int(s.get("peer", 0)) == 0:
				nm.text = "(свободно — ждём игрока)"
			elif NetGame.online and int(s.get("peer", 0)) == (net.my_peer() if net != null else 1):
				nm.text = str(s["name"]) + " (вы)"
		nm.editable = can_edit(i, "name") and s["kind"] != MatchSetup.KIND_CLOSED
		(r["level"] as OptionButton).select(int(s["level"]))
		(r["level"] as OptionButton).disabled = s["kind"] != MatchSetup.KIND_AI or not can_edit(i, "level")
		(r["team"] as OptionButton).select(int(s["team"]) - 1)
		(r["team"] as OptionButton).disabled = s["kind"] == MatchSetup.KIND_CLOSED or not can_edit(i, "team")
		(r["color"] as OptionButton).select(int(s["color"]) % MatchSetup.palette().size())
		(r["color"] as OptionButton).disabled = s["kind"] == MatchSetup.KIND_CLOSED or not can_edit(i, "color")
		var st := r["start"] as OptionButton
		st.clear()
		st.add_item("—", 99)
		for k in players:
			st.add_item("Старт %d" % (k + 1), k)
		st.select(st.get_item_index(int(s["start"])) if int(s["start"]) >= 0 and int(s["start"]) < players else 0)
		st.disabled = s["kind"] == MatchSetup.KIND_CLOSED or not can_edit(i, "start")
		for w in r.values():
			(w as Control).modulate = Color(1, 1, 1, 1.0 if fits else 0.35)
	_syncing = false
	var problem := validate()
	_status.text = problem if problem != "" else _summary()
	_status.modulate = Color("ff8a70") if problem != "" else Color(1, 1, 1, 0.85)
	_start_btn.disabled = problem != "" or (NetGame.online and not NetGame.hosting)
	if _host_btn != null:
		_host_btn.disabled = NetGame.online
		_leave_btn.disabled = not NetGame.online and not net.searching()
	_start_btn.text = "▶ Начать бой" if not (NetGame.online and not NetGame.hosting) else "Ждём хоста…"

func _summary() -> String:
	var teams := {}
	var n := 0
	for side in MatchSetup.active_sides():
		teams[MatchSetup.team_of(side)] = true
		n += 1
	return "Карта «%s»: %d сторон, %d команд. Одинаковый номер команды — союзники." % [MapData.current().get("name", ""), n, teams.size()]

# Пустая строка — можно начинать.
func validate() -> String:
	var teams := {}
	var starts := {}
	var players := int(MapData.current().get("players", 2))
	for s in MatchSetup.slots:
		if s["kind"] == MatchSetup.KIND_CLOSED:
			continue
		var st := int(s["start"])
		if st < 0 or st >= players:
			return "Слоту %d нужна стартовая позиция." % int(s["side"])
		if starts.has(st):
			return "Старт %d занят дважды." % (st + 1)
		starts[st] = true
		if s["kind"] == MatchSetup.KIND_HUMAN and not NetGame.online and int(s["side"]) != 1:
			return "Слот %d «Человек» — только в сетевой игре (Создать сервер)." % int(s["side"])
		if s["kind"] == MatchSetup.KIND_HUMAN and NetGame.online and int(s.get("peer", 0)) == 0:
			return "Слот %d ждёт игрока по сети (или сделайте его компьютером / закройте)." % int(s["side"])
		teams[int(s["team"])] = true
	if not MatchSetup.slot(1).is_empty() and MatchSetup.slot(1)["kind"] != MatchSetup.KIND_HUMAN and not NetGame.online:
		return "Слот 1 — это вы."
	if teams.size() < 2:
		return "Нужны хотя бы две разные команды."
	return ""

static func preview_texture(m: Dictionary) -> ImageTexture:
	var size := MapData.size_of(m)
	var k := 4
	var img := Image.create(size.x * k, size.y * k, false, Image.FORMAT_RGB8)
	for z in size.y:
		for x in size.x:
			var c := Color("4f6a36")
			match MapData.kind_at(m, x, z):
				BattleGrid.CellKind.WATER: c = Color("1f5a70")
				BattleGrid.CellKind.TREE: c = Color("2f5230")
				BattleGrid.CellKind.STONE: c = Color("777466")
				BattleGrid.CellKind.MOUNTAIN: c = Color("9a968c")
				BattleGrid.CellKind.BUILDING: c = Color("b08a62")
			img.fill_rect(Rect2i(x * k, z * k, k, k), c)
	for s in m.get("sites", []):
		for cell in s["cells"]:
			img.fill_rect(Rect2i(int(cell[0]) * k, int(cell[1]) * k, k, k), Color("d2c07a"))
	var starts: Array = m.get("starts", [])
	for i in starts.size():
		var st: Dictionary = starts[i]
		var side := MatchSetup.side_at_start(int(st.get("index", i)))
		var col := MatchSetup.color_of(side) if side > 0 else Color("cccccc")
		for cell in st["hq"]:
			img.fill_rect(Rect2i(int(cell[0]) * k - k, int(cell[1]) * k - k, k * 3, k * 3), col)
	return ImageTexture.create_from_image(img)

func start_match() -> void:
	if validate() != "":
		refresh()
		return
	if net != null and NetGame.hosting:
		net.start_online()
		return
	launch(1)

# Запуск боя на этом компьютере за сторону local_side.
func launch(local_side: int) -> void:
	MatchSetup.configured = true
	MatchSetup.local_side = local_side
	SitePlan.OWNER_PLAYER = local_side
	LoadingScreen.open(get_tree(), "Подготовка боя…")
	BattleGrid.staged = true
	get_tree().change_scene_to_file("res://scenes/main.tscn")


# --- Сеть: создать сервер, найти игру (LAN), подключиться по IP ---
func _build_net_panel() -> void:
	_net_box.add_child(_caption("Игра по сети (LAN)"))
	_net_box.set_meta("help", "multiplayer")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_net_box.add_child(row)
	row.add_child(_small("Ваше имя"))
	_pname = LineEdit.new()
	_pname.custom_minimum_size = Vector2(150, 0)
	_pname.max_length = 20
	_pname.text = str(Settings.get_value("net", "player_name"))
	_pname.text_changed.connect(func(t: String) -> void:
		Settings.set_value("net", "player_name", t)
		Settings.save_all())
	row.add_child(_pname)
	row.add_child(_small("Игра"))
	_gname = LineEdit.new()
	_gname.custom_minimum_size = Vector2(200, 0)
	_gname.text = str(Settings.get_value("net", "game_name"))
	_gname.text_changed.connect(func(t: String) -> void:
		Settings.set_value("net", "game_name", t)
		Settings.save_all())
	row.add_child(_gname)
	row.add_child(_small("Порт"))
	_port = SpinBox.new()
	_port.min_value = 1024
	_port.max_value = 65535
	_port.value = int(Settings.get_value("net", "port"))
	_port.value_changed.connect(func(v: float) -> void:
		Settings.set_value("net", "port", int(v))
		Settings.save_all())
	row.add_child(_port)
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 8)
	_net_box.add_child(row2)
	_host_btn = _btn("Создать сервер", func() -> void:
		net.stop_search()
		if net.host(int(_port.value)):
			changed(), "multiplayer")
	row2.add_child(_host_btn)
	_find_btn = _btn("Найти игру", func() -> void: net.start_search(), "multiplayer")
	row2.add_child(_find_btn)
	_leave_btn = _btn("Отключиться", func() -> void:
		net.stop_search()
		net.leave()
		refresh(), "multiplayer")
	row2.add_child(_leave_btn)
	_addr = LineEdit.new()
	_addr.placeholder_text = "IP:порт, например 192.168.1.5:24680"
	_addr.custom_minimum_size = Vector2(260, 0)
	_addr.text = str(Settings.get_value("net", "last_address"))
	row2.add_child(_addr)
	row2.add_child(_btn("Подключиться по IP", func() -> void: _join_text(_addr.text), "multiplayer"))
	_servers = ItemList.new()
	_servers.custom_minimum_size = Vector2(0, 110)
	_servers.set_meta("help", "multiplayer")
	_servers.item_activated.connect(func(i: int) -> void: _join_server(i))
	_net_box.add_child(_servers)
	var row3 := HBoxContainer.new()
	_net_box.add_child(row3)
	row3.add_child(_btn("Подключиться к выбранной", func() -> void:
		var sel := _servers.get_selected_items()
		if not sel.is_empty():
			_join_server(sel[0]), "multiplayer"))
	_net_status = Label.new()
	_net_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_net_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_net_status.text = net.status if net.status != "" else "Одиночная игра. Для сети: «Создать сервер» или «Найти игру»."
	row3.add_child(_net_status)

func _small(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.modulate = Color(1, 1, 1, 0.7)
	return l

func _fill_servers() -> void:
	if _servers == null:
		return
	var keep := _servers.get_selected_items()
	_servers.clear()
	_server_keys.clear()
	for key in net.servers:
		var d: Dictionary = net.servers[key]
		_servers.add_item("%s · карта %s · игроки %d/%d · пинг %d мс · %s%s" % [d.get("name", "?"), d.get("map", "?"), int(d.get("players", 0)), int(d.get("max", 0)), int(d.get("ping", 0)), key, " · идёт бой" if d.get("busy", false) else ""])
		_server_keys.append(key)
	if not keep.is_empty() and keep[0] < _servers.item_count:
		_servers.select(keep[0])
	if net.searching() and _server_keys.is_empty():
		_servers.add_item("Поиск… (если сервер не находится — введите IP:порт)")
		_servers.set_item_disabled(0, true)
		_server_keys.append("")

func _join_server(i: int) -> void:
	if i < 0 or i >= _server_keys.size() or _server_keys[i] == "":
		return
	_join_text(str(_server_keys[i]))

func _join_text(text: String) -> void:
	text = text.strip_edges()
	if text == "":
		return
	var host := text
	var port := int(_port.value)
	if text.contains(":"):
		host = text.substr(0, text.rfind(":"))
		port = int(text.substr(text.rfind(":") + 1))
	Settings.set_value("net", "last_address", text)
	Settings.save_all()
	net.stop_search()
	net.join(host, port)
	refresh()


func ask_quit() -> void:
	ConfirmBox.ask(get_tree(), "Выйти из игры?", quit_now, "Выйти", "Отмена")

# Экран выхода с прогрессом: сохранение настроек, отключение сети, закрытие.
func quit_now() -> void:
	var tree := get_tree()
	LoadingScreen.open(tree, "Выход из игры")
	await LoadingScreen.step(tree, 0.3, "Сохранение настроек")
	Settings.save_all()
	await LoadingScreen.step(tree, 0.7, "Отключение сети")
	NetGame.leave_match(tree)
	await LoadingScreen.step(tree, 1.0, "До встречи, командир")
	await tree.create_timer(0.4).timeout
	tree.quit()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		ask_quit()

# Клиент видит опцию хоста, но не меняет её.
func _process(_d: float) -> void:
	if _cheats_box != null:
		_cheats_box.disabled = NetGame.online and not NetGame.hosting
		if _cheats_box.button_pressed != MatchSetup.allow_cheats:
			_cheats_box.set_pressed_no_signal(MatchSetup.allow_cheats)
