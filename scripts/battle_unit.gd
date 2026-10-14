# Контрибьютор: vibic777
class_name BattleUnit
extends Node3D

var mover := BattleGrid.Mover.TROOPER
var side := SitePlan.OWNER_PLAYER
var grid: BattleGrid
var hull := 1.0
var hull_max := 1.0

var _name := ""
var _speed := 3.0
var _turn_deg := 180.0
var _align := 0.8
var _path: Array[Vector2i] = []
var _index := 0
var _coasting := false
var _blocked := false
var _steer := false
var _closest := 999.0
var _ring: MeshInstance3D
var _markers: Node3D
var _site: CaptureSite
var _dark := false
var weapon := -1
var tier := 1
var _title: Label3D
var _muzzle: MeshInstance3D
var _hull_bar: MeshInstance3D
var _rotor_spin: Node3D
var _rotor_axis := Vector3.UP
var _legs: Array[Node3D] = []
var _gait := 0.0
var _last_pos := Vector3.ZERO
var _stride := 0.0
var _cooldown := 0.0
var _stun := 0.0
var attack_target: BattleUnit
var attack_site: CaptureSite
var _chase := Vector2i(-99, -99)
var _post := Vector2i(-99, -99)
var _post_name := ""
var mode := Arsenal.MODE_DEFAULT
var charge := 0.0
var god := false
var instant := false
var attack_point := Vector3.ZERO
var has_point := false
var ability_cd := 0.0
var shield_left := 0.0
var _deploy := 0.0
var _mortar: Node3D
var _shield: MeshInstance3D
# Боезапас (штурмовик): -1 — без ограничений. Пустой — летит на свой аэродром перевооружаться.
var ammo := -1
# Сеть: номер юнита (одинаковый у хоста и клиентов) и цель сглаживания на клиенте.
var net_id := 0
# Экономика и новые классы: груз грузовика, ворота, погружение подлодки.
var cargo := 0.0
var _haul_wait := 0.0
var _haul_goal: CaptureSite
var gate_mode := "auto"      # auto / open / closed
var submerged_left := 0.0
var built_by: CaptureSite    # турель/стена привязана к базе, давшей радиус постройки
var _drive_k := 1.0
var _drive_tick := 0.0
var _smog_tick := 0.0
var net_target := Vector3.ZERO
var net_rot := 0.0
var ammo_max := -1
var _rearm := 0.0
var _base: CaptureSite

func setup(host: BattleGrid, kind: int, cell: Vector2i, owner_side: int = SitePlan.OWNER_PLAYER) -> void:
	grid = host
	mover = kind
	side = owner_side
	_apply_profile()
	hull = hull_max
	weapon = WeaponRack.default_kind(mover)
	if weapon >= 0:
		tier = WeaponRack.default_tier(mover, weapon)
	var origin := host.cell_center(cell)
	origin.y = host.ride_height(cell, mover)
	position = origin

func _ready() -> void:
	add_to_group("units")
	UnitIndex.add(self)
	if (mover == BattleGrid.Mover.WALL or mover == BattleGrid.Mover.GATE) and grid != null:
		grid.walls[grid.cell_from_world(position)] = self
		grid.version += 1
	if net_id == 0 and not NetGame.is_client():
		net_id = NetGame.next_id()
	net_target = position
	net_rot = rotation.y
	_build_body()
	_build_muzzle()
	_build_ring()
	_markers = Node3D.new()
	add_child(_markers)
	_markers.top_level = true
	_markers.visible = false
	_build_hull()
	if side != SitePlan.OWNER_PLAYER and _title != null:
		_title.modulate = MatchSetup.color_of(side).lightened(0.2)

var _link_ok := false
var _link_left := -1.0
var _foe_left := 0.0
var team_bit := 0
var _ix_in := false
var _ix_key := Vector2i.ZERO
var _ix_team := -1
var _foe_cache: BattleUnit
var _los_left := 0.0
var _los_foe: BattleUnit
var _los_blocked := false

func linked() -> bool:
	if get_tree() == null:
		return false
	# Связь меняется медленно: проверка раз в ~0,4 с, разнесено по юнитам.
	_link_left -= get_process_delta_time()
	if _link_left <= 0.0:
		_link_left = 0.25 + float(net_id % 7) * 0.02
		_link_ok = RelayNet.covers_side(get_tree(), global_position, side)
	return _link_ok

func facing() -> Vector3:
	return _facing()

func status_line() -> String:
	if ammo == 0:
		if _base == null:
			return "%s · боезапас пуст, нет аэродрома" % _name
		return "%s · перевооружение %d%%" % [_name, int(_rearm / maxf(_rearm_time(), 0.1) * 100.0)]
	if _stun > 0.0:
		return "%s · глушение" % _name
	if not linked():
		return "%s · нет связи" % _name
	if _site != null and _site.hack > 0.0:
		return "%s · взлом %d%%" % [_name, int(round(_site.hack / CaptureSite.HACK_TIME * 100.0))]
	if _blocked:
		return "%s · нет пути" % _name
	if _post.x >= 0:
		if _index < _path.size():
			return "%s · идёт охранять %s" % [_name, _post_name]
		return "%s · охрана %s" % [_name, _post_name]
	if _coasting:
		return "%s · летит дальше" % _name
	if _index < _path.size():
		return "%s · в пути" % _name
	if mover == BattleGrid.Mover.ROTOR:
		return "%s · зависание" % _name
	return "%s · %d%%" % [_name, int(round(hull / hull_max * 100.0))]

func has_weapon() -> bool:
	return weapon >= 0

func weapon_line() -> String:
	if weapon < 0:
		return "Без оружия"
	return "%s · сила %s · %d" % [WeaponRack.title(weapon), WeaponRack.roman(tier), WeaponRack.strike(weapon, tier)]

func cycle_weapon(step: int) -> void:
	var list := WeaponRack.options(mover)
	if list.is_empty():
		return
	var index := list.find(weapon)
	if index < 0:
		index = 0
	weapon = list[posmod(index + step, list.size())]
	tier = clampi(tier, WeaponRack.min_tier(weapon), WeaponRack.max_tier(mover))
	_paint_muzzle()

func cycle_tier(step: int) -> void:
	if weapon < 0:
		return
	tier = clampi(tier + step, WeaponRack.min_tier(weapon), WeaponRack.max_tier(mover))
	_paint_muzzle()

func set_selected(enabled: bool) -> void:
	_ring.visible = enabled
	_markers.visible = enabled
	if enabled and _marks_dirty:
		_rebuild_markers()

func order_capture(site: CaptureSite) -> void:
	if NetGame.relay_unit(self, "order_capture", [site]):
		return
	if site.zone >= 0:
		# Ресурсный узел берётся только вместе с зоной: инженер идёт к флагу.
		var zone := _zone_of(site.zone)
		if zone != null:
			order_to(zone.center)
		return
	order_to(site.terminal)
	if not _dark:
		_site = site

func is_tasked() -> bool:
	if _site != null:
		return true
	if attack_target != null and is_instance_valid(attack_target):
		return true
	if attack_site != null and is_instance_valid(attack_site):
		return true
	if _post.x >= 0:
		return true
	return _index < _path.size()

func order_attack(foe: BattleUnit) -> void:
	if NetGame.relay_unit(self, "order_attack", [foe]):
		return
	if foe == null or not MatchSetup.hostile(foe.side, side) or not linked():
		return
	has_point = false
	attack_site = null
	_clear_post()
	attack_target = foe
	_chase = Vector2i(-99, -99)

