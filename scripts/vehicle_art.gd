# Контрибьютор: vibic777
# Модели новой техники: грузовики, разворачиваемые базы, корабли, турели, стены, ворота, труба.
# Вперёд = +Z, как в UnitArt. Окраска стороны — UnitArt.tint().
class_name VehicleArt
extends RefCounted

const B := ArtKit.Builder
const M := ArtKit.METAL
const G := ArtKit.GLOW
const GL := ArtKit.GLASS
const TIRE := Color("1f2120")
const RIM := Color("8c9096")
const CHROME := Color("d4d8dc")

static func make(mover: int) -> Dictionary:
	var b := B.new()
	match mover:
		BattleGrid.Mover.OIL_TRUCK:
			_truck_cab(b, UnitArt.tint(Color("b8452e")))
			_tank_body(b, Color("3a3a3c"), Color("d9b44a"))
		BattleGrid.Mover.GAS_TRUCK:
			_truck_cab(b, UnitArt.tint(Color("3f6fa8")))
			_gas_body(b)
		BattleGrid.Mover.URANIUM_TRUCK:
			_truck_cab(b, UnitArt.tint(Color("5b6a3a")))
			_uranium_body(b)
		BattleGrid.Mover.COAL_TRUCK:
			_truck_cab(b, UnitArt.tint(Color("c48a2a")))
			_dump_body(b)
		BattleGrid.Mover.PIPE:
			_pipe(b)
		BattleGrid.Mover.SEMI:
			_semi(b)
		BattleGrid.Mover.BUS:
			_bus(b)
		BattleGrid.Mover.TRACTOR:
			_tractor(b)
		BattleGrid.Mover.SUB:
			_sub(b)
		BattleGrid.Mover.CRUISER:
			_cruiser(b)
		BattleGrid.Mover.BOAT:
			_boat(b)
		BattleGrid.Mover.WALL:
			_wall(b)
		BattleGrid.Mover.GATE:
			_gate(b)
		_:
			_turret(b, mover)
	return {"body": b.commit(), "legs": [], "rotor": null, "rotor_at": Vector3.ZERO}

static func _wheel(b: B, at: Vector3, r: float = 0.13, w: float = 0.1) -> void:
	b.cyl(r, r, w, at, TIRE, ArtKit.MATTE, Vector3(0, 0, PI * 0.5), 14)
	b.cyl(r * 0.55, r * 0.55, w + 0.01, at, RIM, M, Vector3(0, 0, PI * 0.5), 10)

# Кабина грузовика спереди (z 0.35..0.75), рама и колёса под всем шасси.
static func _truck_cab(b: B, paint: Color) -> void:
	b.box(Vector3(0.5, 0.08, 1.5), Vector3(0, 0.2, 0), Color("2a2c2e"), M)
	b.box(Vector3(0.58, 0.36, 0.38), Vector3(0, 0.46, 0.52), paint, M)
	b.box(Vector3(0.56, 0.12, 0.2), Vector3(0, 0.3, 0.72), paint.darkened(0.15), M)
	b.box(Vector3(0.5, 0.16, 0.02), Vector3(0, 0.56, 0.715), Color("9ec4dc"), GL)
	for sx in [-1.0, 1.0]:
		b.box(Vector3(0.02, 0.12, 0.18), Vector3(sx * 0.291, 0.54, 0.54), Color("9ec4dc"), GL)
		b.ball(0.035, Vector3(sx * 0.2, 0.32, 0.83), Color("fff3c0"), G)
		b.box(Vector3(0.04, 0.08, 0.02), Vector3(sx * 0.34, 0.54, 0.66), CHROME, M)
	b.box(Vector3(0.4, 0.04, 0.03), Vector3(0, 0.25, 0.83), CHROME, M)
	b.box(Vector3(0.3, 0.04, 0.1), Vector3(0, 0.66, 0.5), Color("e8a030"), G)
	for z in [0.55, -0.25, -0.55]:
		for sx in [-1.0, 1.0]:
			_wheel(b, Vector3(sx * 0.28, 0.14, z))

