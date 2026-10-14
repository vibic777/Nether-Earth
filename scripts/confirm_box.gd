# Контрибьютор: vibic777
# Окно подтверждения: «Да» / «Нет», Esc — «Нет», Enter — «Да». ConfirmBox.ask(tree, текст, действие).
class_name ConfirmBox
extends CanvasLayer

static var _open: ConfirmBox
var _yes: Callable

static func is_open() -> bool:
	return _open != null and is_instance_valid(_open)

static func ask(tree: SceneTree, text: String, on_yes: Callable, yes_text: String = "Да", no_text: String = "Нет") -> ConfirmBox:
	if is_open():
		_open.queue_free()
	var box := ConfirmBox.new()
	box.layer = 110
	box._yes = on_yes
	box._build(text, yes_text, no_text)
	tree.root.add_child(box)
	_open = box
	return box

func _build(text: String, yes_text: String, no_text: String) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.09, 0.11, 0.96)
	sb.border_color = Color(0.35, 0.85, 1.0, 0.8)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(22)
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 18)
	panel.add_child(col)
	var label := Label.new()
	label.name = "Text"
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 22)
	col.add_child(label)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	col.add_child(row)
	var yes := Button.new()
	yes.name = "Yes"
	yes.text = yes_text
	yes.custom_minimum_size = Vector2(140, 40)
	yes.pressed.connect(confirm)
	row.add_child(yes)
	var no := Button.new()
	no.name = "No"
	no.text = no_text
	no.custom_minimum_size = Vector2(140, 40)
	no.pressed.connect(cancel)
	row.add_child(no)
	no.call_deferred("grab_focus")

func confirm() -> void:
	var cb := _yes
	queue_free()
	_open = null
	if cb.is_valid():
		cb.call()

func cancel() -> void:
	queue_free()
	_open = null

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			cancel()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			confirm()
			get_viewport().set_input_as_handled()
