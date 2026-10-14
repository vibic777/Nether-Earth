# Контрибьютор: vibic777
# Модели узлов сети: штаб, вышка, заводы, аэродром, добыча.
# accent — материал цвета владельца (зелёный/красный/песочный, мигает при сирене).
class_name SiteArt
extends RefCounted

const B := ArtKit.Builder
const CONCRETE := Color("9a978c")
const STEEL := Color("5d646b")
const DARK := Color("2f3438")
const RUST := Color("8a5a3a")

# Возвращает {"top": высота для подписи, "spin": Node3D или null}
static func build(site: Node3D, kind: int, wide_x: bool, two: bool, accent: Material) -> Dictionary:
	var b := B.new()
	var a := B.new()
	var spin_b: B = null
	var top := 2.0
	var spin_at := Vector3.ZERO
	match kind:
		SitePlan.KIND_HQ:
			top = _hq(b, a, two)
			spin_b = B.new()
			_dish(spin_b, 0.55)
			spin_at = Vector3(0.0, 2.25, -0.35)
		SitePlan.KIND_RELAY:
			top = _relay(b, a)
			spin_b = B.new()
			_dish(spin_b, 0.42)
			spin_at = Vector3(0.0, 3.05, 0.0)
		SitePlan.KIND_FACTORY:
			top = _factory(b, a, two)
		SitePlan.KIND_AIR:
			top = _airfield(b, a)
			spin_b = B.new()
			_dish(spin_b, 0.22)
			spin_at = Vector3(0.62, 2.0, -0.45)
		SitePlan.KIND_ROBOT:
			top = _workshop(b, a)
		SitePlan.KIND_EXTRACTOR:
			top = _extractor(b, a)
		_:
			top = InfraArt.build(b, a, kind)
	var holder := Node3D.new()
	holder.name = "Art"
	if wide_x:
		holder.rotation.y = PI * 0.5
	site.add_child(holder)
	holder.add_child(ArtKit.node(b.commit()))
	var accent_node := ArtKit.node(a.commit())
	accent_node.material_override = accent
	holder.add_child(accent_node)
	var spin: Node3D = null
	if spin_b != null:
		spin = ArtKit.node(spin_b.commit(), spin_at)
		holder.add_child(spin)
	return {"top": top, "spin": spin}

static func _plinth(b: B, w: float, d: float) -> void:
	b.box(Vector3(w, 0.16, d), Vector3(0, 0.28, 0), CONCRETE.darkened(0.1))
	b.box(Vector3(w - 0.12, 0.04, d - 0.12), Vector3(0, 0.38, 0), CONCRETE)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			b.box(Vector3(0.14, 0.05, 0.14), Vector3(sx * (w * 0.5 - 0.12), 0.42, sz * (d * 0.5 - 0.12)), Color("d6b04a"))

static func _dish(b: B, r: float) -> void:
	b.cyl(0.04, 0.06, 0.3, Vector3(0, 0.15, 0), STEEL, ArtKit.METAL)
	b.cyl(r, r * 0.25, r * 0.35, Vector3(0, 0.38, 0.05), Color("d8dcdf"), ArtKit.METAL, Vector3(-1.0, 0, 0), 16)
	b.rod(Vector3(0, 0.38, 0.1), Vector3(0, 0.62, r * 0.9), 0.015, DARK)
	b.ball(0.035, Vector3(0, 0.63, r * 0.92), Color("ff6a4a"), ArtKit.GLOW)

static func _windows(b: B, count: int, span: float, y: float, z: float, h: float = 0.16) -> void:
	for i in count:
		var x := -span * 0.5 + span * (float(i) + 0.5) / float(count)
		b.box(Vector3(span / count * 0.6, h, 0.03), Vector3(x, y, z), Color("9fd4ea"), ArtKit.GLASS)

