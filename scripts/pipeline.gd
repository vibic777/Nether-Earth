# Контрибьютор: vibic777
# Газопровод от завода к своей газовой скважине. Цел и зона наша — газ идёт сам.
class_name Pipeline
extends Node

var side := 0
var well: CaptureSite
var segments: Array = []
var _acc := 0.0

func alive() -> bool:
	if well == null or not is_instance_valid(well) or well.team != side:
		return false
	for s in segments:
		if not is_instance_valid(s) or s.hull <= 0.0:
			return false
	return true

func _process(delta: float) -> void:
	if NetGame.is_client() and NetGame.in_match:
		return
	if well == null or not is_instance_valid(well):
		queue_free()
		return
	if not alive():
		return
	var cfg: Dictionary = Stockpile.eco("pipeline", {})
	_acc += float(cfg.get("gas_per_s", 0.8)) * delta
	if _acc >= 1.0:
		var stock := Stockpile.of(get_tree(), side)
		if stock != null:
			stock.deliver("gas", _acc)
		_acc = 0.0

# Клетки по прямой (Брезенхэм) от a до b, без самих концов.
static func line_cells(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var dx := absi(b.x - a.x)
	var dy := -absi(b.y - a.y)
	var sx := 1 if a.x < b.x else -1
	var sy := 1 if a.y < b.y else -1
	var err := dx + dy
	var p := a
	while p != b:
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			p.x += sx
		if e2 <= dx:
			err += dx
			p.y += sy
		if p != b:
			out.append(p)
	return out
