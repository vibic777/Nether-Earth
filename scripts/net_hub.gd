# Контрибьютор: vibic777
# Автозагрузка «Net»: сервер/клиент ENet, поиск игр в LAN (UDP-рассылка), синхронизация лобби и боя.
# Хост считает бой; клиенты присылают приказы (command) и получают снимки (snapshot) и выстрелы (fx).
class_name NetHub
extends Node

signal servers_changed
signal status_changed(text: String)
signal setup_changed

const MAGIC := "NERELOADED1"
static var VERSION: String:
	get: return GameVersion.version()
const COMMANDS_UNIT := ["order_capture", "order_attack", "order_attack_site", "order_guard", "order_to", "set_mode", "order_fire_at", "use_ability", "cycle_gate", "deploy"]
const COMMANDS_SITE := ["enqueue", "cancel_all", "undeploy"]

var servers := {}           # "ip:port" -> {name, map, players, max, ip, port, ping, seen}
var status := ""
var game: Node              # boot.gd текущего боя
var _udp_host: PacketPeerUDP
var _udp_find: PacketPeerUDP
var _find_wait := 0.0
var _snap_wait := 0.0
var _units := {}            # клиент: net_id -> BattleUnit
var _hosted_port := 0

func _ready() -> void:
	UiTheme.apply(get_tree())
	GameLog.configure()
	if GameLog.crash_note != "":
		print(GameLog.crash_note)
		GameLog.warning(GameLog.crash_note)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(func() -> void: _say("Не удалось подключиться."); leave())
	multiplayer.server_disconnected.connect(_on_server_lost)

static func net_cfg(field: String, fallback: Variant) -> Variant:
	var n: Dictionary = GameData.skirmish("net", {})
	return n.get(field, fallback)

func game_port() -> int:
	return int(Settings.get_value("net", "port"))

func discovery_port() -> int:
	return int(net_cfg("discovery_port", 24681))

func my_peer() -> int:
	return multiplayer.get_unique_id() if NetGame.online else 1

func _say(text: String) -> void:
	print("[net] ", text)
	status = text
	status_changed.emit(text)

# --- Хост ---
func host(port: int) -> bool:
	_close_peer()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, int(net_cfg("max_clients", 7)))
	if err != OK:
		_say("Порт %d занят или закрыт (ошибка %d)." % [port, err])
		return false
	multiplayer.multiplayer_peer = peer
	_hosted_port = port
	NetGame.online = true
	NetGame.hosting = true
	_udp_host = PacketPeerUDP.new()
	if _udp_host.bind(discovery_port()) != OK:
		_say("Сервер на порту %d. Поиск в сети недоступен (порт %d занят) — подключайтесь по IP." % [port, discovery_port()])
	else:
		_say("Сервер создан: порт %d. Адреса: %s" % [port, ", ".join(local_ips())])
	var s0: Dictionary = MatchSetup.slots[0]
	s0["peer"] = 1
	s0["kind"] = MatchSetup.KIND_HUMAN
	s0["name"] = str(Settings.get_value("net", "player_name"))
	setup_changed.emit()
	return true

static func local_ips() -> PackedStringArray:
	var out := PackedStringArray()
	for ip in IP.get_local_addresses():
		if ip.count(".") == 3 and not ip.begins_with("127.") and not ip.begins_with("169.254."):
			out.append(ip)
	return out

func _on_peer_connected(id: int) -> void:
	if NetGame.hosting:
		_say("Подключается игрок #%d…" % id)

func _on_peer_disconnected(id: int) -> void:
	if not NetGame.hosting:
		return
	for s in MatchSetup.slots:
		if int(s.get("peer", 0)) == id:
			s["peer"] = 0
			if NetGame.in_match:
				# Ушедшего игрока заменяет компьютер.
				s["kind"] = MatchSetup.KIND_AI
				if game != null and is_instance_valid(game):
					game.spawn_mind_for(int(s["side"]))
				_say("%s отключился — его сторону ведёт компьютер." % s["name"])
			else:
				s["name"] = "(свободно)"
				_say("%s отключился." % s["name"])
	broadcast_setup()

@rpc("any_peer", "reliable")
func hello(player_name: String, version: String) -> void:
	if not NetGame.hosting:
		return
	var id := multiplayer.get_remote_sender_id()
	if version != VERSION:
		rejected.rpc_id(id, "Версии не совпадают: у сервера %s, у вас %s. Обновите игру." % [VERSION, version])
		return
	if NetGame.in_match:
		rejected.rpc_id(id, "Бой уже идёт.")
		return
	var players := int(MapData.current().get("players", 2))
	for i in mini(players, MatchSetup.slots.size()):
		var s: Dictionary = MatchSetup.slots[i]
		if s["kind"] == MatchSetup.KIND_HUMAN and int(s.get("peer", 0)) == 0:
			s["peer"] = id
			s["name"] = player_name.substr(0, 20)
			_say("%s занял слот %d." % [s["name"], i + 1])
			broadcast_setup()
			return
	rejected.rpc_id(id, "Нет свободных мест: хост должен поставить «Человек» в свободный слот.")

