# Контрибьютор: vibic777
# Модели боевых машин. Вперёд = +Z. Точки дула совпадают с BattleUnit._muzzle_at().
# Возвращает {"body": Mesh, "legs": [{"at": Vector3, "mesh": Mesh, "phase": float}], "rotor": Mesh|null, "rotor_at": Vector3}
class_name UnitArt
extends RefCounted

const B := ArtKit.Builder
const M := ArtKit.METAL
const G := ArtKit.GLOW
const GL := ArtKit.GLASS

static var _enemy := false
static var _tint := Color("8e3a32")

# Окраска чужой стороны: цвет слота из лобби.
static func tint(c: Color) -> Color:
	return c.lerp(_tint, 0.42) if _enemy else c

static var _cache := {}

# Меши одинаковы для всех машин одного типа и стороны: строятся один раз.
static func make(mover: int, enemy: bool, side_tint: Color = Color("8e3a32")) -> Dictionary:
	var key := "%d|%s|%s" % [mover, enemy, side_tint.to_html()]
	if not _cache.has(key):
		_cache[key] = _make(mover, enemy, side_tint)
	return _cache[key]

static func _make(mover: int, enemy: bool, side_tint: Color) -> Dictionary:
	_enemy = enemy
	_tint = side_tint
	match mover:
		BattleGrid.Mover.WALKER:
			return _walker()
		BattleGrid.Mover.UAV:
			return _uav()
		BattleGrid.Mover.JET:
			return _jet()
		BattleGrid.Mover.ROTOR:
			return _rotor()
		BattleGrid.Mover.TRACK:
			return _tank()
		BattleGrid.Mover.BIKE:
			return _bike()
		BattleGrid.Mover.ENGINEER:
			return _human(true)
		BattleGrid.Mover.TROOPER:
			return _human(false)
		_:
			if mover > BattleGrid.Mover.ENGINEER:
				return VehicleArt.make(mover)
			return _human(false)

static func _out(body: B, legs: Array = [], rotor: B = null, rotor_at: Vector3 = Vector3.ZERO) -> Dictionary:
	return {"body": body.commit(), "legs": legs, "rotor": rotor.commit() if rotor != null else null, "rotor_at": rotor_at}

