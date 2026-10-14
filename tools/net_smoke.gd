# Контрибьютор: vibic777
# Сетевой дым-тест: NET_ROLE=host|client, два процесса на одной машине.
extends SceneTree
var n := 0
var net
var role := ""
var started := false
func _initialize():
	role = OS.get_environment("NET_ROLE")
	MatchSetup.map_id = "duel"
	MatchSetup.slots = MatchSetup.default_slots(2)
	Settings.load_all()
func _process(_d):
	n += 1
	OS.delay_msec(16)
	if n == 2:
		net = root.get_node("Net")
		if role == "host":
			MatchSetup.slots[1]["kind"] = MatchSetup.KIND_HUMAN
			MatchSetup.slots[1]["peer"] = 0
			print("host ok=", net.host(24690))
		else:
			net.start_search()
	if role == "client" and n == 90:
		print("найдено серверов: ", net.servers.size(), " ", net.servers.keys())
		net.stop_search()
		net.join("127.0.0.1", 24690)
	if role == "host" and not started and int(MatchSetup.slots[1].get("peer", 0)) > 1:
		started = true
		print("клиент занял слот 2, старт")
		net.start_online()
	if role == "client" and n % 60 == 0 and NetGame.in_match:
		var mine := 0
		var all := 0
		for u in get_nodes_in_group("units"):
			all += 1
			if u.side == SitePlan.OWNER_PLAYER: mine += 1
		print("клиент: сторона ", SitePlan.OWNER_PLAYER, " юнитов ", all, " своих ", mine)
		if all > 0 and mine > 0:
			for u in get_nodes_in_group("units"):
				if u.side == SitePlan.OWNER_PLAYER:
					u.order_to(Vector2i(20, 14))
					print("клиент: приказ отправлен")
					break
	if role == "host" and NetGame.in_match and n % 120 == 0:
		for u in get_nodes_in_group("units"):
			if u.side == 2 and u._path.size() > 0:
				print("хост: юнит стороны 2 получил путь ", u._path.size())
				break
	if n > 2400:
		quit()
	return false