func order_attack_site(site: CaptureSite) -> void:
	if NetGame.relay_unit(self, "order_attack_site", [site]):
		return
	if site == null or not site.is_hostile_hq(side) or not linked():
		return
	attack_target = null
	_clear_post()
	attack_site = site
	_chase = Vector2i(-99, -99)

func take_hit(amount: float, stun_time: float, from_side: int) -> void:
	if NetGame.is_client() and NetGame.in_match:
		return
	if from_side == side or MatchSetup.allied(from_side, side) or hull <= 0.0 or amount <= 0.0:
		return
	if god or shield_left > 0.0:
		return
	if submerged_left > 0.0 and from_side > 0:
		return
	if side == SitePlan.OWNER_PLAYER and from_side > 0 and get_parent() != null and get_parent().has_method("note_alert"):
		get_parent().note_alert(global_position)
	hull = maxf(hull - amount, 0.0)
	if stun_time > 0.0:
		_stun = maxf(_stun, stun_time)
	if _site != null:
		_site.hack_step(0.0, false)
		_site = null
		_path = []
		_index = 0
	_paint_hull()
	if hull <= 0.0:
		var spec: Dictionary = GameData.unit(mover, "death_blast", {})
		if not spec.is_empty():
			Blast.spawn(get_parent(), global_position, spec)
		var host := get_parent()
		if host != null and host.has_method("release_unit"):
			host.release_unit(self)
		queue_free()

func order_guard(cell: Vector2i, label: String) -> void:
	if NetGame.relay_unit(self, "order_guard", [cell, label]):
		return
	order_to(cell)
	if _dark:
		return
	_post = cell
	_post_name = label

func _clear_post() -> void:
	_post = Vector2i(-99, -99)
	_post_name = ""

func order_to(cell: Vector2i) -> void:
	if NetGame.relay_unit(self, "order_to", [cell]):
		return
	has_point = false
	_deploy = 0.0
	attack_target = null
	attack_site = null
	_clear_post()
	_chase = Vector2i(-99, -99)
	if _site != null:
		_site.hack_step(0.0, false)
	_site = null
	_dark = false
	if not linked():
		_dark = true
		_path = []
		_index = 0
		_coasting = false
		_blocked = false
		_rebuild_markers()
		return
	_set_path(cell)

func _set_path(cell: Vector2i) -> void:
	var tp := Prof.t()
	_set_path_body(cell)
	Prof.add("path", tp)

func _set_path_body(cell: Vector2i) -> void:
	var start := grid.cell_from_world(global_position)
	if not grid.contains(start):
		start = _nearest_owned_cell()
	_path = Pathfinder.route(grid, start, cell, mover)
	_index = 1 if _path.size() > 1 else _path.size()
	_coasting = false
	_blocked = _path.size() <= 1 and start != cell and not grid.can_enter(cell, mover)
	if _path.size() <= 1 and start != cell and grid.can_enter(cell, mover):
		_blocked = true
	_closest = 999.0
	_rebuild_markers()

var _lag := 0.0
var _view_seen := -1
static var _view_gen := 0
static var _cam_frame := -1
static var _cam_xf := Transform3D()
static var _cam_size := 0.0
static var _cam_fov := 0.0
static var offscreen_step := int(OS.get_environment("NE_OFFSTEP")) if OS.get_environment("NE_OFFSTEP") != "" else 6

func _process(delta: float) -> void:
	var t0 := Prof.t()
	# Камера сдвинулась — видимость в кадре пересчитывается сразу (без «выскакивания»).
	var f := Engine.get_process_frames()
	if f != _cam_frame:
		_cam_frame = f
		var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
		if cam != null and (not cam.global_transform.is_equal_approx(_cam_xf) or cam.size != _cam_size or cam.fov != _cam_fov):
			_cam_xf = cam.global_transform
			_cam_size = cam.size
			_cam_fov = cam.fov
			_view_gen += 1
	if _view_seen != _view_gen:
		_view_seen = _view_gen
		var c2 := get_viewport().get_camera_3d()
		_onscreen = c2 == null or _in_view(c2)
	# Вне кадра: узел снимается с _process и тикает из общего планировщика раз в N кадров.
	if not _onscreen and offscreen_step > 1 and UnitBatch.active() and (_ring == null or not _ring.visible):
		_go_off()
		Prof.add("unit", t0)
		return
	if false:
		pass
	elif _onscreen and onscreen_split and UnitIndex.all.size() > 300 and not BattleGrid.is_static(mover):
		# Под нагрузкой и в кадре: логика через кадр (30 Гц, разнесено по net_id),
		# в промежуточном кадре — экстраполяция позиции/курса и анимация ног: на глаз без разницы.
		if (f + net_id) % 2 != 0 and _vel_ok:
			_lag += delta
			_vshow = _vpos + _vel * _lag
			global_position = _vshow
			rotation.y = _vyaw + _yaw_rate * _lag
			_vshow_yaw = rotation.y
			_animate_gait(delta)
			Prof.add("unit", t0)
			return
		# Вернуть логическое положение, если его не сдвинули извне (приказ, сеть, телепорт).
		if _vel_ok and _lag > 0.0 and global_position.is_equal_approx(_vshow) and is_equal_approx(rotation.y, _vshow_yaw):
			global_position = _vpos
			rotation.y = _vyaw
		delta = minf(_lag + delta, 0.1)
	_lag = 0.0
	_process_body(delta)
	_remember_motion(delta)
	UnitIndex.track(self)
	Prof.add("unit", t0)

# --- Планировщик юнитов вне кадра ---
const OFF_BUCKETS := 16
static var _off: Array = []          # OFF_BUCKETS массивов
static var _off_count := 0
static var _clock := 0.0
static var _off_view := -1
var _is_off := false
var _t_last := 0.0

func _go_off() -> void:
	if _is_off:
		return
	if _off.is_empty():
		for i in OFF_BUCKETS:
			_off.append([])
	_is_off = true
	_t_last = _clock
	_off[net_id % OFF_BUCKETS].append(self)
	_off_count += 1
	set_process(false)

func _go_on() -> void:
	if not _is_off:
		return
	_is_off = false
	var b: Array = _off[net_id % OFF_BUCKETS]
	var i := b.find(self)
	if i >= 0:
		b[i] = b[b.size() - 1]
		b.pop_back()
	_off_count -= 1
	_lag = 0.0
	set_process(true)

# Вызывается раз в кадр (UnitBatch): тикает долю юнитов вне кадра, следит за входом в кадр.
static func tick_offscreen(delta: float, tree: SceneTree) -> void:
	_clock += delta
	if _off.is_empty() or _off_count == 0:
		return
	var t0 := Prof.t()
	var cam: Camera3D = tree.root.get_camera_3d() if tree != null else null
	# Адаптивно: до 500 машин — 10 Гц, до 1200 — 6 Гц, больше — ~4 Гц (вне кадра на глаз не видно).
	var nu := UnitIndex.all.size()
	var step := offscreen_step if nu < 500 else (offscreen_step + 4 if nu < 1200 else offscreen_step + 8)
	step = clampi(step, 1, OFF_BUCKETS)
	var f := Engine.get_process_frames()
	var moved := _off_view != _view_gen
	_off_view = _view_gen
	for b in OFF_BUCKETS:
		var bucket: Array = _off[b]
		var due := (f + b) % step == 0
		if not due and not moved:
			continue
		var i := bucket.size() - 1
		while i >= 0:
			if i >= bucket.size():
				i = bucket.size() - 1
				continue
			var u: BattleUnit = bucket[i]
			i -= 1
			if not is_instance_valid(u) or not u.is_inside_tree():
				continue
			if (cam == null or u._in_view(cam)) or (u._ring != null and u._ring.visible):
				u._onscreen = true
				u._go_on()
				continue
			if due:
				var d := minf(_clock - u._t_last, 0.25)
				u._t_last = _clock
				u._process_body(d)
				u._onscreen = false
				u._remember_motion(d)
				UnitIndex.track(u)
	Prof.add("unit.off", t0)

