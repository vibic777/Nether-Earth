# Контрибьютор: vibic777
# Казна стороны: доллары ($), сырьё (нефть, газ, уран, уголь), топливо (⛽) и электросеть (⚡).
# Сырьё везут грузовики; на заводе (штабе) оно продаётся за $, если нет своей станции-потребителя.
# Все курсы и расходы — data/game.json → economy.
class_name Stockpile
extends Node

const RESOURCES := ["oil", "gas", "uranium", "coal"]
const RES_TITLE := {"oil": "нефть", "gas": "газ", "uranium": "уран", "coal": "уголь"}

var money := 0
var fuel := 0.0
var raw := {"oil": 0.0, "gas": 0.0, "uranium": 0.0, "coal": 0.0}
var power_cap := 0.0       # выработка ⚡ за последнюю секунду
var power_use := 0.0       # потребление ⚡
var infinite := false
var side := SitePlan.OWNER_PLAYER
var income_scale := 1.0
var _money_f := 0.0
var _tick := 0.0

static func eco(field: String, fallback: Variant) -> Variant:
	var sec = GameData.data().get("economy", {})
	if sec is Dictionary and sec.has(field):
		var v = sec[field]
		if fallback is float and (v is float or v is int):
			return float(v)
		if fallback is int and (v is float or v is int):
			return int(v)
		if typeof(v) == typeof(fallback):
			return v
	return fallback

static var _by_side := {}

static func of(tree: SceneTree, owner_side: int) -> Stockpile:
	var hit = _by_side.get(owner_side)
	if hit != null and is_instance_valid(hit) and hit.is_inside_tree() and hit.side == owner_side:
		return hit
	for node in tree.get_nodes_in_group("stockpiles"):
		if (node as Stockpile).side == owner_side:
			_by_side[owner_side] = node
		if (node as Stockpile).side == owner_side:
			return node
	return null

func _init() -> void:
	reset_start()

func _ready() -> void:
	add_to_group("stockpiles")

func _process(delta: float) -> void:
	var _pt := Prof.t()
	_process_inner(delta)
	Prof.add("stock", _pt)

func _process_inner(delta: float) -> void:
	if NetGame.is_client() and NetGame.in_match:
		return
	apply_income(delta)
	_tick -= delta
	if _tick <= 0.0:
		_tick = 1.0
		_run_plants(1.0)
	for node in get_tree().get_nodes_in_group("sites"):
		var site := node as CaptureSite
		site.tick_build(delta, self)

func line() -> String:
	var t := "$ %d · ⚡ %d/%d · ⛽ %d" % [money, int(power_cap), int(power_use), int(fuel)]
	for r in RESOURCES:
		if raw[r] >= 1.0:
			t += " · %s %d" % [RES_TITLE[r], int(raw[r])]
	return t

# Цена — Vector3i(доллары, 0, 0): так её отдаёт Yard.cost().
func can_pay(price: Vector3i) -> bool:
	return infinite or money >= price.x

func pay(price: Vector3i) -> bool:
	if not can_pay(price):
		return false
	if not infinite:
		money -= price.x
	return true

func refund(price: Vector3i) -> void:
	money += price.x

func reset_start() -> void:
	money = int(eco("start_money", 1200))
	fuel = float(eco("start_fuel", 60.0))
	for r in RESOURCES:
		raw[r] = 0.0
	_money_f = 0.0

# Доход узлов (штаб, жилы): $ в секунду.
func apply_income(delta: float) -> void:
	var rate := 0.0
	var k := float(eco("site_income_usd", 2.0))
	for node in get_tree().get_nodes_in_group("sites"):
		var site := node as CaptureSite
		if site.team != side:
			continue
		rate += float(site.metal_rate + site.chip_rate * 2 + site.power_rate) * k
	_money_f += rate * delta * income_scale
	while _money_f >= 1.0:
		money += 1
		_money_f -= 1.0
	fuel += float(eco("hq_fuel_per_s", 0.2)) * delta

