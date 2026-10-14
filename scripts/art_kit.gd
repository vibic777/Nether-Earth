# Контрибьютор: vibic777
# Процедурный арт: сборка деталей в один ArrayMesh с цветами вершин.
# Без внешних ассетов. Правила — docs/ART.md.
class_name ArtKit
extends RefCounted

const MATTE := "matte"
const METAL := "metal"
const GLOW := "glow"
const GLASS := "glass"

static var _mats := {}

class Builder:
	var _sets := {}

	func _bucket(kind: String) -> Dictionary:
		if not _sets.has(kind):
			_sets[kind] = {"v": PackedVector3Array(), "n": PackedVector3Array(), "c": PackedColorArray()}
		return _sets[kind]

	# Добавить примитив. flat=true даёт гранёный вид (камни, скалы), jitter — смещение вершин.
	func add(mesh: PrimitiveMesh, xf: Transform3D, color: Color, kind: String = ArtKit.MATTE, flat: bool = false, jitter: float = 0.0, seed: int = 0) -> void:
		var arrays := mesh.get_mesh_arrays()
		var src_v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var src_n: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var src_i: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		if jitter > 0.0:
			var moved := PackedVector3Array()
			moved.resize(src_v.size())
			for i in src_v.size():
				var p := src_v[i]
				moved[i] = p + ArtKit.noise3(p * 3.1 + Vector3(seed, seed * 0.37, seed * 1.7)) * jitter
			src_v = moved
		var b := _bucket(kind)
		var nb := xf.basis.inverse().transposed()
		var count := src_i.size() if src_i.size() > 0 else src_v.size()
		var tri := 0
		while tri + 2 < count:
			var ia := src_i[tri] if src_i.size() > 0 else tri
			var ib := src_i[tri + 1] if src_i.size() > 0 else tri + 1
			var ic := src_i[tri + 2] if src_i.size() > 0 else tri + 2
			var a := xf * src_v[ia]
			var bb := xf * src_v[ib]
			var c := xf * src_v[ic]
			var fn := (c - a).cross(bb - a).normalized()
			for pair in [[a, ia], [bb, ib], [c, ic]]:
				b["v"].append(pair[0])
				if flat or jitter > 0.0:
					b["n"].append(fn)
				else:
					b["n"].append((nb * src_n[pair[1]]).normalized())
				var shade := 1.0
				if flat:
					shade = 0.92 + 0.16 * ArtKit.hash1(pair[0] * 5.3)
				b["c"].append(Color(color.r * shade, color.g * shade, color.b * shade, color.a))
			tri += 3

	func box(size: Vector3, at: Vector3, color: Color, kind: String = ArtKit.MATTE, rot: Vector3 = Vector3.ZERO) -> void:
		var m := BoxMesh.new()
		m.size = size
		add(m, Transform3D(Basis.from_euler(rot), at), color, kind)

	func cyl(r_top: float, r_bottom: float, h: float, at: Vector3, color: Color, kind: String = ArtKit.MATTE, rot: Vector3 = Vector3.ZERO, seg: int = 12) -> void:
		var m := CylinderMesh.new()
		m.top_radius = r_top
		m.bottom_radius = r_bottom
		m.height = h
		m.radial_segments = seg
		m.rings = 1
		add(m, Transform3D(Basis.from_euler(rot), at), color, kind)

	func ball(r: float, at: Vector3, color: Color, kind: String = ArtKit.MATTE, squash: Vector3 = Vector3.ONE, seg: int = 12) -> void:
		var m := SphereMesh.new()
		m.radius = r
		m.height = r * 2.0
		m.radial_segments = seg
		m.rings = maxi(4, seg / 2)
		add(m, Transform3D(Basis.from_scale(squash), at), color, kind)

	# Труба между двумя точками.
	func rod(a: Vector3, b: Vector3, r: float, color: Color, kind: String = ArtKit.METAL, seg: int = 8) -> void:
		var len := maxf(a.distance_to(b), 0.01)
		var up := (b - a) / len
		var side := up.cross(Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.95 else Vector3.RIGHT).normalized()
		var fwd := side.cross(up).normalized()
		var m := CylinderMesh.new()
		m.top_radius = r
		m.bottom_radius = r
		m.height = len
		m.radial_segments = seg
		m.rings = 1
		add(m, Transform3D(Basis(side, up, fwd), (a + b) * 0.5), color, kind)

	func rock(r: float, at: Vector3, color: Color, squash: Vector3, seed: int, rough: float = 0.28) -> void:
		var m := SphereMesh.new()
		m.radius = r
		m.height = r * 2.0
		m.radial_segments = 9
		m.rings = 5
		var basis := Basis(Vector3.UP, float(seed) * 1.37).scaled(squash)
		add(m, Transform3D(basis, at), color, ArtKit.MATTE, true, r * rough, seed)

	# Плоская деталь по контуру (точки в плоскости XZ, выпуклый контур), толщина по Y.
	func plate(points: PackedVector2Array, y: float, thick: float, color: Color, kind: String = ArtKit.METAL) -> void:
		var b := _bucket(kind)
		var n := points.size()
		var top := y + thick * 0.5
		var bot := y - thick * 0.5
		for i in range(1, n - 1):
			for tri in [[0, i + 1, i, top, Vector3.UP], [0, i, i + 1, top, Vector3.UP], [0, i, i + 1, bot, Vector3.DOWN], [0, i + 1, i, bot, Vector3.DOWN]]:
				for k in 3:
					var pt: Vector2 = points[tri[k]]
					b["v"].append(Vector3(pt.x, tri[3], pt.y))
					b["n"].append(tri[4])
					b["c"].append(color if tri[3] == top else color.darkened(0.25))
		for i in n:
			var a2: Vector2 = points[i]
			var c2: Vector2 = points[(i + 1) % n]
			var nrm := Vector3(c2.y - a2.y, 0.0, -(c2.x - a2.x)).normalized()
			var quad := [Vector3(a2.x, top, a2.y), Vector3(c2.x, top, c2.y), Vector3(c2.x, bot, c2.y), Vector3(a2.x, bot, a2.y)]
			for idx in [0, 1, 2, 0, 2, 3, 0, 2, 1, 0, 3, 2]:
				b["v"].append(quad[idx])
				b["n"].append(nrm)
				b["c"].append(color.darkened(0.12))

	func commit() -> ArrayMesh:
		var mesh := ArrayMesh.new()
		for kind in _sets.keys():
			var b: Dictionary = _sets[kind]
			if b["v"].size() == 0:
				continue
			var arrays := []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = b["v"]
			arrays[Mesh.ARRAY_NORMAL] = b["n"]
			arrays[Mesh.ARRAY_COLOR] = b["c"]
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			mesh.surface_set_material(mesh.get_surface_count() - 1, ArtKit.material(kind))
		return mesh

static func material(kind: String) -> StandardMaterial3D:
	if _mats.has(kind):
		return _mats[kind]
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	match kind:
		METAL:
			m.metallic = 0.55
			m.roughness = 0.42
		GLOW:
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		GLASS:
			m.metallic = 0.3
			m.roughness = 0.08
			m.metallic_specular = 0.9
		_:
			m.roughness = 0.86
	_mats[kind] = m
	return m

static func hash1(p: Vector3) -> float:
	var h := sin(p.dot(Vector3(12.9898, 78.233, 37.719))) * 43758.5453
	return h - floor(h)

static func noise3(p: Vector3) -> Vector3:
	return Vector3(hash1(p) - 0.5, hash1(p + Vector3(5.2, 1.3, 7.7)) - 0.5, hash1(p + Vector3(2.9, 8.1, 3.3)) - 0.5) * 2.0

static func node(mesh: Mesh, at: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.mesh = mesh
	n.position = at
	return n