var _vpos := Vector3.ZERO
var _vyaw := 0.0
var _vel := Vector3.ZERO
var _yaw_rate := 0.0
var _vel_ok := false
var _vshow := Vector3.ZERO
var _vshow_yaw := 0.0
static var onscreen_split := OS.get_environment("NE_NOSPLIT") == ""

# Скорость и поворот за последний логический шаг — для экстраполяции между шагами.
func _remember_motion(delta: float) -> void:
	var p := global_position
	var y := rotation.y
	if _vel_ok and delta > 0.0:
		_vel = (p - _vpos) / delta
		_yaw_rate = angle_difference(_vyaw, y) / delta
		# Телепорт/спавн/сеть — не экстраполировать скачок.
		if _vel.length() > _speed * 3.0 + 2.0 or absf(_yaw_rate) > 20.0:
			_vel = Vector3.ZERO
			_yaw_rate = 0.0
	_vpos = p
	_vyaw = y
	_vel_ok = true

var _onscreen := true
static var _planes: Array[Plane] = []
static var _planes_frame := -1

# В кадре с запасом 6 м: не «выскакивает» на краю экрана, хотя проверка раз в ~10 кадров.
func _in_view(cam: Camera3D) -> bool:
	var f := Engine.get_process_frames()
	if f != _planes_frame:
		_planes_frame = f
		_planes = cam.get_frustum()
	var p := global_position
	for pl in _planes:
		if pl.distance_to(p) > 6.0:
			return false
	return true
var _onscreen_n := 0
static var label_reach := 38.0

# Подписи над далёкими машинами не рисуются (LOD), у выбранных — всегда.
func _near_camera() -> bool:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return true
	if cam.projection == Camera3D.PROJECTION_ORTHOGONAL:
		return cam.size <= label_reach
	return cam.global_position.distance_to(global_position) <= label_reach * 1.6

func _process_body(delta: float) -> void:
	var ta := Prof.t()
	# LOD анимации: вне кадра камеры ноги и винты не анимируются (проверка раз в 8 кадров).
	_onscreen_n -= 1
	if _onscreen_n <= 0:
		_onscreen_n = 8 + net_id % 4
		var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
		_onscreen = cam == null or _in_view(cam)
	if _title != null:
		var tv := _onscreen and (_ring.visible or _near_camera())
		if _title.visible != tv:
			_title.visible = tv
	if _onscreen:
		if _rotor_spin != null:
			_rotor_spin.rotate_object_local(_rotor_axis, delta * 22.0)
		_animate_gait(delta)
	# Вне кадра наклон/кольцо не нужны: высоту ставит шаг движения; при входе в кадр наклон доведётся.
	if _onscreen or _settle_n < 30:
		_settle(delta)
		_seat_ring()
	_tick_modes(delta)
	Prof.add("unit.anim", ta)
	if NetGame.is_client() and NetGame.in_match:
		_net_follow(delta)
		_paint_hull()
		return
	var host := get_parent()
	if host != null and str(host.verdict) != "":
		return
	# Перенос остатка: при редких тиках (вне кадра) темп стрельбы не падает.
	_cooldown = maxf(_cooldown - delta, -0.2)
	if _stun > 0.0:
		_stun = maxf(_stun - delta, 0.0)
		_coasting = false
		_paint_hull()
		return
	var tl := Prof.t()
	var ok := linked()
	Prof.add("unit.link", tl)
	if not ok:
		_coasting = false
		_paint_hull()
		return
	var tc := Prof.t()
	var fought := false
	var tm := 0
	if ammo == 0:
		_tick_rearm(delta)
	else:
		fought = _combat(delta)
	Prof.add("unit.combat", tc)
	if fought:
		_paint_hull()
		return
	_paint_hull()
	tm = Prof.t()
	if _coasting:
		_coast(delta)
		Prof.add("unit.move", tm)
		return
	if BattleGrid.is_static(mover):
		return
	if BattleGrid.truck(mover) and _index >= _path.size():
		_haul_tick(delta)
	if _index < _path.size() and grid.blocked_for(_path[_index], side):
		return
	if _index < _path.size():
		var td := Prof.t()
		_tick_drive(delta)
		Prof.add("unit.drive", td)
		var target := grid.cell_center(_path[_index])
		target.y = grid.ride_height(_path[_index], mover)
		var to := target - global_position
		to.y = 0.0
		var ts := Prof.t()
		if _steer:
			_steer_to(delta, target, to)
		else:
			_step_to(delta, target, to)
		Prof.add("unit.step", ts)
	_tick_capture(delta)
	Prof.add("unit.move", tm)

func _apply_profile() -> void:
	_d_profile()
	_name = GameData.unit(mover, "name", _name)
	_speed = GameData.unit(mover, "speed", _speed)
	_turn_deg = GameData.unit(mover, "turn_deg", _turn_deg)
	_align = GameData.unit(mover, "align", _align)
	hull_max = GameData.unit(mover, "hull", hull_max)
	ammo_max = GameData.unit(mover, "ammo", -1)
	ammo = ammo_max

func _d_profile() -> void:
	match mover:
		BattleGrid.Mover.WALKER:
			_name = "Шагоход"
			_speed = 2.0
			_turn_deg = 55.0
			_align = 0.96
			hull_max = 84.0
		BattleGrid.Mover.UAV, BattleGrid.Mover.JET:
			_name = "БПЛА"
			_speed = 11.0
			_turn_deg = 70.0
			_steer = true
			hull_max = 32.0
		BattleGrid.Mover.ROTOR:
			_name = "Ротор"
			_speed = 6.0
			_turn_deg = 160.0
			_align = 0.2
			hull_max = 36.0
		BattleGrid.Mover.TRACK:
			_name = "Гусеницы"
			_speed = 3.4
			_turn_deg = 220.0
			_align = 0.93
			hull_max = 70.0
		BattleGrid.Mover.BIKE:
			_name = "Мото"
			_speed = 7.5
			_turn_deg = 200.0
			_steer = true
			hull_max = 22.0
		BattleGrid.Mover.ENGINEER:
			_name = "Инженер"
			_speed = 2.8
			_turn_deg = 300.0
			_align = 0.5
			hull_max = 18.0
		_:
			_name = "Пехота"
			_speed = 3.1
			_turn_deg = 320.0
			_align = 0.55
			hull_max = 24.0

func _step_to(delta: float, target: Vector3, to: Vector3) -> void:
	if to.length() > 0.04:
		_turn_toward(to, delta)
	var facing := _facing()
	var ready := to.length() <= 0.04 or facing.dot(to.normalized()) >= _align
	if ready:
		# Одна запись позиции за шаг (каждая запись обходит все дочерние узлы).
		var np := global_position.move_toward(target, _speed * _drive_k * delta)
		if _legal(np):
			# Высоту по рельефу сразу (иначе _settle сделает вторую запись трансформа).
			if not BattleGrid.airborne(mover) and grid != null:
				np.y = grid.height_at(np.x, np.z) + 0.02
			global_position = np
	if global_position.distance_to(target) < 0.08:
		_arrive()

