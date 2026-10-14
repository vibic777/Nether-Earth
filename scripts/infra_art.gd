# Контрибьютор: vibic777
# Модели экономики и баз: добыча (вышка, хранилище, скважина, рудники), станции, док, казарма, завод техники.
# b — общий меш, a — меш цвета владельца. Возвращает высоту для подписи.
class_name InfraArt
extends RefCounted

const B := ArtKit.Builder
const M := ArtKit.METAL
const G := ArtKit.GLOW
const CONCRETE := Color("9a978c")
const STEEL := Color("5d646b")
const DARK := Color("2f3438")
const RUST := Color("8a5a3a")

static func build(b: B, a: B, kind: int) -> float:
	match kind:
		SitePlan.KIND_DERRICK:
			return _derrick(b, a)
		SitePlan.KIND_OIL_STORAGE:
			return _storage(b, a)
		SitePlan.KIND_GAS_WELL:
			return _gas_well(b, a)
		SitePlan.KIND_URANIUM_MINE:
			return _headframe(b, a, Color("6a7a3a"))
		SitePlan.KIND_COAL_MINE:
			return _coal_mine(b, a)
		SitePlan.KIND_REFINERY:
			return _refinery(b, a)
		SitePlan.KIND_GAS_PLANT:
			return _gas_plant(b, a)
		SitePlan.KIND_NUCLEAR:
			return _nuclear(b, a)
		SitePlan.KIND_COAL_PLANT:
			return _coal_plant(b, a)
		SitePlan.KIND_DOCK:
			return _dock(b, a)
		SitePlan.KIND_BARRACKS:
			return _barracks(b, a)
		_:
			return _plant(b, a)

static func _pad(b: B, a: B, w: float) -> void:
	b.box(Vector3(w, 0.14, w), Vector3(0, 0.27, 0), CONCRETE.darkened(0.12))
	b.box(Vector3(w - 0.1, 0.04, w - 0.1), Vector3(0, 0.36, 0), CONCRETE)
	a.box(Vector3(w + 0.02, 0.05, 0.08), Vector3(0, 0.3, w * 0.5), Color.WHITE)
	a.box(Vector3(w + 0.02, 0.05, 0.08), Vector3(0, 0.3, -w * 0.5), Color.WHITE)

# Станок-качалка: балансир, голова «лошади», противовес.
static func _derrick(b: B, a: B) -> float:
	_pad(b, a, 1.5)
	b.box(Vector3(0.9, 0.1, 0.3), Vector3(0, 0.43, 0), DARK, M)
	for sx in [-1.0, 1.0]:
		b.rod(Vector3(sx * 0.12, 0.45, -0.25), Vector3(0, 1.25, 0), 0.03, STEEL)
		b.rod(Vector3(sx * 0.12, 0.45, 0.25), Vector3(0, 1.25, 0), 0.03, STEEL)
	b.box(Vector3(1.3, 0.1, 0.1), Vector3(0, 1.3, 0), Color("d0a030"), M, Vector3(0, 0, 0.18))
	b.box(Vector3(0.14, 0.4, 0.16), Vector3(0.68, 1.3, 0), Color("d0a030"), M, Vector3(0, 0, 0.5))
	b.rod(Vector3(0.74, 1.08, 0), Vector3(0.74, 0.45, 0), 0.012, DARK)
	b.cyl(0.08, 0.08, 0.24, Vector3(0.74, 0.5, 0), STEEL, M)
	b.cyl(0.22, 0.22, 0.08, Vector3(-0.5, 0.9, 0), DARK, M, Vector3(PI * 0.5, 0, 0), 16)
	b.box(Vector3(0.24, 0.16, 0.22), Vector3(-0.55, 0.52, 0), Color("4a5058"), M)
	a.box(Vector3(0.2, 0.06, 0.12), Vector3(0, 1.38, 0), Color.WHITE)
	return 2.0

static func _storage(b: B, a: B) -> float:
	_pad(b, a, 1.6)
	for p in [Vector2(-0.38, -0.3), Vector2(0.38, -0.3), Vector2(0, 0.38)]:
		b.cyl(0.32, 0.32, 0.7, Vector3(p.x, 0.73, p.y), Color("d8d8d0"), M, Vector3.ZERO, 18)
		b.cyl(0.3, 0.33, 0.06, Vector3(p.x, 1.1, p.y), Color("b8b8b0"), M, Vector3.ZERO, 18)
		a.cyl(0.33, 0.33, 0.06, Vector3(p.x, 0.62, p.y), Color.WHITE, M, Vector3.ZERO, 18)
		b.rod(Vector3(p.x + 0.3, 0.4, p.y), Vector3(p.x + 0.2, 1.12, p.y + 0.2), 0.01, DARK)
	b.cyl(0.05, 0.05, 0.9, Vector3(0, 0.5, -0.3), STEEL, M, Vector3(0, 0, PI * 0.5))
	return 1.7

