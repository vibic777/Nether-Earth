# Контрибьютор: vibic777
class_name WeaponRack
extends RefCounted

enum Kind { BULLET, SHELL, FLAME, ROCKET, BOMB, LASER, PLASMA, ION, TESLA }

const _ORDER: Array[int] = [
	Kind.BULLET,
	Kind.SHELL,
	Kind.FLAME,
	Kind.ROCKET,
	Kind.BOMB,
	Kind.LASER,
	Kind.PLASMA,
	Kind.ION,
	Kind.TESLA,
]

static func _d_title(kind: int) -> String:
	match kind:
		Kind.BULLET:
			return "Пули"
		Kind.SHELL:
			return "Снаряды"
		Kind.FLAME:
			return "Огнемёт"
		Kind.ROCKET:
			return "Ракеты"
		Kind.BOMB:
			return "Бомбы"
		Kind.LASER:
			return "Лазер"
		Kind.PLASMA:
			return "Плазма"
		Kind.ION:
			return "Ионная пушка"
		Kind.TESLA:
			return "Тесла"
		_:
			return ""

static func _d_base_power(kind: int) -> int:
	match kind:
		Kind.BULLET:
			return 2
		Kind.FLAME:
			return 3
		Kind.LASER:
			return 4
		Kind.SHELL:
			return 5
		Kind.ROCKET:
			return 6
		Kind.TESLA:
			return 6
		Kind.ION:
			return 7
		Kind.PLASMA:
			return 8
		Kind.BOMB:
			return 9
		_:
			return 0

static func _d_min_tier(kind: int) -> int:
	match kind:
		Kind.BULLET, Kind.FLAME, Kind.LASER:
			return 1
		Kind.SHELL, Kind.ROCKET, Kind.TESLA, Kind.ION, Kind.BOMB:
			return 2
		_:
			return 3

static func _d_max_tier(mover: int) -> int:
	match mover:
		BattleGrid.Mover.WALKER, BattleGrid.Mover.TRACK, BattleGrid.Mover.UAV, BattleGrid.Mover.JET:
			return 3
		BattleGrid.Mover.ROTOR:
			return 2
		BattleGrid.Mover.BIKE, BattleGrid.Mover.TROOPER:
			return 1
		_:
			return 0

static func flies(mover: int) -> bool:
	return BattleGrid.airborne(mover)

static func allowed(mover: int, kind: int) -> bool:
	if max_tier(mover) <= 0 or max_tier(mover) < min_tier(kind):
		return false
	if kind == Kind.BOMB and not flies(mover):
		return false
	if kind == Kind.FLAME and BattleGrid.fixed_wing(mover):
		return false
	return true

static func options(mover: int) -> Array[int]:
	var list: Array[int] = []
	for kind in _ORDER:
		if allowed(mover, kind):
			list.append(kind)
	return list

static func strike(kind: int, tier: int) -> int:
	return base_power(kind) * tier

static func _d_strike(kind: int, tier: int) -> int:
	return _d_base_power(kind) * tier

static func roman(tier: int) -> String:
	match tier:
		1:
			return "I"
		2:
			return "II"
		_:
			return "III"

static func _d_color_of(kind: int) -> Color:
	match kind:
		Kind.BULLET:
			return Color("c5c8cc")
		Kind.SHELL:
			return Color("e07a2f")
		Kind.FLAME:
			return Color("e23b2b")
		Kind.ROCKET:
			return Color("f2f2f2")
		Kind.BOMB:
			return Color("2a2d31")
		Kind.LASER:
			return Color("3ec8e6")
		Kind.PLASMA:
			return Color("b14bff")
		Kind.ION:
			return Color("3d6dff")
		_:
			return Color("f0d24a")

static func default_kind(mover: int) -> int:
	var key := str(GameData.unit(mover, "weapon", ""))
	if key != "":
		return GameData.WEAPON_KEYS.find(key)
	match mover:
		BattleGrid.Mover.WALKER:
			return Kind.SHELL
		BattleGrid.Mover.UAV:
			return Kind.BOMB
		BattleGrid.Mover.JET:
			return Kind.ROCKET
		BattleGrid.Mover.ROTOR:
			return Kind.ROCKET
		BattleGrid.Mover.TRACK:
			return Kind.PLASMA
		BattleGrid.Mover.BIKE:
			return Kind.BULLET
		BattleGrid.Mover.TROOPER:
			return Kind.LASER
		_:
			return -1

