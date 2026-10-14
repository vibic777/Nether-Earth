# Контрибьютор: vibic777
class_name CaptureSite
extends Node3D

const HACK_TIME := 8.0

var kind := SitePlan.KIND_RELAY
var team := SitePlan.OWNER_NEUTRAL:
	set(v):
		if v != team:
			RelayNet.stamp += 1
		team = v
var title := ""
var terminal := Vector2i.ZERO
var radius := 0.0:
	set(v):
		if v != radius:
			RelayNet.stamp += 1
		radius = v
var hack := 0.0
var home := SitePlan.OWNER_NEUTRAL
var hull := 0.0
var hull_max := 0.0
var _radius_full := 0.0
var metal_rate := 0
var chip_rate := 0
var power_rate := 0
var footprint: Array[Vector2i] = []
var queue: Array[int] = []
var net_id := 0
var zone := -1             # ресурсный узел зоны: берётся только вместе с флагом
var _prev_cells := {}      # клетки до постройки (вернуть при сносе)

var _grid: BattleGrid
var _center := Vector3.ZERO
var _build_time := 0.0
var _alarm := false
var _label: Label3D
var _disc: MeshInstance3D
var _loop: MeshInstance3D
var _loop_mat: StandardMaterial3D
var _mast_mat: StandardMaterial3D
var _spin: Node3D

func setup(grid: BattleGrid, def: Dictionary) -> void:
	kind = def["kind"]
	team = def["owner"]
	title = def["title"]
	terminal = def["terminal"]
	radius = def["radius"]
	_radius_full = radius
	home = team
	zone = int(def.get("zone", -1))
	if kind == SitePlan.KIND_HQ:
		hull_max = GameData.site(kind, "hull", 160.0)
		hull = hull_max
	elif SitePlan.is_deployed(kind) or SitePlan.is_built(kind):
		hull_max = float(GameData.site(kind, "hull", 100.0))
		hull = hull_max
	metal_rate = def["metal"]
	chip_rate = def["chips"]
	power_rate = def["power"]
	_grid = grid
	for cell in def["cells"]:
		footprint.append(cell)
	var sum := Vector3.ZERO
	for cell in footprint:
		sum += grid.cell_center(cell)
	_center = sum / float(footprint.size())
	_center.y = 0.0
	position = _center
	position.y = grid.terrain_y(_center.x, _center.z) - BattleGrid.BASE_Y
	_build(grid)
	_refresh()

func _ready() -> void:
	RelayNet.stamp += 1
	add_to_group("sites")

func is_hostile_hq(from_side: int) -> bool:
	return kind == SitePlan.KIND_HQ and team > 0 and MatchSetup.hostile(team, from_side) and hull > 0.0

func take_hit(amount: float, from_side: int) -> void:
	if NetGame.is_client() and NetGame.in_match:
		return
	if hull_max <= 0.0 or not MatchSetup.hostile(team, from_side) or hull <= 0.0 or amount <= 0.0:
		return
	_damage(amount)

# Урон без проверки стороны (взрывы).
func take_hit_any(amount: float) -> void:
	if NetGame.is_client() and NetGame.in_match:
		return
	if hull_max <= 0.0 or hull <= 0.0 or amount <= 0.0:
		return
	_damage(amount)

func _damage(amount: float) -> void:
	RelayNet.stamp += 1 if hull - amount <= 0.0 else 0
	if team == SitePlan.OWNER_PLAYER and get_parent().has_method("note_alert"):
		get_parent().note_alert(global_position)
	hull = maxf(hull - amount, 0.0)
	if hull <= 0.0:
		radius = 0.0
		if kind != SitePlan.KIND_HQ:
			_destroyed()
			return
	_refresh()

# Постройка или развёрнутая база разрушена: взрыв (АЭС — большой), снос, турели базы продаются.
func _destroyed() -> void:
	var spec: Dictionary = GameData.site(kind, "death_blast", {})
	if not spec.is_empty():
		Blast.spawn(get_parent(), global_position, spec)
	remove_site(false)

func remove_site(refund_turrets: bool) -> void:
	RelayNet.stamp += 1
	var stock := Stockpile.of(get_tree(), team) if team > 0 else null
	for node in get_tree().get_nodes_in_group("units"):
		var u := node as BattleUnit
		if u.built_by == self:
			if refund_turrets and stock != null:
				stock.refund(Vector3i(int(Yard.usd(u.mover) * float(Stockpile.eco("turret_refund", 0.6))), 0, 0))
			u.queue_free()
	if stock != null:
		cancel_all(stock)
	for c in footprint:
		_grid.set_cell(c, int(_prev_cells.get(c, BattleGrid.CellKind.PLAIN)), false)
	_grid.set_cell(terminal, _grid.kind_at(terminal))
	queue_free()

func restore_hq() -> void:
	if kind != SitePlan.KIND_HQ:
		return
	hull = hull_max
	radius = _radius_full
	_refresh()