static func _hq(b: B, a: B, two: bool) -> float:
	var d := 3.4 if two else 1.7
	_plinth(b, 1.85, d)
	# Бронированный корпус со скосами
	b.box(Vector3(1.5, 0.9, d - 0.5), Vector3(0, 0.85, 0), Color("6f756d"))
	b.box(Vector3(1.62, 0.12, d - 0.38), Vector3(0, 0.44, 0), DARK)
	for sx in [-1.0, 1.0]:
		b.box(Vector3(0.14, 0.8, d - 0.55), Vector3(sx * 0.78, 0.8, 0), Color("5f655e"), ArtKit.MATTE, Vector3(0, 0, sx * 0.22))
	b.box(Vector3(1.1, 0.5, 1.0), Vector3(0, 1.55, 0.25), Color("7c8278"))
	b.box(Vector3(1.0, 0.16, 0.04), Vector3(0, 1.62, 0.76), Color("9fd4ea"), ArtKit.GLASS)
	_windows(b, 4, 1.2, 1.0, d * 0.5 - 0.24)
	b.box(Vector3(0.5, 0.55, 0.05), Vector3(0, 0.72, d * 0.5 - 0.24), DARK)
	# Антенны
	b.rod(Vector3(0.4, 1.8, 0.5), Vector3(0.4, 2.9, 0.5), 0.025, STEEL)
	b.rod(Vector3(-0.42, 1.8, 0.55), Vector3(-0.42, 2.5, 0.55), 0.02, STEEL)
	b.ball(0.05, Vector3(0.4, 2.92, 0.5), Color("ff5040"), ArtKit.GLOW)
	b.box(Vector3(0.5, 0.25, 0.5), Vector3(0, 1.95, -0.35), STEEL, ArtKit.METAL)
	# Цвет владельца: полосы и флаг
	a.box(Vector3(1.53, 0.1, d - 0.47), Vector3(0, 1.22, 0), Color.WHITE)
	a.box(Vector3(1.13, 0.06, 1.03), Vector3(0, 1.82, 0.25), Color.WHITE)
	a.box(Vector3(0.36, 0.22, 0.02), Vector3(-0.24, 2.4, 0.55), Color.WHITE)
	if two:
		for sz in [-1.0, 1.0]:
			b.cyl(0.18, 0.2, 0.5, Vector3(0.5, 1.55, sz * 1.1), Color("8c9088"), ArtKit.METAL, Vector3.ZERO, 12)
			b.cyl(0.21, 0.21, 0.05, Vector3(0.5, 1.81, sz * 1.1), DARK)
	return 3.2

static func _relay(b: B, a: B) -> float:
	_plinth(b, 1.4, 1.4)
	var h := 2.8
	var base := 0.5
	var top := 0.14
	var legs := [Vector3(-1, 0, -1), Vector3(1, 0, -1), Vector3(1, 0, 1), Vector3(-1, 0, 1)]
	for i in 4:
		var l: Vector3 = legs[i]
		b.rod(l * base + Vector3(0, 0.4, 0), l * top + Vector3(0, 0.4 + h, 0), 0.035, STEEL)
		var n: Vector3 = legs[(i + 1) % 4]
		for k in 5:
			var t0 := float(k) / 5.0
			var t1 := float(k + 1) / 5.0
			var p0 := l * lerpf(base, top, t0) + Vector3(0, 0.4 + h * t0, 0)
			var q1 := n * lerpf(base, top, t1) + Vector3(0, 0.4 + h * t1, 0)
			b.rod(p0, q1, 0.012, STEEL)
	b.box(Vector3(0.5, 0.06, 0.5), Vector3(0, 0.4 + h, 0), DARK)
	b.box(Vector3(0.5, 0.45, 0.4), Vector3(0.38, 0.62, 0.35), Color("777d76"))
	a.box(Vector3(0.52, 0.08, 0.42), Vector3(0.38, 0.8, 0.35), Color.WHITE)
	for k in 3:
		a.box(Vector3(0.1, 0.1, 0.1), Vector3(0, 1.2 + k * 0.7, 0) + Vector3(lerpf(base, top, (0.8 + k * 0.7) / h), 0, lerpf(base, top, (0.8 + k * 0.7) / h)), Color.WHITE)
	b.ball(0.06, Vector3(0, 3.8, 0), Color("ff5040"), ArtKit.GLOW)
	b.rod(Vector3(0, 3.2, 0), Vector3(0, 3.78, 0), 0.015, STEEL)
	return 4.1

