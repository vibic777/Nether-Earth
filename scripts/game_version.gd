# Контрибьютор: vibic777
# Версия игры: единый источник — файл VERSION; сборка пишет data/version.json (версия, дата, коммит).
class_name GameVersion
extends RefCounted

static var _info: Dictionary = {}

static func info() -> Dictionary:
	if _info.is_empty():
		var p := "res://data/version.json"
		if FileAccess.file_exists(p):
			var d = JSON.parse_string(FileAccess.get_file_as_string(p))
			if d is Dictionary:
				_info = d
		if _info.is_empty():
			var v := "0.0.0"
			if FileAccess.file_exists("res://VERSION"):
				v = FileAccess.get_file_as_string("res://VERSION").strip_edges()
			_info = {"version": v, "date": "dev", "commit": "dev"}
	return _info

static func version() -> String:
	return str(info().get("version", "0.0.0"))

static func line() -> String:
	return "Nether Earth Reloaded %s · сборка %s · коммит %s" % [version(), info().get("date", "?"), info().get("commit", "?")]
