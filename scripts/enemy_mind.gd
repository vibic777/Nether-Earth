# Контрибьютор: vibic777
# ИИ одной стороны. Уровни и их параметры — data/game.json → skirmish.levels.
class_name EnemyMind
extends Node

enum Level { BEGINNER, EASY, NORMAL, HARD, EXPERT }

var level := Level.NORMAL
var side := SitePlan.OWNER_ENEMY
var _wait := 1.5
var _build_wait := 6.0

func level_name() -> String:
	return str(GameData.level(level, "name", "Средний"))

static func level_title(value: int) -> String:
	return str(GameData.level(value, "name", str(value)))

func set_level(value: int) -> void:
	level = clampi(value, 0, GameData.levels().size() - 1)
	_wait = 0.4
	var stock := Stockpile.of(get_tree(), side) if is_inside_tree() else null
	if stock != null:
		stock.income_scale = _f("income", 1.0)

func _ready() -> void:
	set_level(level)

func _f(field: String, fallback: float) -> float:
	return float(GameData.level(level, field, fallback))

func _b(field: String, fallback: bool) -> bool:
	return bool(GameData.level(level, field, fallback))

func _process(delta: float) -> void:
	var _pt := Prof.t()
	_process_inner(delta)
	Prof.add("mind", _pt)

func _process_inner(delta: float) -> void:
	if not alive():
		return
	_build_wait -= delta
	if _build_wait <= 0.0:
		_build_wait = _f("build_interval", 18.0)
		produce()
	_wait -= delta
	if _wait > 0.0:
		return
	_wait = _f("interval", 4.0)
	decide()

func alive() -> bool:
	var hq := _home()
	return hq != null and hq.hull > 0.0 and hq.team == side

func decide() -> void:
	# Каждый свободный инженер: зона, до которой дотягивается сеть (клетка зоны в связи), иначе вышка/узел.
	var taken := {}
	for engineer in _own():
		if engineer.mover != BattleGrid.Mover.ENGINEER or not engineer.linked() or engineer._site != null:
			continue
		var pick := _zone_spot(taken)
		if pick.size() == 2:
			var zone: FlagZone = pick[0]
			taken[zone] = true
			if not zone.inside(engineer.global_position) and not engineer.is_tasked():
				engineer.order_to(pick[1])
			continue
		var site := _capture_target()
		if site != null and not engineer.is_tasked():
			engineer.order_capture(site)
	_economy()
	var prey := _engineer_prey()
	var raid := _raid_target()
	var hq := _hostile_hq()
	var assault := _b("assault", false)
	for unit in _fighters():
		if not unit.linked():
			continue
		var goal: BattleUnit = prey if prey != null and _hunts(unit) else null
		if goal == null and _raids(unit):
			goal = raid
		if goal == null and assault and hq != null:
			if unit.attack_site != hq:
				unit.order_attack_site(hq)
			continue
		if goal == null:
			continue
		if unit.attack_target == goal:
			continue
		if not assault and unit.is_tasked():
			continue
		unit.order_attack(goal)

# Постройка: на каждом своём заводе, если очередь пуста, заказывает машину (инженер — если его нет).
func produce() -> void:
	if not _b("builds", true):
		return
	var stock := Stockpile.of(get_tree(), side)
	if stock == null:
		return
	var count := _own().size()
	var cap := int(GameData.skirmish("unit_cap", 40))
	var need_engineer := _engineer() == null
	for node in get_tree().get_nodes_in_group("sites"):
		var site := node as CaptureSite
		if count >= cap:
			return
		if site.team != side or not site.queue.is_empty():
			continue
		var list := Yard.catalog(site.kind)
		if list.is_empty():
			continue
		var combat: Array = []
		var engineers := _count(BattleGrid.Mover.ENGINEER)
		for m in list:
			if not BattleGrid.truck(m) and not BattleGrid.deployable(m):
				# Инженеров хватит 3 — дальше строим боевых.
				if m == BattleGrid.Mover.ENGINEER and engineers >= 3:
					continue
				combat.append(m)
		if combat.is_empty():
			continue
		var pick: int = combat[randi() % combat.size()]
		if need_engineer and list.has(BattleGrid.Mover.ENGINEER):
			pick = BattleGrid.Mover.ENGINEER
			need_engineer = false
		elif pick == BattleGrid.Mover.ENGINEER and combat.size() > 1:
			pick = combat[(combat.find(pick) + 1) % combat.size()]
		if site.enqueue(pick, stock):
			count += 1

