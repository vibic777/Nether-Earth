# Контрибьютор: vibic777
# Мини-профайлер: Prof.add("метка", мкс). Включается переменной NE_PROF=1, отчёт Prof.report().
class_name Prof
extends RefCounted

static var on := OS.get_environment("NE_PROF") != ""
static var acc := {}

static func t() -> int:
	return Time.get_ticks_usec() if on else 0

static func add(label: String, since: int) -> void:
	if on:
		acc[label] = int(acc.get(label, 0)) + Time.get_ticks_usec() - since

static func report(frames: int) -> String:
	var keys := acc.keys()
	keys.sort_custom(func(a, b): return acc[a] > acc[b])
	var out := ""
	for k in keys:
		out += "  %-22s %8.2f мс/кадр\n" % [k, acc[k] / 1000.0 / maxf(1, frames)]
	return out
