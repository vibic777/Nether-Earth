# Контрибьютор: vibic777
# Окружение: земля, вода, камни, деревья, горы, нейтральные дома, свет и небо.
class_name WorldArt
extends RefCounted

const B := ArtKit.Builder

static var _root: Node3D

static func build(grid: BattleGrid) -> void:
	var old := grid.get_node_or_null("WorldArtRoot")
	if old != null:
		grid.remove_child(old)
		old.queue_free()
	_root = Node3D.new()
	_root.name = "WorldArtRoot"
	grid.add_child(_root)
	_environment(grid)
	_ground(grid)
	_water(grid)
	_tufts(grid)
	_props(grid, BattleGrid.CellKind.STONE, _stone_variants(), 0.18)
	_props(grid, BattleGrid.CellKind.TREE, _tree_variants(), 0.18)
	_props(grid, BattleGrid.CellKind.MOUNTAIN, _mountain_variants(), 0.18)
	_houses(grid)

# То же, что build(), но по этапам: после каждого — отчёт экрану загрузки и кадр отрисовки.
static func build_staged(grid: BattleGrid, from: float, to: float) -> void:
	var old := grid.get_node_or_null("WorldArtRoot")
	if old != null:
		grid.remove_child(old)
		old.queue_free()
	_root = Node3D.new()
	_root.name = "WorldArtRoot"
	grid.add_child(_root)
	var tree := grid.get_tree()
	var steps := [
		["Небо и свет", func() -> void: _environment(grid)],
		["Генерация рельефа", func() -> void: _ground(grid)],
		["Вода", func() -> void: _water(grid)],
		["Трава", func() -> void: _tufts(grid)],
		["Камни", func() -> void: _props(grid, BattleGrid.CellKind.STONE, _stone_variants(), 0.18)],
		["Леса", func() -> void: _props(grid, BattleGrid.CellKind.TREE, _tree_variants(), 0.18)],
		["Горы", func() -> void: _props(grid, BattleGrid.CellKind.MOUNTAIN, _mountain_variants(), 0.18)],
		["Постройки", func() -> void: _houses(grid)],
	]
	for i in steps.size():
		await LoadingScreen.step(tree, lerpf(from, to, float(i) / steps.size()), str(steps[i][0]) + "…")
		(steps[i][1] as Callable).call()

const CHUNK := 16

static func _rnd(x: int, z: int, salt: int) -> float:
	return ArtKit.hash1(Vector3(x * 1.13 + salt * 7.1, salt * 0.31, z * 2.17))

static func _environment(grid: BattleGrid) -> void:
	var host := grid.get_parent()
	if host == null or host.get_node_or_null("WorldEnvironment") != null:
		return
	var env := Environment.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("3d6f9e")
	sky_mat.sky_horizon_color = Color("b9cbd6")
	sky_mat.ground_horizon_color = Color("8e9a88")
	sky_mat.ground_bottom_color = Color("39402f")
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.35
	env.glow_bloom = 0.04
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.08
	env.adjustment_contrast = 1.05
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	host.add_child.call_deferred(we)
	var sun := host.get_node_or_null("Sun")
	if sun is DirectionalLight3D:
		sun.light_color = Color("fff1dc")
		sun.light_energy = 1.0
		sun.shadow_enabled = true
		sun.shadow_blur = 1.5
		sun.directional_shadow_max_distance = 140.0

const _KIND_COLOR := {
	BattleGrid.CellKind.PLAIN: Color("5b7a3a"),
	BattleGrid.CellKind.STONE: Color("7d7a66"),
	BattleGrid.CellKind.TREE: Color("44602f"),
	BattleGrid.CellKind.WATER: Color("6b6346"),
	BattleGrid.CellKind.MOUNTAIN: Color("77736a"),
	BattleGrid.CellKind.BUILDING: Color("7d7a5c"),
	BattleGrid.CellKind.LINK: Color("7f7d74"),
}

static func _kind_color(grid: BattleGrid, x: int, z: int) -> Color:
	x = clampi(x, 0, BattleGrid.WIDTH - 1)
	z = clampi(z, 0, BattleGrid.HEIGHT - 1)
	return _KIND_COLOR[grid.kind_at(Vector2i(x, z))]