func _capture_target() -> CaptureSite:
	if not _b("captures", false):
		return null
	var hard := _b("assault", false)
	var best: CaptureSite = null
	var best_score := INF
	var base := _base_pos()
	for node in get_tree().get_nodes_in_group("sites"):
		var site := node as CaptureSite
		if site.team == side or MatchSetup.allied(site.team, side):
			continue
		if not RelayNet.covers_side(get_tree(), _pad(site), side):
			continue
		var hostile := site.team > 0
		if not hard and hostile:
			continue
		if not hard and site.kind != SitePlan.KIND_RELAY and site.kind != SitePlan.KIND_EXTRACTOR:
			continue
		if hard and site.kind != SitePlan.KIND_RELAY and site.kind != SitePlan.KIND_HQ and site.kind != SitePlan.KIND_EXTRACTOR and hostile:
			continue
		var score := _pad(site).distance_to(base) / BattleGrid.TILE
		if site.kind == SitePlan.KIND_RELAY:
			score -= 30.0
		if hostile and site.kind == SitePlan.KIND_RELAY:
			score -= 80.0
		if score < best_score:
			best_score = score
			best = site
	return best

func _engineer_prey() -> BattleUnit:
	if not _b("hunts", false):
		return null
	var hard := _b("assault", false)
	var best: BattleUnit = null
	var best_d := INF
	var base := _base_pos()
	for unit in _foes():
		if unit.mover != BattleGrid.Mover.ENGINEER:
			continue
		if not hard and not RelayNet.covers_side(get_tree(), unit.global_position, side):
			continue
		var d := unit.global_position.distance_to(base)
		if d < best_d:
			best_d = d
			best = unit
	return best

func _raid_target() -> BattleUnit:
	if not _b("raids", false):
		return null
	var best: BattleUnit = null
	var best_d := INF
	var base := _base_pos()
	for unit in _foes():
		if unit.mover == BattleGrid.Mover.ENGINEER:
			continue
		if not RelayNet.covers_side(get_tree(), unit.global_position, side):
			continue
		var d := unit.global_position.distance_to(base)
		if d < best_d:
			best_d = d
			best = unit
	return best

func _hunts(unit: BattleUnit) -> bool:
	return _b("assault", false) or unit.mover == BattleGrid.Mover.BIKE or unit.mover == BattleGrid.Mover.TROOPER

func _raids(unit: BattleUnit) -> bool:
	if _b("assault", false):
		return true
	return unit.mover == BattleGrid.Mover.BIKE

func _engineer() -> BattleUnit:
	for unit in _own():
		if unit.mover == BattleGrid.Mover.ENGINEER:
			return unit
	return null

func _fighters() -> Array[BattleUnit]:
	var list: Array[BattleUnit] = []
	for unit in _own():
		if unit.mover != BattleGrid.Mover.ENGINEER and unit.weapon >= 0 and not BattleGrid.is_static(unit.mover):
			list.append(unit)
	return list

var _own_frame := -1
var _own_list: Array[BattleUnit] = []

# Свои юниты: один проход по сетке на кадр (раньше — проход по всем юнитам на каждый вызов).
func _own() -> Array[BattleUnit]:
	var f := Engine.get_process_frames()
	if f != _own_frame:
		_own_frame = f
		_own_list.clear()
		UnitIndex.refresh(get_tree())
		for node in UnitIndex.all:
			var unit := node as BattleUnit
			if is_instance_valid(unit) and unit.side == side and unit.hull > 0.0:
				_own_list.append(unit)
	return _own_list

func _foes() -> Array[BattleUnit]:
	var list: Array[BattleUnit] = []
	for node in get_tree().get_nodes_in_group("units"):
		var unit := node as BattleUnit
		if MatchSetup.hostile(unit.side, side) and unit.hull > 0.0:
			list.append(unit)
	return list

func _home() -> CaptureSite:
	for node in get_tree().get_nodes_in_group("sites"):
		var site := node as CaptureSite
		if site.kind == SitePlan.KIND_HQ and site.home == side:
			return site
	return null

func _base_pos() -> Vector3:
	var hq := _home()
	return _pad(hq) if hq != null else Vector3.ZERO