@rpc("authority", "reliable")
func rejected(reason: String) -> void:
	_say("Отказ сервера: " + reason)
	leave()

func broadcast_setup() -> void:
	setup_changed.emit()
	if NetGame.hosting and multiplayer.get_peers().size() > 0:
		setup.rpc(MatchSetup.to_dict(), MapData.current())

@rpc("authority", "reliable")
func setup(d: Dictionary, map_json: Dictionary) -> void:
	MapData._cache[str(d.get("map", ""))] = map_json
	MatchSetup.from_dict(d)
	setup_changed.emit()

func request_edit(i: int, field: String, value: Variant) -> void:
	edit.rpc_id(1, i, field, value)

@rpc("any_peer", "reliable")
func edit(i: int, field: String, value: Variant) -> void:
	if not NetGame.hosting or i < 0 or i >= MatchSetup.slots.size():
		return
	var s: Dictionary = MatchSetup.slots[i]
	if int(s.get("peer", 0)) != multiplayer.get_remote_sender_id() or not (field in ["name", "color", "team"]):
		return
	s[field] = str(value).substr(0, 20) if field == "name" else int(value)
	broadcast_setup()

func start_online() -> void:
	if not NetGame.hosting:
		return
	begin.rpc(MatchSetup.to_dict(), MapData.current())
	_begin_local()

@rpc("authority", "reliable")
func begin(d: Dictionary, map_json: Dictionary) -> void:
	setup(d, map_json)
	_begin_local()

func _begin_local() -> void:
	var mine := 0
	for s in MatchSetup.slots:
		if int(s.get("peer", 0)) == my_peer() and s["kind"] == MatchSetup.KIND_HUMAN:
			mine = int(s["side"])
	if mine == 0:
		_say("Для вас нет слота.")
		return
	_units.clear()
	NetGame.in_match = true
	MatchSetup.configured = true
	MatchSetup.local_side = mine
	SitePlan.OWNER_PLAYER = mine
	LoadingScreen.open(get_tree(), "Подготовка боя…")
	BattleGrid.staged = true
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func match_ended() -> void:
	game = null
	_units.clear()

# --- Клиент ---
func join(address: String, port: int) -> bool:
	_close_peer()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		_say("Не удалось начать подключение к %s:%d (ошибка %d)." % [address, port, err])
		return false
	multiplayer.multiplayer_peer = peer
	NetGame.online = true
	NetGame.hosting = false
	_say("Подключение к %s:%d…" % [address, port])
	return true

func _on_connected() -> void:
	_say("Подключено. Ждём место в лобби…")
	hello.rpc_id(1, str(Settings.get_value("net", "player_name")), VERSION)

func _on_server_lost() -> void:
	var was := NetGame.in_match
	leave()
	_say("Связь с хостом потеряна.")
	if was:
		get_tree().change_scene_to_file("res://scenes/lobby.tscn")

func _close_peer() -> void:
	if multiplayer.multiplayer_peer != null and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	if _udp_host != null:
		_udp_host.close()
		_udp_host = null

func leave() -> void:
	if multiplayer.multiplayer_peer != null and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	if _udp_host != null:
		_udp_host.close()
		_udp_host = null
	NetGame.online = false
	NetGame.hosting = false
	NetGame.in_match = false
	for s in MatchSetup.slots:
		s["peer"] = 1 if int(s["side"]) == 1 else 0
		if s["kind"] == MatchSetup.KIND_HUMAN and int(s["side"]) != 1:
			s["kind"] = MatchSetup.KIND_AI
			s["name"] = "Компьютер %d" % (int(s["side"]) - 1)
	MatchSetup.local_side = 1
	SitePlan.OWNER_PLAYER = 1
	setup_changed.emit()

# --- Поиск игр в LAN ---
func start_search() -> void:
	stop_search()
	_udp_find = PacketPeerUDP.new()
	_udp_find.set_broadcast_enabled(true)
	_udp_find.bind(0)
	servers.clear()
	_find_wait = 0.0
	_say("Ищем игры в локальной сети…")
	servers_changed.emit()

func stop_search() -> void:
	if _udp_find != null:
		_udp_find.close()
		_udp_find = null

func searching() -> bool:
	return _udp_find != null

