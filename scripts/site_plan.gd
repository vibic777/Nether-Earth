# Контрибьютор: vibic777
# Узлы карты: штабы стартов (по слотам лобби) и нейтральные узлы из data/maps/*.json.
class_name SitePlan
extends RefCounted

const OWNER_NEUTRAL := 0
# Сторона этого компьютера (в сетевой игре — слот клиента). Меняется лобби.
static var OWNER_PLAYER := 1
# Сторона 2: противник классической карты и тестов.
const OWNER_ENEMY := 2

const KIND_HQ := 0
const KIND_RELAY := 1
const KIND_FACTORY := 2
const KIND_EXTRACTOR := 3
const KIND_AIR := 4
const KIND_ROBOT := 5
# Разворачиваемые базы
const KIND_DOCK := 6
const KIND_BARRACKS := 7
const KIND_PLANT := 8
# Постройки экономики (ставятся в радиусе завода)
const KIND_REFINERY := 9
const KIND_GAS_PLANT := 10
const KIND_NUCLEAR := 11
const KIND_COAL_PLANT := 12
# Ресурсная инфраструктура у флагов (захватывается вместе с зоной)
const KIND_DERRICK := 13
const KIND_OIL_STORAGE := 14
const KIND_GAS_WELL := 15
const KIND_URANIUM_MINE := 16
const KIND_COAL_MINE := 17

static func is_resource(kind: int) -> bool:
	return kind >= KIND_DERRICK and kind <= KIND_COAL_MINE

static func is_deployed(kind: int) -> bool:
	return kind == KIND_DOCK or kind == KIND_BARRACKS or kind == KIND_PLANT

static func is_built(kind: int) -> bool:
	return kind >= KIND_REFINERY and kind <= KIND_COAL_PLANT

static func defs() -> Array:
	var m := MapData.current()
	var out: Array = []
	var starts: Array = m.get("starts", [])
	for i in starts.size():
		var st: Dictionary = starts[i]
		var side := MatchSetup.side_at_start(int(st.get("index", i)))
		if side <= 0:
			continue
		out.append(_site(KIND_HQ, side, str(st.get("title", "Штаб")), _cells(st["hq"]), MapData.cell(st["terminal"]),
			float(st.get("radius", 28.0)), int(st.get("metal", 1)), int(st.get("chips", 0)), int(st.get("power", 1))))
	for s in m.get("sites", []):
		# "start": N — узел принадлежит стороне старта N с начала боя (свой цех у каждого).
		var owner := OWNER_NEUTRAL
		if s.has("start"):
			owner = MatchSetup.side_at_start(int(s["start"]))
		var def := _site(MapData.site_kind(str(s.get("kind", "RELAY"))), owner, str(s.get("title", "")), _cells(s["cells"]),
			MapData.cell(s["terminal"]), float(s.get("radius", 0.0)), int(s.get("metal", 0)), int(s.get("chips", 0)), int(s.get("power", 0)))
		def["zone"] = int(s.get("zone", -1))
		out.append(def)
	return out

# Все клетки-основания (и неиспользуемых стартов тоже: они остаются площадками).
static func footprints() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for def in defs():
		for cell in def["cells"]:
			cells.append(cell)
	return cells

static func _cells(list: Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c in list:
		out.append(MapData.cell(c))
	return out

static func _site(kind: int, owner: int, title: String, cells: Array[Vector2i], terminal: Vector2i, radius: float, metal: int = 0, chips: int = 0, power: int = 0) -> Dictionary:
	return {
		"kind": kind,
		"owner": owner,
		"title": title,
		"cells": cells,
		"terminal": terminal,
		"radius": radius,
		"metal": metal,
		"chips": chips,
		"power": power,
	}
