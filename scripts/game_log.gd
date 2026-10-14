# Контрибьютор: vibic777
# Журнал игры: уровни TRACE/DEBUG/INFO/WARNING/ERROR/CRITICAL, по умолчанию выключен.
# Файлы logs/ рядом с exe (в редакторе — user://logs), имя с датой/временем, ротация (хранится MAX_FILES).
# Переопределение: флаг --log=all|info,error|off или переменная NE_LOG.
# «Запись при падении» (отдельно, выкл.): сброс на диск каждой строки, перехват ошибок движка/скриптов
# (OS.add_logger), маркер сессии — при следующем запуске прошлый журнал сохраняется как crash_<время>.log.
class_name GameLog
extends RefCounted

enum Level { TRACE, DEBUG, INFO, WARNING, ERROR, CRITICAL }
const NAMES := ["TRACE", "DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"]
const KEYS := ["trace", "debug", "info", "warning", "error", "critical"]
const MAX_FILES := 10
const MARKER := "session.lock"

static var enabled := false
static var crash := false
static var mask := 0
static var _file: FileAccess
static var _path := ""
static var _engine_logger: Logger
static var crash_note := ""        # «прошлая сессия упала, журнал сохранён как …»
static var _started := false

static func dir() -> String:
	if OS.has_feature("editor") or OS.has_feature("headless_tests"):
		return ProjectSettings.globalize_path("user://logs")
	return OS.get_executable_path().get_base_dir().path_join("logs")

static func level_on(level: int) -> bool:
	return enabled and (mask & (1 << level)) != 0

# Настройки + CLI/окружение → состояние. Повторный вызов (после смены настроек) переоткрывает файл.
static func configure() -> void:
	var on := bool(Settings.get_value("log", "enabled"))
	var m := 0
	for i in KEYS.size():
		if bool(Settings.get_value("log", KEYS[i])):
			m |= 1 << i
	var spec := OS.get_environment("NE_LOG")
	for a in OS.get_cmdline_user_args() + OS.get_cmdline_args():
		if str(a).begins_with("--log="):
			spec = str(a).substr(6)
	if spec != "":
		var r := parse_spec(spec)
		on = r[0]
		m = r[1]
	var want_crash := bool(Settings.get_value("log", "crash_capture"))
	var was := enabled or crash
	enabled = on
	mask = m
	crash = want_crash
	if not _started:
		_started = true
		_check_marker()
	if (enabled or crash) and _file == null:
		_open()
	elif not (enabled or crash) and _file != null:
		_close()
	if crash and _engine_logger == null and ClassDB.class_exists("Logger"):
		_engine_logger = _EngineHook.new()
		OS.add_logger(_engine_logger)
	elif not crash and _engine_logger != null:
		OS.remove_logger(_engine_logger)
		_engine_logger = null
	if crash:
		_write_marker()
	else:
		_clear_marker()
	if not was and (enabled or crash):
		info("Журнал включён: уровни %s, запись при падении: %s" % [describe(mask), "да" if crash else "нет"])

# "all" | "off" | "info,error" → [вкл, маска]
static func parse_spec(spec: String) -> Array:
	spec = spec.strip_edges().to_lower()
	if spec == "off" or spec == "0" or spec == "none":
		return [false, 0]
	if spec == "all" or spec == "1" or spec == "":
		return [true, 63]
	var m := 0
	for part in spec.split(",", false):
		var i := KEYS.find(part.strip_edges())
		if i >= 0:
			m |= 1 << i
	return [m != 0, m]

static func describe(m: int) -> String:
	if m == 63:
		return "все"
	var out: PackedStringArray = []
	for i in NAMES.size():
		if m & (1 << i):
			out.append(NAMES[i])
	return ", ".join(out) if not out.is_empty() else "нет"

static func trace(t: String) -> void: write(Level.TRACE, t)
static func debug(t: String) -> void: write(Level.DEBUG, t)
static func info(t: String) -> void: write(Level.INFO, t)
static func warning(t: String) -> void: write(Level.WARNING, t)
static func error(t: String) -> void: write(Level.ERROR, t)
static func critical(t: String) -> void: write(Level.CRITICAL, t)

static func write(level: int, text: String) -> void:
	# Ошибки (ERROR/CRITICAL) при «записи при падении» пишутся даже с выключенным журналом.
	if not level_on(level) and not (crash and level >= Level.ERROR):
		return
	_raw("%s [%s] %s" % [Time.get_datetime_string_from_system(false, true), NAMES[level], text])

static func _raw(line: String) -> void:
	if _file == null:
		return
	_file.store_line(line)
	if crash:
		_file.flush()

static func path() -> String:
	return _path

static func _open() -> void:
	DirAccess.make_dir_recursive_absolute(dir())
	var stamp := Time.get_datetime_string_from_system(false, false).replace(":", "-").replace("T", "_")
	_path = dir().path_join("game_%s.log" % stamp)
	_file = FileAccess.open(_path, FileAccess.WRITE)
	_rotate()

static func _close() -> void:
	if _file != null:
		_file.flush()
		_file = null

# Ротация: оставить MAX_FILES свежих game_*.log (crash_*.log не трогаем).
static func _rotate() -> void:
	var files: Array = []
	for f in DirAccess.get_files_at(dir()):
		if f.begins_with("game_") and f.ends_with(".log"):
			files.append(f)
	files.sort()
	while files.size() > MAX_FILES:
		DirAccess.remove_absolute(dir().path_join(files.pop_front()))

static func _write_marker() -> void:
	DirAccess.make_dir_recursive_absolute(dir())
	var f := FileAccess.open(dir().path_join(MARKER), FileAccess.WRITE)
	if f:
		f.store_string(_path)

static func _clear_marker() -> void:
	var p := dir().path_join(MARKER)
	if FileAccess.file_exists(p):
		DirAccess.remove_absolute(p)

# Маркер остался — прошлая сессия не завершилась штатно: сохранить её журнал как crash_<время>.log.
static func _check_marker() -> void:
	var p := dir().path_join(MARKER)
	if not FileAccess.file_exists(p):
		return
	var prev := FileAccess.get_file_as_string(p).strip_edges()
	DirAccess.remove_absolute(p)
	if prev == "" or not FileAccess.file_exists(prev):
		return
	var stamp := Time.get_datetime_string_from_system(false, false).replace(":", "-").replace("T", "_")
	var dest := dir().path_join("crash_%s.log" % stamp)
	DirAccess.copy_absolute(prev, dest)
	crash_note = "Прошлая сессия завершилась аварийно. Журнал сохранён: " + dest

# Штатный выход: убрать маркер.
static func shutdown() -> void:
	info("Штатное завершение")
	_clear_marker()
	_close()

class _EngineHook extends Logger:
	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _script_backtraces: Array) -> void:
		var kind := "SCRIPT" if error_type == 2 else ("WARNING" if error_type == 1 else "ERROR")
		GameLog._raw("%s [ENGINE %s] %s %s (%s:%d %s)" % [Time.get_datetime_string_from_system(false, true), kind, code, rationale, file, line, function])

	func _log_message(message: String, is_error: bool) -> void:
		if is_error:
			GameLog._raw("%s [ENGINE] %s" % [Time.get_datetime_string_from_system(false, true), message.strip_edges()])