# Шагоход: «куриный» шаг, колени назад. Корпус-кабина, две пушки по бокам, ракетный блок на спине.
static func _walker() -> Dictionary:
	var armor := tint(Color("6a7266"))
	var plate := tint(Color("858c7c"))
	var dark := Color("2b2f31")
	var steel := Color("5a6066")
	var b := B.new()
	# Таз и корпус
	b.box(Vector3(0.9, 0.22, 0.5), Vector3(0, 0.98, -0.05), steel, M)
	b.box(Vector3(0.86, 0.52, 0.86), Vector3(0, 1.38, 0.02), armor, M)
	b.box(Vector3(0.7, 0.24, 0.5), Vector3(0, 1.48, 0.42), plate, M, Vector3(-0.35, 0, 0))
	b.box(Vector3(0.58, 0.12, 0.05), Vector3(0, 1.5, 0.69), Color("ff5a3a"), GL)
	b.box(Vector3(0.9, 0.08, 0.9), Vector3(0, 1.66, 0.0), plate.darkened(0.15), M)
	for sx in [-1.0, 1.0]:
		b.box(Vector3(0.06, 0.4, 0.7), Vector3(sx * 0.46, 1.36, 0.02), dark, M)
	# Ракетный блок на спине (крепится к корпусу)
	b.box(Vector3(0.62, 0.34, 0.36), Vector3(0, 1.62, -0.42), armor.darkened(0.1), M)
	for i in 3:
		for j in 2:
			b.cyl(0.045, 0.045, 0.04, Vector3(-0.18 + i * 0.18, 1.56 + j * 0.14, -0.22), Color("e6c04a"), G, Vector3(PI * 0.5, 0, 0), 8)
	# Плечи и пушки: оружие сидит на плечевых шарнирах корпуса
	for sx in [-1.0, 1.0]:
		b.ball(0.13, Vector3(sx * 0.5, 1.32, 0.05), steel, M)
		b.box(Vector3(0.18, 0.18, 0.62), Vector3(sx * 0.6, 1.2, 0.42), dark, M)
		b.cyl(0.05, 0.05, 0.36, Vector3(sx * 0.6, 1.2, 0.9), Color("1c1e20"), M, Vector3(PI * 0.5, 0, 0), 10)
		b.cyl(0.07, 0.07, 0.06, Vector3(sx * 0.6, 1.2, 1.06), Color("1c1e20"), M, Vector3(PI * 0.5, 0, 0), 10)
	# Центральная пушка под кабиной (дуло = muzzle)
	b.box(Vector3(0.18, 0.16, 0.3), Vector3(0, 1.12, 0.58), dark, M)
	b.cyl(0.04, 0.04, 0.3, Vector3(0, 1.12, 0.82), Color("1c1e20"), M, Vector3(PI * 0.5, 0, 0), 10)
	# Антенна и прожектор
	b.rod(Vector3(0.3, 1.7, -0.3), Vector3(0.36, 2.15, -0.34), 0.012, steel)
	b.ball(0.05, Vector3(-0.28, 1.74, 0.36), Color("fff3c0"), G)
	var legs := []
	for sx in [-1.0, 1.0]:
		var l := B.new()
		# локальные координаты от тазобедренного шарнира (0,0,0)
		var hip := Vector3(0, 0, 0)
		var knee := Vector3(0, -0.36, -0.32)   # колено назад
		var ankle := Vector3(0, -0.78, 0.06)
		var foot := Vector3(0, -0.86, 0.1)
		l.ball(0.12, hip, steel, M)
		l.box(Vector3(0.16, 0.5, 0.16), (hip + knee) * 0.5, armor, M, Vector3(-0.72, 0, 0))
		l.ball(0.09, knee, steel, M)
		l.rod(knee, ankle, 0.06, dark)
		l.rod(knee + Vector3(0, 0.02, 0.08), ankle + Vector3(0, 0.1, 0.05), 0.025, steel)
		l.box(Vector3(0.32, 0.07, 0.5), foot + Vector3(0, 0, 0.06), dark, M)
		l.box(Vector3(0.1, 0.06, 0.16), foot + Vector3(0, 0, -0.22), dark, M)
		legs.append({"at": Vector3(sx * 0.44, 0.96, -0.05), "mesh": l.commit(), "phase": 0.0 if sx < 0 else PI})
	return _out(b, legs)

# БПЛА: летающее крыло с винтом-толкателем и подвесами.
static func _uav() -> Dictionary:
	var skin := tint(Color("4a5258"))
	var light := tint(Color("6a737a"))
	var dark := Color("1e2226")
	var b := B.new()
	b.ball(0.24, Vector3(0, 0.02, 0.15), skin, M, Vector3(0.9, 0.55, 3.4), 14)
	b.ball(0.14, Vector3(0, 0.1, 0.55), Color("1a2a38"), GL, Vector3(1.0, 0.6, 1.6), 10)
	# Стреловидное крыло одной плитой с законцовками, на каждом крыле пилон с ракетой.
	for sx in [-1.0, 1.0]:
		var wing := PackedVector2Array([
			Vector2(sx * 0.16, 0.38), Vector2(sx * 1.12, -0.28), Vector2(sx * 1.14, -0.46),
			Vector2(sx * 0.98, -0.48), Vector2(sx * 0.16, -0.3),
		])
		if sx < 0:
			wing.reverse()
		b.plate(wing, 0.0, 0.05, light, M)
		var flap := PackedVector2Array([Vector2(sx * 0.3, -0.3), Vector2(sx * 0.95, -0.47), Vector2(sx * 0.95, -0.53), Vector2(sx * 0.3, -0.36)])
		if sx < 0:
			flap.reverse()
		b.plate(flap, -0.005, 0.03, skin.darkened(0.15), M)
		# Законцовка-винглет, слегка наклонена наружу
		b.box(Vector3(0.025, 0.16, 0.2), Vector3(sx * 1.12, 0.07, -0.38), skin, M, Vector3(0, 0, sx * -0.25))
		b.ball(0.025, Vector3(sx * 1.13, 0.0, -0.3), Color("ff4a3a") if sx < 0 else Color("4aff6a"), G)
		# Пилон и ракета под крылом
		b.box(Vector3(0.035, 0.07, 0.24), Vector3(sx * 0.5, -0.055, 0.0), dark, M)
		b.cyl(0.035, 0.035, 0.46, Vector3(sx * 0.5, -0.12, 0.02), Color("d8dcdf"), M, Vector3(PI * 0.5, 0, 0), 10)
		b.cyl(0.0, 0.035, 0.1, Vector3(sx * 0.5, -0.12, 0.3), Color("c4473a"), M, Vector3(PI * 0.5, 0, 0), 10)
		for k in 4:
			b.box(Vector3(0.012, 0.09, 0.07), Vector3(sx * 0.5, -0.12, -0.18), dark, M, Vector3(0, 0, k * PI * 0.5 + PI * 0.25))
	# Хвостовое V-оперение
	for sx in [-1.0, 1.0]:
		b.box(Vector3(0.025, 0.22, 0.22), Vector3(sx * 0.12, 0.12, -0.5), skin, M, Vector3(0, 0, sx * 0.6))
	# Нос и пушка под носом (muzzle 0,-0.02,0.95)
	b.cyl(0.03, 0.03, 0.3, Vector3(0, -0.04, 0.78), dark, M, Vector3(PI * 0.5, 0, 0), 8)
	b.cyl(0.08, 0.1, 0.16, Vector3(0, 0.03, -0.62), dark, M, Vector3(PI * 0.5, 0, 0), 10)
	var prop := B.new()
	for k in 3:
		prop.box(Vector3(0.05, 0.02, 0.5), Vector3.ZERO, Color("2a2d30"), M, Vector3(0, k * TAU / 3.0, 0))
	prop.ball(0.04, Vector3.ZERO, Color("c0c4c8"), M)
	var r := _out(b, [], prop, Vector3(0, 0.03, -0.72))
	r["rotor_axis"] = Vector3.FORWARD
	return r

