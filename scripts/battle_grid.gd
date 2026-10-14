# Контрибьютор: vibic777
class_name BattleGrid
extends Node3D

enum CellKind { PLAIN, STONE, TREE, WATER, MOUNTAIN, BUILDING, LINK }
enum Mover { WALKER, UAV, ROTOR, TRACK, BIKE, TROOPER, ENGINEER, JET,
	OIL_TRUCK, GAS_TRUCK, URANIUM_TRUCK, COAL_TRUCK, PIPE,
	SUB, CRUISER, BOAT,
	SEMI, BUS, TRACTOR,
	T_MG, T_CANNON, T_MISSILE, T_LASER, T_ION, T_TESLA, WALL, GATE }

# Неподвижные постройки-«юниты»: трубы, турели, стены, ворота.
static func is_static(mover: int) -> bool:
	return mover == Mover.PIPE or mover >= Mover.T_MG

static func is_turret(mover: int) -> bool:
	return mover >= Mover.T_MG and mover <= Mover.T_TESLA

static func naval(mover: int) -> bool:
	return mover == Mover.SUB or mover == Mover.CRUISER or mover == Mover.BOAT

static func truck(mover: int) -> bool:
	return mover >= Mover.OIL_TRUCK and mover <= Mover.COAL_TRUCK

static func deployable(mover: int) -> bool:
	return mover == Mover.SEMI or mover == Mover.BUS or mover == Mover.TRACTOR

# Стены и закрытые ворота: клетка занята для наземных (см. blocked_for).
var walls := {}   # Vector2i -> BattleUnit (WALL/GATE)

# Самолёты (БПЛА, штурмовик): летят над всем, кружат, держат горизонт.
static func fixed_wing(mover: int) -> bool:
	return mover == Mover.UAV or mover == Mover.JET

static func airborne(mover: int) -> bool:
	return fixed_wing(mover) or mover == Mover.ROTOR

const TILE := 2.0
static var WIDTH := 48
static var HEIGHT := 14

const _TOP := {
	CellKind.PLAIN: 0.2,
	CellKind.STONE: 0.75,
	CellKind.TREE: 1.95,
	CellKind.WATER: 0.1,
	CellKind.MOUNTAIN: 2.3,
	CellKind.BUILDING: 1.68,
	CellKind.LINK: 2.4,
}

static var staged := false   # true — мир строится по этапам (экран загрузки)
var cells := PackedInt32Array()
var version := 0           # растёт при любой смене проходимости (карта, стены)
var hovered := Vector2i(-1, -1)

var _highlight: MeshInstance3D

func _ready() -> void:
	MatchSetup.ensure()
	var m := MapData.current()
	var dims := MapData.size_of(m)
	WIDTH = dims.x
	HEIGHT = dims.y
	cells.resize(WIDTH * HEIGHT)
	_paint_map(m)
	if staged:
		set_process(false)
		return   # мир строит boot.gd по этапам под экраном загрузки
	WorldArt.build(self)
	_build_highlight()

func finish_staged() -> void:
	_build_highlight()
	set_process(true)

func _process(_delta: float) -> void:
	var cell := _cell_under_pointer()
	hovered = cell
	_highlight.visible = false  # подсветка клетки отключена
	if cell.x < 0:
		return
	var c := cell_center(cell)
	_highlight.position = Vector3(c.x, terrain_y(c.x, c.z) + 0.06, c.z)

func start_focus() -> Vector3:
	var m := MapData.current()
	for st in m.get("starts", []):
		if MatchSetup.side_at_start(int(st.get("index", 0))) == SitePlan.OWNER_PLAYER:
			var c := cell_center(MapData.cell(st["terminal"]))
			if m.get("id", "") == "classic":
				return Vector3(16.0, 0.0, HEIGHT * TILE * 0.5)
			return c
	return Vector3(WIDTH * TILE * 0.5, 0.0, HEIGHT * TILE * 0.5)

