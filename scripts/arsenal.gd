# Контрибьютор: vibic777
# Три режима оружия у каждой машины: 0 — основной, 1 — усиленный (сильнее, долгая перезарядка),
# 2 — особый (копит заряд; у миномёта ещё и развёртывание). Основной режим = выбранное в WeaponRack оружие.
class_name Arsenal
extends RefCounted

const MODE_DEFAULT := 0
const MODE_HEAVY := 1
const MODE_SPECIAL := 2
const K := WeaponRack.Kind

# kind: -1 = основное оружие юнита. dmg/cd/range/splash — множители и добавки.
static func _d_modes(mover: int) -> Array:
	match mover:
		BattleGrid.Mover.TRACK:
			return [
				_m("Пушка", -1, "barrel"),
				_m("Ракеты", K.ROCKET, "rocket", 1.9, 2.4, 1.15, 0.6),
				_m("Миномёт", K.SHELL, "mortar", 3.2, 1.0, 1.7, 3.6, 14.0, 1.6, true),
			]
		BattleGrid.Mover.WALKER:
			return [
				_m("Пулемёты", K.BULLET, "mg"),
				_m("Гранатомёт", K.SHELL, "grenade", 1.8, 2.2, 1.0, 1.6),
				_m("Лазерная турель", K.LASER, "laser", 4.0, 1.0, 1.4, 0.0, 12.0),
			]
		BattleGrid.Mover.UAV:
			return [
				_m("Пушка", -1, "barrel"),
				_m("Ракеты", K.ROCKET, "rocket", 1.8, 2.3, 1.1, 0.4),
				_m("Ковровая бомба", K.BOMB, "bomb", 3.0, 1.0, 1.0, 4.5, 15.0),
			]
		BattleGrid.Mover.JET:
			var gun := _m("Пушка (и по воздуху)", K.BULLET, "mg", 1.2, 0.8, 1.2)
			var bombs := _m("Управляемые бомбы", K.BOMB, "bomb", 3.4, 1.0, 1.2, 3.0, 0.0)
			bombs["targets"] = "ground"
			return [gun, _m("Ракеты", K.ROCKET, "rocket", 2.0, 1.6, 1.3, 0.6), bombs]
		BattleGrid.Mover.ROTOR:
			return [
				_m("Пулемёт", K.BULLET, "mg"),
				_m("НУРС-залп", K.ROCKET, "rocket", 1.9, 2.4, 1.1, 0.8),
				_m("ПТУР (глушит)", K.ION, "ion", 3.0, 1.0, 1.3, 0.0, 11.0),
			]
		BattleGrid.Mover.BIKE:
			return [
				_m("Пулемёт", K.BULLET, "mg"),
				_m("Огнемёт", K.FLAME, "flame", 1.7, 2.0, 1.0),
				_m("Тесла-разряд", K.TESLA, "tesla", 3.0, 1.0, 1.0, 0.0, 10.0),
			]
		BattleGrid.Mover.TROOPER:
			return [
				_m("Винтовка", -1, "mg"),
				_m("Подствольник", K.SHELL, "grenade", 1.7, 2.2, 0.9, 1.4),
				_m("Снайперский выстрел", K.LASER, "laser", 4.5, 1.0, 1.6, 0.0, 10.0),
			]
		_:
			return []

static func _m(title: String, kind: int, icon: String, dmg: float = 1.0, cd: float = 1.0, reach: float = 1.0, splash: float = 0.0, charge: float = 0.0, deploy: float = 0.0, lob: bool = false) -> Dictionary:
	return {"title": title, "kind": kind, "icon": icon, "dmg": dmg, "cd": cd, "range": reach, "splash": splash, "charge": charge, "deploy": deploy, "lob": lob, "targets": "all"}

static func mode_name(mode: int) -> String:
	return ["Основной", "Усиленный", "Особый"][clampi(mode, 0, 2)]

# Способности (кнопка в панели, клавиша T).
static func _d_ability(mover: int) -> Dictionary:
	match mover:
		BattleGrid.Mover.UAV:
			return {"title": "Разведка", "cooldown": 30.0, "time": 12.0, "radius": 9}
		BattleGrid.Mover.ROTOR:
			return {"title": "Осветительная ракета", "cooldown": 25.0, "time": 8.0, "radius": 6}
		BattleGrid.Mover.ENGINEER:
			return {"title": "Ремонт рядом", "cooldown": 20.0, "time": 0.0, "radius": 3}
		BattleGrid.Mover.WALKER:
			return {"title": "Щит", "cooldown": 30.0, "time": 6.0, "radius": 0}
		_:
			return {}

static var _modes_cache := {}

static func modes(mover: int) -> Array:
	if not _modes_cache.has(mover):
		_modes_cache[mover] = _modes_build(mover)
	return _modes_cache[mover]

static func _modes_build(mover: int) -> Array:
	var d := _d_modes(mover)
	var raw: Array = GameData.unit(mover, "modes", [])
	if raw.size() == 3 and d.size() != 3:
		d = [_m("", -1, "mg"), _m("", -1, "mg"), _m("", -1, "mg")]
	if raw.size() != 3 or d.size() != 3:
		return d
	var out := []
	for i in 3:
		var m: Dictionary = d[i].duplicate()
		var r: Dictionary = raw[i]
		for key in m.keys():
			if r.has(key):
				if key == "kind":
					m[key] = GameData.WEAPON_KEYS.find(str(r[key])) if str(r[key]) != "MAIN" else -1
				elif m[key] is bool:
					m[key] = bool(r[key])
				elif m[key] is String:
					m[key] = str(r[key])
				else:
					m[key] = float(r[key])
		out.append(m)
	return out

static func ability(mover: int) -> Dictionary:
	var d := _d_ability(mover)
	var r: Dictionary = GameData.unit(mover, "ability", {})
	if d.is_empty() and not r.is_empty():
		d = {"title": "", "cooldown": 20.0, "time": 0.0, "radius": 0}
	if d.is_empty() or r.is_empty():
		return d
	var m := d.duplicate()
	for key in m.keys():
		if r.has(key):
			m[key] = str(r[key]) if m[key] is String else (int(r[key]) if m[key] is int else float(r[key]))
	return m