static func _tank_body(b: B, shell: Color, band: Color) -> void:
	b.cyl(0.26, 0.26, 0.95, Vector3(0, 0.48, -0.25), shell, M, Vector3(PI * 0.5, 0, 0), 16)
	for z in [-0.6, 0.1]:
		b.cyl(0.27, 0.27, 0.05, Vector3(0, 0.48, z), band, M, Vector3(PI * 0.5, 0, 0), 16)
	b.cyl(0.06, 0.07, 0.06, Vector3(0, 0.77, -0.25), CHROME, M)
	b.box(Vector3(0.06, 0.02, 0.9), Vector3(0, 0.75, -0.25), Color("4a4a4c"), M)
	b.box(Vector3(0.44, 0.2, 0.02), Vector3(0, 0.48, -0.73), Color("e04a30"))

static func _gas_body(b: B) -> void:
	for sx in [-1.0, 1.0]:
		b.cyl(0.13, 0.13, 0.95, Vector3(sx * 0.14, 0.42, -0.25), Color("e8eef2"), M, Vector3(PI * 0.5, 0, 0), 14)
		b.ball(0.13, Vector3(sx * 0.14, 0.42, 0.22), Color("e8eef2"), M)
		b.ball(0.13, Vector3(sx * 0.14, 0.42, -0.72), Color("e8eef2"), M)
	b.cyl(0.11, 0.11, 0.95, Vector3(0, 0.62, -0.25), Color("dfe6ea"), M, Vector3(PI * 0.5, 0, 0), 14)
	b.box(Vector3(0.5, 0.04, 1.0), Vector3(0, 0.27, -0.25), Color("2e6ab0"), M)
	b.box(Vector3(0.2, 0.12, 0.02), Vector3(0.29, 0.44, -0.25), Color("ff9a30"), G, Vector3(0, PI * 0.5, 0))

static func _uranium_body(b: B) -> void:
	b.box(Vector3(0.56, 0.42, 0.92), Vector3(0, 0.5, -0.25), Color("5a5e58"), M)
	for z in [-0.6, -0.4, -0.2, 0.0]:
		b.box(Vector3(0.58, 0.44, 0.03), Vector3(0, 0.5, z), Color("44483f"), M)
	b.cyl(0.14, 0.14, 0.02, Vector3(0.29, 0.52, -0.3), Color("f0d020"), ArtKit.MATTE, Vector3(0, 0, PI * 0.5), 18)
	for i in 3:
		var a := i * TAU / 3.0
		b.box(Vector3(0.012, 0.07, 0.035), Vector3(0.302, 0.52 + sin(a) * 0.06, -0.3 + cos(a) * 0.06), Color("181818"), ArtKit.MATTE, Vector3(a, 0, 0))
	b.ball(0.035, Vector3(0, 0.75, -0.65), Color("7fff6a"), G)

static func _dump_body(b: B) -> void:
	b.box(Vector3(0.58, 0.3, 0.9), Vector3(0, 0.45, -0.25), UnitArt.tint(Color("9a7a2e")), M)
	b.box(Vector3(0.6, 0.06, 0.92), Vector3(0, 0.62, -0.25), Color("7a5e22"), M)
	for i in 7:
		b.rock(0.12, Vector3(-0.16 + (i % 3) * 0.16, 0.64, -0.6 + i * 0.1), Color("1a1a1a"), Vector3(1, 0.6, 1), i * 13)
	b.box(Vector3(0.6, 0.1, 0.2), Vector3(0, 0.66, 0.24), Color("7a5e22"), M, Vector3(-0.3, 0, 0))

static func _pipe(b: B) -> void:
	b.cyl(0.13, 0.13, 1.0, Vector3(0, 0.32, 0), Color("d8a43a"), M, Vector3(PI * 0.5, 0, 0), 14)
	for z in [-0.48, 0.48]:
		b.cyl(0.16, 0.16, 0.05, Vector3(0, 0.32, z), Color("8a6a2a"), M, Vector3(PI * 0.5, 0, 0), 14)
	for z in [-0.3, 0.3]:
		b.box(Vector3(0.36, 0.2, 0.06), Vector3(0, 0.12, z), Color("6a6c6e"), M)

