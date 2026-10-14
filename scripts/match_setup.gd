# Контрибьютор: vibic777
# Настройка схватки: карта и до 8 слотов (человек / компьютер / закрыт), команды, цвета, старты.
# Сторона = номер слота 1..8 (0 — нейтрал). Заполняется лобби, читается боем.
class_name MatchSetup
extends RefCounted

const MAX_SLOTS := 8
const KIND_HUMAN := "human"
const KIND_AI := "ai"
const KIND_CLOSED := "closed"

static var map_id := "classic"
static var slots: Array = []          # [{side, kind, name, team, color, start, level, peer}]
static var local_side := 1
static var allow_cheats := true        # опция хоста «Разрешить читы» (F9)
static var configured := false        # false — бой запущен без лобби (тесты, скриншоты)

static func palette() -> Array:
	var list: Array = GameData.skirmish("colors", [])
	if list.is_empty():
		list = [{"name": "Зелёный", "color": "#5fe08a"}, {"name": "Красный", "color": "#ff5a4a"}]
	return list

static func default_slots(players: int) -> Array:
	var out: Array = []
	for i in MAX_SLOTS:
		out.append({
			"side": i + 1,
			"kind": (KIND_HUMAN if i == 0 else KIND_AI) if i < players else KIND_CLOSED,
			"name": "Игрок" if i == 0 else "Компьютер %d" % i,
			"team": i + 1,
			"color": i % palette().size(),
			"start": i if i < players else -1,
			"level": int(GameData.skirmish("default_level", 2)),
			"peer": 1 if i == 0 else 0,
		})
	return out

# Бой без лобби: классическая карта, игрок против компьютера.
static func ensure() -> void:
	if slots.is_empty():
		var m := MapData.load_map(map_id)
		slots = default_slots(int(m.get("players", 2)))
		local_side = 1

static func slot(side: int) -> Dictionary:
	ensure()
	if side >= 1 and side <= slots.size():
		return slots[side - 1]
	return {}

static func active(side: int) -> bool:
	var s := slot(side)
	return not s.is_empty() and s["kind"] != KIND_CLOSED and int(s["start"]) >= 0

static func active_sides() -> Array[int]:
	ensure()
	var out: Array[int] = []
	for s in slots:
		if s["kind"] != KIND_CLOSED and int(s["start"]) >= 0:
			out.append(int(s["side"]))
	return out

static func ai_sides() -> Array[int]:
	var out: Array[int] = []
	for side in active_sides():
		if slot(side)["kind"] == KIND_AI:
			out.append(side)
	return out

static func team_of(side: int) -> int:
	var s := slot(side)
	return int(s.get("team", side)) if not s.is_empty() else side

# Враги: обе стороны в игре и в разных командах. Нейтрал (0) никому не враг.
static func hostile(a: int, b: int) -> bool:
	if a <= 0 or b <= 0 or a == b:
		return false
	return team_of(a) != team_of(b)

static func allied(a: int, b: int) -> bool:
	return a > 0 and b > 0 and not hostile(a, b)

static func color_of(side: int) -> Color:
	if side <= 0:
		return Color("d2c07a")
	var s := slot(side)
	var pal := palette()
	var idx := int(s.get("color", side - 1)) % pal.size()
	return Color(str(pal[idx]["color"]))

static func name_of(side: int) -> String:
	var s := slot(side)
	return str(s.get("name", "Сторона %d" % side))

# Сторона, владеющая стартом карты с номером index.
static func side_at_start(index: int) -> int:
	ensure()
	for s in slots:
		if s["kind"] != KIND_CLOSED and int(s["start"]) == index:
			return int(s["side"])
	return 0

static func level_of(side: int) -> int:
	return int(slot(side).get("level", 2))

static func to_dict() -> Dictionary:
	return {"map": map_id, "slots": slots.duplicate(true), "cheats": allow_cheats}

static func from_dict(d: Dictionary) -> void:
	map_id = str(d.get("map", map_id))
	slots = (d.get("slots", []) as Array).duplicate(true)
	allow_cheats = bool(d.get("cheats", false))
	configured = true