func _steer_to(delta: float, target: Vector3, to: Vector3) -> void:
	if to.length() > 0.04:
		_turn_toward(to, delta)
	var np := global_position + _facing() * _speed * _drive_k * delta
	np.y = target.y
	if not _legal(np):
		return
	global_position = np
	var distance := Vector2(global_position.x, global_position.z).distance_to(Vector2(target.x, target.z))
	if distance < _closest:
		_closest = distance
	if distance < BattleGrid.TILE * 0.55 or (_closest < BattleGrid.TILE and distance > _closest + 0.2):
		_arrive()

func _coast(delta: float) -> void:
	var ahead := global_position + _facing() * BattleGrid.TILE
	if not grid.contains(grid.cell_from_world(ahead)):
		rotation.y += deg_to_rad(110.0) * delta
		return
	global_position += _facing() * _speed * _drive_k * delta
	global_position.y = grid.ride_height(grid.cell_from_world(global_position), mover)

func _combat(delta: float) -> bool:
	if weapon < 0:
		return false
	if has_point:
		return _combat_point(delta)
	if attack_site != null and (not is_instance_valid(attack_site) or not attack_site.is_hostile_hq(side)):
		attack_site = null
	if attack_site != null:
		return _combat_site(delta)
	if attack_target != null and not is_instance_valid(attack_target):
		attack_target = null
	var foe := attack_target
	if foe != null and not can_target(foe):
		foe = null
	if foe == null:
		var tf := Prof.t()
		foe = _nearest_foe(WeaponRack.range_of(weapon))
		Prof.add("c.foe", tf)
	if foe == null:
		return false
	var to := foe.global_position - global_position
	to.y = 0.0
	var distance := to.length()
	var reach := fire_range()
	var blocked := false
	if distance <= reach and not _arcs():
		# Линия огня через рельеф — раз в 0,25 с на цель.
		_los_left -= get_process_delta_time()
		if _los_left <= 0.0 or _los_foe != foe:
			_los_left = 0.25
			_los_foe = foe
			_los_blocked = grid.blocks_fire(global_position, foe.global_position)
		blocked = _los_blocked
	if distance <= reach and not blocked:
		if to.length() > 0.04:
			_turn_toward(to, delta)
		if to.length() <= 0.04 or _facing().dot(to.normalized()) > 0.45:
			var tq := Prof.t()
			_fire(foe.global_position + Vector3(0.0, 0.6, 0.0), foe, null, delta)
			Prof.add("c.fire", tq)
		return true
	if attack_target != null:
		var cell := grid.cell_from_world(foe.global_position)
		if cell != _chase:
			_chase = cell
			_set_path(cell)
		return false
	return false

func _combat_site(delta: float) -> bool:
	var to := attack_site.global_position - global_position
	to.y = 0.0
	var distance := to.length()
	var reach := fire_range()
	var blocked := not _arcs() and grid.blocks_fire(global_position, attack_site.global_position)
	if distance <= reach and not blocked:
		if to.length() > 0.04:
			_turn_toward(to, delta)
		if to.length() <= 0.04 or _facing().dot(to.normalized()) > 0.45:
			_fire(attack_site.global_position + Vector3(0.0, 1.2, 0.0), null, attack_site, delta)
		return true
	var cell := attack_site.terminal
	if cell != _chase:
		_chase = cell
		_set_path(cell)
	return false

func _nearest_foe(reach: float) -> BattleUnit:
	# Поиск цели раз в ~0,2 с по пространственной сетке.
	_foe_left -= get_process_delta_time()
	if _foe_left > 0.0 and (_foe_cache == null or (is_instance_valid(_foe_cache) and _foe_cache.hull > 0.0)):
		return _foe_cache if _foe_cache != null and is_instance_valid(_foe_cache) else null
	_foe_left = 0.18 + float(net_id % 5) * 0.02
	# Живая цель в радиусе удерживается дольше — пересканирование реже в гуще боя.
	if _foe_cache != null and is_instance_valid(_foe_cache) and _foe_cache.hull > 0.0 and _foe_cache.submerged_left <= 0.0:
		var d := _foe_cache.global_position - global_position
		d.y = 0.0
		if d.length() < reach * 0.8:
			_foe_left += 0.3
			return _foe_cache
	_foe_cache = _scan_foe(reach)
	return _foe_cache

func _scan_foe(reach: float) -> BattleUnit:
	var m := _mode_spec()
	var t := str(m.get("targets", "all")) if not m.is_empty() else "all"
	if t != "ground" and t != "air":
		t = "all"
	return UnitIndex.nearest_hostile(get_tree(), global_position, reach, MatchSetup.team_of(side), t)

func _build_hull() -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.1, 0.08, 0.12)
	_hull_bar = MeshInstance3D.new()
	_hull_bar.mesh = mesh
	_hull_bar.position = Vector3(0.0, _label_height() - 0.22, 0.0)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("d24a3a")
	_hull_bar.material_override = material
	_hull_bar.visible = false
	add_child(_hull_bar)

var _painted := -1.0

func _paint_hull() -> void:
	if _hull_bar == null or hull_max <= 0.0 or hull == _painted:
		return
	_painted = hull
	var ratio := clampf(hull / hull_max, 0.0, 1.0)
	_hull_bar.visible = ratio < 0.999
	_hull_bar.scale = Vector3(maxf(ratio, 0.05), 1.0, 1.0)

func _tick_capture(delta: float) -> void:
	if _site == null:
		return
	var here := grid.cell_from_world(global_position)
	var on_pad := _index >= _path.size() and here == _site.terminal
	_site.hack_step(delta, on_pad, side)
	if _site.team == side:
		_site = null

func _arrive() -> void:
	var tr := Prof.t()
	_arrive_body()
	Prof.add("unit.arrive", tr)

func _arrive_body() -> void:
	_index += 1
	_closest = 999.0
	if _index >= _path.size() and BattleGrid.fixed_wing(mover) and _post.x < 0:
		_coasting = true
	_rebuild_markers()

func _turn_toward(dir: Vector3, delta: float) -> void:
	var desired := atan2(dir.x, dir.z)
	var ny := rotate_toward(rotation.y, desired, deg_to_rad(_turn_deg) * delta)
	if ny != rotation.y:
		rotation.y = ny

func _facing() -> Vector3:
	return Vector3(sin(rotation.y), 0.0, cos(rotation.y))

func pick_points() -> Array[Vector3]:
	var list: Array[Vector3] = []
	var lift := 0.5
	match mover:
		BattleGrid.Mover.WALKER:
			lift = 1.05
		BattleGrid.Mover.UAV, BattleGrid.Mover.JET:
			lift = 0.08
		BattleGrid.Mover.ROTOR:
			lift = 0.45
		BattleGrid.Mover.TROOPER, BattleGrid.Mover.ENGINEER:
			lift = 0.85
		_:
			lift = 0.4
	list.append(global_position + Vector3(0.0, lift, 0.0))
	var nose := _facing()
	var wing := Vector3(nose.z, 0.0, -nose.x)
	if BattleGrid.fixed_wing(mover):
		list.append(global_position + nose * 0.85 + Vector3(0.0, 0.05, 0.0))
		list.append(global_position - nose * 0.55)
		list.append(global_position + wing * 1.15)
		list.append(global_position - wing * 1.15)
		list.append(global_position + wing * 0.6 + nose * 0.15)
		list.append(global_position - wing * 0.6 + nose * 0.15)
	elif mover == BattleGrid.Mover.ROTOR:
		list.append(global_position + nose * 0.75 + Vector3(0.0, 0.35, 0.0))
		list.append(global_position - nose * 1.05 + Vector3(0.0, 0.4, 0.0))
		list.append(global_position + Vector3(0.0, 0.85, 0.0))
	elif mover == BattleGrid.Mover.WALKER:
		list.append(global_position + Vector3(0.0, 1.7, 0.0))
		list.append(global_position + nose * 0.55 + Vector3(0.0, 1.0, 0.0))
	return list

