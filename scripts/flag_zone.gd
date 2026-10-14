# Контрибьютор: vibic777
# Ресурсная зона с флагом. Захватывает ТОЛЬКО инженер (без инженеров зону не взять).
# Удержание: любой свой юнит в зоне. Нет своих — контроль падает к нейтралу.
# Параметры — data/game.json → economy.flag. Своя зона даёт связь (как вышка).
class_name FlagZone
extends Node3D

var zone_id := -1
var resource := "oil"
var title := ""
var center := Vector2i.ZERO
var radius := 3          # в клетках
var owner_side := 0      # 0 — нейтрал
var control := 0.0       # 0..100 у owner_side (или у захватчика, пока owner 0)
var capturer := 0        # сторона, чей инженер берёт нейтральную зону
var _grid: BattleGrid
var _tick := 0.0
var _cloth: MeshInstance3D
var _cloth_mat: StandardMaterial3D
var _ring_mat: StandardMaterial3D
var _label: Label3D

func setup(grid: BattleGrid, z: Dictionary) -> void:
	_grid = grid
	zone_id = int(z.get("id", -1))
	resource = str(z.get("resource", "OIL")).to_lower()
	title = str(z.get("title", resource))
	center = MapData.cell(z["center"])
	radius = int(z.get("radius", 3))
	var c := grid.cell_center(center)
	position = Vector3(c.x, grid.terrain_y(c.x, c.z), c.z)

func _ready() -> void:
	add_to_group("zones")
	var b := ArtKit.Builder.new()
	b.cyl(0.05, 0.06, 3.2, Vector3(0, 1.6, 0), Color("c8ccd0"), ArtKit.METAL, Vector3.ZERO, 8)
	b.ball(0.09, Vector3(0, 3.25, 0), Color("e2c060"), ArtKit.METAL)
	b.cyl(0.35, 0.42, 0.18, Vector3(0, 0.09, 0), Color("6d6a62"), ArtKit.MATTE, Vector3.ZERO, 12)
	add_child(ArtKit.node(b.commit()))
	var cloth := BoxMesh.new()
	cloth.size = Vector3(1.0, 0.6, 0.03)
	_cloth = MeshInstance3D.new()
	_cloth.mesh = cloth
	_cloth.position = Vector3(0.52, 2.85, 0)
	_cloth_mat = StandardMaterial3D.new()
	_cloth.material_override = _cloth_mat
	add_child(_cloth)
	var ring := TorusMesh.new()
	ring.inner_radius = radius * BattleGrid.TILE - 0.12
	ring.outer_radius = radius * BattleGrid.TILE
	_ring_mat = StandardMaterial3D.new()
	_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var ring_node := MeshInstance3D.new()
	ring_node.mesh = ring
	ring_node.material_override = _ring_mat
	ring_node.position.y = 0.25
	ring_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring_node)
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.font_size = 30
	_label.pixel_size = 0.012
	_label.outline_size = 8
	_label.position = Vector3(0, 3.8, 0)
	add_child(_label)
	_paint()

static func cfg(field: String, fallback: float) -> float:
	var f: Dictionary = Stockpile.eco("flag", {})
	return float(f.get(field, fallback))

func _process(delta: float) -> void:
	var _pt := Prof.t()
	_process_inner(delta)
	Prof.add("zone", _pt)

func _process_inner(delta: float) -> void:
	_cloth.rotation.y = sin(Time.get_ticks_msec() / 400.0 + zone_id) * 0.25
	if NetGame.is_client() and NetGame.in_match:
		return
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 0.25
	step(0.25)

func inside(world: Vector3) -> bool:
	var flat := world - position
	flat.y = 0.0
	return flat.length() <= radius * BattleGrid.TILE

# Один шаг правил зоны (вынесен для тестов).
func step(dt: float) -> void:
	var engineers := {}
	var present := {}
	for node in UnitIndex.near(get_tree(), position, radius * BattleGrid.TILE + 1.0):
		var u := node as BattleUnit
		if u.hull <= 0.0 or BattleGrid.is_static(u.mover) or not inside(u.global_position):
			continue
		present[u.side] = true
		if u.mover == BattleGrid.Mover.ENGINEER:
			engineers[u.side] = true
	var rate := cfg("capture_per_s", 12.5) * dt
	var decay := cfg("decay_per_s", 4.0) * dt
	if owner_side > 0:
		var held := false
		for s in present:
			if MatchSetup.allied(int(s), owner_side):
				held = true
		var raiders := false
		for s in engineers:
			if MatchSetup.hostile(int(s), owner_side):
				raiders = true
		if held:
			if engineers.has(owner_side):
				control = minf(100.0, control + rate)
		else:
			control -= decay * (cfg("contest_mult", 2.0) if raiders else 1.0)
			if control <= 0.0:
				_set_owner(0)
				control = 0.0
	else:
		# Нейтральная: растёт у единственной стороны с инженером в зоне.
		var sides := engineers.keys()
		if sides.size() == 1:
			var s := int(sides[0])
			if capturer != s:
				capturer = s
				control = 0.0
			control += rate
			if control >= 100.0:
				control = 100.0
				_set_owner(s)
		elif sides.is_empty():
			control = maxf(0.0, control - decay)
			if control <= 0.0:
				capturer = 0
	_paint()

func _set_owner(side: int) -> void:
	RelayNet.stamp += 1
	owner_side = side
	capturer = side
	for node in get_tree().get_nodes_in_group("sites"):
		var site := node as CaptureSite
		if site.zone == zone_id:
			site.set_team(side)

func covers_side(side: int, world: Vector3) -> bool:
	if owner_side != side:
		return false
	var flat := world - position
	flat.y = 0.0
	return flat.length() <= cfg("relay_radius", 14.0) * BattleGrid.TILE * 0.5 + radius * BattleGrid.TILE

func percent_line() -> String:
	var who := "нейтрал"
	var side := owner_side if owner_side > 0 else capturer
	if side == SitePlan.OWNER_PLAYER:
		who = "наша"
	elif side > 0:
		who = MatchSetup.name_of(side)
	if owner_side == 0 and capturer == 0:
		return "%s · нейтральная" % title
	return "%s · %s %d%%" % [title, who, int(control)]

func _paint() -> void:
	if _label == null:
		return
	var side := owner_side if owner_side > 0 else capturer
	var col := MatchSetup.color_of(side) if side > 0 else Color("d2c07a")
	_cloth_mat.albedo_color = col
	_ring_mat.albedo_color = Color(col.r, col.g, col.b, 0.35 + control / 300.0)
	_label.text = percent_line()

func net_state() -> Array:
	return [owner_side, control, capturer]

func net_apply(e: Array) -> void:
	if owner_side != int(e[0]):
		RelayNet.stamp += 1
	owner_side = int(e[0])
	control = float(e[1])
	capturer = int(e[2])
	_paint()