# Седельный тягач в американском стиле (длинный капот, хром, трубы) + полуприцеп.
static func _semi(b: B) -> void:
	var paint := UnitArt.tint(Color("b0222a"))
	b.box(Vector3(0.5, 0.08, 2.4), Vector3(0, 0.22, -0.3), Color("262829"), M)
	b.box(Vector3(0.5, 0.26, 0.5), Vector3(0, 0.44, 0.7), paint, M)
	b.box(Vector3(0.46, 0.06, 0.48), Vector3(0, 0.6, 0.72), paint.lightened(0.1), M, Vector3(0.12, 0, 0))
	b.box(Vector3(0.36, 0.26, 0.03), Vector3(0, 0.42, 0.96), CHROME, M)
	for i in 6:
		b.box(Vector3(0.32, 0.015, 0.035), Vector3(0, 0.33 + i * 0.035, 0.975), Color("4a4c4e"), M)
	b.box(Vector3(0.62, 0.5, 0.38), Vector3(0, 0.6, 0.27), paint, M)
	b.box(Vector3(0.58, 0.2, 0.02), Vector3(0, 0.7, 0.465), Color("9ec4dc"), GL)
	b.box(Vector3(0.6, 0.16, 0.3), Vector3(0, 0.92, 0.2), paint.darkened(0.1), M)
	for sx in [-1.0, 1.0]:
		b.cyl(0.03, 0.03, 0.75, Vector3(sx * 0.33, 0.85, 0.12), CHROME, M, Vector3.ZERO, 10)
		b.ball(0.04, Vector3(sx * 0.2, 0.42, 0.98), Color("fff3c0"), G)
		b.box(Vector3(0.05, 0.14, 0.03), Vector3(sx * 0.36, 0.7, 0.42), CHROME, M)
		b.cyl(0.08, 0.08, 0.26, Vector3(sx * 0.3, 0.3, 0.3), CHROME, M, Vector3(PI * 0.5, 0, 0), 12)
	for i in 4:
		b.ball(0.018, Vector3(-0.15 + i * 0.1, 1.01, 0.33), Color("ffb040"), G)
	# Полуприцеп-контейнер
	b.box(Vector3(0.66, 0.58, 1.9), Vector3(0, 0.78, -0.75), Color("dadcd8"), M)
	for i in 10:
		b.box(Vector3(0.67, 0.56, 0.02), Vector3(0, 0.78, -1.62 + i * 0.19), Color("c4c6c2"), M)
	b.box(Vector3(0.02, 0.2, 1.2), Vector3(0.34, 0.85, -0.75), paint)
	b.box(Vector3(0.02, 0.2, 1.2), Vector3(-0.34, 0.85, -0.75), paint)
	for z in [0.75, -1.2, -1.42]:
		for sx in [-1.0, 1.0]:
			_wheel(b, Vector3(sx * 0.27, 0.15, z), 0.15)
	for z in [0.15, -0.05]:
		for sx in [-1.0, 1.0]:
			_wheel(b, Vector3(sx * 0.27, 0.15, z), 0.15)

# Автобус в стиле школьного: жёлтый, капот спереди, ряд окон, чёрные полосы.
static func _bus(b: B) -> void:
	var paint := Color("f2b51c").lerp(UnitArt.tint(Color("f2b51c")), 0.4)
	b.box(Vector3(0.66, 0.62, 1.8), Vector3(0, 0.62, -0.15), paint, M)
	b.box(Vector3(0.6, 0.06, 1.74), Vector3(0, 0.95, -0.15), paint.lightened(0.1), M)
	b.box(Vector3(0.56, 0.24, 0.34), Vector3(0, 0.44, 0.9), paint, M)
	b.box(Vector3(0.4, 0.18, 0.03), Vector3(0, 0.4, 1.07), Color("2a2a2a"), M)
	for side in [-1.0, 1.0]:
		for i in 7:
			b.box(Vector3(0.02, 0.18, 0.18), Vector3(side * 0.335, 0.78, 0.55 - i * 0.24), Color("9ec4dc"), GL)
		b.box(Vector3(0.02, 0.03, 1.8), Vector3(side * 0.335, 0.6, -0.15), Color("1a1a1a"))
		b.box(Vector3(0.02, 0.03, 1.8), Vector3(side * 0.335, 0.5, -0.15), Color("1a1a1a"))
		b.ball(0.04, Vector3(side * 0.2, 0.46, 1.08), Color("fff3c0"), G)
		b.ball(0.035, Vector3(side * 0.22, 0.98, 0.76), Color("ff4030"), G)
	b.box(Vector3(0.58, 0.26, 0.02), Vector3(0, 0.78, 0.745), Color("9ec4dc"), GL)
	b.box(Vector3(0.12, 0.14, 0.02), Vector3(-0.42, 0.6, 0.5), Color("d02020"))
	for z in [0.75, -0.75]:
		for sx in [-1.0, 1.0]:
			_wheel(b, Vector3(sx * 0.3, 0.15, z), 0.15)

