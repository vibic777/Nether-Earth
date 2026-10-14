# Контрибьютор: vibic777
# Горящая нефть после взрыва нефтевоза: урон всем внутри, пламя мерцает.
class_name FireSpill
extends Node3D

var radius := 4.0
var dps := 4.0
var left := 8.0
var _flames: Array[MeshInstance3D] = []
var _tick := 0.0

func _ready() -> void:
	var disc := CylinderMesh.new()
	disc.top_radius = radius
	disc.bottom_radius = radius
	disc.height = 0.04
	var dm := StandardMaterial3D.new()
	dm.albedo_color = Color("1a1410")
	dm.roughness = 0.2
	var d := MeshInstance3D.new()
	d.mesh = disc
	d.material_override = dm
	d.position.y = 0.06
	add_child(d)
	for i in 9:
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 0.3
		cone.height = 0.9
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(1.0, 0.55 + 0.04 * i, 0.15)
		var f := MeshInstance3D.new()
		f.mesh = cone
		f.material_override = m
		f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var a := float(i) * TAU / 9.0
		f.position = Vector3(cos(a), 0.45, sin(a)) * Vector3(radius * 0.6 * (0.4 + 0.6 * fmod(i * 0.37, 1.0)), 1.0, radius * 0.6 * (0.4 + 0.6 * fmod(i * 0.37, 1.0)))
		add_child(f)
		_flames.append(f)

func _process(delta: float) -> void:
	left -= delta
	var k := 0
	for f in _flames:
		f.scale.y = 0.6 + 0.5 * abs(sin(Time.get_ticks_msec() / 120.0 + k))
		k += 1
	_tick -= delta
	if _tick <= 0.0 and not (NetGame.is_client() and NetGame.in_match):
		_tick = 0.5
		for node in get_tree().get_nodes_in_group("units"):
			var u := node as BattleUnit
			var flat := u.global_position - global_position
			flat.y = 0.0
			if flat.length() <= radius and not BattleGrid.airborne(u.mover):
				u.take_hit(dps * 0.5, 0.0, -1)
	if left <= 0.0:
		queue_free()
