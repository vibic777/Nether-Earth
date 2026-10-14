# Контрибьютор: vibic777
# Флаги сетевой игры и мост «приказ клиента → хост». Сам обмен — scripts/net_hub.gd (автозагрузка Net).
# Модель: хост считает весь бой; клиенты шлют приказы и получают снимки состояния.
class_name NetGame
extends RefCounted

static var online := false
static var hosting := false
static var in_match := false
static var _next_id := 0

static func is_client() -> bool:
	return online and not hosting

static func next_id() -> int:
	_next_id += 1
	return _next_id

static func hub() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("Net") if tree != null else null

# Клиент: приказ юниту уходит хосту. true — вызов перехвачен (локально не выполнять).
static func relay_unit(unit: Object, method: String, args: Array) -> bool:
	if not is_client() or not in_match:
		return false
	var h := hub()
	if h != null:
		h.send_command("u", int(unit.get("net_id")), method, args)
	return true

static func relay_site(site: Object, method: String, args: Array) -> bool:
	if not is_client() or not in_match:
		return false
	var h := hub()
	if h != null:
		h.send_command("s", int(site.get("net_id")), method, args)
	return true

static func shot_fx(shot: Node3D) -> void:
	if not (online and hosting and in_match):
		return
	var h := hub()
	if h != null:
		h.send_fx(shot)

static func leave_match(_tree: SceneTree) -> void:
	in_match = false
	var h := hub()
	if h != null:
		h.match_ended()
