# Контрибьютор: vibic777
class_name IsoCamera
extends Node3D

const YAWS := [45.0, 135.0, 225.0, 315.0]
const VIEW_NAMES := ["ЮВ", "СВ", "СЗ", "ЮЗ"]
const PITCH_DEG := 35.264
const ARM := 48.0
const DEFAULT_SIZE := 24.0
const MIN_SIZE := 8.0
const MAX_SIZE := 48.0
const ZOOM_STEP := 2.5
const PAN_SPEED := 18.0

var _camera: Camera3D
var _grid: BattleGrid
var _view := 0
var _yaw := 0.0
var _target_yaw := 0.0
var _size := DEFAULT_SIZE
var _target_size := DEFAULT_SIZE
var _touches := {}
var _pinch := -1.0

func _ready() -> void:
	process_priority = -10
	_bind_input()
	_camera = $Camera3D
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.near = 0.05
	_camera.far = 800.0
	var grid := get_parent().get_node_or_null("Grid")
	if grid is BattleGrid:
		_grid = grid
		global_position = _grid.start_focus()
	_yaw = deg_to_rad(YAWS[0])
	_target_yaw = _yaw
	_apply_camera()

func _process(delta: float) -> void:
	_pan(delta)
	var blend := 1.0 - exp(-10.0 * delta)
	_yaw = lerp_angle(_yaw, _target_yaw, blend)
	_size = lerpf(_size, _target_size, blend)
	_apply_camera()
	_clamp_focus()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return
	if event is InputEventScreenTouch:
		_on_screen_touch(event)
		return
	if event is InputEventScreenDrag:
		_on_screen_drag(event)
		return
	if event.is_action_pressed("camera_rotate_left"):
		turn(1)
	elif event.is_action_pressed("camera_rotate_right"):
		turn(-1)
	elif event.is_action_pressed("camera_zoom_in"):
		zoom_by(-ZOOM_STEP * _zoom_sign())
	elif event.is_action_pressed("camera_zoom_out"):
		zoom_by(ZOOM_STEP * _zoom_sign())
	elif event.is_action_pressed("camera_normalize"):
		normalize_zoom()

func turn(steps: int) -> void:
	_view = wrapi(_view + steps, 0, 4)
	_target_yaw = deg_to_rad(YAWS[_view])

func zoom_by(delta_size: float) -> void:
	_target_size = clampf(_target_size + delta_size, MIN_SIZE, MAX_SIZE)

func normalize_zoom() -> void:
	_target_size = DEFAULT_SIZE

func view_name() -> String:
	return VIEW_NAMES[_view]

func zoom_percent() -> int:
	return int(round(DEFAULT_SIZE / _target_size * 100.0))

func _pan(delta: float) -> void:
	var stick := Input.get_vector("camera_pan_left", "camera_pan_right", "camera_pan_back", "camera_pan_forward")
	stick += _edge_scroll()
	if stick.length() > 1.0:
		stick = stick.normalized()
	if stick == Vector2.ZERO:
		return
	var look := Vector3(-sin(_yaw), 0.0, -cos(_yaw))
	var right := look.cross(Vector3.UP)
	position += (right * stick.x + look * stick.y) * PAN_SPEED * float(Settings.get_value("controls", "pan_speed")) * (_size / DEFAULT_SIZE) * delta

func _edge_scroll() -> Vector2:
	if DisplayServer.is_touchscreen_available() or not bool(Settings.get_value("controls", "edge_scroll")):
		return Vector2.ZERO
	var mouse := get_viewport().get_mouse_position()
	var size := get_viewport().get_visible_rect().size
	if mouse.x < 0.0 or mouse.y < 0.0 or mouse.x > size.x or mouse.y > size.y:
		return Vector2.ZERO
	var margin := 18.0
	var scroll := Vector2.ZERO
	if mouse.x < margin:
		scroll.x = -1.0
	elif mouse.x > size.x - margin:
		scroll.x = 1.0
	if mouse.y < margin:
		scroll.y = 1.0
	elif mouse.y > size.y - margin:
		scroll.y = -1.0
	return scroll

func _on_screen_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		_touches[event.index] = event.position
	else:
		_touches.erase(event.index)
	if _touches.size() < 2:
		_pinch = -1.0

func _on_screen_drag(event: InputEventScreenDrag) -> void:
	_touches[event.index] = event.position
	if _touches.size() >= 2:
		_pinch_zoom()
		return
	var before: Variant = _plane_point(event.position - event.relative)
	var after: Variant = _plane_point(event.position)
	if before == null or after == null:
		return
	position += before - after
	_clamp_focus()

func _pinch_zoom() -> void:
	var points: Array = _touches.values()
	if points.size() < 2:
		return
	var distance: float = points[0].distance_to(points[1])
	if _pinch > 0.0:
		zoom_by(-(distance - _pinch) * 0.045)
	_pinch = distance

func _plane_point(screen: Vector2) -> Variant:
	var origin := _camera.project_ray_origin(screen)
	var dir := _camera.project_ray_normal(screen)
	return Plane(Vector3.UP, 0.0).intersects_ray(origin, dir)

func _clamp_focus() -> void:
	if _grid == null:
		return
	var limit_x: float = float(BattleGrid.WIDTH) * BattleGrid.TILE
	var limit_z: float = float(BattleGrid.HEIGHT) * BattleGrid.TILE
	position.x = clampf(position.x, 0.0, limit_x)
	position.z = clampf(position.z, 0.0, limit_z)
	position.y = 0.0

func _apply_camera() -> void:
	var pitch := deg_to_rad(PITCH_DEG)
	var offset := Vector3(sin(_yaw) * cos(pitch), sin(pitch), cos(_yaw) * cos(pitch)) * ARM
	_camera.position = offset
	_camera.size = _size
	_camera.look_at(global_position, Vector3.UP)

func _bind_input() -> void:
	_key("camera_pan_forward", [KEY_W, KEY_UP])
	_key("camera_pan_back", [KEY_S, KEY_DOWN])
	_key("camera_pan_left", [KEY_A, KEY_LEFT])
	_key("camera_pan_right", [KEY_D, KEY_RIGHT])
	_key("camera_rotate_left", [KEY_Q])
	_key("camera_rotate_right", [KEY_E])
	_key("camera_zoom_in", [KEY_EQUAL, KEY_KP_ADD])
	_key("camera_zoom_out", [KEY_MINUS, KEY_KP_SUBTRACT])
	_key("camera_normalize", [KEY_HOME])
	_key("camera_base", [KEY_SPACE])
	_key("camera_selection", [KEY_BACKSPACE])
	_key("camera_alert", [KEY_END])
	_wheel("camera_zoom_in", MOUSE_BUTTON_WHEEL_UP)
	_wheel("camera_zoom_out", MOUSE_BUTTON_WHEEL_DOWN)
	Settings.apply_keys()

func _zoom_sign() -> float:
	return -1.0 if bool(Settings.get_value("controls", "invert_zoom")) else 1.0

func _key(action: StringName, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for keycode in keys:
		var event := InputEventKey.new()
		event.physical_keycode = keycode
		if _has_key(action, keycode):
			continue
		InputMap.action_add_event(action, event)

func _wheel(action: StringName, button: int) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	if _has_wheel(action, button):
		return
	var event := InputEventMouseButton.new()
	event.button_index = button
	InputMap.action_add_event(action, event)

func _has_key(action: StringName, keycode: int) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey and event.physical_keycode == keycode:
			return true
	return false

func _has_wheel(action: StringName, button: int) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventMouseButton and event.button_index == button:
			return true
	return false
