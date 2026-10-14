# Контрибьютор: vibic777
# Туман войны: неразведанное — тёмное, разведанное вне обзора — полупрозрачное, в обзоре — чисто.
# Враги вне обзора скрыты. Обзор дают свои юниты, свои узлы и временные «вспышки» (разведка БПЛА).
class_name FogOfWar
extends Node3D

const UNSEEN := 0
const MEMORY := 1
const SEEN := 2

var enabled := true
var grid: BattleGrid
var state := PackedByteArray()
var _reveals: Array = []   # [{"cell": Vector2i, "radius": int, "left": float}]
var _img: Image
var _tex: ImageTexture
var _mat: ShaderMaterial
var _plane: MeshInstance3D
var _tick := 0.0
var version := 0

func setup(host: BattleGrid) -> void:
	grid = host
	state.resize(BattleGrid.WIDTH * BattleGrid.HEIGHT)
	state.fill(UNSEEN)
	_img = Image.create(BattleGrid.WIDTH, BattleGrid.HEIGHT, false, Image.FORMAT_L8)
	_tex = ImageTexture.create_from_image(_img)
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, depth_test_disabled, cull_disabled;
uniform sampler2D fog : filter_linear;
uniform vec2 world_size;
varying vec3 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float v = texture(fog, wpos.xz / world_size).r;
	float n = fract(sin(dot(floor(wpos.xz * 3.0), vec2(12.9898, 78.233))) * 43758.5453);
	ALBEDO = vec3(0.03, 0.04, 0.05) + vec3(0.02) * n;
	ALPHA = (1.0 - v) * 0.88;
}
"""
	_mat = ShaderMaterial.new()
	_mat.shader = shader
	_mat.set_shader_parameter("fog", _tex)
	_mat.set_shader_parameter("world_size", Vector2(BattleGrid.WIDTH * BattleGrid.TILE, BattleGrid.HEIGHT * BattleGrid.TILE))
	_mat.render_priority = 10
	var pm := PlaneMesh.new()
	pm.size = Vector2(BattleGrid.WIDTH * BattleGrid.TILE, BattleGrid.HEIGHT * BattleGrid.TILE)
	_plane = MeshInstance3D.new()
	_plane.mesh = pm
	_plane.material_override = _mat
	_plane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_plane.position = Vector3(pm.size.x * 0.5, 0.35, pm.size.y * 0.5)
	add_child(_plane)
	refresh()

func set_enabled(on: bool) -> void:
	enabled = on
	_plane.visible = on
	refresh()

func reveal(world: Vector3, radius: int, seconds: float) -> void:
	_reveals.append({"cell": grid.cell_from_world(world), "radius": radius, "left": seconds})
	refresh()

func visible_cell(cell: Vector2i) -> bool:
	if not enabled:
		return true
	if not grid.contains(cell):
		return false
	return state[cell.y * BattleGrid.WIDTH + cell.x] == SEEN

func explored_cell(cell: Vector2i) -> bool:
	if not enabled:
		return true
	if not grid.contains(cell):
		return false
	return state[cell.y * BattleGrid.WIDTH + cell.x] != UNSEEN

func visible_at(world: Vector3) -> bool:
	return visible_cell(grid.cell_from_world(world))

static func _d_sight(mover: int) -> int:
	match mover:
		BattleGrid.Mover.UAV, BattleGrid.Mover.JET:
			return 6
		BattleGrid.Mover.ROTOR:
			return 5
		BattleGrid.Mover.WALKER, BattleGrid.Mover.TRACK:
			return 4
		_:
			return 3

func _process(delta: float) -> void:
	var _pt := Prof.t()
	_process_inner(delta)
	Prof.add("fog", _pt)

func _process_inner(delta: float) -> void:
	for r in _reveals:
		r["left"] = float(r["left"]) - delta
	_reveals = _reveals.filter(func(r) -> bool: return float(r["left"]) > 0.0)
	_tick -= delta
	if _tick <= 0.0:
		_tick = 0.2
		refresh()

var _bytes := PackedByteArray()

func refresh() -> void:
	if grid == null:
		return
	for i in state.size():
		if state[i] == SEEN:
			state[i] = MEMORY
	UnitIndex.refresh(get_tree())
	# Одна подсветка на (клетка, радиус): толпа в одной клетке светит один раз.
	var lit := {}
	for node in UnitIndex.all:
		var unit := node as BattleUnit
		if not is_instance_valid(unit):
			continue
		if MatchSetup.allied(unit.side, SitePlan.OWNER_PLAYER) and unit.hull > 0.0:
			var c := grid.cell_from_world(unit.global_position)
			var r := sight(unit.mover)
			var key := (c.y * BattleGrid.WIDTH + c.x) * 64 + r
			if lit.has(key):
				continue
			lit[key] = true
			_light(c, r)
	for node in get_tree().get_nodes_in_group("sites"):
		var site := node as CaptureSite
		if MatchSetup.allied(site.team, SitePlan.OWNER_PLAYER):
			_light(site.terminal, 4)
	for r in _reveals:
		_light(r["cell"], int(r["radius"]))
	# Текстура тумана одним буфером (без set_pixel на каждую клетку).
	var n := state.size()
	if _bytes.size() != n:
		_bytes.resize(n)
	for i in n:
		var v := state[i]
		_bytes[i] = 255 if (v == SEEN or not enabled) else (128 if v == MEMORY else 0)
	_img.set_data(BattleGrid.WIDTH, BattleGrid.HEIGHT, false, Image.FORMAT_L8, _bytes)
	_tex.update(_img)
	version += 1
	for node in get_tree().get_nodes_in_group("units"):
		var unit := node as BattleUnit
		if not MatchSetup.allied(unit.side, SitePlan.OWNER_PLAYER):
			var see := visible_at(unit.global_position)
			if unit.visible != see:
				unit.visible = see

func _light(center: Vector2i, radius: int) -> void:
	# Строками: границы диска на строку, затем сплошной отрезок.
	var w := BattleGrid.WIDTH
	var lim := radius * radius + radius
	for dz in range(-radius, radius + 1):
		var z := center.y + dz
		if z < 0 or z >= BattleGrid.HEIGHT:
			continue
		var span := int(sqrt(float(lim - dz * dz)))
		var x0 := maxi(0, center.x - span)
		var x1 := mini(w - 1, center.x + span)
		var row := z * w
		for x in range(x0, x1 + 1):
			state[row + x] = SEEN

static func sight(mover: int) -> int:
	return GameData.unit(mover, "sight", _d_sight(mover))
