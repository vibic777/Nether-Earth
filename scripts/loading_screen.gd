# Контрибьютор: vibic777
# Экран загрузки: процедурная иллюстрация (две армии — танки, шагоходы, самолёты — идут навстречу),
# полоса прогресса и строка этапа. Живёт в корне дерева и переживает смену сцены.
# Этапы сообщают сами загрузчики: LoadingScreen.report(доля, "текст").
class_name LoadingScreen
extends CanvasLayer

static var _inst: LoadingScreen

var _bar: ProgressBar
var _status: Label
var _view: SubViewport
var _army: Array = []        # [{node, dir, speed, base}]
var _flashes: Array = []
var _t := 0.0
var _fade := -1.0
var _shade: ColorRect

static func open(tree: SceneTree, title: String = "Загрузка") -> LoadingScreen:
	if _inst != null and is_instance_valid(_inst):
		_inst._fade = -1.0
		_inst._shade.modulate.a = 1.0
		_inst.report(0.0, title)
		return _inst
	_inst = LoadingScreen.new()
	tree.root.add_child(_inst)
	_inst.report(0.0, title)
	return _inst

static func active() -> bool:
	return _inst != null and is_instance_valid(_inst) and _inst._fade < 0.0

# Обновить прогресс и дать кадру отрисоваться (await LoadingScreen.report(...)).
static func step(tree: SceneTree, fraction: float, text: String) -> void:
	if not active():
		return
	_inst.report(fraction, text)
	await tree.process_frame
	await tree.process_frame

static func close() -> void:
	if _inst != null and is_instance_valid(_inst):
		_inst.report(1.0, "Готово")
		_inst._fade = 0.0

func report(fraction: float, text: String) -> void:
	_bar.value = clampf(fraction, 0.0, 1.0) * 100.0
	_status.text = text
	print("[загрузка] %d%% %s" % [int(_bar.value), text])

func _init() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	_shade = ColorRect.new()
	_shade.color = Color(0.02, 0.03, 0.03)
	_shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_shade)
	var holder := SubViewportContainer.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.stretch = true
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shade.add_child(holder)
	_view = SubViewport.new()
	_view.own_world_3d = true
	_view.msaa_3d = Viewport.MSAA_4X
	holder.add_child(_view)
	_scene()
	var grad := TextureRect.new()
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0.0))
	g.set_color(1, Color(0, 0, 0, 0.85))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0.45)
	gt.fill_to = Vector2(0, 1)
	grad.texture = gt
	grad.set_anchors_preset(Control.PRESET_FULL_RECT)
	grad.stretch_mode = TextureRect.STRETCH_SCALE
	grad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shade.add_child(grad)
	var title := Label.new()
	title.text = "NETHER EARTH RELOADED"
	title.add_theme_font_size_override("font_size", 54)
	title.add_theme_color_override("font_color", Color("e8f4ea"))
	title.add_theme_color_override("font_outline_color", Color("0c1a12"))
	title.add_theme_constant_override("outline_size", 12)
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(-500, 40)
	title.size = Vector2(1000, 70)
	_shade.add_child(title)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	box.position = Vector2(-380, -130)
	box.size = Vector2(760, 90)
	box.add_theme_constant_override("separation", 8)
	_shade.add_child(box)
	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_font_size_override("font_size", 20)
	_status.add_theme_color_override("font_color", Color("b8e0c4"))
	box.add_child(_status)
	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(760, 22)
	_bar.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("5fe08a")
	fill.set_corner_radius_all(4)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0.08, 0.12, 0.1, 0.9)
	back.border_color = Color("3a6a4a")
	back.set_border_width_all(1)
	back.set_corner_radius_all(4)
	_bar.add_theme_stylebox_override("fill", fill)
	_bar.add_theme_stylebox_override("background", back)
	box.add_child(_bar)
	var ver := Label.new()
	ver.text = "v" + GameVersion.version()
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ver.add_theme_color_override("font_color", Color(0.6, 0.7, 0.65, 0.7))
	box.add_child(ver)

