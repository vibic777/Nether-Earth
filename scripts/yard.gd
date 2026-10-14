# Контрибьютор: vibic777
class_name Yard
extends RefCounted

static func catalog(kind: int) -> Array[int]:
	var list: Array[int] = []
	var keys: Array = GameData.site(kind, "builds", [])
	if not keys.is_empty():
		for k in keys:
			var m := GameData.UNIT_KEYS.find(str(k))
			if m >= 0:
				list.append(m)
		return list
	match kind:
		SitePlan.KIND_FACTORY:
			list = [BattleGrid.Mover.WALKER, BattleGrid.Mover.TRACK]
		SitePlan.KIND_AIR:
			list = [BattleGrid.Mover.UAV, BattleGrid.Mover.ROTOR, BattleGrid.Mover.JET]
		SitePlan.KIND_ROBOT:
			list = [BattleGrid.Mover.TROOPER, BattleGrid.Mover.BIKE, BattleGrid.Mover.ENGINEER]
	return list

static func builds(kind: int, mover: int) -> bool:
	return catalog(kind).has(mover)

static func _d_cost(mover: int) -> Vector3i:
	match mover:
		BattleGrid.Mover.TROOPER:
			return Vector3i(12, 0, 2)
		BattleGrid.Mover.BIKE:
			return Vector3i(18, 6, 2)
		BattleGrid.Mover.ENGINEER:
			return Vector3i(14, 10, 2)
		BattleGrid.Mover.ROTOR:
			return Vector3i(22, 16, 8)
		BattleGrid.Mover.UAV:
			return Vector3i(28, 22, 10)
		BattleGrid.Mover.TRACK:
			return Vector3i(40, 12, 10)
		BattleGrid.Mover.WALKER:
			return Vector3i(48, 18, 14)
		_:
			return Vector3i(999, 999, 999)

static func _d_seconds(mover: int) -> float:
	match mover:
		BattleGrid.Mover.TROOPER:
			return 4.0
		BattleGrid.Mover.BIKE, BattleGrid.Mover.ENGINEER:
			return 5.0
		BattleGrid.Mover.ROTOR:
			return 7.0
		BattleGrid.Mover.UAV:
			return 8.0
		BattleGrid.Mover.TRACK:
			return 9.0
		_:
			return 10.0

static func _d_mover_name(mover: int) -> String:
	match mover:
		BattleGrid.Mover.WALKER:
			return "Шагоход"
		BattleGrid.Mover.UAV:
			return "БПЛА"
		BattleGrid.Mover.ROTOR:
			return "Ротор"
		BattleGrid.Mover.TRACK:
			return "Гусеницы"
		BattleGrid.Mover.BIKE:
			return "Мото"
		BattleGrid.Mover.TROOPER:
			return "Пехота"
		BattleGrid.Mover.ENGINEER:
			return "Инженер"
		_:
			return ""

static func price_text(mover: int) -> String:
	return "%s\n$%d" % [mover_name(mover), cost(mover).x]

# Цена в долларах: Vector3i($, 0, 0). Поле price в data/game.json; без него — из старой цены.
static func cost(mover: int) -> Vector3i:
	var legacy: Vector3i = GameData.unit(mover, "cost", _d_cost(mover))
	return Vector3i(int(GameData.unit(mover, "price", legacy.x * 3 + legacy.y * 4 + legacy.z * 2)), 0, 0)

static func usd(mover: int) -> int:
	return cost(mover).x

static func seconds(mover: int) -> float:
	return GameData.unit(mover, "build_seconds", _d_seconds(mover))

static func mover_name(mover: int) -> String:
	return GameData.unit(mover, "name", _d_mover_name(mover))