func _broadcast_targets() -> PackedStringArray:
	var out := PackedStringArray(["255.255.255.255"])
	for ip in local_ips():
		var parts := ip.split(".")
		out.append("%s.%s.%s.255" % [parts[0], parts[1], parts[2]])
	return out

func _process(delta: float) -> void:
	if _udp_host != null:
		while _udp_host.get_available_packet_count() > 0:
			var pkt := _udp_host.get_packet().get_string_from_utf8()
			var ip := _udp_host.get_packet_ip()
			var port := _udp_host.get_packet_port()
			if pkt.begins_with(MAGIC + "?"):
				var m := MapData.current()
				var humans := 0
				var seats := 0
				for s in MatchSetup.slots:
					if s["kind"] == MatchSetup.KIND_HUMAN:
						seats += 1
						if int(s.get("peer", 0)) != 0:
							humans += 1
				var reply := {"magic": MAGIC, "t": pkt.substr(MAGIC.length() + 1), "name": str(Settings.get_value("net", "game_name")),
					"map": str(m.get("name", "")), "players": humans, "max": seats, "port": _hosted_port, "busy": NetGame.in_match}
				_udp_host.set_dest_address(ip, port)
				_udp_host.put_packet(JSON.stringify(reply).to_utf8_buffer())
	if _udp_find != null:
		_find_wait -= delta
		if _find_wait <= 0.0:
			_find_wait = 1.0
			var msg := (MAGIC + "?" + str(Time.get_ticks_msec())).to_utf8_buffer()
			for target in _broadcast_targets():
				_udp_find.set_dest_address(target, discovery_port())
				_udp_find.put_packet(msg)
			var now := Time.get_ticks_msec()
			for key in servers.keys():
				if now - int(servers[key]["seen"]) > 4000:
					servers.erase(key)
			servers_changed.emit()
		while _udp_find.get_available_packet_count() > 0:
			var data = JSON.parse_string(_udp_find.get_packet().get_string_from_utf8())
			var ip := _udp_find.get_packet_ip()
			if data is Dictionary and data.get("magic", "") == MAGIC:
				var key := "%s:%d" % [ip, int(data["port"])]
				var ping := Time.get_ticks_msec() - int(str(data.get("t", "0")))
				data["ip"] = ip
				data["ping"] = ping
				data["seen"] = Time.get_ticks_msec()
				servers[key] = data
				servers_changed.emit()
	if NetGame.hosting and NetGame.in_match and game != null and is_instance_valid(game) and multiplayer.get_peers().size() > 0:
		_snap_wait -= delta
		if _snap_wait <= 0.0:
			_snap_wait = 1.0 / float(net_cfg("snapshot_hz", 10))
			_send_snapshot()

# --- Бой ---
func side_of_peer(id: int) -> int:
	for s in MatchSetup.slots:
		if int(s.get("peer", 0)) == id and s["kind"] == MatchSetup.KIND_HUMAN:
			return int(s["side"])
	return -1

func _encode(v: Variant) -> Variant:
	if v is BattleUnit:
		return {"@u": (v as BattleUnit).net_id}
	if v is CaptureSite:
		return {"@s": (v as CaptureSite).net_id}
	return v

func _decode(v: Variant) -> Variant:
	if v is Dictionary and v.has("@u"):
		return _unit_by_id(int(v["@u"]))
	if v is Dictionary and v.has("@s"):
		return _site_by_id(int(v["@s"]))
	return v

func _unit_by_id(id: int) -> BattleUnit:
	for node in get_tree().get_nodes_in_group("units"):
		if (node as BattleUnit).net_id == id:
			return node
	return null

func _site_by_id(id: int) -> CaptureSite:
	for node in get_tree().get_nodes_in_group("sites"):
		if (node as CaptureSite).net_id == id:
			return node
	return null

func send_command(target_kind: String, id: int, method: String, args: Array) -> void:
	var enc := []
	for a in args:
		enc.append(_encode(a))
	command.rpc_id(1, target_kind, id, method, enc)

@rpc("any_peer", "reliable")
func command(target_kind: String, id: int, method: String, args: Array) -> void:
	if not NetGame.hosting or not NetGame.in_match:
		return
	var side := side_of_peer(multiplayer.get_remote_sender_id())
	if side <= 0:
		return
	var dec := []
	for a in args:
		dec.append(_decode(a))
	if target_kind == "b" and game != null and dec.size() == 2:
		BuildRules.place(game, game._grid, side, method, Vector2i(int(dec[0]), int(dec[1])))
		return
	if target_kind == "u" and method in COMMANDS_UNIT:
		var unit := _unit_by_id(id)
		if unit != null and unit.side == side:
			unit.callv(method, dec)
	elif target_kind == "s" and method in COMMANDS_SITE:
		var site := _site_by_id(id)
		var stock := Stockpile.of(get_tree(), side)
		if site != null and stock != null and site.team == side:
			if method == "enqueue":
				site.enqueue(int(dec[0]), stock)
			else:
				site.cancel_all(stock)