# Ближайший враждебный штаб в зоне своей связи.
func _hostile_hq() -> CaptureSite:
	var best: CaptureSite = null
	var best_d := INF
	var base := _base_pos()
	for node in get_tree().get_nodes_in_group("sites"):
		var site := node as CaptureSite
		if not site.is_hostile_hq(side) or not RelayNet.covers_side(get_tree(), _pad(site), side):
			continue
		var d := _pad(site).distance_to(base)
		if d < best_d:
			best_d = d
			best = site
	return best

func _pad(site: CaptureSite) -> Vector3:
	return Vector3((site.terminal.x + 0.5) * BattleGrid.TILE, 0.0, (site.terminal.y + 0.5) * BattleGrid.TILE)


# --- Экономика ИИ: зоны, грузовики, станции, газопровод, турели, развёртываемые базы ---
const TRUCK_FOR := {"oil": "OIL_TRUCK", "gas": "GAS_TRUCK", "uranium": "URANIUM_TRUCK", "coal": "COAL_TRUCK"}
const PLANT_FOR := {"oil": "REFINERY", "gas": "GAS_PLANT", "uranium": "NUCLEAR", "coal": "COAL_PLANT"}
var _eco_wait := 0.0

# [зона, клетка] — ближайшая не наша зона, у которой есть клетка внутри зоны и в нашей сети.
func _zone_spot(taken: Dictionary) -> Array:
	if not _b("captures", false):
		return []
	var grid: BattleGrid = get_parent().get("_grid")
	var base := _base_pos()
	var best: Array = []
	var best_d := INF
	for node in get_tree().get_nodes_in_group("zones"):
		var z := node as FlagZone
		if taken.has(z) or z.owner_side == side or MatchSetup.allied(z.owner_side, side):
			continue
		if z.owner_side > 0 and not _b("assault", false):
			continue
		var d := z.global_position.distance_to(base)
		if d >= best_d:
			continue
		var r := int(ceil(z.radius))
		for dz in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var cell: Vector2i = z.center + Vector2i(dx, dz)
				if not grid.can_enter(cell, BattleGrid.Mover.ENGINEER):
					continue
				var w := grid.cell_center(cell)
				if z.inside(w) and RelayNet.covers_side(get_tree(), w, side):
					best = [z, cell]
					best_d = d
					break
			if best_d == d:
				break
	return best

func _zone_target() -> FlagZone:
	if not _b("captures", false):
		return null
	var best: FlagZone = null
	var best_d := INF
	var base := _base_pos()
	for node in get_tree().get_nodes_in_group("zones"):
		var z := node as FlagZone
		if z.owner_side == side or MatchSetup.allied(z.owner_side, side):
			continue
		if z.owner_side > 0 and not _b("assault", false):
			continue
		# Вне связи инженер замирает — берём только зоны, центр которых в нашей сети.
		if not RelayNet.covers_side(get_tree(), z.global_position, side):
			continue
		var d := z.global_position.distance_to(base)
		if d < best_d:
			best_d = d
			best = z
	return best

func _owned_resources() -> Array:
	var out: Array = []
	for node in get_tree().get_nodes_in_group("zones"):
		var z := node as FlagZone
		if z.owner_side == side and not out.has(z.resource):
			out.append(z.resource)
	return out

func _count(mover: int) -> int:
	var n := 0
	for u in _own():
		if u.mover == mover:
			n += 1
	return n

func _has_site(kind: int) -> bool:
	for node in get_tree().get_nodes_in_group("sites"):
		var s := node as CaptureSite
		if s.team == side and s.kind == kind:
			return true
	return false