func contains(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < WIDTH and cell.y < HEIGHT

func kind_at(cell: Vector2i) -> int:
	return cells[cell.y * WIDTH + cell.x]

func kind_name(kind: int) -> String:
	return GameData.terrain(kind, "name", _d_kind_name(kind))

func _d_kind_name(kind: int) -> String:
	match kind:
		CellKind.PLAIN:
			return "равнина"
		CellKind.STONE:
			return "камни"
		CellKind.TREE:
			return "деревья"
		CellKind.WATER:
			return "вода"
		CellKind.MOUNTAIN:
			return "гора"
		CellKind.BUILDING:
			return "здание"
		CellKind.LINK:
			return "узел"
		_:
			return ""

func cell_from_world(world: Vector3) -> Vector2i:
	return Vector2i(floori(world.x / TILE), floori(world.z / TILE))

func blocks_fire(start: Vector3, finish: Vector3) -> bool:
	var span := start.distance_to(finish)
	var steps := maxi(1, int(span / TILE))
	for step in range(1, steps):
		var point := start.lerp(finish, float(step) / float(steps))
		var cell := cell_from_world(point)
		if not contains(cell):
			continue
		var kind := kind_at(cell)
		if kind == CellKind.MOUNTAIN or kind == CellKind.BUILDING or kind == CellKind.LINK:
			return true
	return false

func cell_center(cell: Vector2i) -> Vector3:
	return Vector3((cell.x + 0.5) * TILE, 0.0, (cell.y + 0.5) * TILE)

func can_enter(cell: Vector2i, mover: int) -> bool:
	if not contains(cell):
		return false
	var kind := kind_at(cell)
	if naval(mover):
		return kind == CellKind.WATER
	if not airborne(mover) and walls.has(cell):
		var w = walls[cell]
		if not is_instance_valid(w):
			walls.erase(cell)
		elif w.mover == Mover.WALL:
			return false
	match kind:
		CellKind.PLAIN:
			return true
		CellKind.STONE:
			return mover == Mover.WALKER or mover == Mover.TROOPER or mover == Mover.ENGINEER or airborne(mover)
		CellKind.TREE:
			return mover == Mover.TROOPER or mover == Mover.ENGINEER or airborne(mover)
		CellKind.WATER:
			return airborne(mover)
		CellKind.MOUNTAIN, CellKind.BUILDING, CellKind.LINK:
			return fixed_wing(mover)
		_:
			return false

# Ворота: закрыты ли для стороны (ручной режим — для всех, авто — только для врагов).
func blocked_for(cell: Vector2i, side: int) -> bool:
	if not walls.has(cell):
		return false
	var w = walls[cell]
	if not is_instance_valid(w):
		walls.erase(cell)
		return false
	if w.mover == Mover.WALL:
		return true
	return w.gate_closed_for(side)

func ride_height(cell: Vector2i, mover: int) -> float:
	if not contains(cell):
		return 0.22
	if naval(mover):
		return 0.02 if mover != Mover.SUB else -0.12
	if mover == Mover.JET:
		return 6.6
	if mover == Mover.UAV:
		return 5.2
	if mover == Mover.ROTOR:
		return 2.6
	var c := cell_center(cell)
	return height_at(c.x, c.z) + 0.02

# --- Рельеф. Сетка остаётся только логикой; поверхность сплошная и неровная. ---
const _LIFT := {
	CellKind.PLAIN: 0.0, CellKind.STONE: 0.32, CellKind.TREE: 0.12, CellKind.WATER: -0.5,
	CellKind.MOUNTAIN: 0.75, CellKind.BUILDING: 0.0, CellKind.LINK: 0.0,
}
const _ROUGH := {
	CellKind.PLAIN: 1.0, CellKind.STONE: 1.4, CellKind.TREE: 1.1, CellKind.WATER: 0.3,
	CellKind.MOUNTAIN: 1.8, CellKind.BUILDING: 0.1, CellKind.LINK: 0.0,
}
const BASE_Y := 0.2

func _cell_value(x: int, z: int, table: Dictionary) -> float:
	x = clampi(x, 0, WIDTH - 1)
	z = clampi(z, 0, HEIGHT - 1)
	var kind := cells[z * WIDTH + x]
	var field := "lift" if table == _LIFT else "rough"
	return GameData.terrain(kind, field, float(table[kind]))

# Плавная интерполяция значения клетки между центрами клеток (smoothstep), без ступенек.
func _field(wx: float, wz: float, table: Dictionary) -> float:
	var fx := wx / TILE - 0.5
	var fz := wz / TILE - 0.5
	var x0 := int(floor(fx))
	var z0 := int(floor(fz))
	var tx := fx - x0
	var tz := fz - z0
	tx = tx * tx * (3.0 - 2.0 * tx)
	tz = tz * tz * (3.0 - 2.0 * tz)
	var a := lerpf(_cell_value(x0, z0, table), _cell_value(x0 + 1, z0, table), tx)
	var b := lerpf(_cell_value(x0, z0 + 1, table), _cell_value(x0 + 1, z0 + 1, table), tx)
	return lerpf(a, b, tz)

static func _hills(x: float, z: float) -> float:
	return 0.16 * sin(x * 0.31 + 1.3) * cos(z * 0.27 - 0.4) \
		+ 0.09 * sin(x * 0.83 + z * 0.41) \
		+ 0.05 * cos(x * 1.7 - z * 1.3 + 2.0) \
		+ 0.025 * sin(x * 3.1 + z * 2.7)

func terrain_y(wx: float, wz: float) -> float:
	return BASE_Y + _field(wx, wz, _LIFT) + (_hills(wx, wz) + 0.15) * _field(wx, wz, _ROUGH)

# Быстрая высота для юнитов: кэш точных значений рельефа с шагом TILE/4 и билинейная интерполяция.
const _HS := 4
var _hcache := PackedFloat32Array()
var _hver := -1
var _hw := 0

func _hsample(ix: int, iz: int) -> float:
	var i := iz * _hw + ix
	var v := _hcache[i]
	if is_nan(v):
		v = terrain_y(float(ix) * TILE / _HS, float(iz) * TILE / _HS)
		_hcache[i] = v
	return v

func height_at(wx: float, wz: float) -> float:
	if _hver != version:
		_hver = version
		_hw = WIDTH * _HS + 2
		_hcache.resize(_hw * (HEIGHT * _HS + 2))
		_hcache.fill(NAN)
	var fx := clampf(wx * _HS / TILE, 0.0, WIDTH * _HS)
	var fz := clampf(wz * _HS / TILE, 0.0, HEIGHT * _HS)
	var ix := int(fx)
	var iz := int(fz)
	var tx := fx - ix
	var tz := fz - iz
	var a := lerpf(_hsample(ix, iz), _hsample(ix + 1, iz), tx)
	var b := lerpf(_hsample(ix, iz + 1), _hsample(ix + 1, iz + 1), tx)
	return lerpf(a, b, tz)

func fast_normal(wx: float, wz: float) -> Vector3:
	var e := 0.25
	var dx := height_at(wx + e, wz) - height_at(wx - e, wz)
	var dz := height_at(wx, wz + e) - height_at(wx, wz - e)
	return Vector3(-dx, 2.0 * e, -dz).normalized()

func terrain_normal(wx: float, wz: float) -> Vector3:
	var e := 0.25
	var dx := terrain_y(wx + e, wz) - terrain_y(wx - e, wz)
	var dz := terrain_y(wx, wz + e) - terrain_y(wx, wz - e)
	return Vector3(-dx, 2.0 * e, -dz).normalized()

func _paint_map(m: Dictionary) -> void:
	for z in HEIGHT:
		for x in WIDTH:
			cells[z * WIDTH + x] = MapData.kind_at(m, x, z)
	for cell in SitePlan.footprints():
		_put(cell.x, cell.y, CellKind.LINK)

func _put(x: int, z: int, kind: int) -> void:
	if x < 0 or z < 0 or x >= WIDTH or z >= HEIGHT:
		return
	cells[z * WIDTH + x] = kind
	version += 1

func _rect(x: int, z: int, w: int, h: int, kind: int) -> void:
	for dz in h:
		for dx in w:
			_put(x + dx, z + dz, kind)

func _build_ground() -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.94
	mesh.material = material
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = mesh
	multi.instance_count = WIDTH * HEIGHT
	var index := 0
	for z in HEIGHT:
		for x in WIDTH:
			var water := cells[index] == CellKind.WATER
			var height := 0.08 if water else 0.18
			var basis := Basis.from_scale(Vector3(TILE * 0.98, height, TILE * 0.98))
			var origin := Vector3((x + 0.5) * TILE, height * 0.5, (z + 0.5) * TILE)
			multi.set_instance_transform(index, Transform3D(basis, origin))
			var grass := Color("7c8b62") if (x + z) % 2 == 0 else Color("6f8158")
			multi.set_instance_color(index, Color("1d5568") if water else grass)
			index += 1
	var body := MultiMeshInstance3D.new()
	body.multimesh = multi
	add_child(body)
	var pad := BoxMesh.new()
	pad.size = Vector3(WIDTH * TILE, 0.2, HEIGHT * TILE)
	var pad_mesh := MeshInstance3D.new()
	pad_mesh.mesh = pad
	pad_mesh.position = Vector3(WIDTH * TILE * 0.5, -0.16, HEIGHT * TILE * 0.5)
	var pad_material := StandardMaterial3D.new()
	pad_material.albedo_color = Color("171918")
	pad_mesh.material_override = pad_material
	add_child(pad_mesh)

func _build_props() -> void:
	_scatter(CellKind.STONE, _stone_mesh(), 0.32)
	_scatter(CellKind.TREE, _trunk_mesh(), 0.45)
	_scatter(CellKind.TREE, _canopy_mesh(), 1.15)
	_scatter(CellKind.MOUNTAIN, _peak_mesh(), 1.15)
	_scatter(CellKind.BUILDING, _house_mesh(), 0.7)
	_scatter(CellKind.BUILDING, _roof_mesh(), 1.48)

func _tone(color: Color, rough: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = rough
	return material

func _stone_mesh() -> Mesh:
	var mesh := SphereMesh.new()
	mesh.radius = 0.48
	mesh.height = 0.62
	mesh.radial_segments = 8
	mesh.rings = 4
	mesh.material = _tone(Color("9aa09a"), 0.92)
	return mesh

func _trunk_mesh() -> Mesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.1
	mesh.bottom_radius = 0.16
	mesh.height = 0.9
	mesh.radial_segments = 6
	mesh.material = _tone(Color("6a4a32"), 0.88)
	return mesh

func _canopy_mesh() -> Mesh:
	var mesh := SphereMesh.new()
	mesh.radius = 0.58
	mesh.height = 0.85
	mesh.radial_segments = 8
	mesh.rings = 5
	mesh.material = _tone(Color("2f6b3c"), 0.8)
	return mesh

func _peak_mesh() -> Mesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.05
	mesh.bottom_radius = 0.95
	mesh.height = 2.3
	mesh.radial_segments = 5
	mesh.material = _tone(Color("6d7580"), 0.9)
	return mesh

func _house_mesh() -> Mesh:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.25, 1.15, 1.25)
	mesh.material = _tone(Color("c9b59a"), 0.82)
	return mesh

func _roof_mesh() -> Mesh:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.45, 0.22, 1.45)
	mesh.material = _tone(Color("7d3d34"), 0.7)
	return mesh