# Штурмовик: собственный дизайн проекта — гранёный фюзеляж с острыми кромками, трапециевидное крыло,
# развал килей наружу, боковые воздухозаборники, одно сопло; пушка под носом, ракеты и бомбы на пилонах.
static func _jet() -> Dictionary:
	var skin := tint(Color("5d666e"))
	var light := tint(Color("7b858c"))
	var dark := Color("1c2024")
	var b := B.new()
	# Фюзеляж: гранёная плита-ромб по виду сверху + горб хребта
	b.plate(PackedVector2Array([Vector2(0, 1.18), Vector2(0.17, 0.62), Vector2(0.26, -0.2), Vector2(0.2, -0.86), Vector2(-0.2, -0.86), Vector2(-0.26, -0.2), Vector2(-0.17, 0.62)]), 0.0, 0.14, skin, M)
	b.ball(0.17, Vector3(0, 0.07, -0.05), light, M, Vector3(1.0, 0.55, 4.6), 14)
	b.cyl(0.0, 0.07, 0.34, Vector3(0, 0.0, 1.02), skin.darkened(0.1), M, Vector3(PI * 0.5, 0, 0), 8)
	# Фонарь кабины
	b.ball(0.11, Vector3(0, 0.15, 0.48), Color("2a3a30"), GL, Vector3(0.9, 0.7, 2.6), 12)
	b.box(Vector3(0.02, 0.05, 0.02), Vector3(0, 0.23, 0.34), dark, M)
	for sx in [-1.0, 1.0]:
		# Трапециевидное крыло
		var wing := PackedVector2Array([Vector2(sx * 0.24, 0.22), Vector2(sx * 0.86, -0.36), Vector2(sx * 0.86, -0.5), Vector2(sx * 0.22, -0.56)])
		if sx < 0:
			wing.reverse()
		b.plate(wing, 0.0, 0.04, light, M)
		# Стабилизатор
		var tail := PackedVector2Array([Vector2(sx * 0.2, -0.66), Vector2(sx * 0.5, -0.86), Vector2(sx * 0.5, -0.96), Vector2(sx * 0.18, -0.92)])
		if sx < 0:
			tail.reverse()
		b.plate(tail, 0.0, 0.03, skin, M)
		# Кили с развалом наружу
		b.box(Vector3(0.025, 0.3, 0.26), Vector3(sx * 0.2, 0.17, -0.74), skin, M, Vector3(-0.25, 0, sx * -0.42))
		# Воздухозаборники по бокам кабины
		b.box(Vector3(0.1, 0.12, 0.36), Vector3(sx * 0.21, 0.0, 0.22), skin.darkened(0.12), M, Vector3(0, sx * 0.12, 0))
		b.box(Vector3(0.07, 0.09, 0.02), Vector3(sx * 0.23, 0.0, 0.41), dark, M, Vector3(0, sx * 0.12, 0))
		# Пилоны: ракета ближе к концу крыла, управляемая бомба у фюзеляжа
		b.box(Vector3(0.03, 0.06, 0.2), Vector3(sx * 0.62, -0.05, -0.28), dark, M)
		b.cyl(0.028, 0.028, 0.42, Vector3(sx * 0.62, -0.1, -0.24), Color("d8dcdf"), M, Vector3(PI * 0.5, 0, 0), 8)
		b.cyl(0.0, 0.028, 0.08, Vector3(sx * 0.62, -0.1, 0.01), Color("c4473a"), M, Vector3(PI * 0.5, 0, 0), 8)
		b.box(Vector3(0.03, 0.06, 0.2), Vector3(sx * 0.38, -0.06, -0.3), dark, M)
		b.ball(0.055, Vector3(sx * 0.38, -0.13, -0.3), Color("6a6e58"), M, Vector3(1.0, 1.0, 3.2), 10)
		for k in 4:
			b.box(Vector3(0.008, 0.07, 0.06), Vector3(sx * 0.38, -0.13, -0.47), dark, M, Vector3(0, 0, k * PI * 0.5 + PI * 0.25))
		# Огни на законцовках
		b.ball(0.022, Vector3(sx * 0.86, 0.0, -0.42), Color("ff4a3a") if sx < 0 else Color("4aff6a"), G)
	# Сопло и пламя форсажа
	b.cyl(0.11, 0.09, 0.2, Vector3(0, 0.03, -0.94), dark, M, Vector3(PI * 0.5, 0, 0), 12)
	b.cyl(0.07, 0.0, 0.18, Vector3(0, 0.03, -1.12), Color("ffb060"), G, Vector3(-PI * 0.5, 0, 0), 10)
	# Пушка под носом (muzzle 0,-0.02,0.95)
	b.cyl(0.022, 0.022, 0.26, Vector3(0.0, -0.05, 0.8), dark, M, Vector3(PI * 0.5, 0, 0), 8)
	return _out(b)