func has_consumer(resource: String) -> bool:
	var kinds := {"oil": SitePlan.KIND_REFINERY, "gas": SitePlan.KIND_GAS_PLANT, "uranium": SitePlan.KIND_NUCLEAR, "coal": SitePlan.KIND_COAL_PLANT}
	for node in get_tree().get_nodes_in_group("sites"):
		var site := node as CaptureSite
		if site.team == side and site.kind == kinds[resource] and site.hull > 0.0:
			return true
	return false

# Разгрузка на заводе: при своей станции сырьё идёт в запас, иначе продаётся за $.
func deliver(resource: String, amount: float) -> int:
	var cap := float(eco("raw_cap", 200.0))
	var earned := 0
	if has_consumer(resource):
		raw[resource] = raw[resource] + amount
		if raw[resource] > cap:
			earned = sell(resource, raw[resource] - cap)
	else:
		earned = sell(resource, amount)
	return earned

func sell(resource: String, amount: float) -> int:
	var rates: Dictionary = eco("rates", {})
	var usd := int(round(amount * float(rates.get(resource, 5.0)) * income_scale))
	money += usd
	if resource in raw:
		raw[resource] = maxf(0.0, raw[resource] - amount) if raw[resource] >= amount else raw[resource]
	return usd

# Станции и НПЗ: расход сырья → ⚡ и ⛽. Потребление ⚡ — электротехника на ходу и постройка.
func _run_plants(dt: float) -> void:
	power_cap = float(eco("hq_power", 10.0))
	for node in get_tree().get_nodes_in_group("sites"):
		var site := node as CaptureSite
		if site.team != side or site.hull_max > 0.0 and site.hull <= 0.0:
			continue
		var key: String = GameData.SITE_KEYS[site.kind]
		match site.kind:
			SitePlan.KIND_REFINERY:
				var need := float(GameData.site(site.kind, "oil_per_s", 1.0)) * dt
				var used := minf(need, raw["oil"])
				raw["oil"] -= used
				fuel += used * float(GameData.site(site.kind, "fuel_per_oil", 3.0))
			SitePlan.KIND_GAS_PLANT, SitePlan.KIND_NUCLEAR, SitePlan.KIND_COAL_PLANT:
				var res := {"GAS_PLANT": "gas", "NUCLEAR": "uranium", "COAL_PLANT": "coal"}[key] as String
				var per := float(GameData.site(site.kind, res + "_per_s", 0.5)) * dt
				if raw[res] >= per:
					raw[res] -= per
					power_cap += float(GameData.site(site.kind, "power", 10.0))
	power_use = 0.0
	for node in get_tree().get_nodes_in_group("units"):
		var u := node as BattleUnit
		if u.side == side and u.hull > 0.0 and str(GameData.unit(u.mover, "power", "")) == "electric":
			power_use += float(GameData.unit(u.mover, "draw", 1.0)) * (1.0 if u.is_tasked() else 0.3)
	for node in get_tree().get_nodes_in_group("sites"):
		var s2 := node as CaptureSite
		if s2.team == side and not s2.queue.is_empty():
			power_use += float(eco("build_draw", 2.0))

# Множитель скорости: электротехника при нехватке ⚡, топливная без ⛽.
func drive_factor(power_class: String) -> float:
	if infinite:
		return 1.0
	if power_class == "electric":
		if power_use <= power_cap or power_use <= 0.0:
			return 1.0
		return clampf(power_cap / power_use, float(eco("blackout_min", 0.35)), 1.0)
	if power_class == "fuel":
		return 1.0 if fuel > 0.0 else float(eco("no_fuel_factor", 0.4))
	return 1.0

func burn_fuel(amount: float) -> void:
	if not infinite:
		fuel = maxf(0.0, fuel - amount)

func build_factor() -> float:
	if power_use <= power_cap or power_use <= 0.0:
		return 1.0
	return clampf(power_cap / power_use, 0.3, 1.0)