static func _gas_well(b: B, a: B) -> float:
	_pad(b, a, 1.3)
	b.cyl(0.08, 0.08, 0.6, Vector3(0, 0.66, 0), Color("c03030"), M)
	for y in [0.55, 0.78]:
		b.cyl(0.14, 0.14, 0.06, Vector3(0, y, 0), Color("c03030"), M)
		b.cyl(0.05, 0.05, 0.4, Vector3(0, y, 0.15), STEEL, M, Vector3(PI * 0.5, 0, 0))
	b.ball(0.06, Vector3(0, 1.0, 0), Color("c03030"), M)
	# Факел
	b.cyl(0.03, 0.04, 1.4, Vector3(0.5, 1.1, -0.45), STEEL, M)
	b.ball(0.09, Vector3(0.5, 1.85, -0.45), Color("ffa030"), G, Vector3(1, 1.6, 1))
	b.ball(0.05, Vector3(0.5, 1.95, -0.45), Color("fff0a0"), G)
	a.box(Vector3(0.3, 0.08, 0.3), Vector3(-0.4, 0.42, 0.4), Color.WHITE)
	return 2.1

# Копёр шахты: две стойки, шкивы, здание подъёма.
static func _headframe(b: B, a: B, tint: Color) -> float:
	_pad(b, a, 1.6)
	b.box(Vector3(0.6, 0.5, 0.6), Vector3(-0.4, 0.62, 0.35), Color("7a786e"))
	b.box(Vector3(0.62, 0.05, 0.62), Vector3(-0.4, 0.88, 0.35), DARK)
	for sx in [-1.0, 1.0]:
		b.rod(Vector3(0.3 + sx * 0.18, 0.38, -0.4), Vector3(0.3 + sx * 0.08, 1.7, -0.25), 0.035, RUST)
		b.rod(Vector3(0.3 + sx * 0.18, 0.38, 0.0), Vector3(0.3 + sx * 0.08, 1.7, -0.25), 0.035, RUST)
	b.cyl(0.16, 0.16, 0.04, Vector3(0.3, 1.72, -0.25), DARK, M, Vector3(0, 0, PI * 0.5), 16)
	b.rod(Vector3(0.3, 1.72, -0.25), Vector3(-0.4, 0.9, 0.35), 0.01, DARK)
	b.box(Vector3(0.3, 0.18, 0.3), Vector3(0.45, 0.48, 0.45), tint, M)
	b.ball(0.04, Vector3(0.45, 0.6, 0.45), Color("8aff6a"), G)
	a.box(Vector3(0.2, 0.08, 0.04), Vector3(-0.4, 0.75, 0.66), Color.WHITE)
	return 2.1

static func _coal_mine(b: B, a: B) -> float:
	var top := _headframe(b, a, Color("3a3a3a"))
	for i in 6:
		b.rock(0.2 - i * 0.015, Vector3(0.45 + (i % 2) * 0.12, 0.42 + i * 0.03, 0.4 - i * 0.06), Color("1c1c1c"), Vector3(1.2, 0.7, 1.1), i * 7)
	return top

static func _refinery(b: B, a: B) -> float:
	_pad(b, a, 1.8)
	for i in 3:
		var h := 1.2 + i * 0.3
		b.cyl(0.13, 0.13, h, Vector3(-0.5 + i * 0.3, 0.37 + h * 0.5, -0.35), Color("c8c8c0"), M, Vector3.ZERO, 14)
		for k in 3:
			b.cyl(0.15, 0.15, 0.03, Vector3(-0.5 + i * 0.3, 0.6 + k * 0.35, -0.35), DARK, M, Vector3.ZERO, 14)
	b.cyl(0.32, 0.32, 0.4, Vector3(0.45, 0.57, 0.4), Color("d8d8d0"), M, Vector3.ZERO, 18)
	b.box(Vector3(0.8, 0.3, 0.4), Vector3(-0.25, 0.52, 0.4), Color("7a786e"))
	b.cyl(0.04, 0.04, 1.0, Vector3(0.55, 0.9, -0.5), STEEL, M)
	b.ball(0.07, Vector3(0.55, 1.45, -0.5), Color("ffa030"), G, Vector3(1, 1.5, 1))
	a.cyl(0.33, 0.33, 0.06, Vector3(0.45, 0.66, 0.4), Color.WHITE, M, Vector3.ZERO, 18)
	return 2.4