# Военный тягач 12 осей / 24 колеса с модулем завода на платформе.
static func _tractor(b: B) -> void:
	var paint := UnitArt.tint(Color("5a6448"))
	b.box(Vector3(0.7, 0.12, 2.9), Vector3(0, 0.3, -0.2), Color("2c2e2a"), M)
	b.box(Vector3(0.78, 0.46, 0.5), Vector3(0, 0.62, 1.02), paint, M)
	b.box(Vector3(0.7, 0.16, 0.02), Vector3(0, 0.74, 1.27), Color("9ec4dc"), GL)
	b.box(Vector3(0.6, 0.1, 0.3), Vector3(0, 0.9, 1.0), paint.darkened(0.2), M)
	for sx in [-1.0, 1.0]:
		b.ball(0.04, Vector3(sx * 0.28, 0.48, 1.28), Color("fff3c0"), G)
	b.box(Vector3(0.76, 0.5, 1.6), Vector3(0, 0.7, -0.4), paint.darkened(0.08), M)
	b.box(Vector3(0.6, 0.18, 0.5), Vector3(0, 1.04, -0.1), paint, M)
	b.cyl(0.08, 0.1, 0.4, Vector3(0.2, 1.25, -0.6), Color("4a4c48"), M, Vector3.ZERO, 10)
	b.box(Vector3(0.3, 0.06, 0.5), Vector3(-0.15, 0.98, -0.9), Color("e8a030"), G)
	b.box(Vector3(0.7, 0.16, 0.4), Vector3(0, 0.48, -1.4), Color("3c3e3a"), M)
	for i in 12:
		for sx in [-1.0, 1.0]:
			_wheel(b, Vector3(sx * 0.36, 0.14, 1.1 - i * 0.22), 0.11, 0.1)

static func _hull_shape(b: B, length: float, beam: float, color: Color, deck: Color, height: float) -> void:
	var pts := PackedVector2Array([Vector2(0, length * 0.5), Vector2(beam * 0.5, length * 0.18), Vector2(beam * 0.5, -length * 0.5), Vector2(-beam * 0.5, -length * 0.5), Vector2(-beam * 0.5, length * 0.18)])
	b.plate(pts, height * 0.5, height, color, M)
	var inner := PackedVector2Array()
	for p in pts:
		inner.append(p * 0.92)
	b.plate(inner, height + 0.01, 0.02, deck, ArtKit.MATTE)

static func _sub(b: B) -> void:
	var hull := UnitArt.tint(Color("2b3036"))
	b.cyl(0.24, 0.24, 1.7, Vector3(0, 0.1, 0), hull, M, Vector3(PI * 0.5, 0, 0), 18)
	b.ball(0.24, Vector3(0, 0.1, 0.85), hull, M, Vector3(1, 1, 1.6))
	b.cyl(0.24, 0.04, 0.5, Vector3(0, 0.1, -1.08), hull, M, Vector3(PI * 0.5, 0, 0), 18)
	b.box(Vector3(0.16, 0.36, 0.44), Vector3(0, 0.46, 0.2), hull.lightened(0.05), M)
	b.box(Vector3(0.5, 0.03, 0.12), Vector3(0, 0.5, 0.25), hull, M)
	b.cyl(0.015, 0.015, 0.3, Vector3(0.03, 0.78, 0.25), Color("8a8e92"), M)
	b.box(Vector3(0.7, 0.03, 0.14), Vector3(0, 0.1, -1.1), hull, M)
	b.box(Vector3(0.03, 0.4, 0.14), Vector3(0, 0.1, -1.12), hull, M)
	b.ball(0.025, Vector3(0, 0.66, 0.42), Color("ff4030"), G)

