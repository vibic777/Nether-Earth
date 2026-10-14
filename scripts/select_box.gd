# Контрибьютор: vibic777
extends Control

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var game := get_parent().get_parent()
	if game == null or not game.dragging():
		return
	var rect: Rect2 = game.drag_rect()
	if rect.size.x < 6.0 and rect.size.y < 6.0:
		return
	draw_rect(rect, Color(0.93, 0.82, 0.42, 0.16), true)
	draw_rect(rect, Color(0.98, 0.9, 0.45, 0.95), false, 2.0)
