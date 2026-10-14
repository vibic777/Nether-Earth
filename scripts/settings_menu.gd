# Контрибьютор: vibic777
# Окно настроек: вкладки Графика / Экран / Интерфейс / Звук / Управление. Esc или F10.
class_name SettingsMenu
extends PanelContainer

var _tabs: TabContainer
var _waiting_action := ""
var _bind_buttons := {}
var _preset: OptionButton
var _refreshers: Array[Callable] = []

func _ready() -> void:
	custom_minimum_size = Vector2(760, 600)
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.07, 0.08, 0.08, 0.97)
	st.border_color = Color("c9b06a")
	st.set_border_width_all(2)
	st.set_content_margin_all(14)
	add_theme_stylebox_override("panel", st)
	set_meta("help", "ui_settings")
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var title := Label.new()
	title.text = "⚙ Настройки   v" + GameVersion.version()
	title.add_theme_font_size_override("font_size", 24)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(_button("По умолчанию", func() -> void:
		Settings.reset_defaults()
		_changed()
		_refresh()))
	var quit_btn := _button("Выйти в лобби", func() -> void:
		var game := get_tree().current_scene
		if game != null and game.has_method("to_lobby"):
			game.to_lobby())
	quit_btn.visible = get_tree().current_scene != null and get_tree().current_scene.has_method("to_lobby")
	head.add_child(quit_btn)
	head.add_child(_button("✕ Закрыть", func() -> void: visible = false))
	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_tabs)
	_graphics()
	_display()
	_interface()
	_audio()
	_controls()
	_journal()
	_about()
	var note := Label.new()
	note.text = "Сохраняется сразу в user://settings.cfg"
	note.add_theme_font_size_override("font_size", 13)
	note.modulate = Color(1, 1, 1, 0.6)
	v.add_child(note)

func _page(name: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = name
	_tabs.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 8)
	scroll.add_child(box)
	return box

func _row(box: VBoxContainer, label: String, control: Control) -> void:
	var h := HBoxContainer.new()
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(300, 0)
	h.add_child(l)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(control)
	box.add_child(h)

func _check(box: VBoxContainer, label: String, section: String, key: String) -> void:
	var c := CheckBox.new()
	c.toggled.connect(func(on: bool) -> void:
		Settings.set_value(section, key, on)
		_changed())
	_refreshers.append(func() -> void: c.set_pressed_no_signal(bool(Settings.get_value(section, key))))
	_row(box, label, c)

func _choice(box: VBoxContainer, label: String, section: String, key: String, items: Array, titles: Array) -> OptionButton:
	var o := OptionButton.new()
	for t in titles:
		o.add_item(str(t))
	o.item_selected.connect(func(i: int) -> void:
		Settings.set_value(section, key, items[i])
		_changed())
	_refreshers.append(func() -> void:
		var idx := items.find(Settings.get_value(section, key))
		o.select(maxi(idx, 0)))
	_row(box, label, o)
	return o

func _slider(box: VBoxContainer, label: String, section: String, key: String, lo: float, hi: float, step: float, suffix: String = "") -> void:
	var h := HBoxContainer.new()
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.custom_minimum_size = Vector2(260, 24)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var val := Label.new()
	val.custom_minimum_size = Vector2(70, 0)
	h.add_child(s)
	h.add_child(val)
	s.value_changed.connect(func(x: float) -> void:
		var v: Variant = int(x) if step >= 1.0 else x
		Settings.set_value(section, key, v)
		val.text = ("%d" % int(x) if step >= 1.0 else "%.2f" % x) + suffix
		_changed())
	_refreshers.append(func() -> void:
		var x := float(Settings.get_value(section, key))
		s.set_value_no_signal(x)
		val.text = ("%d" % int(x) if step >= 1.0 else "%.2f" % x) + suffix)
	_row(box, label, h)

func _graphics() -> void:
	var b := _page("Графика")
	_preset = OptionButton.new()
	for t in ["Низкое", "Среднее", "Высокое", "Своё"]:
		_preset.add_item(t)
	_preset.item_selected.connect(func(i: int) -> void:
		if i < 3:
			Settings.apply_preset(["low", "medium", "high"][i])
			_changed()
			_refresh())
	_refreshers.append(func() -> void: _preset.select(maxi(["low", "medium", "high", "custom"].find(Settings.get_value("graphics", "preset")), 0)))
	_row(b, "Пресет качества", _preset)
	_choice(b, "Тени", "graphics", "shadows", [0, 1, 2], ["Выкл", "Обычные", "Высокие"])
	_choice(b, "Сглаживание (MSAA)", "graphics", "msaa", [0, 2, 4, 8], ["Выкл", "2×", "4×", "8×"])
	_check(b, "Трава и цветы", "graphics", "grass")
	_check(b, "Волны на воде", "graphics", "water_waves")
	_check(b, "Свечение (glow)", "graphics", "glow")
	_slider(b, "Масштаб рендера 3D", "graphics", "render_scale", 0.5, 1.0, 0.05)