# Цвет почвы плавно смешан между клетками + пятна травы/земли + тон по уклону и высоте.
static func _soil(grid: BattleGrid, wx: float, wz: float, h: float, n: Vector3) -> Color:
	var t := BattleGrid.TILE
	var fx := wx / t - 0.5
	var fz := wz / t - 0.5
	var x0 := int(floor(fx))
	var z0 := int(floor(fz))
	var tx := fx - x0
	var tz := fz - z0
	tx = tx * tx * (3.0 - 2.0 * tx)
	tz = tz * tz * (3.0 - 2.0 * tz)
	var c := _kind_color(grid, x0, z0).lerp(_kind_color(grid, x0 + 1, z0), tx).lerp(
		_kind_color(grid, x0, z0 + 1).lerp(_kind_color(grid, x0 + 1, z0 + 1), tx), tz)
	var patch := 0.5 + 0.5 * sin(wx * 0.9 + 2.0 * sin(wz * 0.5)) * cos(wz * 0.7 - wx * 0.2)
	c = c.lerp(Color("7c8340"), patch * 0.28)
	c = c.lerp(Color("4d6a2c"), (1.0 - patch) * 0.18)
	var steep := 1.0 - n.y
	c = c.lerp(Color("7a6a50"), clampf(steep * 5.0, 0.0, 0.55))
	if h < 0.1:
		c = c.lerp(Color("b3a27a"), clampf((0.1 - h) * 8.0, 0.0, 1.0) * 0.7)
	if h < -0.05:
		c = c.lerp(Color("4f5a48"), clampf((-0.05 - h) * 4.0, 0.0, 1.0))
	var grain := ArtKit.hash1(Vector3(wx * 3.7, 0.0, wz * 3.7))
	return c * (0.95 + grain * 0.1)

static func _ground(grid: BattleGrid) -> void:
	var t := BattleGrid.TILE
	# Большие карты: чуть реже сетка рельефа, иначе сборка мира длится минуты.
	var sub := 5 if BattleGrid.WIDTH * BattleGrid.HEIGHT <= 6000 else 4
	var step := t / float(sub)
	# Рельеф кусками по CHUNK клеток: каждый кусок отсекается камерой и тенью отдельно.
	var mat := ArtKit.material(ArtKit.MATTE)
	for cz in range(0, BattleGrid.HEIGHT, CHUNK):
		for cx in range(0, BattleGrid.WIDTH, CHUNK):
			var x0 := cx * sub
			var z0 := cz * sub
			var nx := mini(CHUNK, BattleGrid.WIDTH - cx) * sub
			var nz := mini(CHUNK, BattleGrid.HEIGHT - cz) * sub
			var verts := PackedVector3Array()
			var norms := PackedVector3Array()
			var cols := PackedColorArray()
			for iz in nz + 1:
				for ix in nx + 1:
					var wx := (x0 + ix) * step
					var wz := (z0 + iz) * step
					var h := grid.terrain_y(wx, wz)
					var n := grid.terrain_normal(wx, wz)
					verts.append(Vector3(wx, h, wz))
					norms.append(n)
					cols.append(_soil(grid, wx, wz, h, n))
			var idx := PackedInt32Array()
			for iz in nz:
				for ix in nx:
					var a := iz * (nx + 1) + ix
					var b := a + 1
					var c := a + nx + 1
					var d := c + 1
					idx.append_array([a, b, c, b, d, c])
			var arrays := []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = verts
			arrays[Mesh.ARRAY_NORMAL] = norms
			arrays[Mesh.ARRAY_COLOR] = cols
			arrays[Mesh.ARRAY_INDEX] = idx
			var mesh := ArrayMesh.new()
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			mesh.surface_set_material(0, mat)
			var mi := ArtKit.node(mesh)
			mi.name = "Terrain_%d_%d" % [cx, cz]
			_root.add_child(mi)
	# Борт карты: земляной срез по краю
	var b := B.new()
	var w := BattleGrid.WIDTH * t
	var d := BattleGrid.HEIGHT * t
	b.box(Vector3(w + 0.4, 1.4, 0.2), Vector3(w * 0.5, -0.55, -0.1), Color("4a3d2c"))
	b.box(Vector3(w + 0.4, 1.4, 0.2), Vector3(w * 0.5, -0.55, d + 0.1), Color("4a3d2c"))
	b.box(Vector3(0.2, 1.4, d), Vector3(-0.1, -0.55, d * 0.5), Color("4a3d2c"))
	b.box(Vector3(0.2, 1.4, d), Vector3(w + 0.1, -0.55, d * 0.5), Color("4a3d2c"))
	b.box(Vector3(w, 0.1, d), Vector3(w * 0.5, -1.2, d * 0.5), Color("3a3024"))
	_root.add_child(ArtKit.node(b.commit()))

