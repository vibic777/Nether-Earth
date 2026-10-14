# Контрибьютор: vibic777
# Карты схватки: data/maps/<id>.json (формат — docs/MAPS.md).
# Поиск как у game.json: data/maps рядом с exe → user://maps → встроенные res://data/maps.
class_name MapData
extends RefCounted

const CHARS := {".": BattleGrid.CellKind.PLAIN, "s": BattleGrid.CellKind.STONE, "t": BattleGrid.CellKind.TREE,
	"w": BattleGrid.CellKind.WATER, "m": BattleGrid.CellKind.MOUNTAIN, "b": BattleGrid.CellKind.BUILDING}

static var _cache: Dictionary = {}

static func ids() -> Array:
	var list: Array = GameData.skirmish("maps", [])
	return list if not list.is_empty() else ["classic"]

static func _path(id: String) -> String:
	var file := id + ".json"
	if not OS.has_feature("editor"):
		var beside := OS.get_executable_path().get_base_dir().path_join("data/maps").path_join(file)
		if FileAccess.file_exists(beside):
			return beside
	if FileAccess.file_exists("user://maps/" + file):
		return "user://maps/" + file
	return "res://data/maps/" + file

static func load_map(id: String) -> Dictionary:
	if _cache.has(id):
		return _cache[id]
	var m: Dictionary = {}
	var path := _path(id)
	if FileAccess.file_exists(path):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary:
			m = parsed
		else:
			push_warning("карта %s: ошибка разбора" % path)
	if m.is_empty() and id != "classic":
		return load_map("classic")
	_cache[id] = m
	return m

static func current() -> Dictionary:
	return load_map(MatchSetup.map_id)

static func size_of(m: Dictionary) -> Vector2i:
	return Vector2i(int(m.get("width", 48)), int(m.get("height", 14)))

static func kind_at(m: Dictionary, x: int, z: int) -> int:
	var rows: Array = m.get("rows", [])
	if z < 0 or z >= rows.size():
		return BattleGrid.CellKind.PLAIN
	var row: String = rows[z]
	if x < 0 or x >= row.length():
		return BattleGrid.CellKind.PLAIN
	return CHARS.get(row[x], BattleGrid.CellKind.PLAIN)

static func cell(v) -> Vector2i:
	return Vector2i(int(v[0]), int(v[1]))

static func site_kind(key: String) -> int:
	var i := GameData.SITE_KEYS.find(key)
	return i if i >= 0 else SitePlan.KIND_RELAY

static func mover_kind(key: String) -> int:
	var i := GameData.UNIT_KEYS.find(key)
	return i if i >= 0 else BattleGrid.Mover.TROOPER
