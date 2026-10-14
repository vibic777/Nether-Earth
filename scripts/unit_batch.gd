# Контрибьютор: vibic777
# Инстансинг: одинаковые меши юнитов рисуются одним MultiMesh на (меш) — тысячи машин за десятки вызовов отрисовки.
# Юнит держит пустые Node3D-«якоря» (корпус, ноги, ротор) и анимирует их как раньше;
# раз в кадр UnitBatch переписывает их мировые матрицы в MultiMesh. Скрытые (туман) — нулевой масштаб.
class_name UnitBatch
extends Node3D

static var ZERO := Transform3D(Basis().scaled(Vector3.ZERO), Vector3(0, -999, 0))

class Batch:
	var mmi: MultiMeshInstance3D
	var mm: MultiMesh
	var owners: Array[Node3D] = []
	var units: Array = []        # BattleUnit владельца якоря (или null)
	var loose: Array[Node3D] = [] # якоря без юнита

static var _inst: UnitBatch
static var enabled := true
var _batches := {}           # mesh instance_id -> Batch

static func get_or_make(host: Node) -> UnitBatch:
	if _inst != null and is_instance_valid(_inst) and _inst.is_inside_tree():
		return _inst
	_inst = UnitBatch.new()
	_inst.name = "UnitBatch"
	host.add_child(_inst)
	return _inst

static func active() -> bool:
	return enabled and _inst != null and is_instance_valid(_inst) and _inst.is_inside_tree()

func register(anchor: Node3D, mesh: Mesh) -> void:
	var key := mesh.get_instance_id()
	var b: Batch = _batches.get(key)
	if b == null:
		b = Batch.new()
		b.mm = MultiMesh.new()
		b.mm.transform_format = MultiMesh.TRANSFORM_3D
		b.mm.mesh = mesh
		b.mm.instance_count = 16
		b.mm.visible_instance_count = 0
		b.mmi = MultiMeshInstance3D.new()
		b.mmi.multimesh = b.mm
		add_child(b.mmi)
		_batches[key] = b
	anchor.set_meta("batch", key)
	b.owners.append(anchor)
	var u: Node = anchor
	while u != null and not (u is BattleUnit):
		u = u.get_parent()
	b.units.append(u)
	if u == null:
		b.loose.append(anchor)
	if b.owners.size() > b.mm.instance_count:
		b.mm.instance_count = b.mm.instance_count * 2
	b.mm.visible_instance_count = b.owners.size()

func unregister(anchor: Node3D) -> void:
	if not anchor.has_meta("batch"):
		return
	var b: Batch = _batches.get(anchor.get_meta("batch"))
	if b == null:
		return
	var i := b.owners.find(anchor)
	if i < 0:
		return
	b.owners[i] = b.owners[b.owners.size() - 1]
	b.owners.pop_back()
	b.units[i] = b.units[b.units.size() - 1]
	b.units.pop_back()
	b.loose.erase(anchor)

func _process(_delta: float) -> void:
	BattleUnit.tick_offscreen(_delta, get_tree())
	var t0 := Prof.t()
	for key in _batches:
		var b: Batch = _batches[key]
		var mm := b.mm
		mm.visible_instance_count = 0
	# Упаковка: проходим только юниты в кадре (не все якоря всех машин) и пишем их детали
	# в свои MultiMesh подряд — GPU не видит машин за экраном и в тумане.
	var fill := {}
	for key in _batches:
		fill[key] = 0
	for node in UnitIndex.all:
		if not is_instance_valid(node):
			continue
		var u := node as BattleUnit
		if u._is_off or not u._onscreen or not u.visible:
			continue
		for a in u._anchors:
			if not a.is_visible_in_tree():
				continue
			var key: int = a.get_meta("batch", 0)
			var b: Batch = _batches.get(key)
			if b == null:
				continue
			var i: int = fill[key]
			if i >= b.mm.instance_count:
				continue
			b.mm.set_instance_transform(i, a.global_transform)
			fill[key] = i + 1
	for key in fill:
		(_batches[key] as Batch).mm.visible_instance_count = fill[key]
	# Якоря без юнита (редко) — по-старому.
	for key in _batches:
		var b: Batch = _batches[key]
		for a in b.loose:
			if is_instance_valid(a) and a.is_visible_in_tree():
				var i: int = fill[key]
				if i < b.mm.instance_count:
					b.mm.set_instance_transform(i, a.global_transform)
					fill[key] = i + 1
					b.mm.visible_instance_count = i + 1
	Prof.add("batch", t0)
