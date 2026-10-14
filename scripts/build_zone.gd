# Контрибьютор: vibic777
# Показ зоны постройки: светящиеся круги радиуса вокруг своих баз и призрак на клетке под курсором
# (зелёный — можно, красный — нельзя). Видно только в режиме постройки.
class_name BuildZone
extends Node3D

var game: Node
var _rings: Array[MeshInstance3D] = []
var _ghost: MeshInstance3D
var _ok_mat: StandardMaterial3D
var _bad_mat: StandardMaterial3D
var _ring_mat: StandardMaterial3D
var _tick := 0.0

func _ready() -> void:
	_ring_mat = _mat(Color(0.4, 0.9, 1.0, 0.55))
	_ok_mat = _mat(Color(0.35, 1.0, 0.5, 0.45))
	_bad_mat = _mat(Color(1.0, 0.3, 0.25, 0.45))
	_ghost = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(BattleGrid.TILE * 0.95, 0.9, BattleGrid.TILE * 0.95)
	_ghost.mesh = box
	_ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ghost)

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = c
	m.no_depth_test = false
	return m

func _process(delta: float) -> void:
	var place: Dictionary = game.place
	var on := str(place.get("what", "")) == "build"
	visible = on
	if not on:
		return
	var grid: BattleGrid = game._grid
	_tick -= delta
	if _tick <= 0.0:
		_tick = 0.5
		for r in _rings:
			r.queue_free()
		_rings.clear()
		for s in BuildRules.anchors(get_tree(), int(place["side"])):
			var ring := MeshInstance3D.new()
			var t := TorusMesh.new()
			var rad := BuildRules.radius_of(s.kind) * BattleGrid.TILE
			t.inner_radius = rad - 0.15
			t.outer_radius = rad
			t.rings = 64
			ring.mesh = t
			ring.material_override = _ring_mat
			ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var c := grid.cell_center(s.footprint[0])
			ring.position = Vector3(c.x, grid.terrain_y(c.x, c.z) + 0.3, c.z)
			add_child(ring)
			_rings.append(ring)
	var cell: Vector2i = grid.hovered
	_ghost.visible = cell.x >= 0
	if cell.x >= 0:
		var c2 := grid.cell_center(cell)
		_ghost.position = Vector3(c2.x, grid.terrain_y(c2.x, c2.z) + 0.45, c2.z)
		var ok := BuildRules.check(grid, get_tree(), int(place["side"]), str(place["key"]), cell) == ""
		_ghost.material_override = _ok_mat if ok else _bad_mat