# Ротор: ударный вертолёт с соосными винтами, турель под носом, пилоны с блоками НУР.
static func _rotor() -> Dictionary:
	var olive := tint(Color("5a6a42"))
	var dark := Color("23281c")
	var steel := Color("4a5048")
	var b := B.new()
	b.ball(0.3, Vector3(0, 0.36, 0.2), olive, M, Vector3(1.0, 1.0, 2.3), 14)
	b.ball(0.2, Vector3(0, 0.46, 0.62), Color("223040"), GL, Vector3(1.0, 0.9, 1.5), 12)
	b.cyl(0.07, 0.15, 1.1, Vector3(0, 0.44, -0.75), olive, M, Vector3(PI * 0.5, 0, 0), 10)
	b.box(Vector3(0.05, 0.4, 0.26), Vector3(0, 0.62, -1.28), olive, M, Vector3(-0.3, 0, 0))
	b.box(Vector3(0.6, 0.04, 0.16), Vector3(0, 0.45, -1.2), olive, M)
	b.box(Vector3(0.3, 0.16, 0.45), Vector3(0, 0.64, 0.05), steel, M)
	for sx in [-1.0, 1.0]:
		b.cyl(0.07, 0.08, 0.32, Vector3(sx * 0.17, 0.66, -0.1), dark, M, Vector3(PI * 0.5, 0, 0), 10)
		b.box(Vector3(0.48, 0.04, 0.14), Vector3(sx * 0.42, 0.3, 0.05), olive, M)
		b.cyl(0.055, 0.055, 0.34, Vector3(sx * 0.58, 0.22, 0.08), Color("3a3e36"), M, Vector3(PI * 0.5, 0, 0), 10)
		b.cyl(0.045, 0.045, 0.3, Vector3(sx * 0.36, 0.22, 0.1), Color("d8dcdf"), M, Vector3(PI * 0.5, 0, 0), 8)
		b.rod(Vector3(sx * 0.18, 0.12, 0.45), Vector3(sx * 0.25, -0.02, 0.45), 0.015, dark)
		b.rod(Vector3(sx * 0.18, 0.12, -0.15), Vector3(sx * 0.25, -0.02, -0.15), 0.015, dark)
		b.rod(Vector3(sx * 0.25, -0.02, 0.62), Vector3(sx * 0.25, -0.02, -0.35), 0.02, dark)
	# Турель под носом справа (muzzle 0.22,0.28,0.95)
	b.ball(0.08, Vector3(0.18, 0.24, 0.7), dark, M)
	b.cyl(0.025, 0.025, 0.24, Vector3(0.21, 0.27, 0.8), Color("15181a"), M, Vector3(PI * 0.5, 0, 0), 8)
	b.cyl(0.03, 0.03, 0.12, Vector3(0, 0.66, 0.1), dark, M)
	var rotor := B.new()
	for level in [0.0, 0.1]:
		for k in 3:
			var ang: float = k * TAU / 3.0 + level * 6.0
			rotor.box(Vector3(0.07, 0.02, 0.9), Vector3(sin(ang) * 0.45, level, cos(ang) * 0.45), Color("1c1e18"), M, Vector3(0, ang, 0))
	rotor.cyl(0.06, 0.06, 0.14, Vector3(0, 0.05, 0), steel, M)
	return _out(b, [], rotor, Vector3(0, 0.68, 0.1))

