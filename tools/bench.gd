# Контрибьютор: vibic777
# Стресс-тест: godot [--headless] --path . -s res://tools/bench.gd
# BENCH_MAP (eight), BENCH_UNITS (на сторону, 300), BENCH_FRAMES (600). Отчёт: средний/p95/худший кадр, FPS.
extends SceneTree
var n := 0
var main
var frames := 600
var per := 300
var t0 := 0
var worst := 0.0
var last := 0
var samples: Array[float] = []
var rcpu := 0.0
var rgpu := 0.0
var proc := 0.0
func _initialize():
	var mp := OS.get_environment("BENCH_MAP") if OS.get_environment("BENCH_MAP") != "" else "eight"
	per = int(OS.get_environment("BENCH_UNITS")) if OS.get_environment("BENCH_UNITS") != "" else 300
	frames = int(OS.get_environment("BENCH_FRAMES")) if OS.get_environment("BENCH_FRAMES") != "" else 600
	MatchSetup.map_id = mp
	MatchSetup.slots = MatchSetup.default_slots(int(MapData.load_map(mp).get("players", 2)))
	for s in MatchSetup.slots:
		if s["kind"] == MatchSetup.KIND_HUMAN:
			s["kind"] = MatchSetup.KIND_AI
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
func _spawn():
	var kinds := [BattleGrid.Mover.TRACK, BattleGrid.Mover.WALKER, BattleGrid.Mover.TROOPER, BattleGrid.Mover.BIKE, BattleGrid.Mover.ROTOR]
	var grid: BattleGrid = main._grid
	for side in MatchSetup.active_sides():
		var hq: CaptureSite = main._home_hq(side)
		if hq == null:
			continue
		var c := hq.footprint[0]
		var placed := 0
		var r := 3
		while placed < per and r < 60:
			for dx in range(-r, r + 1):
				for dz in [-r, r]:
					if placed >= per:
						break
					var cell := c + Vector2i(dx, dz)
					var m: int = kinds[placed % kinds.size()]
					if grid.can_enter(cell, m):
						main._spawn_unit(m, cell, side)
						placed += 1
			r += 1
	var mid := Vector2i(BattleGrid.WIDTH / 2, BattleGrid.HEIGHT / 2)
	for u in main.get_tree().get_nodes_in_group("units"):
		u.order_to(mid + Vector2i(randi_range(-6, 6), randi_range(-6, 6)))
func _process(_d):
	n += 1
	if n == 5:
		var a := Time.get_ticks_msec()
		_spawn()
		var off := OS.get_environment("BENCH_OFF").split(",", false)
		for node in main.find_children("*", "", true, false):
			var nm := str(node.name)
			for o in off:
				if (o == "terrain" and nm.begins_with("Terrain")) or (o == "props" and nm.begins_with("Props")) or (o == "grass" and nm.begins_with("Grass")) or (o == "water" and nm.begins_with("Water")) or (o == "fog" and nm == "Fog"):
					if node is Node3D: node.visible = false
					if node.has_method("set_enabled") and o == "fog": node.set_enabled(false)
				if o == "shadows" and node is DirectionalLight3D: node.shadow_enabled = false
				if o == "glow" and node is WorldEnvironment: node.environment.glow_enabled = false
		if off.has("fogplane"):
			main.fog._plane.visible = false
		if off.has("fogtex"):
			main.fog.set_process(false)
		if off.has("msaa"):
			main.get_viewport().msaa_3d = Viewport.MSAA_DISABLED
		print("выключено: ", off)
		print("юнитов: ", main.get_tree().get_nodes_in_group("units").size(), " спавн ", Time.get_ticks_msec() - a, " мс")
		Prof.acc.clear()
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = 0
		RenderingServer.viewport_set_measure_render_time(main.get_viewport().get_viewport_rid(), true)
		t0 = Time.get_ticks_usec()
		last = t0
		return false
	if n > 5:
		var now := Time.get_ticks_usec()
		var dt := (now - last) / 1000.0
		last = now
		samples.append(dt)
		var vr: RID = main.get_viewport().get_viewport_rid()
		rcpu += RenderingServer.viewport_get_measured_render_time_cpu(vr) + RenderingServer.get_frame_setup_time_cpu()
		rgpu += RenderingServer.viewport_get_measured_render_time_gpu(vr)
		proc += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		worst = maxf(worst, dt)
	if n == frames + 5:
		var total := (Time.get_ticks_usec() - t0) / 1000.0
		samples.sort()
		var avg := total / frames
		var vis := 0
		for u in main.get_tree().get_nodes_in_group("units"):
			if u._onscreen: vis += 1
		print("BENCH в кадре=%d" % vis)
		var cls := {}
		var total_nodes := 0
		for node in main.find_children("*", "", true, false):
			total_nodes += 1
			if node.is_processing():
				var k: String = node.get_script().get_global_name() if node.get_script() else node.get_class()
				cls[k] = int(cls.get(k, 0)) + 1
		print("BENCH узлов=%d с _process: %s" % [total_nodes, str(cls)])
		print("BENCH юнитов=%d кадров=%d средний=%.2f мс (%.1f FPS) p95=%.2f мс худший=%.2f мс" % [main.get_tree().get_nodes_in_group("units").size(), frames, avg, 1000.0 / avg, samples[int(samples.size() * 0.95)], worst])
		var rep := Prof.report(frames)
		rep += "  process %.2f мс, physics %.2f мс, вызовов отрисовки %d, примитивов %d, объектов %d\n" % [Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)]
		rep += "  среднее: скрипты(process) %.2f мс, рендер CPU %.2f мс, GPU %.2f мс\n" % [proc / frames, rcpu / frames, rgpu / frames]
		print(rep)
		var f := FileAccess.open("user://bench.txt", FileAccess.WRITE)
		if f: f.store_string(rep)
		quit()
	return false