static func _cruiser(b: B) -> void:
	var hull := UnitArt.tint(Color("6b7480"))
	_hull_shape(b, 2.6, 0.82, hull, Color("4a5058"), 0.32)
	b.box(Vector3(0.5, 0.4, 0.7), Vector3(0, 0.52, -0.1), hull.lightened(0.08), M)
	b.box(Vector3(0.36, 0.3, 0.4), Vector3(0, 0.85, -0.05), hull.lightened(0.12), M)
	b.box(Vector3(0.34, 0.06, 0.02), Vector3(0, 0.9, 0.16), Color("9ec4dc"), GL)
	b.cyl(0.02, 0.03, 0.6, Vector3(0, 1.3, -0.1), Color("3a3e44"), M)
	b.box(Vector3(0.4, 0.05, 0.05), Vector3(0, 1.45, -0.1), Color("3a3e44"), M)
	b.cyl(0.12, 0.12, 0.04, Vector3(0, 1.08, 0.08), Color("c8ccd0"), M, Vector3(0.5, 0, 0), 14)
	b.cyl(0.1, 0.12, 0.3, Vector3(0, 0.55, -0.7), Color("3a3e44"), M)
	# Ракетные шахты и носовая башня
	for i in 8:
		b.box(Vector3(0.1, 0.03, 0.1), Vector3(-0.17 + (i % 4) * 0.115, 0.34, 0.55 + (i / 4) * 0.13), Color("2a2e34"), M)
	b.cyl(0.13, 0.15, 0.12, Vector3(0, 0.4, 0.95), hull, M)
	b.cyl(0.03, 0.03, 0.4, Vector3(0, 0.44, 1.15), Color("2a2e34"), M, Vector3(PI * 0.5, 0, 0), 8)
	for sx in [-1.0, 1.0]:
		b.box(Vector3(0.14, 0.16, 0.3), Vector3(sx * 0.22, 0.42, -0.95), Color("4a5058"), M, Vector3(-0.4, 0, 0))
	b.ball(0.03, Vector3(0.38, 0.38, 0.6), Color("40ff60"), G)
	b.ball(0.03, Vector3(-0.38, 0.38, 0.6), Color("ff4030"), G)

static func _boat(b: B) -> void:
	var hull := UnitArt.tint(Color("d8dcd8"))
	_hull_shape(b, 1.3, 0.5, hull, Color("8a8e88"), 0.22)
	b.box(Vector3(0.34, 0.22, 0.36), Vector3(0, 0.34, -0.05), hull.darkened(0.08), M)
	b.box(Vector3(0.32, 0.08, 0.02), Vector3(0, 0.4, 0.13), Color("9ec4dc"), GL)
	b.cyl(0.012, 0.012, 0.3, Vector3(0, 0.6, -0.1), Color("3a3e44"), M)
	b.cyl(0.05, 0.06, 0.06, Vector3(0, 0.27, 0.4), Color("2a2e34"), M)
	b.cyl(0.012, 0.012, 0.22, Vector3(0, 0.31, 0.52), Color("2a2e34"), M, Vector3(PI * 0.5, 0, 0), 6)
	b.box(Vector3(0.2, 0.1, 0.14), Vector3(0, 0.3, -0.45), Color("3a3e44"), M)
	b.box(Vector3(0.52, 0.03, 0.06), Vector3(0, 0.1, 0.0), Color("c03020"))