func _scatter(kind: int, mesh: Mesh, lift: float) -> void:
	var count := 0
	for cell in cells:
		if cell == kind:
			count += 1
	if count == 0:
		return
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = count
	var index := 0
	var cursor := 0
	for z in HEIGHT:
		for x in WIDTH:
			if cells[cursor] == kind:
				var origin := Vector3((x + 0.5) * TILE, lift, (z + 0.5) * TILE)
				multi.set_instance_transform(index, Transform3D(Basis.IDENTITY, origin))
				index += 1
			cursor += 1
	var node := MultiMeshInstance3D.new()
	node.multimesh = multi
	add_child(node)

func _build_highlight() -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(TILE * 0.96, 0.06, TILE * 0.96)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(1.0, 0.78, 0.28, 0.45)
	_highlight = MeshInstance3D.new()
	_highlight.mesh = mesh
	_highlight.material_override = material
	_highlight.visible = false
	add_child(_highlight)

func _cell_under_pointer() -> Vector2i:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return Vector2i(-1, -1)
	var screen := get_viewport().get_mouse_position()
	var origin := camera.project_ray_origin(screen)
	var dir := camera.project_ray_normal(screen)
	var hit: Variant = Plane(Vector3.UP, 0.0).intersects_ray(origin, dir)
	if hit == null:
		return Vector2i(-1, -1)
	var cell := cell_from_world(hit)
	if not contains(cell):
		return Vector2i(-1, -1)
	return cell

# Чит-редактор: поменять тип клетки и перестроить окружение.
func set_cell(cell: Vector2i, kind: int, rebuild: bool = true) -> void:
	if not contains(cell):
		return
	_put(cell.x, cell.y, kind)
	if rebuild:
		WorldArt.build(self)
