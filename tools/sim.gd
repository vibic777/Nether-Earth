# Контрибьютор: vibic777
# Прогон схватки без экрана: godot --headless -s res://tools/sim.gd  (SIM_MAP, SIM_FRAMES)
extends SceneTree
var n := 0
var main
func _initialize():
	var mp := OS.get_environment("SIM_MAP") if OS.get_environment("SIM_MAP") != "" else "eight"
	MatchSetup.map_id = mp
	MatchSetup.slots = MatchSetup.default_slots(int(MapData.load_map(mp).get("players", 2)))
	for s in MatchSetup.slots:
		s["level"] = 4
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	Engine.time_scale = 4.0
func _process(_d):
	n += 1
	var frames := int(OS.get_environment("SIM_FRAMES")) if OS.get_environment("SIM_FRAMES") != "" else 3000
	if n % 500 == 0 or n == frames:
		var per := {}
		for u in main.get_tree().get_nodes_in_group("units"):
			per[u.side] = per.get(u.side, 0) + 1
		var owned := {}
		for s in main.get_tree().get_nodes_in_group("sites"):
			owned[s.team] = owned.get(s.team, 0) + 1
		for s in main.get_tree().get_nodes_in_group("sites"):
			if s.team == 2:
				print("  side2 site ", GameData.SITE_KEYS[s.kind], " queue ", s.queue)
		var st = Stockpile.of(main.get_tree(), 3)
		print("  stock3 ", st.line() if st else "нет")
		var zs := {}
		for z in main.get_tree().get_nodes_in_group("zones"):
			zs[z.owner_side] = zs.get(z.owner_side, 0) + 1
		var kinds := {}
		for u in main.get_tree().get_nodes_in_group("units"):
			if u.side == 2:
				var k: String = GameData.UNIT_KEYS[u.mover]
				kinds[k] = kinds.get(k, 0) + 1
		print("  зоны ", zs, " состав2 ", kinds, " $2=", Stockpile.of(main.get_tree(), 2).money if Stockpile.of(main.get_tree(), 2) else -1)
		if OS.get_environment("SIM_DIAG") != "":
			for u in main.get_tree().get_nodes_in_group("units"):
				if u.side == 2 and u.mover == BattleGrid.Mover.ENGINEER:
					print("    инж ", main._grid.cell_from_world(u.global_position), " link=", u.linked(), " site=", u._site, " path ", u._index, "/", u._path.size())
			for z in main.get_tree().get_nodes_in_group("zones"):
				print("    зона ", z.title, " c=", z.center, " own=", z.owner_side, " cap=", z.capturer, " ", int(z.control), "% сеть2=", RelayNet.covers_side(main.get_tree(), z.global_position, 2))
		print("кадр %d юниты %s узлы %s итог '%s'" % [n, per, owned, main.outcome()])
	if n >= frames:
		quit()
	return false