func pick_reach() -> float:
	match mover:
		BattleGrid.Mover.UAV, BattleGrid.Mover.JET:
			return 1.05
		BattleGrid.Mover.ROTOR:
			return 0.85
		BattleGrid.Mover.WALKER:
			return 0.8
		BattleGrid.Mover.TRACK:
			return 0.75
		_:
			return 0.6

func ray_gap(origin: Vector3, dir: Vector3) -> float:
	var best := 999.0
	for point in pick_points():
		var along := (point - origin).dot(dir)
		if along <= 0.0:
			continue
		var closest := origin + dir * along
		best = minf(best, closest.distance_to(point))
	return best

func _legal(world: Vector3) -> bool:
	if BattleGrid.fixed_wing(mover):
		return grid.contains(grid.cell_from_world(world))
	return grid.can_enter(grid.cell_from_world(world), mover)

func _nearest_owned_cell() -> Vector2i:
	return grid.cell_from_world(global_position)

static var _mark_mesh: BoxMesh
static var _mark_mat: StandardMaterial3D
var _marks_dirty := false

# Метки пути видны только у выбранных: перестраиваются лениво и общими ресурсами.
func _rebuild_markers() -> void:
	if _markers == null:
		return
	if not _markers.visible:
		_marks_dirty = true
		return
	_marks_dirty = false
	for child in _markers.get_children():
		child.queue_free()
	if _mark_mesh == null:
		_mark_mesh = BoxMesh.new()
		_mark_mesh.size = Vector3(0.28, 0.08, 0.28)
		_mark_mat = StandardMaterial3D.new()
		_mark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mark_mat.albedo_color = Color("e2b15a")
	var mesh := _mark_mesh
	var material := _mark_mat
	for i in range(_index, _path.size()):
		var mark := MeshInstance3D.new()
		mark.mesh = mesh
		mark.material_override = material
		var at := grid.cell_center(_path[i])
		at.y = 0.35
		mark.position = at
		_markers.add_child(mark)

func _build_ring() -> void:
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.72
	mesh.outer_radius = 0.86
	if BattleGrid.fixed_wing(mover):
		mesh.inner_radius = 1.05
		mesh.outer_radius = 1.2
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("e6c15a")
	_ring = MeshInstance3D.new()
	_ring.mesh = mesh
	_ring.material_override = material
	_ring.position = Vector3(0.0, 0.08, 0.0)
	_ring.visible = false
	add_child(_ring)

func _seat_ring() -> void:
	if _ring == null:
		return
	if BattleGrid.airborne(mover):
		_ring.position.y = 0.1 - position.y

var _anchors: Array[Node3D] = []

# Деталь модели: при инстансинге — пустой якорь в общем MultiMesh, иначе обычный MeshInstance3D.
func _part(mesh: Mesh) -> Node3D:
	if UnitBatch.enabled and is_inside_tree():
		var anchor := Node3D.new()
		UnitBatch.get_or_make(get_parent()).register(anchor, mesh)
		_anchors.append(anchor)
		return anchor
	return ArtKit.node(mesh)

func _build_body() -> void:
	var art := UnitArt.make(mover, side != SitePlan.OWNER_PLAYER, MatchSetup.color_of(side).darkened(0.45))
	add_child(_part(art["body"]))
	for leg in art["legs"]:
		var pivot := Node3D.new()
		pivot.position = leg["at"]
		pivot.set_meta("phase", leg["phase"])
		pivot.add_child(_part(leg["mesh"]))
		add_child(pivot)
		_legs.append(pivot)
	if art["rotor"] != null:
		_rotor_spin = Node3D.new()
		_rotor_spin.position = art["rotor_at"]
		_rotor_axis = art.get("rotor_axis", Vector3.UP)
		_rotor_spin.add_child(_part(art["rotor"]))
		add_child(_rotor_spin)
	_title = Label3D.new()
	_title.text = _name
	_title.font_size = 28
	_title.pixel_size = 0.01
	_title.position = Vector3(0.0, _label_height(), 0.0)
	_title.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_title.no_depth_test = true
	_title.outline_size = 8
	add_child(_title)

func _label_height() -> float:
	match mover:
		BattleGrid.Mover.WALKER:
			return 2.25
		BattleGrid.Mover.UAV, BattleGrid.Mover.JET:
			return 0.55
		BattleGrid.Mover.ROTOR:
			return 1.35
		BattleGrid.Mover.TRACK:
			return 1.25
		BattleGrid.Mover.BIKE:
			return 1.45
		_:
			return 1.7

static var _muzzle_meshes := {}
var _muzzle_anchor: Node3D

# Огонёк дула: общий меш на (оружие, сила) — тоже через инстансинг.
static func _muzzle_mesh(kind: int, level: int) -> Mesh:
	var key := kind * 10 + level
	if not _muzzle_meshes.has(key):
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.08, 0.08, 0.12)
		var material := StandardMaterial3D.new()
		material.albedo_color = WeaponRack.color_of(kind)
		material.emission_enabled = true
		material.emission = WeaponRack.color_of(kind)
		material.emission_energy_multiplier = 0.35 + float(level) * 0.4
		mesh.material = material
		_muzzle_meshes[key] = mesh
	return _muzzle_meshes[key]

func _build_muzzle() -> void:
	_muzzle = MeshInstance3D.new()
	_muzzle.position = _muzzle_at()
	add_child(_muzzle)
	_paint_muzzle()

func _muzzle_at() -> Vector3:
	match mover:
		BattleGrid.Mover.WALKER:
			return Vector3(0.0, 1.12, 1.05)
		BattleGrid.Mover.UAV, BattleGrid.Mover.JET:
			return Vector3(0.0, -0.02, 0.95)
		BattleGrid.Mover.ROTOR:
			return Vector3(0.22, 0.28, 0.95)
		BattleGrid.Mover.TRACK:
			return Vector3(0.0, 0.62, 1.15)
		BattleGrid.Mover.BIKE:
			return Vector3(0.16, 0.72, 0.55)
		_:
			return Vector3(0.16, 0.92, 0.42)

func _paint_muzzle() -> void:
	if _muzzle == null:
		return
	_muzzle.visible = weapon >= 0
	if _title != null:
		_title.text = _name if weapon < 0 else "%s\n%s %s" % [_name, WeaponRack.title(weapon), WeaponRack.roman(tier)]
	if _muzzle_anchor != null:
		if UnitBatch.active():
			UnitBatch._inst.unregister(_muzzle_anchor)
		_anchors.erase(_muzzle_anchor)
		_muzzle_anchor.queue_free()
		_muzzle_anchor = null
	if weapon < 0:
		return
	var mesh := _muzzle_mesh(weapon, tier)
	if UnitBatch.enabled and is_inside_tree():
		_muzzle.mesh = null
		_muzzle_anchor = _part(mesh)
		_muzzle.add_child(_muzzle_anchor)
	else:
		_muzzle.mesh = mesh

