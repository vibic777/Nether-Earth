# Контрибьютор: vibic777
# Миникарта: клетки, узлы, юниты, рамка обзора камеры. ЛКМ/перетаскивание — камера, ПКМ — приказ выбранным.
class_name Minimap
extends Control

var grid: BattleGrid
var camera_rig: Node3D
var game: Node
var _tex: ImageTexture
var _held := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true

func _bake() -> void:
	var img := Image.create(BattleGrid.WIDTH, BattleGrid.HEIGHT, false, Image.FORMAT_RGB8)
	for z in BattleGrid.HEIGHT:
		for x in BattleGrid.WIDTH:
			var c := Color("4f6a36")
			match grid.kind_at(Vector2i(x, z)):
				BattleGrid.CellKind.WATER: c = Color("1f5a70")
				BattleGrid.CellKind.TREE: c = Color("2f5230")
				BattleGrid.CellKind.STONE: c = Color("777466")
				BattleGrid.CellKind.MOUNTAIN: c = Color("9a968c")
				BattleGrid.CellKind.BUILDING: c = Color("b08a62")
				BattleGrid.CellKind.LINK: c = Color("6a6a66")
			img.set_pixel(x, z, c)
	_tex = ImageTexture.create_from_image(img)

func rebake() -> void:
	_tex = null

func _scale() -> Vector2:
	return size / Vector2(BattleGrid.WIDTH * BattleGrid.TILE, BattleGrid.HEIGHT * BattleGrid.TILE)

func _to_map(w: Vector3) -> Vector2:
	return Vector2(w.x, w.z) * _scale()

func _process(_d: float) -> void:
	var _pt := Prof.t()
	_process_inner(_d)
	Prof.add("minimap", _pt)

var _redraw_left := 0.0
var _fog_img: Image
var _fog_tex: ImageTexture
var _fog_ver := -1

# Миникарта перерисовывается 15 раз в секунду (камера — каждый кадр не нужна точнее).
func _process_inner(d: float) -> void:
	_redraw_left -= d
	if _redraw_left <= 0.0 or _held:
		_redraw_left = 1.0 / 15.0
		queue_redraw()

func _draw() -> void:
	if grid == null:
		return
	if _tex == null:
		_bake()
	draw_texture_rect(_tex, Rect2(Vector2.ZERO, size), false)
	for node in get_tree().get_nodes_in_group("sites"):
		var site := node as CaptureSite
		var col := Color("d2c07a")
		if site.team == SitePlan.OWNER_PLAYER: col = Color("5fe08a")
		elif site.team > 0: col = MatchSetup.color_of(site.team)
		var p := _to_map(site.global_position)
		draw_rect(Rect2(p - Vector2(5, 5), Vector2(10, 10)), col)
		draw_rect(Rect2(p - Vector2(5, 5), Vector2(10, 10)), Color.BLACK, false, 1.0)
	for node in get_tree().get_nodes_in_group("units"):
		var unit := node as BattleUnit
		if unit.hull <= 0.0:
			continue
		if not MatchSetup.allied(unit.side, SitePlan.OWNER_PLAYER) and not unit.visible:
			continue
		var col := Color("8cf0ff") if unit.side == SitePlan.OWNER_PLAYER else MatchSetup.color_of(unit.side)
		if game != null and game.selected_units.has(unit):
			col = Color.WHITE
		draw_circle(_to_map(unit.global_position), 3.0, col)
	if game != null and game.fog != null and game.fog.enabled:
		# Туман на миникарте — одна текстура (раньше — прямоугольник на каждую клетку).
		if _fog_ver != game.fog.version:
			_fog_ver = game.fog.version
			var st: PackedByteArray = game.fog.state
			var rgba := PackedByteArray()
			rgba.resize(st.size() * 4)
			for i in st.size():
				var a := 217 if st[i] == FogOfWar.UNSEEN else (102 if st[i] == FogOfWar.MEMORY else 0)
				rgba[i * 4 + 3] = a
			if _fog_img == null:
				_fog_img = Image.create_from_data(BattleGrid.WIDTH, BattleGrid.HEIGHT, false, Image.FORMAT_RGBA8, rgba)
				_fog_tex = ImageTexture.create_from_image(_fog_img)
			else:
				_fog_img.set_data(BattleGrid.WIDTH, BattleGrid.HEIGHT, false, Image.FORMAT_RGBA8, rgba)
				_fog_tex.update(_fog_img)
		var cs := _scale() * BattleGrid.TILE
		draw_texture_rect(_fog_tex, Rect2(Vector2.ZERO, Vector2(BattleGrid.WIDTH, BattleGrid.HEIGHT) * cs), false)
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		var vs := get_viewport().get_visible_rect().size
		var pts := PackedVector2Array()
		for c in [Vector2.ZERO, Vector2(vs.x, 0), vs, Vector2(0, vs.y)]:
			var o := cam.project_ray_origin(c)
			var d := cam.project_ray_normal(c)
			if absf(d.y) > 0.001:
				pts.append(_to_map(o + d * (-o.y / d.y)))
		if pts.size() == 4:
			pts.append(pts[0])
			draw_polyline(pts, Color(1, 1, 1, 0.9), 1.5)
	draw_rect(Rect2(Vector2.ZERO, size), Color("c9b06a"), false, 2.0)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var b := event as InputEventMouseButton
		if b.button_index == MOUSE_BUTTON_LEFT:
			_held = b.pressed
			if b.pressed:
				_jump(b.position)
			accept_event()
		elif b.button_index == MOUSE_BUTTON_RIGHT and b.pressed and game != null and game.has_method("order_from_minimap"):
			game.order_from_minimap(_cell(b.position))
			accept_event()
	elif event is InputEventMouseMotion and _held:
		_jump(event.position)
		accept_event()

func _cell(p: Vector2) -> Vector2i:
	var w := p / _scale()
	return Vector2i(clampi(int(w.x / BattleGrid.TILE), 0, BattleGrid.WIDTH - 1), clampi(int(w.y / BattleGrid.TILE), 0, BattleGrid.HEIGHT - 1))

func _jump(p: Vector2) -> void:
	if camera_rig == null:
		return
	var w := p / _scale()
	camera_rig.position = Vector3(w.x, 0.0, w.y)