static func _gas_plant(b: B, a: B) -> float:
	_pad(b, a, 1.8)
	b.box(Vector3(1.3, 0.6, 0.8), Vector3(-0.1, 0.67, 0.2), Color("8a9098"))
	b.box(Vector3(1.32, 0.06, 0.82), Vector3(-0.1, 0.98, 0.2), DARK)
	SiteArtWindows.row(b, 5, 1.1, 0.75, 0.61)
	b.cyl(0.12, 0.15, 1.3, Vector3(0.55, 1.0, -0.45), Color("b8b8b0"), M, Vector3.ZERO, 14)
	b.cyl(0.13, 0.13, 0.06, Vector3(0.55, 1.4, -0.45), Color("c03030"), M, Vector3.ZERO, 14)
	b.cyl(0.08, 0.08, 0.8, Vector3(-0.3, 0.5, -0.45), Color("d8a43a"), M, Vector3(0, 0, PI * 0.5))
	a.box(Vector3(0.6, 0.08, 0.04), Vector3(-0.1, 0.9, 0.62), Color.WHITE)
	b.ball(0.05, Vector3(-0.6, 1.05, 0.5), Color("5fc8ff"), G)
	return 2.1

static func _nuclear(b: B, a: B) -> float:
	_pad(b, a, 2.0)
	# Градирня-гиперболоид
	b.cyl(0.42, 0.55, 0.6, Vector3(-0.4, 0.66, -0.3), Color("c8c4b8"), ArtKit.MATTE, Vector3.ZERO, 22)
	b.cyl(0.46, 0.42, 0.6, Vector3(-0.4, 1.26, -0.3), Color("cdc9bd"), ArtKit.MATTE, Vector3.ZERO, 22)
	b.cyl(0.4, 0.4, 0.02, Vector3(-0.4, 1.57, -0.3), Color("3a3a3a"), ArtKit.MATTE, Vector3.ZERO, 22)
	for i in 3:
		b.ball(0.2 + i * 0.05, Vector3(-0.4 + i * 0.08, 1.75 + i * 0.22, -0.3), Color(0.92, 0.92, 0.95), ArtKit.MATTE, Vector3(1.2, 0.7, 1.2))
	# Реакторный купол
	b.cyl(0.38, 0.38, 0.4, Vector3(0.45, 0.57, 0.35), Color("d8d4c8"), ArtKit.MATTE, Vector3.ZERO, 20)
	b.ball(0.38, Vector3(0.45, 0.77, 0.35), Color("e0dcd0"), ArtKit.MATTE, Vector3(1, 0.7, 1), 20)
	b.box(Vector3(0.5, 0.3, 0.4), Vector3(0.5, 0.52, -0.45), Color("8a9098"))
	b.ball(0.05, Vector3(0.45, 1.05, 0.35), Color("ff4030"), G)
	a.cyl(0.39, 0.39, 0.06, Vector3(0.45, 0.42, 0.35), Color.WHITE, M, Vector3.ZERO, 20)
	return 2.6

static func _coal_plant(b: B, a: B) -> float:
	_pad(b, a, 1.8)
	b.box(Vector3(1.2, 0.7, 0.8), Vector3(-0.15, 0.72, 0.25), Color("6a5e52"))
	SiteArtWindows.row(b, 4, 1.0, 0.8, 0.66)
	for sx in [0.35, 0.65]:
		b.cyl(0.1, 0.14, 1.7, Vector3(sx, 1.2, -0.45), Color("8a6a5a"), ArtKit.MATTE, Vector3.ZERO, 14)
		for k in 2:
			b.cyl(0.11, 0.11, 0.06, Vector3(sx, 1.6 + k * 0.25, -0.45), Color("e8e8e8"), ArtKit.MATTE, Vector3.ZERO, 14)
		for i in 3:
			b.ball(0.16 + i * 0.06, Vector3(sx - i * 0.1, 2.15 + i * 0.2, -0.45 - i * 0.05), Color(0.2, 0.19, 0.18), ArtKit.MATTE, Vector3(1.3, 0.8, 1.2))
	for i in 4:
		b.rock(0.18, Vector3(-0.55 + i * 0.12, 0.42, -0.5), Color("181818"), Vector3(1.2, 0.6, 1.0), i * 5)
	a.box(Vector3(0.5, 0.08, 0.04), Vector3(-0.15, 1.0, 0.66), Color.WHITE)
	return 2.8

