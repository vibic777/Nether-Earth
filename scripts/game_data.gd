# Контрибьютор: vibic777
# Все названия, описания и характеристики из data/game.json (правится вручную).
# Если ключа нет в файле, берётся значение по умолчанию из кода.
class_name GameData
extends RefCounted

const PATH := "res://data/game.json"
const USER_PATH := "user://game.json"   # если есть — перекрывает встроенный (удобно для готового exe)

const UNIT_KEYS := ["WALKER", "UAV", "ROTOR", "TRACK", "BIKE", "TROOPER", "ENGINEER", "JET",
	"OIL_TRUCK", "GAS_TRUCK", "URANIUM_TRUCK", "COAL_TRUCK", "PIPE", "SUB", "CRUISER", "BOAT", "SEMI", "BUS", "TRACTOR",
	"T_MG", "T_CANNON", "T_MISSILE", "T_LASER", "T_ION", "T_TESLA", "WALL", "GATE"]
const WEAPON_KEYS := ["BULLET", "SHELL", "FLAME", "ROCKET", "BOMB", "LASER", "PLASMA", "ION", "TESLA"]
const TERRAIN_KEYS := ["PLAIN", "STONE", "TREE", "WATER", "MOUNTAIN", "BUILDING", "LINK"]
const SITE_KEYS := ["HQ", "RELAY", "FACTORY", "EXTRACTOR", "AIR", "ROBOT", "DOCK", "BARRACKS", "PLANT", "REFINERY", "GAS_PLANT", "NUCLEAR", "COAL_PLANT", "DERRICK", "OIL_STORAGE", "GAS_WELL", "URANIUM_MINE", "COAL_MINE"]

static var _data: Dictionary = {}
static var _loaded := false

static func data() -> Dictionary:
	if not _loaded:
		reload()
	return _data

static func reload() -> void:
	_loaded = true
	_data = {}
	# Порядок: data/game.json рядом с exe → user://game.json → встроенный res://data/game.json
	var path := PATH
	if FileAccess.file_exists(USER_PATH):
		path = USER_PATH
	if not OS.has_feature("editor"):
		var beside := OS.get_executable_path().get_base_dir().path_join("data/game.json")
		if FileAccess.file_exists(beside):
			path = beside
	if not FileAccess.file_exists(path):
		return
	var text := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(text)
	if parsed is Dictionary:
		_data = parsed
	else:
		push_warning("data/game.json: ошибка разбора, используются значения из кода")

static func section(name: String, key: String) -> Dictionary:
	var sec = data().get(name, {})
	if sec is Dictionary:
		var item = sec.get(key, {})
		if item is Dictionary:
			return item
	return {}

static func _val(name: String, key: String, field: String, fallback: Variant) -> Variant:
	var item := section(name, key)
	if not item.has(field):
		return fallback
	var v = item[field]
	if fallback is int and (v is float or v is int):
		return int(v)
	if fallback is float and (v is float or v is int):
		return float(v)
	if fallback is String and v is String:
		return v
	if fallback is Color and v is String:
		return Color(v)
	if fallback is Vector3i and v is Array and v.size() == 3:
		return Vector3i(int(v[0]), int(v[1]), int(v[2]))
	if fallback is Array and v is Array:
		return v
	if fallback is Dictionary and v is Dictionary:
		return v
	return fallback

static func unit(mover: int, field: String, fallback: Variant) -> Variant:
	return _val("units", UNIT_KEYS[mover] if mover >= 0 and mover < UNIT_KEYS.size() else "", field, fallback)

static func weapon(kind: int, field: String, fallback: Variant) -> Variant:
	return _val("weapons", WEAPON_KEYS[kind] if kind >= 0 and kind < WEAPON_KEYS.size() else "", field, fallback)

static func terrain(kind: int, field: String, fallback: Variant) -> Variant:
	return _val("terrain", TERRAIN_KEYS[kind] if kind >= 0 and kind < TERRAIN_KEYS.size() else "", field, fallback)

static func site(kind: int, field: String, fallback: Variant) -> Variant:
	return _val("buildings", SITE_KEYS[kind] if kind >= 0 and kind < SITE_KEYS.size() else "", field, fallback)

static func help() -> Dictionary:
	var h = data().get("help", {})
	return h if h is Dictionary else {}

# Раздел "skirmish": цвета, сложности, стартовый отряд, сеть.
static func skirmish(field: String, fallback: Variant) -> Variant:
	var sec = data().get("skirmish", {})
	if sec is Dictionary and sec.has(field):
		var v = sec[field]
		if fallback is int and (v is float or v is int):
			return int(v)
		if fallback is float and (v is float or v is int):
			return float(v)
		if typeof(v) == typeof(fallback):
			return v
	return fallback

# Уровни сложности ИИ (порядок = номер уровня).
static func levels() -> Array:
	var list: Array = skirmish("levels", [])
	if list.is_empty():
		for n in ["Новичок", "Лёгкий", "Средний", "Сложный", "Эксперт"]:
			list.append({"name": n})
	return list

static func level(index: int, field: String, fallback: Variant) -> Variant:
	var list := levels()
	if index < 0 or index >= list.size():
		return fallback
	var item: Dictionary = list[index]
	if not item.has(field):
		return fallback
	var v = item[field]
	if fallback is float and (v is float or v is int):
		return float(v)
	if fallback is int and (v is float or v is int):
		return int(v)
	if fallback is bool and v is bool:
		return v
	if fallback is String and v is String:
		return v
	return fallback
