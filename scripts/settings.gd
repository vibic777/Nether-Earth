# Контрибьютор: vibic777
# Настройки игры: user://settings.cfg. Значения по умолчанию = текущее качество (high).
class_name Settings
extends RefCounted

const PATH := "user://settings.cfg"

const DEFAULTS := {
	"graphics": {"preset": "high", "shadows": 2, "msaa": 2, "grass": true, "water_waves": true, "glow": true, "render_scale": 1.0},
	"display": {"fullscreen": false, "resolution": "1280x720", "vsync": true, "fps_limit": 0},
	"ui": {"text_scale": 1.0, "menu_scale": 1.0, "tooltip_seconds": 5},
	"audio": {"master": 80, "music": 70, "sfx": 80},
	"controls": {"edge_scroll": true, "pan_speed": 1.0, "invert_zoom": false},
	"keys": {},
	"log": {"enabled": false, "trace": false, "debug": false, "info": true, "warning": true, "error": true, "critical": true, "crash_capture": false},
	"net": {"port": 24680, "player_name": "Игрок", "game_name": "Игра Nether Earth Reloaded", "last_address": ""},
}

# Переназначаемые действия (клавиатура). Остальные горячие клавиши — в справке.
const REBINDABLE := {
	"camera_pan_forward": "Камера вперёд", "camera_pan_back": "Камера назад",
	"camera_pan_left": "Камера влево", "camera_pan_right": "Камера вправо",
	"camera_rotate_left": "Поворот против часовой", "camera_rotate_right": "Поворот по часовой",
	"camera_zoom_in": "Приблизить", "camera_zoom_out": "Отдалить", "camera_normalize": "Масштаб 100%",
	"camera_base": "К своей базе / к последней тревоге", "camera_selection": "К выбранным",
	"camera_alert": "К последнему событию",
}

static func apply_keys() -> void:
	if not _loaded:
		load_all()
	var keys: Dictionary = values["keys"]
	for action in keys:
		if not InputMap.has_action(action):
			continue
		for ev in InputMap.action_get_events(action):
			if ev is InputEventKey:
				InputMap.action_erase_event(action, ev)
		var e := InputEventKey.new()
		e.physical_keycode = int(keys[action])
		InputMap.action_add_event(action, e)

static func bind_key(action: String, keycode: int) -> void:
	values["keys"][action] = keycode
	apply_keys()

static func key_label(action: String) -> String:
	var names: Array[String] = []
	if InputMap.has_action(action):
		for ev in InputMap.action_get_events(action):
			if ev is InputEventKey:
				names.append(OS.get_keycode_string(ev.physical_keycode))
	return ", ".join(names)

const PRESETS := {
	"low": {"shadows": 0, "msaa": 0, "grass": false, "water_waves": false, "glow": false, "render_scale": 0.75},
	"medium": {"shadows": 1, "msaa": 0, "grass": true, "water_waves": true, "glow": false, "render_scale": 1.0},
	"high": {"shadows": 2, "msaa": 2, "grass": true, "water_waves": true, "glow": true, "render_scale": 1.0},
}

const RESOLUTIONS := ["1280x720", "1366x768", "1600x900", "1920x1080", "2560x1440", "3840x2160"]
const FPS_LIMITS := [0, 30, 60, 75, 120, 144, 165, 240]

static var values := {}
static var _loaded := false

static func get_value(section: String, key: String) -> Variant:
	if not _loaded:
		load_all()
	return values[section][key]

static func set_value(section: String, key: String, value: Variant) -> void:
	if not _loaded:
		load_all()
	values[section][key] = value
	if section == "graphics" and key != "preset":
		values["graphics"]["preset"] = "custom"

static func apply_preset(name: String) -> void:
	if not PRESETS.has(name):
		return
	for key in PRESETS[name]:
		values["graphics"][key] = PRESETS[name][key]
	values["graphics"]["preset"] = name

static func load_all() -> void:
	_loaded = true
	values = DEFAULTS.duplicate(true)
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	for section in values:
		for key in values[section]:
			if cfg.has_section_key(section, key):
				values[section][key] = cfg.get_value(section, key)
	if cfg.has_section("keys"):
		for key in cfg.get_section_keys("keys"):
			values["keys"][key] = cfg.get_value("keys", key)

static func save_all() -> void:
	var cfg := ConfigFile.new()
	for section in values:
		for key in values[section]:
			cfg.set_value(section, key, values[section][key])
	cfg.save(PATH)

static func reset_defaults() -> void:
	values = DEFAULTS.duplicate(true)

static func _bus(name: String) -> int:
	var idx := AudioServer.get_bus_index(name)
	if idx < 0:
		AudioServer.add_bus()
		idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, name)
		AudioServer.set_bus_send(idx, "Master")
	return idx

static func _db(percent: float) -> float:
	return -80.0 if percent <= 0.0 else linear_to_db(percent / 100.0)

# Применить всё к работающей игре.
static func apply(tree: SceneTree) -> void:
	if not _loaded:
		load_all()
	var g: Dictionary = values["graphics"]
	var d: Dictionary = values["display"]
	var root := tree.root
	root.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X, Viewport.MSAA_8X][[0, 2, 4, 8].find(int(g["msaa"])) if [0, 2, 4, 8].has(int(g["msaa"])) else 0]
	root.scaling_3d_scale = clampf(float(g["render_scale"]), 0.5, 1.0)
	RenderingServer.directional_shadow_atlas_set_size(2048 if int(g["shadows"]) == 1 else 4096, true)
	var main := root.get_node_or_null("Main")
	if main == null and root.get_child_count() > 0:
		main = root.get_child(root.get_child_count() - 1)
	if main != null:
		var sun := main.get_node_or_null("Sun") as DirectionalLight3D
		if sun != null:
			sun.shadow_enabled = int(g["shadows"]) > 0
		var we := main.get_node_or_null("WorldEnvironment") as WorldEnvironment
		if we != null and we.environment != null:
			we.environment.glow_enabled = bool(g["glow"])
	for node in tree.get_nodes_in_group("grass"):
		node.visible = bool(g["grass"])
	for node in tree.get_nodes_in_group("water"):
		var mat := (node as MeshInstance3D).material_override as ShaderMaterial
		if mat != null:
			mat.set_shader_parameter("waves", 1.0 if bool(g["water_waves"]) else 0.0)
	Engine.max_fps = int(d["fps_limit"])
	if not DisplayServer.get_name() in ["headless"]:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if bool(d["vsync"]) else DisplayServer.VSYNC_DISABLED)
		if bool(d["fullscreen"]):
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		else:
			if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			var parts := str(d["resolution"]).split("x")
			if parts.size() == 2:
				DisplayServer.window_set_size(Vector2i(int(parts[0]), int(parts[1])))
	root.content_scale_factor = clampf(float(values["ui"]["menu_scale"]), 0.6, 2.0)
	var a: Dictionary = values["audio"]
	AudioServer.set_bus_volume_db(0, _db(float(a["master"])))
	AudioServer.set_bus_volume_db(_bus("Music"), _db(float(a["music"])))
	AudioServer.set_bus_volume_db(_bus("SFX"), _db(float(a["sfx"])))
	tree.call_group("settings_listeners", "on_settings_changed")
