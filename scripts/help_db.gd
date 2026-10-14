# Контрибьютор: vibic777
# Статьи справочника: собираются из data/game.json (описания + характеристики).
class_name HelpDB
extends RefCounted

const UNIT_ORDER := [BattleGrid.Mover.WALKER, BattleGrid.Mover.TRACK, BattleGrid.Mover.UAV, BattleGrid.Mover.JET, BattleGrid.Mover.ROTOR, BattleGrid.Mover.BIKE, BattleGrid.Mover.TROOPER, BattleGrid.Mover.ENGINEER]

static func unit_id(mover: int) -> String:
	return "unit_" + GameData.UNIT_KEYS[mover]

static func site_id(kind: int) -> String:
	return "site_" + GameData.SITE_KEYS[kind]

static func terrain_id(kind: int) -> String:
	return "terrain_" + GameData.TERRAIN_KEYS[kind]

static func weapon_id(kind: int) -> String:
	return "weapon_" + GameData.WEAPON_KEYS[kind]

# [{"id","title","category"}] в порядке оглавления.
static func index() -> Array:
	var out := []
	for id in ["controls", "cursors", "ui_panel", "ui_minimap", "ui_groups", "ui_selection", "ui_orders", "ui_weapons", "ui_camera", "ui_exit", "ui_log", "ui_story", "ui_resources", "ui_difficulty", "fog", "ui_cheats", "ui_settings", "lobby", "maps", "multiplayer", "victory", "jet_rearm"]:
		var h: Dictionary = GameData.help().get(id, {})
		out.append({"id": id, "title": h.get("title", id), "category": "Управление и интерфейс"})
	for m in UNIT_ORDER:
		out.append({"id": unit_id(m), "title": Yard.mover_name(m), "category": "Техника"})
	for k in GameData.SITE_KEYS.size():
		out.append({"id": site_id(k), "title": GameData.site(k, "name", GameData.SITE_KEYS[k]), "category": "Здания"})
	for k in GameData.WEAPON_KEYS.size():
		out.append({"id": weapon_id(k), "title": WeaponRack.title(k), "category": "Оружие"})
	for k in GameData.TERRAIN_KEYS.size():
		out.append({"id": terrain_id(k), "title": str(GameData.terrain(k, "name", "")).capitalize(), "category": "Ландшафт"})
	return out

static func title(id: String) -> String:
	for e in index():
		if e["id"] == id:
			return e["title"]
	return id

# Короткий текст для подсказки F1.
static func short(id: String) -> String:
	var t := body(id, false)
	return t if t.length() < 260 else t.substr(0, 257) + "…"

# Полный текст статьи (BBCode).
static func body(id: String, full: bool = true) -> String:
	if id.begins_with("unit_"):
		var m := GameData.UNIT_KEYS.find(id.substr(5))
		var desc: String = GameData.unit(m, "description", "")
		if not full:
			return desc
		var cost := Yard.cost(m)
		var t := desc + "\n\n[b]Характеристики[/b]\n"
		t += "Броня: %d · скорость: %.1f · обзор: %d клеток\n" % [int(GameData.unit(m, "hull", 0.0)), float(GameData.unit(m, "speed", 0.0)), FogOfWar.sight(m)]
		t += "Цена: %d металла, %d чипов, %d энергии · постройка %.0f с\n" % [cost.x, cost.y, cost.z, Yard.seconds(m)]
		var modes := Arsenal.modes(m)
		if not modes.is_empty():
			t += "\n[b]Режимы оружия[/b] (Z / X / C)\n"
			for i in modes.size():
				var md: Dictionary = modes[i]
				var extra := ""
				if float(md["charge"]) > 0.0:
					extra += ", заряд %.0f с" % float(md["charge"])
				if float(md["deploy"]) > 0.0:
					extra += ", развёртывание %.1f с" % float(md["deploy"])
				t += "%s — %s: урон ×%.1f, перезарядка ×%.1f, дальность ×%.1f%s\n" % [["Z", "X", "C"][i], md["title"], float(md["dmg"]), float(md["cd"]), float(md["range"]), extra]
		var ab := Arsenal.ability(m)
		if not ab.is_empty():
			t += "\n[b]Способность (T)[/b]: %s, перезарядка %.0f с\n" % [ab["title"], float(ab["cooldown"])]
		return t
	if id.begins_with("site_"):
		var k := GameData.SITE_KEYS.find(id.substr(5))
		var desc2: String = GameData.site(k, "description", "")
		if not full:
			return desc2
		var built := Yard.catalog(k)
		if not built.is_empty():
			var names: Array[String] = []
			for mv in built:
				names.append(Yard.mover_name(mv))
			desc2 += "\n\nСтроит: " + ", ".join(names)
		return desc2
	if id.begins_with("weapon_"):
		var w := GameData.WEAPON_KEYS.find(id.substr(7))
		var d3: String = GameData.weapon(w, "description", "")
		if not full:
			return d3
		return d3 + "\n\nСила: %d × ступень (I–III, мин. %s) · дальность %.0f · перезарядка %.2f с · взрыв %.1f" % [WeaponRack.base_power(w), WeaponRack.roman(WeaponRack.min_tier(w)), WeaponRack.range_of(w), WeaponRack.cooldown(w), WeaponRack.splash_of(w)]
	if id.begins_with("terrain_"):
		var tk := GameData.TERRAIN_KEYS.find(id.substr(8))
		return GameData.terrain(tk, "description", "")
	var h: Dictionary = GameData.help().get(id, {})
	return str(h.get("text", ""))