func claims(cell: Vector2i) -> bool:
	if cell == terminal:
		return true
	return footprint.has(cell)

func covers_world(world: Vector3) -> bool:
	return covers_side(SitePlan.OWNER_PLAYER, world)

func covers_side(side: int, world: Vector3) -> bool:
	if team != side or radius <= 0.0:
		return false
	var flat := world - _center
	flat.y = 0.0
	return flat.length() <= radius

func hack_step(delta: float, active: bool, by_side: int = SitePlan.OWNER_PLAYER) -> void:
	if zone >= 0:
		return
	if team == by_side:
		return
	if not active:
		if hack > 0.0 or _alarm:
			hack = 0.0
			_alarm = false
			_refresh_label()
		return
	_alarm = true
	hack = minf(hack + delta, HACK_TIME)
	if hack >= HACK_TIME:
		hack = 0.0
		_alarm = false
		set_team(by_side)
		return
	_refresh_label()

func order_line() -> String:
	if queue.is_empty():
		return "%s · закажи технику внизу экрана" % title
	var head := Yard.mover_name(queue[0])
	var need := Yard.seconds(queue[0])
	var percent := 0
	if need > 0.0:
		percent = int(round(clampf(_build_time / need, 0.0, 1.0) * 100.0))
	return "%s · %s %d%% · в очереди %d" % [title, head, percent, queue.size()]

func enqueue(mover: int, stock: Stockpile) -> bool:
	if NetGame.relay_site(self, "enqueue", [mover]):
		return true
	if team != stock.side or not Yard.builds(kind, mover):
		return false
	if queue.size() >= 5:
		return false
	if not stock.pay(Yard.cost(mover)):
		return false
	queue.append(mover)
	if queue.size() == 1:
		_build_time = 0.0
	_refresh_label()
	return true

func cancel_all(stock: Stockpile) -> void:
	if NetGame.relay_site(self, "cancel_all", []):
		return
	for mover in queue:
		stock.refund(Yard.cost(mover))
	queue.clear()
	_build_time = 0.0
	_refresh_label()

func tick_build(delta: float, stock: Stockpile) -> void:
	if queue.is_empty() or team != stock.side:
		return
	_build_time += delta * stock.build_factor()
	if _build_time < Yard.seconds(queue[0]):
		_refresh_label()
		return
	_finish_head()

func debug_finish(stock: Stockpile) -> BattleUnit:
	if queue.is_empty():
		return null
	_build_time = Yard.seconds(queue[0])
	return _finish_head()

func _finish_head() -> BattleUnit:
	var mover: int = queue[0]
	queue.remove_at(0)
	_build_time = 0.0
	var unit := BattleUnit.new()
	unit.setup(_grid, mover, _spawn_cell(mover), team)
	get_parent().add_child(unit)
	_refresh_label()
	return unit

func _spawn_cell(mover: int) -> Vector2i:
	var spots: Array[Vector2i] = [
		terminal,
		terminal + Vector2i(1, 0),
		terminal + Vector2i(-1, 0),
		terminal + Vector2i(0, 1),
		terminal + Vector2i(0, -1),
	]
	for dx in range(-2, 3):
		for dz in range(-2, 3):
			spots.append(terminal + Vector2i(dx, dz))
	for cell in spots:
		if _grid.can_enter(cell, mover) and not _unit_on(cell):
			return cell
	return terminal

# Свернуть развёрнутую базу обратно в машину. Турели базы продаются с возвратом $.
func undeploy() -> BattleUnit:
	if NetGame.relay_site(self, "undeploy", []):
		return null
	if not SitePlan.is_deployed(kind) or team <= 0:
		return null
	var key: String = GameData.SITE_KEYS[kind]
	var mover := -1
	for i in GameData.UNIT_KEYS.size():
		if str(GameData.unit(i, "deploys", "")) == key:
			mover = i
	if mover < 0:
		return null
	var at := footprint[0]
	var side := team
	var host := get_parent()
	var grid := _grid
	remove_site(true)
	var unit := BattleUnit.new()
	unit.setup(grid, mover, at, side)
	host.add_child(unit)
	return unit

func _unit_on(cell: Vector2i) -> bool:
	for node in get_tree().get_nodes_in_group("units"):
		var unit := node as BattleUnit
		if _grid.cell_from_world(unit.global_position) == cell:
			return true
	return false

func set_team(value: int) -> void:
	RelayNet.stamp += 1
	if team > 0 and value != team and not queue.is_empty():
		var stock := Stockpile.of(get_tree(), team)
		if stock != null:
			cancel_all(stock)
	team = value
	hack = 0.0
	_alarm = false
	_refresh()

func _process(_delta: float) -> void:
	var _pt := Prof.t()
	_process_inner(_delta)
	Prof.add("site", _pt)