func _display() -> void:
	var b := _page("Экран")
	_check(b, "Полный экран", "display", "fullscreen")
	_choice(b, "Разрешение окна", "display", "resolution", Settings.RESOLUTIONS, Settings.RESOLUTIONS)
	_check(b, "Вертикальная синхронизация (VSync)", "display", "vsync")
	var titles := []
	for f in Settings.FPS_LIMITS:
		titles.append("Без ограничения" if f == 0 else "%d FPS" % f)
	_choice(b, "Ограничение FPS", "display", "fps_limit", Settings.FPS_LIMITS, titles)

func _interface() -> void:
	var b := _page("Интерфейс")
	_slider(b, "Размер текста", "ui", "text_scale", 0.7, 1.6, 0.05)
	_slider(b, "Масштаб меню и панелей", "ui", "menu_scale", 0.7, 1.6, 0.05)
	_slider(b, "Подсказка F1, секунд (0 — выкл)", "ui", "tooltip_seconds", 0, 30, 1, " с")

func _audio() -> void:
	var b := _page("Звук")
	_slider(b, "Общая громкость", "audio", "master", 0, 100, 1, "%")
	_slider(b, "Музыка", "audio", "music", 0, 100, 1, "%")
	_slider(b, "Эффекты", "audio", "sfx", 0, 100, 1, "%")

func _controls() -> void:
	var b := _page("Управление")
	_check(b, "Прокрутка у края экрана", "controls", "edge_scroll")
	_check(b, "Инвертировать колесо масштаба", "controls", "invert_zoom")
	_slider(b, "Скорость камеры", "controls", "pan_speed", 0.3, 3.0, 0.1)
	for action in Settings.REBINDABLE:
		var a: String = action
		var btn := Button.new()
		btn.pressed.connect(func() -> void:
			_waiting_action = a
			btn.text = "… нажмите клавишу (Esc — отмена)")
		_bind_buttons[a] = btn
		_refreshers.append(func() -> void: btn.text = Settings.key_label(a))
		_row(b, Settings.REBINDABLE[a], btn)
	var note := Label.new()
	note.text = "Остальные клавиши (Z/X/C, T, F, R, группы, F1, F9) — см. справку (Shift+F1 → «Управление»)."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.add_child(note)

func _input(event: InputEvent) -> void:
	if not visible or _waiting_action == "":
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode != KEY_ESCAPE:
			Settings.bind_key(_waiting_action, event.physical_keycode)
			_changed()
		_waiting_action = ""
		_refresh()
		get_viewport().set_input_as_handled()

func open() -> void:
	visible = true
	center.call_deferred()
	_refresh()

func _refresh() -> void:
	for r in _refreshers:
		r.call()

func _changed() -> void:
	Settings.save_all()
	Settings.apply(get_tree())
	GameLog.configure()

func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(cb)
	return b


func center() -> void:
	reset_size()
	var vp := get_viewport_rect().size
	position = ((vp - size) * 0.5).floor()


func _journal() -> void:
	var page := _page("Журнал")
	_check(page, "Вести журнал (по умолчанию выключен)", "log", "enabled")
	var all := Button.new()
	all.text = "Все уровни"
	all.pressed.connect(func() -> void:
		for k in GameLog.KEYS:
			Settings.set_value("log", k, true)
		_changed()
		for r in _refreshers:
			r.call())
	page.add_child(all)
	for i in GameLog.KEYS.size():
		_check(page, "  " + GameLog.NAMES[i], "log", GameLog.KEYS[i])
	_check(page, "Запись при падении (отдельно, по умолчанию выключена)", "log", "crash_capture")
	var note := Label.new()
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.text = "Папка: %s\nФайлы с датой и временем, хранятся последние %d. Флаг запуска --log=all|info,error|off или переменная NE_LOG.\n«Запись при падении»: каждая строка сразу на диск, ошибки движка и скриптов, при аварийном завершении журнал сохраняется как crash_<время>.log." % [GameLog.dir(), GameLog.MAX_FILES]
	page.add_child(note)

func _about() -> void:
	var page := _page("Об игре")
	var info := GameVersion.info()
	for line in ["Nether Earth Reloaded", "Версия: %s" % info.get("version", "?"), "Дата сборки: %s" % info.get("date", "?"), "Коммит: %s" % info.get("commit", "?"), "", "Самостоятельная игра по мотивам классической стратегии.", "Код, модели и тексты сделаны с нуля. Автор: Vibic777."]:
		var l := Label.new()
		l.text = line
		page.add_child(l)