static func _factory(b: B, a: B, two: bool) -> float:
	var d := 3.4 if two else 1.7
	_plinth(b, 1.85, d)
	# Цех с полукруглой крышей
	b.box(Vector3(1.6, 0.85, d - 0.3), Vector3(0, 0.82, 0), Color("8b8e86"))
	var roof := CylinderMesh.new()
	roof.top_radius = 0.8
	roof.bottom_radius = 0.8
	roof.height = d - 0.25
	roof.radial_segments = 16
	b.add(roof, Transform3D(Basis.from_euler(Vector3(PI * 0.5, 0, 0)).scaled(Vector3(1, 1, 0.45)), Vector3(0, 1.24, 0)), Color("6a7378"), ArtKit.METAL)
	for k in int(d / 0.4):
		b.box(Vector3(1.66, 0.03, 0.03), Vector3(0, 1.26, -d * 0.5 + 0.3 + k * 0.4), DARK, ArtKit.METAL)
	# Ворота с жёлто-чёрной разметкой
	b.box(Vector3(1.0, 0.7, 0.04), Vector3(0, 0.75, d * 0.5 - 0.13), Color("3b3f42"), ArtKit.METAL)
	for k in 5:
		b.box(Vector3(0.18, 0.07, 0.05), Vector3(-0.4 + k * 0.2, 1.14, d * 0.5 - 0.12), Color("e0b23a") if k % 2 == 0 else DARK)
	_windows(b, 5, 1.4, 1.05, -d * 0.5 + 0.14, 0.12)
	# Трубы
	for i in (2 if two else 1):
		var z := -d * 0.5 + 0.5 + i * 1.3
		b.cyl(0.12, 0.15, 1.5, Vector3(0.62, 1.6, z), Color("8a6a52"), ArtKit.METAL)
		b.cyl(0.14, 0.14, 0.1, Vector3(0.62, 2.35, z), DARK)
		a.cyl(0.155, 0.155, 0.12, Vector3(0.62, 2.0, z), Color.WHITE)
	a.box(Vector3(1.63, 0.1, d - 0.27), Vector3(0, 1.2, 0), Color.WHITE)
	return 2.9

static func _airfield(b: B, a: B) -> float:
	_plinth(b, 1.85, 1.85)
	# Посадочная площадка с разметкой «H»
	b.cyl(0.62, 0.62, 0.05, Vector3(-0.3, 0.43, 0.3), Color("4a4f52"), ArtKit.MATTE, Vector3.ZERO, 20)
	b.box(Vector3(0.08, 0.02, 0.5), Vector3(-0.47, 0.46, 0.3), Color("eeeeee"))
	b.box(Vector3(0.08, 0.02, 0.5), Vector3(-0.13, 0.46, 0.3), Color("eeeeee"))
	b.box(Vector3(0.34, 0.02, 0.07), Vector3(-0.3, 0.46, 0.3), Color("eeeeee"))
	for k in 8:
		var ang := k * TAU / 8.0
		b.ball(0.03, Vector3(-0.3 + cos(ang) * 0.58, 0.47, 0.3 + sin(ang) * 0.58), Color("ffcf5a"), ArtKit.GLOW)
	# Диспетчерская вышка
	b.cyl(0.14, 0.18, 1.2, Vector3(0.62, 1.0, -0.45), Color("a0a39b"))
	b.cyl(0.32, 0.24, 0.32, Vector3(0.62, 1.75, -0.45), Color("8fc7de"), ArtKit.GLASS, Vector3.ZERO, 8)
	b.cyl(0.36, 0.36, 0.06, Vector3(0.62, 1.94, -0.45), DARK, ArtKit.MATTE, Vector3.ZERO, 8)
	a.cyl(0.185, 0.185, 0.12, Vector3(0.62, 1.2, -0.45), Color.WHITE)
	# Ангар
	b.box(Vector3(0.75, 0.55, 0.8), Vector3(-0.42, 0.68, -0.48), Color("8b8e86"))
	b.box(Vector3(0.8, 0.06, 0.86), Vector3(-0.42, 0.98, -0.48), Color("5f676d"), ArtKit.METAL)
	a.box(Vector3(0.77, 0.08, 0.82), Vector3(-0.42, 0.88, -0.48), Color.WHITE)
	# Ветроуказатель
	b.rod(Vector3(0.7, 0.4, 0.6), Vector3(0.7, 1.1, 0.6), 0.015, STEEL)
	b.cyl(0.03, 0.07, 0.3, Vector3(0.7, 1.06, 0.75), Color("ff7a30"), ArtKit.MATTE, Vector3(PI * 0.5, 0, 0), 8)
	return 2.6

