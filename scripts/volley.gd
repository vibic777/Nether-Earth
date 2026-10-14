# Контрибьютор: vibic777
class_name Volley
extends Node3D

var kind := WeaponRack.Kind.BULLET
var side := SitePlan.OWNER_PLAYER
var damage := 1.0
var splash := 0.0
var stun := 0.0
var chains := 0
var speed := 16.0
var aim := Vector3.ZERO
var origin := Vector3.ZERO
var facing := Vector3.FORWARD
var reach := 1.0
var structure: CaptureSite
var lob := false
var _travel := 0.0

var _life := 0.16
var _done := false
var _body: MeshInstance3D
static var _bolt_mesh := _box(Vector3(0.18, 0.18, 0.45))
static var _beam_mesh := _box(Vector3(0.08, 0.08, 1.0))
static var _mats := {}

static func _box(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m

static func _mat(k: int) -> StandardMaterial3D:
	if not _mats.has(k):
		var material := StandardMaterial3D.new()
		material.albedo_color = WeaponRack.color_of(k)
		material.emission_enabled = true
		material.emission = WeaponRack.color_of(k)
		material.emission_energy_multiplier = 1.4
		_mats[k] = material
	return _mats[k]

func setup(attacker: BattleUnit, foe: BattleUnit) -> void:
	setup_from(attacker)
	if kind == WeaponRack.Kind.BOMB:
		aim = Vector3(foe.global_position.x, 0.25, foe.global_position.z)
	else:
		aim = foe.global_position + Vector3(0.0, 0.8, 0.0)
	global_position = origin

func setup_site(attacker: BattleUnit, site: CaptureSite) -> void:
	setup_from(attacker)
	structure = site
	aim = site.global_position + Vector3(0.0, 1.2, 0.0)
	global_position = origin

func setup_from(attacker: BattleUnit) -> void:
	kind = attacker.weapon
	side = attacker.side
	damage = WeaponRack.damage(kind, attacker.tier)
	splash = WeaponRack.splash_of(kind)
	stun = WeaponRack.stun_of(kind)
	chains = WeaponRack.chains_of(kind)
	speed = WeaponRack.speed_of(kind)
	reach = WeaponRack.range_of(kind)
	origin = attacker.global_position + Vector3(0.0, 1.0, 0.0)
	facing = attacker.facing()

func _ready() -> void:
	# Общие сетки и материалы на вид оружия (раньше — новые на каждый выстрел).
	_body = MeshInstance3D.new()
	if WeaponRack.hitscan(kind):
		_body.mesh = _beam_mesh
		_body.scale = Vector3(1.0, 1.0, maxf(origin.distance_to(aim), 0.01))
	else:
		_body.mesh = _bolt_mesh
	_body.material_override = _mat(kind)
	add_child(_body)
	if WeaponRack.hitscan(kind):
		_place_beam()

func _process(delta: float) -> void:
	var _pt := Prof.t()
	_process_inner(delta)
	Prof.add("volley", _pt)

func _process_inner(delta: float) -> void:
	if not _done:
		if WeaponRack.hitscan(kind):
			_resolve(aim)
			_done = true
		elif lob:
			var total := maxf(origin.distance_to(aim), 0.1)
			_travel = minf(_travel + speed * delta * 0.7, total)
			var t := _travel / total
			var prev := global_position
			global_position = origin.lerp(aim, t) + Vector3.UP * (4.0 * total * 0.3 * t * (1.0 - t))
			if global_position.distance_to(prev) > 0.001:
				_body.look_at(global_position + (global_position - prev), Vector3.UP)
			if t >= 1.0:
				_resolve(aim)
				_done = true
		else:
			var to := aim - global_position
			var step := speed * delta
			if to.length() <= step:
				global_position = aim
				_resolve(aim)
				_done = true
			else:
				global_position += to.normalized() * step
				_body.look_at(global_position + to, Vector3.UP)
	if _done:
		_life -= delta
		if _life <= 0.0:
			queue_free()

func _place_beam() -> void:
	var length := maxf(origin.distance_to(aim), 0.2)
	_body.position = Vector3(0.0, 0.0, -length * 0.5)
	look_at(aim, Vector3.UP)

func _resolve(at: Vector3) -> void:
	if structure != null and is_instance_valid(structure):
		structure.take_hit(damage, side)
	if kind == WeaponRack.Kind.FLAME:
		for unit in _enemies(origin, reach):
			var to := unit.global_position - origin
			to.y = 0.0
			if to.length() > reach or to.length() < 0.05:
				continue
			if facing.dot(to.normalized()) < 0.55:
				continue
			unit.take_hit(damage, 0.0, side)
		return
	if kind == WeaponRack.Kind.TESLA:
		var first := _nearest(at, 1.4)
		var hit: Array[BattleUnit] = []
		var cursor := at
		var jump := damage
		if first != null:
			first.take_hit(jump, 0.0, side)
			hit.append(first)
			cursor = first.global_position
		for _hop in chains:
			var next := _nearest_except(cursor, 4.5, hit)
			if next == null:
				break
			jump *= 0.75
			next.take_hit(jump, 0.0, side)
			hit.append(next)
			cursor = next.global_position
		return
	if splash > 0.0:
		for unit in _enemies(at, splash):
			var flat := unit.global_position - at
			flat.y = 0.0
			var distance := flat.length()
			if distance > splash:
				continue
			var falloff := 1.0 - distance / splash * 0.45
			unit.take_hit(damage * falloff, stun, side)
		return
	var direct := _nearest(at, 1.3)
	if direct != null:
		direct.take_hit(damage, stun, side)

# Враги рядом с точкой — по пространственной сетке (раньше — перебор всех юнитов).
func _enemies(at: Vector3 = Vector3.INF, limit: float = 0.0) -> Array[BattleUnit]:
	var list: Array[BattleUnit] = []
	var pool: Array = get_tree().get_nodes_in_group("units") if at == Vector3.INF else UnitIndex.near(get_tree(), at, limit + 0.5)
	for node in pool:
		var unit := node as BattleUnit
		if is_instance_valid(unit) and MatchSetup.hostile(unit.side, side) and unit.hull > 0.0:
			list.append(unit)
	return list

func _nearest(at: Vector3, limit: float) -> BattleUnit:
	return _nearest_except(at, limit, [])

func _nearest_except(at: Vector3, limit: float, skip: Array[BattleUnit]) -> BattleUnit:
	var best: BattleUnit = null
	var best_distance := limit
	for unit in _enemies(at, limit):
		if skip.has(unit):
			continue
		var flat := unit.global_position - at
		flat.y = 0.0
		var distance := flat.length()
		if distance < best_distance:
			best_distance = distance
			best = unit
	return best