# Гусеницы: основной танк. Катки, траки, башня с пушкой и пулемётом.
static func _tank() -> Dictionary:
	var hull := tint(Color("56614a"))
	var hull_l := tint(Color("6a7558"))
	var track := Color("23251f")
	var wheel := Color("3a3d34")
	var b := B.new()
	for sx in [-1.0, 1.0]:
		var x: float = sx * 0.5
		b.box(Vector3(0.26, 0.26, 1.46), Vector3(x, 0.2, 0), track, ArtKit.MATTE)
		b.cyl(0.13, 0.13, 0.26, Vector3(x, 0.2, 0.73), track, ArtKit.MATTE, Vector3(0, 0, PI * 0.5), 12)
		b.cyl(0.13, 0.13, 0.26, Vector3(x, 0.2, -0.73), track, ArtKit.MATTE, Vector3(0, 0, PI * 0.5), 12)
		for i in 6:
			b.cyl(0.1, 0.1, 0.04, Vector3(x + sx * 0.135, 0.18, -0.55 + i * 0.22), wheel, M, Vector3(0, 0, PI * 0.5), 12)
		for i in 15:
			b.box(Vector3(0.28, 0.025, 0.05), Vector3(x, 0.335, -0.7 + i * 0.1), Color("2e302a"))
		# Фальшборт
		b.box(Vector3(0.04, 0.16, 1.4), Vector3(sx * 0.645, 0.3, 0), hull, M)
		b.box(Vector3(0.3, 0.03, 1.44), Vector3(x, 0.38, 0), hull_l, M)
	b.box(Vector3(0.74, 0.22, 1.3), Vector3(0, 0.42, -0.02), hull, M)
	b.box(Vector3(0.74, 0.14, 0.32), Vector3(0, 0.38, 0.72), hull_l, M, Vector3(-0.6, 0, 0))
	b.box(Vector3(0.7, 0.1, 0.22), Vector3(0, 0.46, -0.72), hull.darkened(0.15), M)
	for sx in [-1.0, 1.0]:
		b.ball(0.035, Vector3(sx * 0.3, 0.46, 0.78), Color("fff3c0"), G)
		b.cyl(0.06, 0.06, 0.22, Vector3(sx * 0.2, 0.55, -0.62), Color("3a3a32"), M, Vector3(0, 0, PI * 0.5), 10)
	# Башня (дуло = muzzle 0,0.62,1.15)
	b.box(Vector3(0.62, 0.22, 0.66), Vector3(0, 0.63, -0.02), hull_l, M)
	b.box(Vector3(0.52, 0.12, 0.3), Vector3(0, 0.6, 0.35), hull, M, Vector3(-0.4, 0, 0))
	b.box(Vector3(0.56, 0.1, 0.24), Vector3(0, 0.66, -0.42), hull.darkened(0.1), M)
	b.box(Vector3(0.18, 0.16, 0.12), Vector3(0, 0.62, 0.36), hull.darkened(0.2), M)
	b.cyl(0.045, 0.05, 0.72, Vector3(0, 0.62, 0.72), Color("2a2e26"), M, Vector3(PI * 0.5, 0, 0), 12)
	b.cyl(0.07, 0.07, 0.14, Vector3(0, 0.62, 0.66), Color("2a2e26"), M, Vector3(PI * 0.5, 0, 0), 12)
	# Командирская башенка и пулемёт
	b.cyl(0.11, 0.12, 0.1, Vector3(0.16, 0.79, -0.12), hull, M, Vector3.ZERO, 12)
	b.cyl(0.014, 0.014, 0.32, Vector3(0.16, 0.86, 0.08), Color("181a16"), M, Vector3(PI * 0.5, 0, 0), 6)
	b.box(Vector3(0.06, 0.06, 0.14), Vector3(0.16, 0.86, -0.06), Color("181a16"), M)
	b.ball(0.04, Vector3(-0.18, 0.8, -0.05), Color("ff5a3a"), GL)
	b.rod(Vector3(-0.24, 0.74, -0.3), Vector3(-0.28, 1.25, -0.34), 0.008, Color("2a2a2a"))
	return _out(b)