static func _water(grid: BattleGrid) -> void:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode blend_mix, cull_back, depth_draw_opaque, specular_schlick_ggx;
uniform vec4 deep : source_color = vec4(0.07, 0.29, 0.38, 0.82);
uniform vec4 shallow : source_color = vec4(0.22, 0.55, 0.6, 0.7);
uniform float waves = 1.0;
varying vec3 wpos;
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += (sin(wpos.x * 1.7 + TIME * 1.6) * 0.02 + cos(wpos.z * 2.1 + TIME * 1.2) * 0.015) * waves;
}
void fragment() {
	float r = sin(wpos.x * 3.0 + TIME * 2.0) * cos(wpos.z * 2.6 - TIME * 1.4);
	float s = smoothstep(0.85, 1.0, r);
	vec3 col = mix(deep.rgb, shallow.rgb, 0.35 + 0.25 * r);
	ALBEDO = col + vec3(s * 0.3);
	ALPHA = deep.a;
	ROUGHNESS = 0.08;
	SPECULAR = 0.8;
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	var t := BattleGrid.TILE
	# Одна плоскость воды на уровне 0.05: видна только там, где рельеф ниже (реки, берега).
	var minx := 9999
	var maxx := -1
	var minz := 9999
	var maxz := -1
	for z in BattleGrid.HEIGHT:
		for x in BattleGrid.WIDTH:
			if grid.kind_at(Vector2i(x, z)) == BattleGrid.CellKind.WATER:
				minx = mini(minx, x)
				maxx = maxi(maxx, x)
				minz = mini(minz, z)
				maxz = maxi(maxz, z)
	if maxx < 0:
		return
	var pm := PlaneMesh.new()
	var x0 := maxi(minx - 1, 0)
	var x1 := mini(maxx + 2, BattleGrid.WIDTH)
	var z0 := maxi(minz - 1, 0)
	var z1 := mini(maxz + 2, BattleGrid.HEIGHT)
	pm.size = Vector2((x1 - x0) * t, (z1 - z0) * t)
	pm.subdivide_width = 24
	pm.subdivide_depth = 40
	var mi := MeshInstance3D.new()
	mi.mesh = pm
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Vector3((x0 + x1) * 0.5 * t, 0.05, (z0 + z1) * 0.5 * t)
	mi.add_to_group("water")
	mi.name = "Water"
	mat.set_shader_parameter("waves", 1.0 if bool(Settings.get_value("graphics", "water_waves")) else 0.0)
	_root.add_child(mi)

static func _tufts(grid: BattleGrid) -> void:
	var b := B.new()
	var tuft := Color("6f8a45")
	for i in 5:
		var a := float(i) * TAU / 5.0
		b.cyl(0.0, 0.035, 0.22, Vector3(cos(a) * 0.05, 0.11, sin(a) * 0.05), tuft.lightened(0.06 * i), ArtKit.MATTE, Vector3(sin(a) * 0.35, 0, cos(a) * 0.35), 4)
	var tm := b.commit()
	var fb := B.new()
	fb.cyl(0.006, 0.006, 0.16, Vector3(0, 0.08, 0), Color("4d6b33"))
	fb.ball(0.035, Vector3(0, 0.17, 0), Color("e8d36a"), ArtKit.MATTE, Vector3.ONE, 6)
	var fm := fb.commit()
	var pb := B.new()
	pb.rock(0.07, Vector3(0, 0.02, 0), Color("8d8b82"), Vector3(1.2, 0.6, 1.0), 3)
	var pmesh := pb.commit()
	var t := BattleGrid.TILE
	# Трава разбита на чанки 16×16 клеток: на больших картах невидимые чанки отсекаются камерой.
	var chunks := {}
	for z in BattleGrid.HEIGHT:
		for x in BattleGrid.WIDTH:
			var kind := grid.kind_at(Vector2i(x, z))
			if kind != BattleGrid.CellKind.PLAIN and kind != BattleGrid.CellKind.TREE and kind != BattleGrid.CellKind.STONE:
				continue
			var key := Vector2i(x / 16, z / 16)
			if not chunks.has(key):
				chunks[key] = {tm: [], fm: [], pmesh: []}
			var spots: Dictionary = chunks[key]
			for k in 6:
				var r := _rnd(x, z, 20 + k)
				var px := (x + 0.08 + 0.84 * _rnd(x, z, 40 + k)) * t
				var pz := (z + 0.08 + 0.84 * _rnd(x, z, 60 + k)) * t
				var xf := Transform3D(Basis(Vector3.UP, r * TAU).scaled(Vector3.ONE * (0.7 + r * 0.7)), Vector3(px, grid.terrain_y(px, pz) - 0.02, pz))
				if grid.terrain_y(px, pz) < 0.1:
					continue
				if r < 0.55:
					spots[tm].append(xf)
				elif r < 0.62:
					spots[fm].append(xf)
				elif r < 0.72:
					spots[pmesh].append(xf)
	for key in chunks:
		var spots: Dictionary = chunks[key]
		for mesh in spots.keys():
			var node := _multi(grid, mesh, spots[mesh], false)
			if node != null:
				node.name = "Grass_%d" % node.get_instance_id()
			if node != null:
				node.add_to_group("grass")
				node.visible = bool(Settings.get_value("graphics", "grass"))

static func _multi(grid: BattleGrid, mesh: Mesh, xfs: Array, shadows: bool = true) -> MultiMeshInstance3D:
	if xfs.is_empty():
		return null
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
	var node := MultiMeshInstance3D.new()
	node.multimesh = mm
	if not shadows:
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_root.add_child(node)
	return node

static func _props(grid: BattleGrid, kind: int, variants: Array, lift: float) -> void:
	var buckets := {}            # (вариант, кусок) -> трансформы: отсечение по кускам
	var t := BattleGrid.TILE
	for z in BattleGrid.HEIGHT:
		for x in BattleGrid.WIDTH:
			if grid.kind_at(Vector2i(x, z)) != kind:
				continue
			var per := 1
			if kind == BattleGrid.CellKind.TREE:
				per = 3
			elif kind == BattleGrid.CellKind.STONE:
				per = 2
			for k in per:
				var pick := int(_rnd(x, z, 80 + k) * variants.size()) % variants.size()
				var spread := 0.0 if per == 1 else 0.48
				var ox := (_rnd(x, z, 90 + k) - 0.5) * spread * t
				var oz := (_rnd(x, z, 95 + k) - 0.5) * spread * t
				if per == 3:
					var a := float(k) * TAU / 3.0 + _rnd(x, z, 7)
					ox = cos(a) * 0.5
					oz = sin(a) * 0.5
				var s := 0.85 + 0.3 * _rnd(x, z, 100 + k)
				var basis := Basis(Vector3.UP, _rnd(x, z, 110 + k) * TAU).scaled(Vector3.ONE * s)
				var wx := (x + 0.5) * t + ox
				var wz := (z + 0.5) * t + oz
				var key := Vector3i(pick, x / CHUNK, z / CHUNK)
				if not buckets.has(key):
					buckets[key] = []
				buckets[key].append(Transform3D(basis, Vector3(wx, grid.terrain_y(wx, wz) + lift - 0.22, wz)))
	for key in buckets:
		var pn := _multi(grid, variants[key.x], buckets[key])
		if pn != null:
			pn.name = "Props_%d_%d_%d_%d" % [kind, key.x, key.y, key.z]

static func _stone_variants() -> Array:
	var out := []
	for v in 3:
		var b := B.new()
		var grey := Color("6e6b64").lerp(Color("7f7564"), v * 0.4)
		b.rock(0.42, Vector3(0, 0.22, 0), grey, Vector3(1.0, 0.75, 0.85), 11 + v)
		b.rock(0.24, Vector3(0.38, 0.12, 0.18), grey.darkened(0.08), Vector3(1.0, 0.7, 1.1), 21 + v)
		b.rock(0.16, Vector3(-0.3, 0.07, -0.28), grey.lightened(0.05), Vector3(1.0, 0.6, 1.0), 31 + v)
		b.rock(0.18, Vector3(0.05, 0.42, 0.0), Color("6f8a45"), Vector3(1.4, 0.18, 1.2), 41 + v, 0.15)
		out.append(b.commit())
	return out

static func _tree_variants() -> Array:
	var out := []
	var bark := Color("5c4330")
	# Ели
	for v in 2:
		var b := B.new()
		var h := 1.7 + v * 0.3
		b.cyl(0.05, 0.1, h * 0.5, Vector3(0, h * 0.25, 0), bark, ArtKit.MATTE, Vector3.ZERO, 7)
		var green := Color("2f5a34").lerp(Color("3d6b3a"), v)
		for i in 4:
			var r := 0.62 - i * 0.13
			var y := 0.38 + i * 0.36
			b.cyl(0.0, r, 0.62, Vector3(0, y + 0.31, 0), green.lightened(i * 0.04), ArtKit.MATTE, Vector3(0, i * 0.7, 0), 9)
		out.append(b.commit())
	# Лиственные
	for v in 2:
		var b := B.new()
		b.cyl(0.07, 0.13, 0.95, Vector3(0, 0.47, 0), bark, ArtKit.MATTE, Vector3.ZERO, 7)
		b.rod(Vector3(0, 0.7, 0), Vector3(0.28, 1.05, 0.1), 0.045, bark, ArtKit.MATTE, 5)
		b.rod(Vector3(0, 0.75, 0), Vector3(-0.22, 1.1, -0.15), 0.04, bark, ArtKit.MATTE, 5)
		var leaf := Color("4a7a3a").lerp(Color("6b8a35"), v)
		var blobs := [Vector3(0, 1.3, 0), Vector3(0.3, 1.15, 0.1), Vector3(-0.28, 1.2, -0.12), Vector3(0.05, 1.12, 0.32), Vector3(-0.05, 1.55, -0.05)]
		for i in blobs.size():
			b.rock(0.36 - i * 0.02, blobs[i], leaf.lightened(0.05 * (i % 3)), Vector3(1.0, 0.85, 1.0), 50 + v * 10 + i, 0.18)
		out.append(b.commit())
	return out

static func _mountain_variants() -> Array:
	var out := []
	for v in 3:
		var b := B.new()
		var rock := Color("7a7469").lerp(Color("6a6e72"), v * 0.5)
		b.rock(0.95, Vector3(0, 0.55, 0), rock, Vector3(1.05, 0.75, 1.0), 70 + v)
		b.rock(0.7, Vector3(0.1, 1.3, -0.05), rock.lightened(0.04), Vector3(0.9, 1.0, 0.85), 80 + v)
		b.rock(0.42, Vector3(0.0, 1.95, 0.0), rock.lightened(0.08), Vector3(0.8, 0.9, 0.75), 90 + v)
		b.rock(0.24, Vector3(0.0, 2.3, 0.0), Color("e8ecef"), Vector3(1.1, 0.5, 1.0), 95 + v, 0.2)
		b.rock(0.45, Vector3(0.65, 0.3, 0.4), rock.darkened(0.1), Vector3(1.0, 0.7, 1.0), 99 + v)
		b.rock(0.38, Vector3(-0.6, 0.25, -0.5), rock.darkened(0.05), Vector3(1.0, 0.6, 1.0), 103 + v)
		out.append(b.commit())
	return out

# Нейтральные дома: блок 2×2 клетки собираем в небольшой посёлок.
static func _houses(grid: BattleGrid) -> void:
	var t := BattleGrid.TILE
	var done := {}
	for z in BattleGrid.HEIGHT:
		for x in BattleGrid.WIDTH:
			var cell := Vector2i(x, z)
			if done.has(cell) or grid.kind_at(cell) != BattleGrid.CellKind.BUILDING:
				continue
			done[cell] = true
			var hx := (x + 0.5) * t
			var hz := (z + 0.5) * t
			var mi := ArtKit.node(_house_mesh(int(_rnd(x, z, 5) * 3.0)), Vector3(hx, grid.terrain_y(hx, hz) - 0.05, hz))
			mi.rotation.y = float(int(_rnd(x, z, 6) * 4.0)) * PI * 0.5
			_root.add_child(mi)

static var _house_cache := {}

static func _house_mesh(style: int) -> ArrayMesh:
	if not _house_cache.has(style):
		_house_cache[style] = _house_build(style)
	return _house_cache[style]

static func _house_build(style: int) -> ArrayMesh:
	var b := B.new()
	var walls: Color = [Color("c9b896"), Color("b7a68d"), Color("a9a49a")][style]
	var roof: Color = [Color("8a3e30"), Color("5d4a3c"), Color("4f5a63")][style]
	var trim := Color("e6dcc6")
	var w := 1.4
	var d := 1.2
	var h := 1.0
	b.box(Vector3(w + 0.1, 0.12, d + 0.1), Vector3(0, 0.06, 0), Color("7d7466"))
	b.box(Vector3(w, h, d), Vector3(0, 0.12 + h * 0.5, 0), walls)
	for cx in [-w * 0.5, w * 0.5]:
		for cz in [-d * 0.5, d * 0.5]:
			b.box(Vector3(0.07, h, 0.07), Vector3(cx, 0.12 + h * 0.5, cz), trim)
	# Двускатная крыша
	var rl := sqrt(pow(d * 0.5 + 0.12, 2) + 0.2)
	b.box(Vector3(w + 0.22, 0.07, rl), Vector3(0, 0.12 + h + 0.2, d * 0.25 + 0.03), roof, ArtKit.MATTE, Vector3(0.6, 0, 0))
	b.box(Vector3(w + 0.22, 0.07, rl), Vector3(0, 0.12 + h + 0.2, -d * 0.25 - 0.03), roof, ArtKit.MATTE, Vector3(-0.6, 0, 0))
	b.box(Vector3(w + 0.24, 0.06, 0.08), Vector3(0, 0.12 + h + 0.43, 0), roof.darkened(0.2))
	for sx in [-1.0, 1.0]:
		var g := PrismMesh.new()
		g.size = Vector3(d, 0.42, 0.02)
		b.add(g, Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(sx * w * 0.5, 0.12 + h + 0.21, 0)), walls.darkened(0.06))
	b.box(Vector3(0.16, 0.42, 0.16), Vector3(w * 0.28, 0.12 + h + 0.45, -d * 0.18), Color("8a7a6a"))
	# Окна и дверь
	for side in [-1.0, 1.0]:
		for i in 2:
			var wx := -0.38 + i * 0.76
			b.box(Vector3(0.28, 0.3, 0.03), Vector3(wx, 0.72, side * (d * 0.5 + 0.01)), Color("ffd88a") if (i + style) % 2 == 0 and side > 0 else Color("2c3a44"), ArtKit.GLASS)
			b.box(Vector3(0.34, 0.04, 0.05), Vector3(wx, 0.55, side * (d * 0.5 + 0.02)), trim)
	b.box(Vector3(0.3, 0.52, 0.03), Vector3(0, 0.38, d * 0.5 + 0.015), Color("5a3d28"))
	b.box(Vector3(0.44, 0.04, 0.24), Vector3(0, 0.66, d * 0.5 + 0.12), roof)
	# Двор: заборчик и бочка
	b.cyl(0.11, 0.11, 0.28, Vector3(-w * 0.5 - 0.18, 0.14, d * 0.5 + 0.1), Color("6a5236"), ArtKit.MATTE, Vector3.ZERO, 8)
	for i in 5:
		b.box(Vector3(0.04, 0.22, 0.04), Vector3(-0.8 + i * 0.4, 0.11, d * 0.5 + 0.55), Color("8a6a46"))
	b.box(Vector3(1.64, 0.035, 0.03), Vector3(0, 0.17, d * 0.5 + 0.55), Color("8a6a46"))
	return b.commit()
