extends SceneTree
var n := 0
var main
func _initialize():
	var mp := OS.get_environment("SHOT_MAP")
	if mp != "":
		MatchSetup.map_id = mp
		MatchSetup.slots = MatchSetup.default_slots(int(MapData.load_map(mp).get("players", 2)))
	if OS.get_environment("SHOT_LOADING") != "":
		var t := OS.get_environment("SHOT_LOADING")
		if t == "unload":
			LoadingScreen.open(self, "Выгрузка матча").report(0.55, "Выгрузка техники: 450 / 848")
		elif t == "quit":
			LoadingScreen.open(self, "Выход из игры").report(0.3, "Сохранение настроек")
		else:
			LoadingScreen.open(self).report(0.46, "Генерация рельефа…")
		return
	if OS.get_environment("SHOT_LOBBY") != "":
		main = load("res://scenes/lobby.tscn").instantiate()
		root.add_child(main)
		return
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
func _process(_d):
	n += 1
	if OS.get_environment("SHOT_LOADING") != "":
		if n == 120:
			root.get_texture().get_image().save_png(OS.get_environment("SHOT_OUT"))
			quit()
		return false
	if OS.get_environment("SHOT_LOBBY") != "":
		var tab := OS.get_environment("SHOT_TAB")
		if n == 150 and tab != "":
			main.settings_menu.open()
			var tabs: TabContainer = main.settings_menu._tabs
			for i in tabs.get_tab_count():
				if tabs.get_tab_title(i) == tab:
					tabs.current_tab = i
		if n == 200:
			root.get_texture().get_image().save_png(OS.get_environment("SHOT_OUT"))
			quit()
		return false
	if OS.get_environment("SHOT_CONFIRM") != "":
		if n == 150:
			main.to_lobby()
		if n == 160:
			root.get_texture().get_image().save_png(OS.get_environment("SHOT_OUT"))
			quit()
		return false
	var rig = main.get_node("CameraRig")
	var x := OS.get_environment("SHOT_X")
	if x != "":
		rig.position.x = float(x)
		rig.position.z = float(OS.get_environment("SHOT_Z")) if OS.get_environment("SHOT_Z") != "" else 14.0
	var s := OS.get_environment("SHOT_SIZE")
	if s != "":
		rig.set("_target_size", float(s)); rig.set("_size", float(s))
	if n == 60 and OS.get_environment("SHOT_SELECT") != "":
		var mine: Array[BattleUnit] = []
		for u in main.get_tree().get_nodes_in_group("units"):
			if u.side == SitePlan.OWNER_PLAYER: mine.append(u)
		main._set_selection(mine)
		main._store_group(1)
	if n == 90 and OS.get_environment("SHOT_EXTRA") != "":
		OrderMarker.life_scale = 50.0
		main.get_node("Hud").toggle_cheats()
		var g = main._grid
		var i := 0
		for st in ["foot", "track", "claw", "air", "atk_rocket", "atk_barrel", "atk_mortar"]:
			var p: Vector3 = g.cell_center(Vector2i(6 + i, 4))
			p.y = g.terrain_y(p.x, p.z) + 0.02
			OrderMarker.spawn(main, p, st, Color("7ef08a") if not st.begins_with("atk") else Color("ff7a5a"))
			i += 1
	if n == 100 and OS.get_environment("SHOT_UI") != "":
		var hud = main.get_node("Hud")
		match OS.get_environment("SHOT_UI"):
			"settings": hud.open_settings()
			"help": hud.open_help("unit_WALKER")
			"tip":
				Settings.set_value("ui", "tooltip_seconds", 30)
				hud.show_tip_at(Vector2(800, 400))
	if n == 20 and OS.get_environment("SHOT_JET") != "":
		var j = main._spawn_unit(BattleGrid.Mover.JET, Vector2i(6, 6), SitePlan.OWNER_PLAYER)
		var e = main._spawn_unit(BattleGrid.Mover.JET, Vector2i(8, 8), SitePlan.OWNER_ENEMY)
		j.set_process(false); e.set_process(false)
		j.rotation.y = 0.8; e.rotation.y = -2.2
	if n == 30 and OS.get_environment("SHOT_NOFOG") != "":
		main.fog.set_enabled(false)
	if n == 120:
		root.get_texture().get_image().save_png(OS.get_environment("SHOT_OUT"))
		quit()
	return false
