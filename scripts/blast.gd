# Контрибьютор: vibic777
# Взрывы и пожары: гибель грузовиков, станций, ядерные вспышки, горящая нефть.
class_name Blast
extends Node3D

var radius := 2.0          # в клетках
var _life := 0.0
var _max := 1.2
var _nuke := false
var _ball: MeshInstance3D
var _mat: StandardMaterial3D
var _stem: MeshInstance3D

# spec: {"radius", "damage", "burn_dps", "burn_seconds", "burn_radius", "nuke"} из data/game.json
static func spawn(host: Node, at: Vector3, spec: Dictionary) -> void:
	if host == null or spec.is_empty():
		return
	var r := float(spec.get("radius", 2.0))
	var dmg := float(spec.get("damage", 10.0))
	var b := Blast.new()
	b.radius = r
	b._nuke = bool(spec.get("nuke", false)) or r >= 5.0
	b._max = 2.2 if b._nuke else 1.0
	host.add_child(b)
	b.global_position = at
	if not (NetGame.is_client() and NetGame.in_match):
		hurt(host.get_tree(), at, r * BattleGrid.TILE, dmg)
	if float(spec.get("burn_dps", 0.0)) > 0.0:
		var f := FireSpill.new()
		f.radius = float(spec.get("burn_radius", r)) * BattleGrid.TILE
		f.dps = float(spec["burn_dps"])
		f.left = float(spec.get("burn_seconds", 8.0))
		host.add_child(f)
		f.global_position = at

# Урон всем (свой/чужой) со спадом от центра; узлам с корпусом тоже.
static func hurt(tree: SceneTree, at: Vector3, reach: float, dmg: float) -> void:
	for node in tree.get_nodes_in_group("units"):
		var u := node as BattleUnit
		var d := u.global_position.distance_to(at)
		if d <= reach and u.hull > 0.0:
			u.take_hit(dmg * (1.0 - 0.6 * d / reach), 0.0, -1)
	for node in tree.get_nodes_in_group("sites"):
		var s := node as CaptureSite
		var d2 := s.global_position.distance_to(at)
		if d2 <= reach and s.hull_max > 0.0:
			s.take_hit_any(dmg * 0.6 * (1.0 - 0.6 * d2 / reach))

func _ready() -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	_ball = MeshInstance3D.new()
	_ball.mesh = mesh
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.albedo_color = Color(1.0, 0.75, 0.3, 0.9)
	_ball.material_override = _mat
	_ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ball)
	if _nuke:
		var stem := CylinderMesh.new()
		stem.top_radius = 0.25
		stem.bottom_radius = 0.6
		stem.height = 1.0
		_stem = MeshInstance3D.new()
		_stem.mesh = stem
		_stem.material_override = _mat
		add_child(_stem)

func _process(delta: float) -> void:
	_life += delta
	var t := clampf(_life / _max, 0.0, 1.0)
	var size := radius * BattleGrid.TILE * (0.4 + t * 1.6)
	_ball.scale = Vector3.ONE * size
	if _nuke:
		_ball.position.y = t * radius * 2.4
		_stem.scale = Vector3(size * 0.35, t * radius * 2.4, size * 0.35)
		_stem.position.y = t * radius * 1.2
		_mat.albedo_color = Color(1.0, 0.9 - t * 0.5, 0.5 - t * 0.4, 0.95 - t * 0.9)
	else:
		_mat.albedo_color = Color(1.0, 0.7 - t * 0.4, 0.25, 0.9 - t * 0.9)
	if _life >= _max:
		queue_free()