func _economy() -> void:
	_eco_wait -= _f("interval", 4.0)
	if _eco_wait > 0.0:
		return
	_eco_wait = _f("eco_interval", 12.0)
	var stock := Stockpile.of(get_tree(), side)
	var hq := _home()
	if stock == null or hq == null:
		return
	var level := MatchSetup.level_of(side)
	var game := get_parent()
	var grid: BattleGrid = game.get("_grid")
	# Грузовики: по одному (на сложных — по два) на каждый свой ресурс.
	for res in _owned_resources():
		var truck := GameData.UNIT_KEYS.find(TRUCK_FOR.get(res, ""))
		if truck >= 0 and _count(truck) < (2 if level >= 3 else 1) and hq.queue.size() < 2:
			hq.enqueue(truck, stock)
		# Станция под ресурс, если хватает денег с запасом.
		var plant_key: String = PLANT_FOR.get(res, "")
		var plant := GameData.SITE_KEYS.find(plant_key)
		if level >= 1 and plant >= 0 and not _has_site(plant) and stock.money > BuildRules.price(plant_key) * 2:
			_build_near(grid, hq, plant_key)
		if res == "gas" and level >= 2:
			for node in get_tree().get_nodes_in_group("sites"):
				var w := node as CaptureSite
				if w.team == side and w.kind == SitePlan.KIND_GAS_WELL and stock.money > 600:
					BuildRules.lay_pipeline(game, grid, side, w)
	# Турели у баз: число растёт с уровнем.
	var turrets := 0
	for u in _own():
		if BattleGrid.is_turret(u.mover):
			turrets += 1
	if turrets < level * 2 and stock.money > 700:
		var keys := ["T_MG", "T_CANNON", "T_MISSILE", "T_LASER", "T_ION", "T_TESLA"]
		_build_near(grid, hq, keys[randi() % mini(keys.size(), 2 + level)])
	# Стены и ворота со стороны ближайшего врага (средний уровень и выше).
	if level >= 2 and stock.money > 900:
		_build_walls(grid, hq, level, stock)
	# Развёртываемые базы: казарма, завод техники, док (если есть вода).
	if level >= 2 and stock.money > 900:
		for pair in [["BUS", SitePlan.KIND_BARRACKS], ["TRACTOR", SitePlan.KIND_PLANT], ["SEMI", SitePlan.KIND_DOCK]]:
			var m := GameData.UNIT_KEYS.find(pair[0])
			if not _has_site(int(pair[1])) and _count(m) == 0:
				hq.enqueue(m, stock)
				break
	for u in _own():
		if BattleGrid.deployable(u.mover) and not u.is_tasked():
			if u.deploy_check() == "":
				u.deploy()
			else:
				var goal := _deploy_spot(grid, u)
				if goal.x >= 0:
					u.order_to(goal)

# Дуга стены поперёк направления на ближайший вражеский штаб, ворота посередине.
func _build_walls(grid: BattleGrid, hq: CaptureSite, level: int, stock: Stockpile) -> void:
	var walls := 0
	for u in _own():
		if u.mover == BattleGrid.Mover.WALL or u.mover == BattleGrid.Mover.GATE:
			walls += 1
	if walls >= level * 4:
		return
	var foe: CaptureSite = null
	var best := INF
	for node in get_tree().get_nodes_in_group("sites"):
		var s := node as CaptureSite
		if s.kind == SitePlan.KIND_HQ and MatchSetup.hostile(s.team, side):
			var d := s.global_position.distance_squared_to(hq.global_position)
			if d < best:
				best = d
				foe = s
	if foe == null:
		return
	var dir := Vector2(foe.footprint[0] - hq.footprint[0]).normalized()
	var side_dir := Vector2(-dir.y, dir.x)
	var r := maxi(3, BuildRules.radius_of(hq.kind) - 3)
	var mid := Vector2(hq.footprint[0]) + dir * r
	var placed := 0
	for k in [0, 1, -1, 2, -2, 3, -3]:
		if placed >= 2 or stock.money < 600:
			break
		var cell := Vector2i((mid + side_dir * k).round())
		var key := "GATE" if k == 0 else "WALL"
		if BuildRules.check(grid, get_tree(), side, key, cell) == "":
			BuildRules.place(get_parent(), grid, side, key, cell)
			placed += 1

func _build_near(grid: BattleGrid, hq: CaptureSite, key: String) -> void:
	var c := hq.footprint[0]
	var r := BuildRules.radius_of(hq.kind)
	for i in 30:
		var cell := c + Vector2i(randi_range(-r, r), randi_range(-r, r))
		if BuildRules.check(grid, get_tree(), side, key, cell) == "":
			BuildRules.place(get_parent(), grid, side, key, cell)
			return

func _deploy_spot(grid: BattleGrid, u: BattleUnit) -> Vector2i:
	var here := grid.cell_from_world(u.global_position)
	var dock := str(GameData.unit(u.mover, "deploys", "")) == "DOCK"
	for r in range(2, 30, 2):
		for i in 16:
			var a := i * TAU / 16.0
			var cell := here + Vector2i(roundi(cos(a) * r), roundi(sin(a) * r))
			if not grid.contains(cell) or grid.kind_at(cell) != BattleGrid.CellKind.PLAIN:
				continue
			if not dock:
				return cell
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if grid.contains(cell + d) and grid.kind_at(cell + d) == BattleGrid.CellKind.WATER:
					return cell
	return Vector2i(-1, -1)
