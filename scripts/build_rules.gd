# Контрибьютор: vibic777
# Правило постройки: турели, стены, ворота и ВСЕ здания (НПЗ, станции) — только в радиусе
# своего штаба-завода или развёрнутой базы (док, казарма, завод техники).
# Радиус — data/game.json → buildings.<KIND>.build_radius (иначе economy.build_radius_default).
# Ресурсные узлы у флагов не строятся: это готовая инфраструктура карты. Исключение — газопровод.
class_name BuildRules
extends RefCounted

const SITE_BUILDS := ["REFINERY", "GAS_PLANT", "NUCLEAR", "COAL_PLANT"]
const UNIT_BUILDS := ["T_MG", "T_CANNON", "T_MISSILE", "T_LASER", "T_ION", "T_TESLA", "WALL", "GATE"]

static func catalog() -> Array:
	var list: Array = Stockpile.eco("buildables", [])
	return list if not list.is_empty() else SITE_BUILDS + UNIT_BUILDS

static func is_site_key(key: String) -> bool:
	return GameData.SITE_KEYS.has(key)

static func price(key: String) -> int:
	if is_site_key(key):
		return int(GameData.site(GameData.SITE_KEYS.find(key), "price", 200))
	return Yard.usd(GameData.UNIT_KEYS.find(key))

static func title(key: String) -> String:
	if is_site_key(key):
		return str(GameData.site(GameData.SITE_KEYS.find(key), "name", key))
	return str(GameData.unit(GameData.UNIT_KEYS.find(key), "name", key))

static func is_anchor(kind: int) -> bool:
	return kind == SitePlan.KIND_HQ or SitePlan.is_deployed(kind)

static func radius_of(kind: int) -> int:
	return int(GameData.site(kind, "build_radius", int(Stockpile.eco("build_radius_default", 8))))

# Своя база, в чьём радиусе лежит клетка (ближайшая), или null.
static func anchor_for(tree: SceneTree, side: int, cell: Vector2i) -> CaptureSite:
	var best: CaptureSite = null
	var best_d := INF
	for node in tree.get_nodes_in_group("sites"):
		var s := node as CaptureSite
		if s.team != side or not is_anchor(s.kind) or (s.hull_max > 0.0 and s.hull <= 0.0):
			continue
		var c := s.footprint[0]
		var d := Vector2(cell - c).length()
		if d <= radius_of(s.kind) and d < best_d:
			best_d = d
			best = s
	return best

static func anchors(tree: SceneTree, side: int) -> Array[CaptureSite]:
	var out: Array[CaptureSite] = []
	for node in tree.get_nodes_in_group("sites"):
		var s := node as CaptureSite
		if s.team == side and is_anchor(s.kind) and not (s.hull_max > 0.0 and s.hull <= 0.0):
			out.append(s)
	return out

static func _free(grid: BattleGrid, tree: SceneTree, cell: Vector2i) -> bool:
	if not grid.contains(cell) or grid.kind_at(cell) != BattleGrid.CellKind.PLAIN or grid.walls.has(cell):
		return false
	for node in tree.get_nodes_in_group("sites"):
		var s := node as CaptureSite
		if s.terminal == cell or s.footprint.has(cell):
			return false
	for node in tree.get_nodes_in_group("units"):
		var u := node as BattleUnit
		if BattleGrid.is_static(u.mover) and grid.cell_from_world(u.global_position) == cell:
			return false
	return true

# "" — можно; иначе причина по-русски.
static func check(grid: BattleGrid, tree: SceneTree, side: int, key: String, cell: Vector2i) -> String:
	if anchor_for(tree, side, cell) == null:
		return "Вне радиуса постройки"
	if not _free(grid, tree, cell):
		return "Клетка занята"
	if is_site_key(key) and not _free(grid, tree, cell + Vector2i(0, 1)) and not _free(grid, tree, cell + Vector2i(0, -1)):
		return "Нет места для подъезда"
	var stock := Stockpile.of(tree, side)
	if stock == null or stock.money < price(key):
		return "Не хватает $"
	return ""

static func place(host: Node, grid: BattleGrid, side: int, key: String, cell: Vector2i) -> Node:
	var tree := host.get_tree()
	if check(grid, tree, side, key, cell) != "":
		return null
	var stock := Stockpile.of(tree, side)
	stock.pay(Vector3i(price(key), 0, 0))
	var anchor := anchor_for(tree, side, cell)
	if is_site_key(key):
		var term := cell + Vector2i(0, 1) if _free(grid, tree, cell + Vector2i(0, 1)) else cell + Vector2i(0, -1)
		return spawn_site(host, grid, GameData.SITE_KEYS.find(key), side, cell, term)
	var unit := BattleUnit.new()
	unit.setup(grid, GameData.UNIT_KEYS.find(key), cell, side)
	unit.built_by = anchor
	host.add_child(unit)
	return unit

static func spawn_site(host: Node, grid: BattleGrid, kind: int, side: int, cell: Vector2i, term: Vector2i) -> CaptureSite:
	var cells: Array[Vector2i] = [cell]
	var prev := grid.kind_at(cell)
	grid.set_cell(cell, BattleGrid.CellKind.LINK, false)
	var site := CaptureSite.new()
	var def := SitePlan._site(kind, side, str(GameData.site(kind, "name", "Узел")), cells, term, float(GameData.site(kind, "radius", 0.0)))
	site.setup(grid, def)
	site._prev_cells[cell] = prev
	site.net_id = 10000 + NetGame.next_id()
	host.add_child(site)
	return site

# Газопровод от своего штаба к своей газовой скважине: сегменты по прямой, цена за сегмент.
static func pipeline_cost(grid: BattleGrid, from: Vector2i, to: Vector2i) -> int:
	var seg := int((Stockpile.eco("pipeline", {}) as Dictionary).get("segment_price", 12))
	return Pipeline.line_cells(from, to).size() * seg

static func lay_pipeline(host: Node, grid: BattleGrid, side: int, well: CaptureSite) -> Pipeline:
	var tree := host.get_tree()
	var hq: CaptureSite = null
	for s in anchors(tree, side):
		if s.kind == SitePlan.KIND_HQ:
			hq = s
	if hq == null or well == null or well.team != side or well.kind != SitePlan.KIND_GAS_WELL:
		return null
	for node in tree.get_nodes_in_group("pipelines"):
		if (node as Pipeline).well == well:
			return null
	var cost := pipeline_cost(grid, hq.terminal, well.terminal)
	var stock := Stockpile.of(tree, side)
	if stock == null or stock.money < cost:
		return null
	stock.pay(Vector3i(cost, 0, 0))
	var pipe := Pipeline.new()
	pipe.side = side
	pipe.well = well
	pipe.add_to_group("pipelines")
	var cells := Pipeline.line_cells(hq.terminal, well.terminal)
	for i in cells.size():
		var c: Vector2i = cells[i]
		if grid.kind_at(c) == BattleGrid.CellKind.WATER or grid.kind_at(c) == BattleGrid.CellKind.MOUNTAIN:
			continue
		var seg := BattleUnit.new()
		seg.setup(grid, BattleGrid.Mover.PIPE, c, side)
		host.add_child(seg)
		var nxt: Vector2i = cells[mini(i + 1, cells.size() - 1)] if i + 1 < cells.size() else well.terminal
		var d := grid.cell_center(nxt) - grid.cell_center(c)
		if d.length() > 0.01:
			seg.rotation.y = atan2(d.x, d.z)
		pipe.segments.append(seg)
	host.add_child(pipe)
	return pipe
