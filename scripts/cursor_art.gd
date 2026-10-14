# Контрибьютор: vibic777
# Курсоры в классическом RTS-стиле, рисуются в коде со сглаживанием (SDF + 4×4 выборки).
class_name CursorArt
extends RefCounted

const SIZE := 48
const INK := Color(0.03, 0.035, 0.04, 1.0)

# Возвращает {"tex": ImageTexture, "hot": Vector2}
static func make(name: String) -> Dictionary:
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	for y in SIZE:
		for x in SIZE:
			var acc := Color(0, 0, 0, 0)
			for sy in 4:
				for sx in 4:
					var p := Vector2(x + (sx + 0.5) / 4.0, y + (sy + 0.5) / 4.0)
					acc += _sample(name, p)
			acc /= 16.0
			if acc.a > 0.001:
				img.set_pixel(x, y, Color(acc.r / acc.a, acc.g / acc.a, acc.b / acc.a, acc.a))
			else:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
	var hot := Vector2(SIZE * 0.5, SIZE * 0.5)
	if name == "arrow":
		hot = Vector2(3, 3)
	elif name == "capture":
		hot = Vector2(12, 44)
	return {"tex": ImageTexture.create_from_image(img), "hot": hot}

# Слой: d — signed distance (мм < 0 внутри). Обводка 2 px тёмная, внутри цвет.
static func _layer(d: float, fill: Color) -> Color:
	if d < 0.0:
		var c := fill
		# лёгкий объём: светлее к центру фигуры
		return Color(c.r, c.g, c.b, 1.0)
	if d < 2.0:
		return INK
	return Color(0, 0, 0, 0)

static func _over(top: Color, under: Color) -> Color:
	if top.a > 0.0:
		return top
	return under

static func _sample(name: String, p: Vector2) -> Color:
	var c := Vector2(SIZE * 0.5, SIZE * 0.5)
	match name:
		"arrow":
			var poly := [Vector2(3, 3), Vector2(3, 33), Vector2(11, 26), Vector2(17, 39), Vector2(23, 36), Vector2(17, 24), Vector2(28, 23)]
			var d := _sd_poly(p, poly)
			var col := _layer(d, Color("f2f4f6"))
			if d < -1.5 and p.x - p.y * 0.2 > 6.0:
				col = Color("c9d0d6")
			return col
		"march":
			var out := Color(0, 0, 0, 0)
			var g := Color("7ef08a")
			# Четыре шеврона, направленные внутрь, + точка в центре
			for k in 4:
				var dir := Vector2.from_angle(k * PI * 0.5)
				var tip := c + dir * 8.0
				var w := dir.orthogonal() * 7.0
				var back := c + dir * 17.0
				var poly := [tip, back + w, back + w * 0.45 - dir * -3.0, tip + dir * 5.0, back - w * 0.45 - dir * -3.0, back - w]
				out = _over(_layer(_sd_poly(p, poly), g), out)
			out = _over(_layer(p.distance_to(c) - 3.0, g), out)
			return out
		"attack", "force":
			var red := Color("ff3b2e") if name == "attack" else Color("ff9a2a")
			var ring := absf(p.distance_to(c) - 13.0) - 2.0
			var out := _layer(ring, red)
			for k in 4:
				var dir := Vector2.from_angle(k * PI * 0.5 + PI * 0.25 * (1.0 if name == "force" else 0.0))
				var seg := _sd_segment(p, c + dir * 6.0, c + dir * 21.0) - 1.6
				out = _over(_layer(seg, red), out)
			out = _over(_layer(p.distance_to(c) - 2.2, red), out)
			if name == "force":
				# «земля» под прицелом
				var base := _sd_segment(p, Vector2(8, 44), Vector2(40, 44)) - 1.6
				out = _over(_layer(base, red), out)
			return out
		"capture":
			# Флажок на древке
			var pole := _sd_segment(p, Vector2(12, 44), Vector2(12, 6)) - 1.8
			var flag := _sd_poly(p, [Vector2(13, 6), Vector2(38, 11), Vector2(30, 17), Vector2(38, 23), Vector2(13, 22)])
			var out := _layer(flag, Color("f2c14a"))
			if flag < -2.0 and int((p.x + p.y) / 4.0) % 2 == 0:
				out = Color("e0a83a")
			out = _over(_layer(pole, Color("d8dcdf")), out)
			out = _over(_layer(p.distance_to(Vector2(12, 44)) - 3.0, Color("d8dcdf")), out)
			return out
		"guard":
			var shield := _sd_poly(p, [Vector2(24, 5), Vector2(40, 11), Vector2(38, 26), Vector2(24, 43), Vector2(10, 26), Vector2(8, 11)])
			var out := _layer(shield, Color("7eb6e8"))
			if shield < -3.0 and p.x > 24.0:
				out = Color("5f94c8")
			return out
		"place":
			var bar1 := _sd_segment(p, Vector2(24, 8), Vector2(24, 40)) - 2.5
			var bar2 := _sd_segment(p, Vector2(8, 24), Vector2(40, 24)) - 2.5
			var out := _layer(minf(bar1, bar2), Color("d48cff"))
			out = _over(out, _layer(absf(p.distance_to(c) - 19.0) - 1.0, Color("d48cff")))
			return out
	return Color(0, 0, 0, 0)

static func _sd_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var pa := p - a
	var ba := b - a
	var h := clampf(pa.dot(ba) / ba.dot(ba), 0.0, 1.0)
	return (pa - ba * h).length()

static func _sd_poly(p: Vector2, poly: Array) -> float:
	var d := INF
	var inside := false
	var n := poly.size()
	for i in n:
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[(i + 1) % n]
		d = minf(d, _sd_segment(p, a, b))
		if ((a.y > p.y) != (b.y > p.y)) and p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x:
			inside = not inside
	return -d if inside else d