static func _turret(b: B, mover: int) -> void:
	var base := UnitArt.tint(Color("6a6e66"))
	b.cyl(0.42, 0.48, 0.24, Vector3(0, 0.12, 0), Color("8a8a82"), ArtKit.MATTE, Vector3.ZERO, 8)
	b.cyl(0.32, 0.36, 0.14, Vector3(0, 0.31, 0), base, M, Vector3.ZERO, 16)
	match mover:
		BattleGrid.Mover.T_MG:
			b.box(Vector3(0.34, 0.24, 0.36), Vector3(0, 0.5, 0), base.lightened(0.05), M)
			for sx in [-1.0, 1.0]:
				b.cyl(0.03, 0.03, 0.5, Vector3(sx * 0.08, 0.55, 0.38), Color("1e2022"), M, Vector3(PI * 0.5, 0, 0), 8)
				b.box(Vector3(0.08, 0.1, 0.16), Vector3(sx * 0.22, 0.5, -0.04), Color("4a4a44"), M)
			b.box(Vector3(0.2, 0.03, 0.12), Vector3(0, 0.64, 0.12), Color("9ec4dc"), GL)
		BattleGrid.Mover.T_CANNON:
			b.box(Vector3(0.62, 0.26, 0.66), Vector3(0, 0.52, -0.02), base, M)
			b.box(Vector3(0.52, 0.14, 0.3), Vector3(0, 0.5, 0.36), base.darkened(0.1), M, Vector3(-0.4, 0, 0))
			b.cyl(0.05, 0.055, 0.85, Vector3(0, 0.55, 0.75), Color("2a2e26"), M, Vector3(PI * 0.5, 0, 0), 12)
			b.cyl(0.08, 0.08, 0.14, Vector3(0, 0.55, 1.15), Color("2a2e26"), M, Vector3(PI * 0.5, 0, 0), 12)
			b.cyl(0.1, 0.11, 0.08, Vector3(0.15, 0.7, -0.12), base, M)
		BattleGrid.Mover.T_MISSILE:
			b.box(Vector3(0.2, 0.3, 0.2), Vector3(0, 0.52, 0), base, M)
			for sx in [-1.0, 1.0]:
				b.box(Vector3(0.24, 0.24, 0.5), Vector3(sx * 0.24, 0.62, 0.05), base.lightened(0.06), M, Vector3(-0.25, 0, 0))
				for i in 4:
					b.cyl(0.04, 0.04, 0.02, Vector3(sx * 0.24 + (i % 2 - 0.5) * 0.11, 0.69 + (i / 2 - 0.5) * 0.11, 0.31), Color("e04a30"), G, Vector3(PI * 0.5 - 0.25, 0, 0), 8)
		BattleGrid.Mover.T_LASER:
			b.ball(0.22, Vector3(0, 0.55, 0), base.lightened(0.1), M)
			b.cyl(0.05, 0.08, 0.6, Vector3(0, 0.58, 0.35), Color("c8ccd0"), M, Vector3(PI * 0.5, 0, 0), 12)
			for i in 3:
				b.cyl(0.085, 0.085, 0.02, Vector3(0, 0.58, 0.2 + i * 0.13), Color("ff3040"), G, Vector3(PI * 0.5, 0, 0), 12)
		BattleGrid.Mover.T_ION:
			b.cyl(0.18, 0.24, 0.3, Vector3(0, 0.52, 0), base, M, Vector3.ZERO, 12)
			for i in 3:
				var a := i * TAU / 3.0
				b.rod(Vector3(cos(a) * 0.18, 0.62, sin(a) * 0.18), Vector3(cos(a) * 0.06, 1.05, sin(a) * 0.06 + 0.1), 0.025, Color("8a8e92"))
			b.ball(0.12, Vector3(0, 1.08, 0.1), Color("5fc8ff"), G)
		_:
			b.cyl(0.08, 0.1, 0.7, Vector3(0, 0.75, 0), Color("4a4c50"), M, Vector3.ZERO, 12)
			for i in 5:
				b.cyl(0.2 - i * 0.02, 0.2 - i * 0.02, 0.05, Vector3(0, 0.5 + i * 0.12, 0), Color("c47a3a"), M, Vector3.ZERO, 16)
			b.ball(0.16, Vector3(0, 1.2, 0), Color("c8ccd0"), M)
			b.ball(0.07, Vector3(0, 1.2, 0.14), Color("b0a0ff"), G)

static func _wall(b: B) -> void:
	b.box(Vector3(1.0, 0.7, 0.36), Vector3(0, 0.35, 0), Color("a29e92"), ArtKit.MATTE)
	b.box(Vector3(1.0, 0.08, 0.42), Vector3(0, 0.72, 0), Color("8a867a"), ArtKit.MATTE)
	for x in [-0.3, 0.3]:
		b.box(Vector3(0.02, 0.6, 0.37), Vector3(x, 0.35, 0), Color("7a766a"), ArtKit.MATTE)
	b.box(Vector3(1.0, 0.1, 0.38), Vector3(0, 0.05, 0), UnitArt.tint(Color("6a6e66")), ArtKit.MATTE)

static func _gate(b: B) -> void:
	for sx in [-1.0, 1.0]:
		b.box(Vector3(0.16, 0.95, 0.42), Vector3(sx * 0.45, 0.48, 0), Color("8a867a"), ArtKit.MATTE)
		b.ball(0.04, Vector3(sx * 0.45, 0.99, 0.0), Color("ffb040"), G)
	b.box(Vector3(0.74, 0.62, 0.08), Vector3(0, 0.36, 0), UnitArt.tint(Color("5d646b")), M)
	for i in 5:
		b.box(Vector3(0.03, 0.6, 0.1), Vector3(-0.3 + i * 0.15, 0.36, 0), Color("3a3e44"), M)
	b.box(Vector3(0.74, 0.08, 0.1), Vector3(0, 0.6, 0), Color("e8c040"), ArtKit.MATTE)