# Иллюстрация: равнина в дымке, зелёные слева, красные справа; самолёты над строем; вспышки выстрелов.
func _scene() -> void:
	seed(7)
	var env := Environment.new()
	var sky := ProceduralSkyMaterial.new()
	sky.sky_top_color = Color("2e4a66")
	sky.sky_horizon_color = Color("d89a62")
	sky.ground_horizon_color = Color("6a5a48")
	sky.ground_bottom_color = Color("2a2620")
	var s := Sky.new()
	s.sky_material = sky
	env.background_mode = Environment.BG_SKY
	env.sky = s
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color("c8946a")
	env.fog_density = 0.0045
	env.ambient_light_energy = 0.6
	env.glow_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	_view.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-24, -35, 0)
	sun.light_color = Color("ffd8a8")
	sun.light_energy = 1.6
	sun.shadow_enabled = true
	_view.add_child(sun)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 3.2, 11.5)
	cam.rotation_degrees = Vector3(-12, 0, 0)
	cam.fov = 50
	_view.add_child(cam)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(120, 80)
	pm.subdivide_width = 60
	pm.subdivide_depth = 40
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color("4a5a34")
	gm.roughness = 1.0
	ground.material_override = gm
	_view.add_child(ground)
	var b := ArtKit.Builder.new()
	for i in 40:
		var x := randf_range(-30, 30)
		var z := randf_range(-30, 4)
		b.rock(randf_range(0.2, 0.9), Vector3(x, 0.05, z), Color("6a6a5e").lerp(Color("7a6a4e"), randf()), Vector3(1.3, 0.6, 1.1), i)
	for i in 6:
		b.rock(randf_range(4, 7), Vector3(-26 + i * 10, -1.0, -28), Color("4a4a42"), Vector3(1.5, 0.9, 1.0), 50 + i, 0.4)
	_view.add_child(ArtKit.node(b.commit()))
	var green := Color("5fe08a").darkened(0.45)
	var red := Color("ff5a4a").darkened(0.45)
	var lineup := [BattleGrid.Mover.TRACK, BattleGrid.Mover.WALKER, BattleGrid.Mover.TRACK, BattleGrid.Mover.WALKER, BattleGrid.Mover.TRACK]
	for i in lineup.size():
		_soldier(lineup[i], false, green, Vector3(-4.0 - (i % 2) * 1.4, 0, 2.0 - i * 1.6), 1.0)
		_soldier(lineup[i], true, red, Vector3(4.0 + (i % 2) * 1.4, 0, 2.0 - i * 1.6), -1.0)
	_soldier(BattleGrid.Mover.JET, false, green, Vector3(-7, 3.4, -5.0), 1.0, 3.0)
	_soldier(BattleGrid.Mover.JET, true, red, Vector3(7, 3.9, -1.0), -1.0, 3.0)
	_soldier(BattleGrid.Mover.ROTOR, false, green, Vector3(-6, 2.4, -6.0), 1.0, 0.6)
	_soldier(BattleGrid.Mover.UAV, true, red, Vector3(6, 2.8, -7.0), -1.0, 0.8)
	for i in 6:
		var f := OmniLight3D.new()
		f.light_color = Color("ffb060")
		f.omni_range = 2.5
		f.light_energy = 0.0
		_view.add_child(f)
		_flashes.append(f)

func _soldier(mover: int, enemy: bool, tint: Color, at: Vector3, dir: float, speed: float = 0.35) -> void:
	var art := UnitArt.make(mover, enemy, tint)
	var root := Node3D.new()
	root.add_child(ArtKit.node(art["body"]))
	for leg in art["legs"]:
		var p := Node3D.new()
		p.position = leg["at"]
		p.add_child(ArtKit.node(leg["mesh"]))
		p.set_meta("phase", leg["phase"])
		root.add_child(p)
	if art["rotor"] != null:
		var r := ArtKit.node(art["rotor"], art["rotor_at"])
		r.name = "Rotor"
		root.add_child(r)
	root.position = at
	root.rotation.y = PI * 0.5 * dir
	root.scale = Vector3.ONE * 1.25
	_view.add_child(root)
	_army.append({"node": root, "dir": dir, "speed": speed, "base": at, "air": at.y > 0.5})

func _process(delta: float) -> void:
	_t += delta
	for a in _army:
		var n: Node3D = a["node"]
		var span := 16.0 if a["air"] else 2.2
		var off := fmod(_t * float(a["speed"]), span)
		n.position.x = float(a["base"].x) + float(a["dir"]) * (off - (span * 0.5 if a["air"] else 0.0))
		if a["air"]:
			n.position.y = float(a["base"].y) + sin(_t * 1.3 + n.position.z) * 0.15
		var rotor := n.get_node_or_null("Rotor")
		if rotor != null:
			rotor.rotation.y += delta * 30.0
		for child in n.get_children():
			if child.has_meta("phase"):
				child.rotation.x = sin(_t * 5.0 + float(child.get_meta("phase")) * TAU) * 0.45
	for i in _flashes.size():
		var f: OmniLight3D = _flashes[i]
		var phase := fmod(_t * 1.7 + i * 0.37, 1.0)
		if phase < 0.06:
			var src: Node3D = _army[(i * 3) % 10]["node"]
			f.position = src.global_position + Vector3(float(_army[(i * 3) % 10]["dir"]) * 1.2, 0.7, 0)
			f.light_energy = 6.0
		else:
			f.light_energy = maxf(0.0, f.light_energy - delta * 40.0)
	if _fade >= 0.0:
		_fade += delta
		_shade.modulate.a = 1.0 - clampf(_fade / 0.5, 0.0, 1.0)
		if _fade >= 0.5:
			_inst = null
			queue_free()
