# Контрибьютор: vibic777
# Метки приказов, которые плавно гаснут: следы ног, гусениц, лап шагохода, винт для авиации,
# голограмма оружия над целью атаки.
class_name OrderMarker
extends Node3D

const LIFE := 1.6
static var life_scale := 1.0

var style := "foot"
var tint := Color("8cf0ff")
var _age := 0.0
var _mat: StandardMaterial3D
var _spin: Node3D

static func spawn(parent: Node, at: Vector3, kind: String, color: Color = Color("8cf0ff"), yaw: float = 0.0) -> OrderMarker:
	var m := OrderMarker.new()
	m.style = kind
	m.tint = color
	parent.add_child(m)
	m.global_position = at
	m.rotation.y = yaw
	m.scale = Vector3.ONE * 1.4
	return m

static func style_for(mover: int) -> String:
	match mover:
		BattleGrid.Mover.TRACK:
			return "track"
		BattleGrid.Mover.WALKER:
			return "claw"
		BattleGrid.Mover.BIKE:
			return "wheel"
		BattleGrid.Mover.UAV, BattleGrid.Mover.JET, BattleGrid.Mover.ROTOR:
			return "air"
		_:
			return "foot"

func _ready() -> void:
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat.no_depth_test = style.begins_with("atk_")
	_mat.albedo_color = tint
	_mat.render_priority = 20
	var b := ArtKit.Builder.new()
	var w := Color.WHITE
	match style:
		"foot":
			for i in 3:
				for sx in [-1.0, 1.0]:
					var z := -0.5 + i * 0.4 + (0.2 if sx > 0 else 0.0)
					b.ball(0.07, Vector3(sx * 0.1, 0.02, z), w, ArtKit.MATTE, Vector3(0.8, 0.1, 1.5), 8)
					b.ball(0.05, Vector3(sx * 0.1, 0.02, z - 0.13), w, ArtKit.MATTE, Vector3(0.9, 0.1, 0.9), 8)
		"track":
			for sx in [-1.0, 1.0]:
				for i in 9:
					b.box(Vector3(0.24, 0.01, 0.06), Vector3(sx * 0.32, 0.02, -0.6 + i * 0.15), w)
		"wheel":
			b.box(Vector3(0.07, 0.01, 1.2), Vector3(0.0, 0.02, 0.0), w)
		"claw":
			for i in 2:
				var sx := -1.0 if i == 0 else 1.0
				var c := Vector3(sx * 0.3, 0.02, -0.3 + i * 0.6)
				for t in 3:
					var a := (t - 1) * 0.5
					b.box(Vector3(0.06, 0.01, 0.3), c + Vector3(sin(a) * 0.14, 0, cos(a) * 0.14), w, ArtKit.MATTE, Vector3(0, a, 0))
				b.box(Vector3(0.06, 0.01, 0.18), c + Vector3(0, 0, -0.14), w)
		"air":
			b.cyl(0.55, 0.55, 0.01, Vector3(0, 0.02, 0), w, ArtKit.MATTE, Vector3.ZERO, 24)
			b.cyl(0.48, 0.48, 0.012, Vector3(0, 0.021, 0), Color(0, 0, 0, 0), ArtKit.MATTE, Vector3.ZERO, 24)
			_spin = Node3D.new()
			var p := ArtKit.Builder.new()
			for k in 3:
				p.box(Vector3(0.07, 0.01, 0.42), Vector3(sin(k * TAU / 3.0) * 0.21, 0.05, cos(k * TAU / 3.0) * 0.21), w, ArtKit.MATTE, Vector3(0, k * TAU / 3.0, 0))
			p.cyl(0.05, 0.05, 0.03, Vector3(0, 0.05, 0), w)
			var pm := ArtKit.node(p.commit())
			pm.material_override = _mat
			_spin.add_child(pm)
			add_child(_spin)
		"atk_barrel", "atk_mg":
			b.cyl(0.06, 0.06, 0.9, Vector3(0, 1.4, 0), w, ArtKit.MATTE, Vector3(PI * 0.5, 0, 0), 10)
			b.cyl(0.1, 0.1, 0.18, Vector3(0, 1.4, 0.45), w, ArtKit.MATTE, Vector3(PI * 0.5, 0, 0), 10)
			b.box(Vector3(0.3, 0.2, 0.3), Vector3(0, 1.4, -0.45), w)
		"atk_rocket":
			b.cyl(0.08, 0.08, 0.6, Vector3(0, 1.4, 0), w, ArtKit.MATTE, Vector3(PI * 0.5, 0, 0), 10)
			b.cyl(0.0, 0.08, 0.22, Vector3(0, 1.4, 0.41), w, ArtKit.MATTE, Vector3(PI * 0.5, 0, 0), 10)
			for k in 4:
				b.box(Vector3(0.02, 0.18, 0.14), Vector3(0, 1.4, -0.26), w, ArtKit.MATTE, Vector3(0, 0, k * PI * 0.5))
		"atk_mortar", "atk_grenade":
			b.ball(0.16, Vector3(0, 1.4, 0), w, ArtKit.MATTE, Vector3(1, 1, 1.5), 10)
			b.cyl(0.05, 0.12, 0.2, Vector3(0, 1.4, -0.3), w, ArtKit.MATTE, Vector3(PI * 0.5, 0, 0), 8)
		"atk_bomb":
			b.ball(0.2, Vector3(0, 1.4, 0), w, ArtKit.MATTE, Vector3(1, 1.6, 1), 12)
			b.box(Vector3(0.3, 0.12, 0.02), Vector3(0, 1.75, 0), w)
		"atk_laser", "atk_ion", "atk_tesla", "atk_flame":
			b.cyl(0.03, 0.03, 1.2, Vector3(0, 1.4, 0), w, ArtKit.MATTE, Vector3(0, 0, 0), 8)
			for k in 3:
				b.box(Vector3(0.42, 0.03, 0.03), Vector3(0, 1.0 + k * 0.4, 0), w, ArtKit.MATTE, Vector3(0, k * 0.8, 0))
		"atk_point":
			b.cyl(0.5, 0.5, 0.01, Vector3(0, 0.03, 0), w, ArtKit.MATTE, Vector3.ZERO, 24)
			b.box(Vector3(1.3, 0.012, 0.05), Vector3(0, 0.04, 0), w)
			b.box(Vector3(0.05, 0.012, 1.3), Vector3(0, 0.04, 0), w)
	if style.begins_with("atk_") and style != "atk_point":
		b.cyl(0.42, 0.42, 0.01, Vector3(0, 0.05, 0), w, ArtKit.MATTE, Vector3.ZERO, 20)
		for k in 6:
			b.rod(Vector3(0, 0.05, 0), Vector3(cos(k) * 0.02, 1.0, sin(k) * 0.02), 0.006, w, ArtKit.MATTE, 4)
	var node := ArtKit.node(b.commit())
	node.material_override = _mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	if style.begins_with("atk_"):
		_spin = node

func _process(delta: float) -> void:
	_age += delta
	var t := _age / (LIFE * life_scale)
	if t >= 1.0:
		queue_free()
		return
	var pulse := 1.0
	if style.begins_with("atk_"):
		pulse = 0.75 + 0.25 * sin(_age * 18.0)
	_mat.albedo_color = Color(tint.r, tint.g, tint.b, (1.0 - t) * pulse)
	if _spin != null:
		_spin.rotate_y(delta * (14.0 if style == "air" else 2.5))
	if style == "atk_point":
		scale = Vector3.ONE * (1.0 + t * 0.4)