static func default_tier(mover: int, kind: int) -> int:
	var preferred := 2 if max_tier(mover) >= 2 else 1
	return clampi(preferred, min_tier(kind), max_tier(mover))

static func _d_range_of(kind: int) -> float:
	match kind:
		Kind.FLAME:
			return 5.5
		Kind.TESLA:
			return 8.0
		Kind.BULLET:
			return 9.0
		Kind.BOMB:
			return 11.0
		Kind.PLASMA:
			return 12.0
		Kind.SHELL:
			return 13.0
		Kind.LASER, Kind.ION:
			return 14.0
		Kind.ROCKET:
			return 16.0
		_:
			return 0.0

static func _d_cooldown(kind: int) -> float:
	match kind:
		Kind.FLAME:
			return 0.22
		Kind.BULLET:
			return 0.28
		Kind.LASER:
			return 0.7
		Kind.TESLA:
			return 1.0
		Kind.SHELL:
			return 1.15
		Kind.PLASMA:
			return 1.35
		Kind.ROCKET:
			return 1.4
		Kind.ION:
			return 1.8
		_:
			return 2.0

static func _d_splash_of(kind: int) -> float:
	match kind:
		Kind.SHELL:
			return 1.8
		Kind.ROCKET:
			return 2.4
		Kind.PLASMA:
			return 2.0
		Kind.BOMB:
			return 3.4
		_:
			return 0.0

static func _d_stun_of(kind: int) -> float:
	return 2.4 if kind == Kind.ION else 0.0

static func _d_chains_of(kind: int) -> int:
	return 3 if kind == Kind.TESLA else 0

static func _d_speed_of(kind: int) -> float:
	match kind:
		Kind.BULLET:
			return 28.0
		Kind.ROCKET:
			return 18.0
		Kind.SHELL:
			return 16.0
		Kind.BOMB:
			return 14.0
		Kind.PLASMA:
			return 9.0
		_:
			return 0.0

static func hitscan(kind: int) -> bool:
	return kind == Kind.LASER or kind == Kind.ION or kind == Kind.TESLA or kind == Kind.FLAME

static func _d_damage(kind: int, tier: int) -> float:
	var scale := 1.0
	match kind:
		Kind.BULLET:
			scale = 0.5
		Kind.FLAME:
			scale = 0.4
		Kind.LASER:
			scale = 0.85
		Kind.SHELL:
			scale = 1.15
		Kind.ROCKET:
			scale = 1.25
		Kind.TESLA:
			scale = 0.75
		Kind.ION:
			scale = 0.4
		Kind.PLASMA:
			scale = 1.4
		Kind.BOMB:
			scale = 1.7
	return float(strike(kind, tier)) * scale

static func title(kind: int) -> String:
	return GameData.weapon(kind, "name", _d_title(kind))

static func base_power(kind: int) -> int:
	return GameData.weapon(kind, "power", _d_base_power(kind))

static func min_tier(kind: int) -> int:
	return GameData.weapon(kind, "min_tier", _d_min_tier(kind))

static func color_of(kind: int) -> Color:
	return GameData.weapon(kind, "color", _d_color_of(kind))

static func range_of(kind: int) -> float:
	return GameData.weapon(kind, "range", _d_range_of(kind))

static func cooldown(kind: int) -> float:
	return GameData.weapon(kind, "cooldown", _d_cooldown(kind))

static func splash_of(kind: int) -> float:
	return GameData.weapon(kind, "splash", _d_splash_of(kind))

static func stun_of(kind: int) -> float:
	return GameData.weapon(kind, "stun", _d_stun_of(kind))

static func chains_of(kind: int) -> int:
	return GameData.weapon(kind, "chains", _d_chains_of(kind))

static func speed_of(kind: int) -> float:
	return GameData.weapon(kind, "speed", _d_speed_of(kind))

static func damage(kind: int, tier: int) -> float:
	var scale: float = GameData.weapon(kind, "damage_scale", _d_damage(kind, 1) / maxf(float(_d_strike(kind, 1)), 0.001))
	return float(strike(kind, tier)) * scale

static func max_tier(mover: int) -> int:
	return GameData.unit(mover, "max_tier", _d_max_tier(mover))
