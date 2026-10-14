# Контрибьютор: vibic777
# Пространственная сетка юнитов, инкрементальная: юнит переходит между ячейками только при смене ячейки
# (track), добавляется/убирается при входе/выходе из дерева. Нет пересборки по всем юнитам каждый кадр.
class_name UnitIndex
extends RefCounted

const CELL := 8.0
static var _frame := -1
static var _buckets := {}     # ячейка -> [юниты]
static var _cnt := {}         # Vector3i(x, z, команда) -> число юнитов
static var _mask := {}        # ячейка -> битовая маска команд
static var _coarse := {}      # крупная ячейка 4×4 -> маска команд
static var _ccnt := {}        # Vector3i(cx, cz, команда) -> число
static var all: Array = []
static var _tree: SceneTree

static func key_of(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x / CELL), floori(p.z / CELL))

# Совместимость: «пометить устаревшим» — теперь no-op для сетки, список all обновится в refresh.
static var _retrack := false

# Пометить: на следующем refresh() перепроверить ячейки всех юнитов (после спавна/телепорта).
static func dirty() -> void:
	_frame = -1
	_retrack = true

static func add(u: BattleUnit) -> void:
	if u._ix_in:
		return
	u._ix_in = true
	u._ix_key = key_of(u.global_position)
	u._ix_team = MatchSetup.team_of(u.side) if u.side > 0 else -1
	u.team_bit = (1 << u._ix_team) if u._ix_team >= 0 else 0
	_put(u, u._ix_key)
	dirty()

static func remove(u: BattleUnit) -> void:
	if not u._ix_in:
		return
	u._ix_in = false
	_take(u, u._ix_key)
	_frame = -1

# Вызывается юнитом после движения: дёшево, если ячейка та же.
static func track(u: BattleUnit) -> void:
	if not u._ix_in:
		return
	var k := key_of(u.global_position)
	var t := MatchSetup.team_of(u.side) if u.side > 0 else -1
	if k == u._ix_key and t == u._ix_team:
		return
	_take(u, u._ix_key)
	u._ix_key = k
	u._ix_team = t
	u.team_bit = (1 << t) if t >= 0 else 0
	_put(u, k)

static func _put(u: BattleUnit, k: Vector2i) -> void:
	var b: Array = _buckets.get(k, [])
	if b.is_empty():
		_buckets[k] = b
	b.append(u)
	var t := u._ix_team
	if t < 0:
		return
	var fk := Vector3i(k.x, k.y, t)
	var n := int(_cnt.get(fk, 0)) + 1
	_cnt[fk] = n
	if n == 1:
		_mask[k] = int(_mask.get(k, 0)) | (1 << t)
	var ck := Vector3i(k.x >> 2, k.y >> 2, t)
	var cn := int(_ccnt.get(ck, 0)) + 1
	_ccnt[ck] = cn
	if cn == 1:
		var c2 := Vector2i(k.x >> 2, k.y >> 2)
		_coarse[c2] = int(_coarse.get(c2, 0)) | (1 << t)

static func _take(u: BattleUnit, k: Vector2i) -> void:
	var b: Array = _buckets.get(k, [])
	var i := b.find(u)
	if i >= 0:
		b[i] = b[b.size() - 1]
		b.pop_back()
		if b.is_empty():
			_buckets.erase(k)
	var t := u._ix_team
	if t < 0:
		return
	var fk := Vector3i(k.x, k.y, t)
	var n := int(_cnt.get(fk, 0)) - 1
	if n <= 0:
		_cnt.erase(fk)
		var m := int(_mask.get(k, 0)) & ~(1 << t)
		if m == 0:
			_mask.erase(k)
		else:
			_mask[k] = m
	else:
		_cnt[fk] = n
	var ck := Vector3i(k.x >> 2, k.y >> 2, t)
	var cn := int(_ccnt.get(ck, 0)) - 1
	var c2 := Vector2i(k.x >> 2, k.y >> 2)
	if cn <= 0:
		_ccnt.erase(ck)
		var cm := int(_coarse.get(c2, 0)) & ~(1 << t)
		if cm == 0:
			_coarse.erase(c2)
		else:
			_coarse[c2] = cm
	else:
		_ccnt[ck] = cn

# Раз в кадр: только список всех юнитов (копия группы в C++); ячейки ведут сами юниты через track().
static func refresh(tree: SceneTree) -> void:
	var f := Engine.get_process_frames()
	if f == _frame and _tree == tree:
		return
	if _tree != tree:
		_tree = tree
		_buckets.clear()
		_cnt.clear()
		_mask.clear()
		_coarse.clear()
		_ccnt.clear()
		for node in tree.get_nodes_in_group("units"):
			(node as BattleUnit)._ix_in = false
	_frame = f
	all = tree.get_nodes_in_group("units")
	if _retrack:
		_retrack = false
		for node in all:
			var u := node as BattleUnit
			if u._ix_in:
				track(u)
			elif u.is_inside_tree():
				add(u)
		_retrack = false

static func near(tree: SceneTree, at: Vector3, reach: float) -> Array:
	refresh(tree)
	var out: Array = []
	var r := ceili(reach / CELL)
	var c := key_of(at)
	for dx in range(-r, r + 1):
		for dz in range(-r, r + 1):
			var b = _buckets.get(c + Vector2i(dx, dz))
			if b != null:
				out.append_array(b)
	return out

# Ближайший враг: только ячейки чужих команд, кольцами от центра с ранним выходом.
# targets: "all" / "ground" / "air".
static func nearest_hostile(tree: SceneTree, at: Vector3, reach: float, team: int, targets: String) -> BattleUnit:
	refresh(tree)
	var best: BattleUnit = null
	var best_d2 := reach * reach
	var r := ceili(reach / CELL)
	var c := Vector2i(floori(at.x / CELL), floori(at.z / CELL))
	var mine := 1 << team
	# Ранний выход по крупной сетке: рядом нет чужих команд — без обхода мелких ячеек.
	var any := false
	for cx in range((c.x - r) >> 2, ((c.x + r) >> 2) + 1):
		for cz in range((c.y - r) >> 2, ((c.y + r) >> 2) + 1):
			if (int(_coarse.get(Vector2i(cx, cz), 0)) & ~mine) != 0:
				any = true
				break
		if any:
			break
	if not any:
		return null
	for ring in range(0, r + 1):
		if best != null:
			var inner := (ring - 1) * CELL
			if inner > 0.0 and inner * inner > best_d2:
				break
		for dx in range(-ring, ring + 1):
			var step := 1 if (absi(dx) == ring) else 2 * ring
			var dz := -ring
			while dz <= ring:
				var key := Vector2i(c.x + dx, c.y + dz)
				dz += step
				var mk: int = _mask.get(key, 0)
				if (mk & ~mine) == 0:
					continue
				for node in _buckets[key]:
					var u := node as BattleUnit
					if u.side <= 0 or u.team_bit == mine:
						continue
					if u.hull <= 0.0 or u.submerged_left > 0.0:
						continue
					if targets != "all":
						var air := BattleGrid.airborne(u.mover)
						if (targets == "air") != air:
							continue
					var dxz := u.global_position.x - at.x
					var dzz := u.global_position.z - at.z
					var d2 := dxz * dxz + dzz * dzz
					if d2 < best_d2:
						best_d2 = d2
						best = u
	return best