static func _dock(b: B, a: B) -> float:
	b.box(Vector3(1.9, 0.3, 1.9), Vector3(0, 0.15, 0), CONCRETE.darkened(0.1))
	b.box(Vector3(1.9, 0.04, 1.9), Vector3(0, 0.31, 0), CONCRETE)
	for i in 6:
		b.cyl(0.06, 0.06, 0.6, Vector3(-0.9 + i * 0.36, 0.0, 0.92), Color("4a3a2a"), ArtKit.MATTE, Vector3.ZERO, 8)
	b.box(Vector3(0.9, 0.6, 0.6), Vector3(-0.4, 0.62, -0.5), Color("7a8288"))
	b.box(Vector3(0.6, 0.45, 0.04), Vector3(-0.4, 0.55, -0.19), DARK)
	# Портовый кран
	for sx in [-1.0, 1.0]:
		b.rod(Vector3(0.5 + sx * 0.18, 0.32, 0.2), Vector3(0.5 + sx * 0.08, 1.7, 0.2), 0.035, Color("e8b030"))
	b.box(Vector3(0.14, 0.12, 1.5), Vector3(0.5, 1.72, 0.55), Color("e8b030"), M)
	b.rod(Vector3(0.5, 1.68, 1.2), Vector3(0.5, 0.9, 1.2), 0.01, DARK)
	b.box(Vector3(0.2, 0.16, 0.2), Vector3(0.5, 0.82, 1.2), Color("c04020"), M)
	for sx in [-1.0, 1.0]:
		b.cyl(0.06, 0.07, 0.12, Vector3(sx * 0.7, 0.38, 0.82), DARK, M, Vector3.ZERO, 10)
	a.box(Vector3(0.92, 0.08, 0.62), Vector3(-0.4, 0.95, -0.5), Color.WHITE)
	return 2.3

static func _barracks(b: B, a: B) -> float:
	_pad(b, a, 1.8)
	b.box(Vector3(1.5, 0.45, 1.0), Vector3(0, 0.6, 0), Color("7a7a5a"))
	b.cyl(0.52, 0.52, 1.5, Vector3(0, 0.82, 0), Color("6a6c4c"), M, Vector3(0, 0, PI * 0.5), 18)
	b.box(Vector3(0.5, 0.4, 0.04), Vector3(0, 0.55, 0.51), DARK)
	for sx in [-1.0, 1.0]:
		b.box(Vector3(0.2, 0.12, 0.03), Vector3(sx * 0.5, 0.7, 0.51), Color("9fd4ea"), ArtKit.GLASS)
	b.cyl(0.02, 0.02, 1.0, Vector3(0.7, 0.9, 0.7), STEEL, M)
	a.box(Vector3(0.36, 0.22, 0.02), Vector3(0.88, 1.28, 0.7), Color.WHITE)
	for i in 4:
		b.box(Vector3(0.26, 0.2, 0.26), Vector3(-0.7 + (i % 2) * 0.3, 0.47 + (i / 2) * 0.2, 0.7), Color("8a7a4a"))
	return 1.9

static func _plant(b: B, a: B) -> float:
	_pad(b, a, 2.0)
	b.box(Vector3(1.7, 0.8, 1.3), Vector3(0, 0.77, -0.1), Color("7a8288"))
	for i in 4:
		b.box(Vector3(0.42, 0.18, 1.3), Vector3(-0.64 + i * 0.43, 1.25, -0.1), Color("6a7278"), M, Vector3(0, 0, 0.35))
		b.box(Vector3(0.02, 0.14, 1.28), Vector3(-0.5 + i * 0.43, 1.25, -0.1), Color("9fd4ea"), ArtKit.GLASS, Vector3(0, 0, -0.9))
	b.box(Vector3(0.9, 0.62, 0.04), Vector3(0, 0.68, 0.56), DARK)
	for i in 6:
		b.box(Vector3(0.88, 0.02, 0.05), Vector3(0, 0.42 + i * 0.1, 0.58), Color("4a4e52"), M)
	b.cyl(0.1, 0.13, 1.2, Vector3(0.75, 1.3, -0.6), Color("8a6a5a"), ArtKit.MATTE, Vector3.ZERO, 12)
	b.ball(0.05, Vector3(-0.75, 1.25, 0.56), Color("ffb040"), G)
	b.ball(0.05, Vector3(0.75, 1.25, 0.56), Color("ffb040"), G)
	a.box(Vector3(1.72, 0.1, 0.06), Vector3(0, 1.1, 0.56), Color.WHITE)
	return 2.4

# Окна станций.
class SiteArtWindows:
	static func row(b: B, count: int, span: float, y: float, z: float) -> void:
		for i in count:
			var x := -0.1 - span * 0.5 + span * (float(i) + 0.5) / float(count)
			b.box(Vector3(span / count * 0.6, 0.14, 0.03), Vector3(x, y, z), Color("9fd4ea"), ArtKit.GLASS)