func _send_snapshot() -> void:
	var units := []
	for node in get_tree().get_nodes_in_group("units"):
		var u := node as BattleUnit
		if u.hull <= 0.0 or u.is_queued_for_deletion():
			continue
		var p := u.position
		units.append([u.net_id, u.mover, u.side, p.x, p.y, p.z, u.rotation.y, u.hull, u.hull_max, u.weapon, u.tier, u.mode, u.ammo, u._stun, u.gate_mode, u.submerged_left, u.cargo])
	var sites := []
	for node in get_tree().get_nodes_in_group("sites"):
		var site := node as CaptureSite
		sites.append([site.net_id] + site.net_state())
	var stocks := {}
	for node in get_tree().get_nodes_in_group("stockpiles"):
		var st := node as Stockpile
		stocks[st.side] = [st.money, st.fuel, st.power_cap, st.power_use, st.raw.duplicate()]
	var zones := []
	for node in get_tree().get_nodes_in_group("zones"):
		var z := node as FlagZone
		zones.append([z.zone_id] + z.net_state())
	stocks["zones"] = zones
	snapshot.rpc(units, sites, stocks)

# Надёжный канал 1: снимок крупнее MTU, в LAN это дешевле потерь фрагментов.
@rpc("authority", "reliable", "call_remote", 1)
func snapshot(units: Array, sites: Array, stocks: Dictionary) -> void:
	if game == null or not is_instance_valid(game):
		return
	var seen := {}
	for e in units:
		var id := int(e[0])
		seen[id] = true
		var u: BattleUnit = _units.get(id)
		var at := Vector3(float(e[3]), float(e[4]), float(e[5]))
		if u == null or not is_instance_valid(u):
			u = BattleUnit.new()
			u.setup(game._grid, int(e[1]), game._grid.cell_from_world(at), int(e[2]))
			u.net_id = id
			u.weapon = int(e[9])
			u.tier = int(e[10])
			u.position = at
			u.rotation.y = float(e[6])
			game.add_child(u)
			_units[id] = u
		u.net_target = at
		u.net_rot = float(e[6])
		u.hull = float(e[7])
		u.hull_max = float(e[8])
		if u.weapon != int(e[9]) or u.tier != int(e[10]):
			u.weapon = int(e[9])
			u.tier = int(e[10])
			u._paint_muzzle()
		u.mode = int(e[11])
		u.ammo = int(e[12])
		u._stun = float(e[13])
		u.gate_mode = str(e[14])
		u.submerged_left = float(e[15])
		u.cargo = float(e[16])
	for id in _units.keys():
		if not seen.has(id):
			var gone: BattleUnit = _units[id]
			_units.erase(id)
			if is_instance_valid(gone):
				game.release_unit(gone)
				gone.queue_free()
	for e in sites:
		var site := _site_by_id(int(e[0]))
		if site != null:
			site.net_apply(e.slice(1))
	for z in stocks.get("zones", []):
		for node in get_tree().get_nodes_in_group("zones"):
			if (node as FlagZone).zone_id == int(z[0]):
				(node as FlagZone).net_apply(z.slice(1))
	for side in stocks:
		if str(side) == "zones":
			continue
		var st := Stockpile.of(get_tree(), int(side))
		if st != null:
			var v: Array = stocks[side]
			st.money = int(v[0])
			st.fuel = float(v[1])
			st.power_cap = float(v[2])
			st.power_use = float(v[3])
			st.raw = v[4]

func send_fx(shot: Volley) -> void:
	if multiplayer.get_peers().size() == 0:
		return
	fx.rpc(shot.kind, shot.side, shot.origin, shot.aim, shot.speed, shot.lob, shot.splash, shot.reach)

@rpc("authority", "unreliable")
func fx(kind: int, side: int, origin: Vector3, aim: Vector3, speed: float, lob: bool, splash: float, reach: float) -> void:
	if game == null or not is_instance_valid(game):
		return
	var shot := Volley.new()
	shot.kind = kind
	shot.side = side
	shot.damage = 0.0
	shot.origin = origin
	shot.aim = aim
	shot.speed = speed
	shot.lob = lob
	shot.splash = splash
	shot.reach = reach
	shot.facing = (aim - origin).normalized()
	game.add_child(shot)
	shot.global_position = origin


func _exit_tree() -> void:
	GameLog.shutdown()