static func _workshop(b: B, a: B) -> float:
	_plinth(b, 1.85, 1.85)
	b.box(Vector3(1.2, 0.75, 1.2), Vector3(-0.15, 0.77, -0.1), Color("8b867a"))
	b.box(Vector3(1.28, 0.08, 1.28), Vector3(-0.15, 1.18, -0.1), Color("5a5f63"), ArtKit.METAL)
	for k in 3:
		b.box(Vector3(0.36, 0.12, 0.36), Vector3(-0.5 + k * 0.4, 1.28, -0.1), Color("7a8288"), ArtKit.METAL, Vector3(0.0, 0, 0.35))
	b.box(Vector3(0.6, 0.5, 0.04), Vector3(-0.15, 0.65, 0.51), DARK, ArtKit.METAL)
	a.box(Vector3(1.23, 0.1, 1.23), Vector3(-0.15, 1.05, -0.1), Color.WHITE)
	# Кран
	b.box(Vector3(0.12, 1.6, 0.12), Vector3(0.7, 1.2, 0.6), Color("d9a83a"), ArtKit.METAL)
	b.box(Vector3(0.1, 0.1, 1.1), Vector3(0.7, 1.95, 0.15), Color("d9a83a"), ArtKit.METAL)
	b.rod(Vector3(0.7, 1.9, -0.25), Vector3(0.7, 1.4, -0.25), 0.008, DARK)
	b.box(Vector3(0.14, 0.1, 0.14), Vector3(0.7, 1.36, -0.25), DARK, ArtKit.METAL)
	# Ящики с деталями
	b.box(Vector3(0.24, 0.2, 0.24), Vector3(0.55, 0.5, -0.65), Color("6b5a3a"))
	b.box(Vector3(0.2, 0.18, 0.2), Vector3(0.62, 0.69, -0.62), Color("7a6a46"), ArtKit.MATTE, Vector3(0, 0.4, 0))
	return 2.5

static func _extractor(b: B, a: B) -> float:
	_plinth(b, 1.5, 1.5)
	# Буровая вышка над шахтой
	b.cyl(0.42, 0.48, 0.3, Vector3(0, 0.55, 0), Color("6d6a62"), ArtKit.MATTE, Vector3.ZERO, 14)
	b.cyl(0.3, 0.3, 0.05, Vector3(0, 0.72, 0), Color("1c1d1e"), ArtKit.MATTE, Vector3.ZERO, 14)
	for l in [Vector3(-1, 0, -1), Vector3(1, 0, -1), Vector3(1, 0, 1), Vector3(-1, 0, 1)]:
		b.rod(l * 0.42 + Vector3(0, 0.4, 0), Vector3(0, 1.85, 0), 0.03, RUST)
	b.rod(Vector3(0, 0.6, 0), Vector3(0, 1.75, 0), 0.05, STEEL)
	b.box(Vector3(0.2, 0.14, 0.2), Vector3(0, 1.88, 0), DARK, ArtKit.METAL)
	# Насос и бункер
	b.box(Vector3(0.4, 0.34, 0.3), Vector3(0.45, 0.57, 0.48), Color("8a8e86"))
	b.cyl(0.08, 0.08, 0.5, Vector3(0.45, 0.6, 0.12), STEEL, ArtKit.METAL, Vector3(PI * 0.5, 0, 0))
	a.box(Vector3(0.42, 0.08, 0.32), Vector3(0.45, 0.78, 0.48), Color.WHITE)
	a.cyl(0.5, 0.5, 0.06, Vector3(0, 0.46, 0), Color.WHITE, ArtKit.MATTE, Vector3.ZERO, 14)
	b.rock(0.18, Vector3(-0.5, 0.48, 0.45), Color("8a7a5a"), Vector3(1.2, 0.6, 1.0), 7)
	b.rock(0.12, Vector3(-0.35, 0.45, 0.58), Color("b8963a"), Vector3(1.0, 0.7, 1.0), 9)
	return 2.3