func _team(color: Color) -> Color:
	if side != SitePlan.OWNER_PLAYER:
		return color.lerp(MatchSetup.color_of(side).darkened(0.4), 0.34)
	return color

func _metal(color: Color, rough: float = 0.38, shine: float = 0.78) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = _team(color)
	material.metallic = shine
	material.roughness = rough
	return material

func _glass(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.15
	material.roughness = 0.08
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 0.35
	return material

func _put(mesh: Mesh, at: Vector3, material: Material, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.position = at
	node.rotation = rot
	add_child(node)
	return node

func _slab(size: Vector3, at: Vector3, color: Color, rot: Vector3 = Vector3.ZERO, rough: float = 0.4) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _put(mesh, at, _metal(color, rough), rot)

func _tube(radius: float, length: float, at: Vector3, color: Color, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = length
	mesh.radial_segments = 10
	return _put(mesh, at, _metal(color, 0.45), rot)

func _ball(radius: float, at: Vector3, material: Material) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 10
	mesh.rings = 6
	return _put(mesh, at, material)

func _limb(radius: float, length: float, at: Vector3, color: Color, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = length
	mesh.radial_segments = 8
	return _put(mesh, at, _metal(color, 0.32, 0.88), rot)

func _strut(a: Vector3, b: Vector3, radius: float, color: Color) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius * 0.82
	mesh.height = maxf(a.distance_to(b), 0.05)
	mesh.radial_segments = 8
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = _metal(color, 0.34, 0.84)
	node.position = (a + b) * 0.5
	add_child(node)
	if a.distance_to(b) > 0.04:
		node.look_at(to_global(b), Vector3.UP)
		node.rotate_object_local(Vector3.RIGHT, PI * 0.5)

# Шаг: ноги качаются в противофазе, корпус покачивается. Скорость берём из смещения за кадр.
func _animate_gait(delta: float) -> void:
	if _legs.is_empty() or delta <= 0.0:
		return
	var moved := Vector2(global_position.x - _last_pos.x, global_position.z - _last_pos.z).length() / delta
	_last_pos = global_position
	_stride = lerpf(_stride, clampf(moved / maxf(_speed, 0.1), 0.0, 1.0), 1.0 - exp(-12.0 * delta))
	_gait += delta * _speed * (2.6 if mover == BattleGrid.Mover.WALKER else 4.2)
	var swing := 0.42 * _stride
	if _leg_ph.size() != _legs.size():
		_leg_ph.clear()
		_leg_y.clear()
		for leg in _legs:
			_leg_ph.append(float(leg.get_meta("phase")))
			_leg_y.append(_leg_base_y(leg))
	# Стоим на месте и ноги уже в покое — без записи трансформов.
	if _stride < 0.002 and _legs_rest:
		return
	_legs_rest = _stride < 0.002
	for i in _legs.size():
		var leg := _legs[i]
		var ph := _leg_ph[i]
		leg.rotation.x = sin(_gait + ph) * swing
		leg.position.y = _leg_y[i] + maxf(0.0, cos(_gait + ph)) * 0.04 * _stride

var _leg_ph := PackedFloat32Array()
var _leg_y := PackedFloat32Array()
var _legs_rest := false

func _leg_base_y(leg: Node3D) -> float:
	if not leg.has_meta("base_y"):
		leg.set_meta("base_y", leg.position.y)
	return leg.get_meta("base_y")

# Наземная техника и пехота стоят на рельефе и наклоняются по склону. Летающие держат горизонт.
var _settle_at := Vector3(INF, 0, INF)
var _settle_n := 0
var _pitch := 0.0
var _roll := 0.0

func _settle(delta: float) -> void:
	if grid == null or BattleGrid.airborne(mover):
		return
	var p := global_position
	var moved := absf(p.x - _settle_at.x) + absf(p.z - _settle_at.z) > 0.002
	if moved:
		_settle_at = p
		var hy := grid.height_at(p.x, p.z) + 0.02
		if absf(hy - p.y) > 0.0005:
			global_position = Vector3(p.x, hy, p.z)
	_settle_n += 1
	# Наклон по склону — раз в 4 кадра (разнесено по юнитам); между — плавная доводка.
	if _onscreen and (moved or _settle_n < 30) and (_settle_n + net_id) % 4 == 0:
		_lean_target(p)
	var k := 1.0 - exp(-8.0 * delta)
	if absf(rotation.x - _pitch) + absf(rotation.z - _roll) > 0.0005:
		var rot := rotation
		rotation = Vector3(lerp_angle(rot.x, _pitch, k), rot.y, lerp_angle(rot.z, _roll, k))

func _lean_target(p: Vector3) -> void:
	var lean := 1.0
	match mover:
		BattleGrid.Mover.TROOPER, BattleGrid.Mover.ENGINEER:
			lean = 0.25
		BattleGrid.Mover.WALKER:
			lean = 0.55
		BattleGrid.Mover.BIKE:
			lean = 0.9
	var n := grid.fast_normal(p.x, p.z)
	var fwd := Vector3(sin(rotation.y), 0.0, cos(rotation.y))
	var right := Vector3(fwd.z, 0.0, -fwd.x)
	_pitch = atan2(n.dot(fwd), n.y) * lean
	_roll = -atan2(n.dot(right), n.y) * lean


# --- Режимы оружия, заряд, развёртывание, огонь по точке, способности ---
func weapon_modes() -> Array:
	return Arsenal.modes(mover)

func set_mode(value: int) -> void:
	if NetGame.relay_unit(self, "set_mode", [value]):
		return
	if weapon < 0 or weapon_modes().is_empty():
		return
	mode = clampi(value, 0, 2)
	_deploy = 0.0

func _mode_spec() -> Dictionary:
	var list := weapon_modes()
	if list.is_empty():
		return {}
	var m: Dictionary = list[mode]
	if mode == Arsenal.MODE_SPECIAL and not special_ready():
		m = list[0]
	return m

func special_ready() -> bool:
	var list := weapon_modes()
	if list.size() < 3:
		return false
	return instant or charge >= float(list[2]["charge"])

func charge_ratio() -> float:
	var list := weapon_modes()
	if list.size() < 3:
		return 0.0
	if instant:
		return 1.0
	return clampf(charge / maxf(float(list[2]["charge"]), 0.1), 0.0, 1.0)

func current_kind() -> int:
	var m := _mode_spec()
	if m.is_empty() or int(m["kind"]) < 0:
		return weapon
	return int(m["kind"])

func current_icon() -> String:
	var m := _mode_spec()
	return "barrel" if m.is_empty() else str(m["icon"])

func fire_range() -> float:
	var m := _mode_spec()
	var mul := 1.0 if m.is_empty() else float(m["range"])
	return WeaponRack.range_of(current_kind()) * mul

func _arcs() -> bool:
	var k := current_kind()
	var m := _mode_spec()
	return k == WeaponRack.Kind.BOMB or k == WeaponRack.Kind.TESLA or k == WeaponRack.Kind.FLAME or (not m.is_empty() and bool(m["lob"]))

func muzzle_world() -> Vector3:
	return to_global(_muzzle_at())

func _fire(at: Vector3, foe: BattleUnit, site: CaptureSite, delta: float) -> void:
	var m := _mode_spec()
	var special := mode == Arsenal.MODE_SPECIAL and special_ready()
	if not m.is_empty() and float(m["deploy"]) > 0.0 and _deploy < float(m["deploy"]):
		_deploy += delta
		return
	if _cooldown > 0.0:
		return
	var k := current_kind()
	var shot := Volley.new()
	shot.setup_from(self)
	shot.kind = k
	shot.structure = site
	var dmg_tier := tier if k == weapon else maxi(WeaponRack.min_tier(k), tier)
	var mul := 1.0 if m.is_empty() else float(m["dmg"])
	shot.damage = WeaponRack.damage(k, dmg_tier) * mul
	shot.splash = maxf(WeaponRack.splash_of(k), 0.0 if m.is_empty() else float(m["splash"]))
	shot.stun = WeaponRack.stun_of(k)
	shot.chains = WeaponRack.chains_of(k)
	shot.speed = maxf(WeaponRack.speed_of(k), 12.0)
	shot.reach = fire_range()
	shot.lob = not m.is_empty() and bool(m["lob"])
	shot.origin = muzzle_world()
	if k == WeaponRack.Kind.BOMB:
		shot.origin = global_position - Vector3(0.0, 0.2, 0.0)
		at = Vector3(at.x, grid.terrain_y(at.x, at.z), at.z)
	shot.aim = at
	get_parent().add_child(shot)
	shot.global_position = shot.origin
	NetGame.shot_fx(shot)
	if ammo > 0:
		ammo -= 1
		if ammo == 0:
			_go_rearm()
	_cooldown = minf(_cooldown, 0.0) + WeaponRack.cooldown(k) * (1.0 if m.is_empty() else float(m["cd"]))
	if special:
		charge = 0.0
	if mode == Arsenal.MODE_SPECIAL and float(m.get("deploy", 0.0)) > 0.0:
		_deploy = float(m["deploy"]) * 0.6

func order_fire_at(point: Vector3) -> void:
	if NetGame.relay_unit(self, "order_fire_at", [point]):
		return
	if weapon < 0 or not linked():
		return
	attack_target = null
	attack_site = null
	_clear_post()
	attack_point = point
	has_point = true
	_chase = Vector2i(-99, -99)

func _combat_point(delta: float) -> bool:
	var to := attack_point - global_position
	to.y = 0.0
	if to.length() <= fire_range():
		if to.length() > 0.04:
			_turn_toward(to, delta)
		if to.length() <= 0.04 or _facing().dot(to.normalized()) > 0.45:
			_fire(attack_point + Vector3(0.0, 0.1, 0.0), null, null, delta)
		return true
	var cell := grid.cell_from_world(attack_point)
	if cell != _chase:
		_chase = cell
		_set_path(cell)
	return false

func stop_fire() -> void:
	has_point = false

func ability_info() -> Dictionary:
	return Arsenal.ability(mover)

func ability_ready() -> bool:
	return not ability_info().is_empty() and (instant or ability_cd <= 0.0)

# Возвращает описание сработавшей способности (эффект на карте применяет игра) или {}.
func use_ability() -> Dictionary:
	NetGame.relay_unit(self, "use_ability", [])
	if not ability_ready():
		return {}
	var info := ability_info()
	ability_cd = float(info["cooldown"])
	if mover == BattleGrid.Mover.WALKER or mover == BattleGrid.Mover.BOAT:
		shield_left = float(info["time"])
	if mover == BattleGrid.Mover.SUB:
		submerged_left = float(info["time"])
	return info

var _charge_max := -1.0

func _tick_modes(delta: float) -> void:
	if _charge_max < 0.0:
		var list := weapon_modes()
		_charge_max = float(list[2]["charge"]) if list.size() >= 3 else 0.0
	if _charge_max > 0.0:
		charge = minf(charge + delta, _charge_max)
	if ability_cd <= 0.0 and shield_left <= 0.0 and not god and _shield == null and mover != BattleGrid.Mover.TRACK:
		return
	ability_cd = maxf(ability_cd - delta, 0.0)
	shield_left = maxf(shield_left - delta, 0.0)
	if god or shield_left > 0.0:
		if _shield == null:
			_shield = MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 1.0
			sm.height = 2.0
			_shield.mesh = sm
			var mat := StandardMaterial3D.new()
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.albedo_color = Color(0.4, 0.8, 1.0, 0.16)
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			_shield.material_override = mat
			_shield.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_shield.position = Vector3(0.0, _label_height() * 0.4, 0.0)
			_shield.scale = Vector3.ONE * maxf(_label_height() * 0.55, 0.7)
			add_child(_shield)
		_shield.visible = shield_left > 0.0 or god
		(_shield.material_override as StandardMaterial3D).albedo_color.a = 0.08 if god and shield_left <= 0.0 else 0.2
	elif _shield != null:
		_shield.visible = false
	if mover == BattleGrid.Mover.TRACK:
		_animate_mortar(delta)

# Миномёт танка: по команде «Особый» стрела поднимает трубу над кормой, после залпа опускает.
func _animate_mortar(_delta: float) -> void:
	var list := weapon_modes()
	var need: float = float(list[2]["deploy"])
	var ratio := clampf(_deploy / need, 0.0, 1.0) if mode == Arsenal.MODE_SPECIAL else 0.0
	if _mortar == null:
		if ratio <= 0.0:
			return
		_mortar = Node3D.new()
		_mortar.position = Vector3(0.0, 0.5, -0.55)
		var b := ArtKit.Builder.new()
		b.box(Vector3(0.08, 0.5, 0.08), Vector3(0.0, 0.25, 0.0), Color("d9a83a"), ArtKit.METAL)
		b.cyl(0.09, 0.11, 0.5, Vector3(0.0, 0.62, 0.1), Color("2a2e26"), ArtKit.METAL, Vector3(0.5, 0, 0))
		b.box(Vector3(0.3, 0.06, 0.3), Vector3(0.0, 0.02, 0.0), Color("3a3d34"), ArtKit.METAL)
		_mortar.add_child(ArtKit.node(b.commit()))
		add_child(_mortar)
	_mortar.visible = ratio > 0.0
	_mortar.scale = Vector3(1.0, maxf(ratio, 0.01), 1.0)


# Режим "targets" в data/game.json: "all" (по умолчанию), "ground" — только наземные, "air" — только воздух.
func can_target(foe: BattleUnit) -> bool:
	var m := _mode_spec()
	var t := str(m.get("targets", "all")) if not m.is_empty() else "all"
	if t == "ground":
		return not BattleGrid.airborne(foe.mover)
	if t == "air":
		return BattleGrid.airborne(foe.mover)
	return true

func _rearm_time() -> float:
	return float(GameData.unit(mover, "rearm_seconds", 8.0))

func _home_field() -> CaptureSite:
	var best: CaptureSite = null
	var best_d := INF
	for node in get_tree().get_nodes_in_group("sites"):
		var site := node as CaptureSite
		if site.kind != SitePlan.KIND_AIR or site.team != side:
			continue
		var d := site.global_position.distance_to(global_position)
		if d < best_d:
			best_d = d
			best = site
	return best

func _go_rearm() -> void:
	attack_target = null
	attack_site = null
	has_point = false
	_base = _home_field()
	if _base != null:
		order_to(_base.terminal)

# Над своим аэродромом (в 3 клетках) копит перевооружение; аэродром потерян — ищет другой.
func _tick_rearm(delta: float) -> void:
	if _base == null or not is_instance_valid(_base) or _base.team != side:
		_base = _home_field()
		if _base != null:
			order_to(_base.terminal)
		return
	var pad := grid.cell_center(_base.terminal)
	var flat := global_position - pad
	flat.y = 0.0
	if flat.length() > BattleGrid.TILE * 3.0:
		if _index >= _path.size() and not _coasting:
			order_to(_base.terminal)
		return
	_rearm += delta
	if _rearm >= _rearm_time():
		_rearm = 0.0
		ammo = ammo_max
		hull = minf(hull_max, hull + hull_max * 0.25)


# Клиент: плавно догоняет положение из снимка хоста.
func _net_follow(delta: float) -> void:
	var k := clampf(delta * 10.0, 0.0, 1.0)
	var p := position.lerp(net_target, k)
	if not BattleGrid.airborne(mover):
		p.y = position.y
	position = p
	rotation.y = lerp_angle(rotation.y, net_rot, k)


func _enter_tree() -> void:
	UnitIndex.dirty()

func _exit_tree() -> void:
	UnitIndex.remove(self)
	_go_on()
	if UnitBatch.active():
		for a in _anchors:
			UnitBatch._inst.unregister(a)
	_anchors.clear()
	if grid != null and (mover == BattleGrid.Mover.WALL or mover == BattleGrid.Mover.GATE):
		var c := grid.cell_from_world(position)
		if grid.walls.get(c) == self:
			grid.walls.erase(c)
			grid.version += 1

func _zone_of(id: int) -> FlagZone:
	for node in get_tree().get_nodes_in_group("zones"):
		if (node as FlagZone).zone_id == id:
			return node
	return null

# Скорость от экономики: электро — от ⚡ сети, топливо — от ⛽. Топливо тратится на ходу.
var _power_cls := "?"
var _fuel_rate := 0.0
var _stock_ref: Stockpile

func _tick_drive(delta: float) -> void:
	if _power_cls == "?":
		_power_cls = str(GameData.unit(mover, "power", ""))
		_fuel_rate = float(GameData.unit(mover, "fuel_per_s", 0.1))
	var cls := _power_cls
	if cls == "":
		_drive_k = 1.0
		return
	if _stock_ref == null or not is_instance_valid(_stock_ref):
		_stock_ref = Stockpile.of(get_tree(), side)
	var stock := _stock_ref
	if stock == null:
		return
	if cls == "fuel":
		stock.burn_fuel(_fuel_rate * delta)
	_drive_tick -= delta
	if _drive_tick <= 0.0:
		_drive_tick = 0.5
		_drive_k = stock.drive_factor(cls)
		_smog(delta)
	if submerged_left > 0.0:
		submerged_left = maxf(0.0, submerged_left - delta)

# Смог угольной ТЭС: урон и меньший обзор рядом со станцией.
func _smog(_d: float) -> void:
	for node in get_tree().get_nodes_in_group("sites"):
		var site := node as CaptureSite
		if site.kind != SitePlan.KIND_COAL_PLANT or site.team <= 0:
			continue
		var r := float(GameData.site(site.kind, "smog_radius", 6.0)) * BattleGrid.TILE
		if site.global_position.distance_to(global_position) <= r:
			take_hit(float(GameData.site(site.kind, "smog_dps", 0.6)) * 0.5, 0.0, -1)

# Грузовик: свой ресурсный узел → погрузка → свой завод (штаб / завод техники) → продажа.
func _haul_tick(delta: float) -> void:
	if not linked():
		return
	var res := str(GameData.unit(mover, "hauls", ""))
	if res == "":
		return
	if _haul_wait > 0.0:
		_haul_wait -= delta
		if _haul_wait <= 0.0:
			if cargo <= 0.0:
				cargo = float(GameData.unit(mover, "capacity", 10.0))
			else:
				var stock := Stockpile.of(get_tree(), side)
				if stock != null:
					stock.deliver(res, cargo)
				cargo = 0.0
			_haul_goal = null
		return
	var here := grid.cell_from_world(global_position)
	if _haul_goal != null and is_instance_valid(_haul_goal) and absi(here.x - _haul_goal.terminal.x) + absi(here.y - _haul_goal.terminal.y) <= 1:
		var wait_s := float(GameData.site(_haul_goal.kind, "load_seconds", 3.0)) if cargo <= 0.0 else 2.0
		_haul_wait = wait_s
		return
	_haul_goal = _haul_source(res) if cargo <= 0.0 else _haul_depot()
	if _haul_goal != null:
		order_to(_haul_goal.terminal)

func _haul_source(res: String) -> CaptureSite:
	var best: CaptureSite = null
	var best_d := INF
	for node in get_tree().get_nodes_in_group("sites"):
		var site := node as CaptureSite
		if site.team != side or not SitePlan.is_resource(site.kind):
			continue
		if str(GameData.site(site.kind, "resource", "")) != res:
			continue
		var d := site.global_position.distance_to(global_position)
		if d < best_d:
			best_d = d
			best = site
	return best

func _haul_depot() -> CaptureSite:
	var best: CaptureSite = null
	var best_d := INF
	for node in get_tree().get_nodes_in_group("sites"):
		var site := node as CaptureSite
		if site.team != side or not (site.kind == SitePlan.KIND_HQ or site.kind == SitePlan.KIND_PLANT) or site.hull <= 0.0:
			continue
		var d := site.global_position.distance_to(global_position)
		if d < best_d:
			best_d = d
			best = site
	return best

# Ворота: auto — открыты своим и союзникам, open — всем, closed — никому.
func gate_closed_for(other_side: int) -> bool:
	match gate_mode:
		"open":
			return false
		"closed":
			return true
		_:
			return not MatchSetup.allied(other_side, side)

func cycle_gate() -> String:
	if NetGame.relay_unit(self, "cycle_gate", []):
		return gate_mode
	gate_mode = {"auto": "open", "open": "closed", "closed": "auto"}[gate_mode]
	return gate_mode


# Развернуть машину в базу (G): тягач → док (нужна вода рядом), автобус → казарма, тягач 12×2 → завод.
func deploy_check() -> String:
	var key := str(GameData.unit(mover, "deploys", ""))
	if key == "":
		return "Эта машина не разворачивается"
	var cell := grid.cell_from_world(global_position)
	if grid.kind_at(cell) != BattleGrid.CellKind.PLAIN:
		return "Нужна ровная площадка"
	if key == "DOCK" and _water_near(cell) == Vector2i(-1, -1):
		return "Док ставится только у воды"
	if _land_near(cell) == Vector2i(-1, -1):
		return "Нет места для подъезда"
	return ""

func _water_near(cell: Vector2i) -> Vector2i:
	for r in [1, 2]:
		for d in [Vector2i(r, 0), Vector2i(-r, 0), Vector2i(0, r), Vector2i(0, -r)]:
			if grid.contains(cell + d) and grid.kind_at(cell + d) == BattleGrid.CellKind.WATER:
				return cell + d
	return Vector2i(-1, -1)

func _land_near(cell: Vector2i) -> Vector2i:
	for d in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
		if grid.contains(cell + d) and grid.kind_at(cell + d) == BattleGrid.CellKind.PLAIN and not grid.walls.has(cell + d):
			return cell + d
	return Vector2i(-1, -1)

func deploy() -> CaptureSite:
	if NetGame.relay_unit(self, "deploy", []):
		return null
	if deploy_check() != "":
		return null
	var key := str(GameData.unit(mover, "deploys", ""))
	var cell := grid.cell_from_world(global_position)
	var term := _water_near(cell) if key == "DOCK" else _land_near(cell)
	var site := BuildRules.spawn_site(get_parent(), grid, GameData.SITE_KEYS.find(key), side, cell, term)
	queue_free()
	return site