func _process_inner(_delta: float) -> void:
	if _spin != null and not (hull_max > 0.0 and hull <= 0.0):
		_spin.rotate_y(_delta * 0.9)
	if not _alarm or _mast_mat == null:
		return
	var pulse := 0.5 + 0.5 * sin(float(Time.get_ticks_msec()) / 90.0)
	_mast_mat.albedo_color = Color(0.85, 0.2, 0.12).lerp(Color(1.0, 0.85, 0.25), pulse)
	_mast_mat.emission = _mast_mat.albedo_color

func _build(grid: BattleGrid) -> void:
	_mast_mat = StandardMaterial3D.new()
	_mast_mat.roughness = 0.5
	_mast_mat.emission_enabled = true
	_mast_mat.emission_energy_multiplier = 0.25
	var wide_x := false
	if footprint.size() > 1:
		wide_x = footprint[0].y == footprint[1].y
	var art := SiteArt.build(self, kind, wide_x, footprint.size() > 1, _mast_mat)
	_spin = art["spin"]
	var top: float = art["top"]
	var pad := MeshInstance3D.new()
	var pad_mesh := BoxMesh.new()
	pad_mesh.size = Vector3(1.2, 0.08, 1.2)
	var pad_mat := StandardMaterial3D.new()
	pad_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pad_mat.albedo_color = Color("e2b15a")
	pad.mesh = pad_mesh
	pad.material_override = pad_mat
	var pad_at := grid.cell_center(terminal) - _center
	pad_at.y = 0.16
	pad.position = pad_at
	add_child(pad)
	_label = Label3D.new()
	_label.font_size = 28
	_label.pixel_size = 0.012
	_label.position = Vector3(0.0, top + 0.35, 0.0)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.outline_size = 8
	add_child(_label)
	if radius <= 0.0:
		return
	_disc = _range_disc()
	_loop = _range_loop()
	add_child(_disc)
	add_child(_loop)

func _range_disc() -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.06
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	material.albedo_color = Color(0.35, 0.78, 0.45, 0.16)
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.position = Vector3(0.0, 0.12, 0.0)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node

func _range_loop() -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius - 0.28
	mesh.outer_radius = radius
	_loop_mat = StandardMaterial3D.new()
	_loop_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = _loop_mat
	node.position = Vector3(0.0, 0.2, 0.0)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node

func _refresh() -> void:
	var ruined := hull_max > 0.0 and hull <= 0.0
	if _disc != null:
		_disc.visible = team == SitePlan.OWNER_PLAYER and not ruined
	if _loop != null:
		_loop.visible = team != SitePlan.OWNER_PLAYER and not ruined
		_loop_mat.albedo_color = MatchSetup.color_of(team).darkened(0.15) if team > 0 else Color("d2c07a")
	if _mast_mat != null and not _alarm:
		if team == SitePlan.OWNER_PLAYER:
			_mast_mat.albedo_color = Color("3f8f58")
		elif team > 0:
			_mast_mat.albedo_color = MatchSetup.color_of(team).darkened(0.4)
		else:
			_mast_mat.albedo_color = Color("8a7a48")
		_mast_mat.emission = _mast_mat.albedo_color
	_refresh_label()

func _refresh_label() -> void:
	if _label == null:
		return
	if hull_max > 0.0 and hull <= 0.0:
		_label.text = "%s · разрушен" % title
		return
	if _alarm:
		var percent := int(round(hack / HACK_TIME * 100.0))
		_label.text = "%s · сирена %d%%" % [title, percent]
		return
	if not queue.is_empty() and team == SitePlan.OWNER_PLAYER:
		_label.text = order_line()
		return
	var who := "нейтрал"
	if team == SitePlan.OWNER_PLAYER:
		who = "наш"
	elif MatchSetup.allied(team, SitePlan.OWNER_PLAYER):
		who = "союзник · " + MatchSetup.name_of(team)
	elif team > 0:
		who = "враг" if MatchSetup.active_sides().size() <= 2 else MatchSetup.name_of(team)
	if hull_max > 0.0:
		var left := int(round(hull / hull_max * 100.0))
		_label.text = "%s · %s · %d%%" % [title, who, left]
		return
	_label.text = "%s · %s" % [title, who]

func _box(size: Vector3, at: Vector3, material: StandardMaterial3D) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.position = at
	add_child(node)


# Клиент: состояние узла из снимка хоста.
func net_apply(e: Array) -> void:
	var changed := team != int(e[0]) or absf(hull - float(e[1])) > 0.01 or _alarm != bool(e[3])
	team = int(e[0])
	hull = float(e[1])
	hack = float(e[2])
	_alarm = bool(e[3])
	queue.clear()
	for m in e[4]:
		queue.append(int(m))
	_build_time = float(e[5])
	if hull_max > 0.0 and hull <= 0.0:
		radius = 0.0
	elif hull_max > 0.0:
		radius = _radius_full
	if changed:
		_refresh()
	else:
		_refresh_label()

func net_state() -> Array:
	return [team, hull, hack, _alarm, queue.duplicate(), _build_time]