# Мото: колёсный байк с пилотом в броне и курсовым пулемётом.
static func _bike() -> Dictionary:
	var paint := tint(Color("8a2e28"))
	var frame := Color("1d1f22")
	var chrome := Color("c8ced4")
	var b := B.new()
	for z in [0.48, -0.46]:
		b.cyl(0.19, 0.19, 0.1, Vector3(0, 0.22, z), Color("141414"), ArtKit.MATTE, Vector3(0, 0, PI * 0.5), 16)
		b.cyl(0.1, 0.1, 0.11, Vector3(0, 0.22, z), chrome, M, Vector3(0, 0, PI * 0.5), 12)
	b.rod(Vector3(0, 0.22, 0.48), Vector3(0, 0.66, 0.3), 0.025, chrome)
	b.rod(Vector3(0, 0.22, -0.46), Vector3(0, 0.42, -0.05), 0.03, frame)
	b.ball(0.16, Vector3(0, 0.48, 0.02), paint, M, Vector3(0.8, 0.7, 2.0), 12)
	b.box(Vector3(0.18, 0.12, 0.2), Vector3(0, 0.34, 0.0), Color("3a3d40"), M)
	b.cyl(0.035, 0.04, 0.4, Vector3(0.1, 0.3, -0.3), chrome, M, Vector3(PI * 0.42, 0, 0), 8)
	b.box(Vector3(0.18, 0.06, 0.3), Vector3(0, 0.55, -0.24), Color("1a1a1a"))
	b.box(Vector3(0.36, 0.03, 0.03), Vector3(0, 0.7, 0.3), frame, M)
	b.box(Vector3(0.16, 0.14, 0.04), Vector3(0, 0.74, 0.38), Color("a9d4e8"), GL, Vector3(-0.4, 0, 0))
	b.ball(0.04, Vector3(0, 0.6, 0.44), Color("fff3c0"), G)
	b.ball(0.03, Vector3(0, 0.5, -0.5), Color("ff3a2a"), G)
	# Пулемёт справа (muzzle 0.16,0.72,0.55)
	b.box(Vector3(0.05, 0.06, 0.24), Vector3(0.16, 0.7, 0.3), frame, M)
	b.cyl(0.015, 0.015, 0.16, Vector3(0.16, 0.72, 0.46), Color("101010"), M, Vector3(PI * 0.5, 0, 0), 6)
	# Пилот
	var suit := tint(Color("3e454c"))
	b.rod(Vector3(0.1, 0.62, -0.12), Vector3(0.12, 0.44, 0.12), 0.045, suit, ArtKit.MATTE)
	b.rod(Vector3(-0.1, 0.62, -0.12), Vector3(-0.12, 0.44, 0.12), 0.045, suit, ArtKit.MATTE)
	b.ball(0.12, Vector3(0, 0.86, -0.04), suit, ArtKit.MATTE, Vector3(1.0, 1.3, 0.9))
	b.rod(Vector3(0.12, 0.95, 0.0), Vector3(0.17, 0.72, 0.28), 0.03, suit, ArtKit.MATTE)
	b.rod(Vector3(-0.12, 0.95, 0.0), Vector3(-0.17, 0.72, 0.28), 0.03, suit, ArtKit.MATTE)
	b.ball(0.1, Vector3(0, 1.1, 0.04), paint, M)
	b.box(Vector3(0.14, 0.05, 0.04), Vector3(0, 1.1, 0.13), Color("1a2a38"), GL)
	return _out(b)

# Пехота и инженер: экзоброня, колени вперёд, ноги анимируются.
static func _human(engineer: bool) -> Dictionary:
	var suit := tint(Color("d0a24a") if engineer else Color("58625a"))
	var plate := tint(Color("e2b85c") if engineer else Color("7a8476"))
	var dark := Color("2a2e30")
	var b := B.new()
	b.box(Vector3(0.26, 0.12, 0.16), Vector3(0, 0.56, 0), dark, M)
	b.ball(0.15, Vector3(0, 0.78, 0), suit, ArtKit.MATTE, Vector3(1.15, 1.3, 0.8))
	b.box(Vector3(0.26, 0.2, 0.08), Vector3(0, 0.82, 0.1), plate, M)
	b.box(Vector3(0.24, 0.26, 0.12), Vector3(0, 0.8, -0.13), dark if not engineer else Color("5a4a30"), M)
	for sx in [-1.0, 1.0]:
		b.ball(0.07, Vector3(sx * 0.17, 0.93, 0), plate, M)
	b.ball(0.035, Vector3(0, 0.98, 0), dark)
	b.ball(0.095, Vector3(0, 1.08, 0.01), plate, M)
	b.box(Vector3(0.14, 0.05, 0.05), Vector3(0, 1.08, 0.08), Color("6ad4ff") if not engineer else Color("ffd060"), GL)
	if engineer:
		b.ball(0.04, Vector3(0.0, 1.17, 0.06), Color("fff0a0"), G)
		b.rod(Vector3(-0.17, 0.92, 0.0), Vector3(-0.2, 0.7, 0.14), 0.03, suit, ArtKit.MATTE)
		b.rod(Vector3(0.17, 0.92, 0.0), Vector3(0.22, 0.66, 0.14), 0.03, suit, ArtKit.MATTE)
		b.box(Vector3(0.1, 0.12, 0.2), Vector3(0.24, 0.62, 0.2), Color("6a6a6a"), M)
		b.rod(Vector3(-0.1, 0.9, -0.18), Vector3(-0.14, 1.3, -0.2), 0.008, Color("333333"))
		b.ball(0.02, Vector3(-0.14, 1.31, -0.2), Color("ff4a3a"), G)
	else:
		# Винтовка в руках (muzzle 0.16,0.92,0.42)
		b.rod(Vector3(-0.17, 0.92, 0.0), Vector3(0.04, 0.86, 0.22), 0.03, suit, ArtKit.MATTE)
		b.rod(Vector3(0.17, 0.92, 0.0), Vector3(0.16, 0.86, 0.1), 0.03, suit, ArtKit.MATTE)
		b.box(Vector3(0.05, 0.08, 0.36), Vector3(0.14, 0.9, 0.12), dark, M)
		b.cyl(0.014, 0.014, 0.16, Vector3(0.15, 0.92, 0.34), Color("101010"), M, Vector3(PI * 0.5, 0, 0), 6)
		b.box(Vector3(0.03, 0.08, 0.05), Vector3(0.14, 0.82, 0.18), dark, M)
	var legs := []
	for sx in [-1.0, 1.0]:
		var l := B.new()
		var knee := Vector3(0, -0.24, 0.05)   # колено вперёд
		var ankle := Vector3(0, -0.46, -0.01)
		l.rod(Vector3.ZERO, knee, 0.05, suit, ArtKit.MATTE)
		l.ball(0.05, knee, plate, M)
		l.rod(knee, ankle, 0.045, dark)
		l.box(Vector3(0.1, 0.06, 0.2), ankle + Vector3(0, -0.02, 0.04), dark, M)
		legs.append({"at": Vector3(sx * 0.08, 0.54, 0), "mesh": l.commit(), "phase": 0.0 if sx < 0 else PI})
	return _out(b, legs)
