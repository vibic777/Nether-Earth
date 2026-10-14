# Контрибьютор: vibic777
# Поиск пути: встроенный AStarGrid2D (C++) на каждый тип движения, 4 направления, манхэттен.
# Сетка проходимости пересобирается, только когда меняется карта (BattleGrid.version).
class_name Pathfinder
extends RefCounted

static var _grids := {}      # mover -> {"astar": AStarGrid2D, "version": int, "grid": BattleGrid}
static var calls := 0

static func _astar_for(grid: BattleGrid, mover: int) -> AStarGrid2D:
	var e: Dictionary = _grids.get(mover, {})
	if not e.is_empty() and e["grid"] == grid and int(e["version"]) == grid.version:
		return e["astar"]
	var a: AStarGrid2D = e.get("astar", null) if not e.is_empty() and e["grid"] == grid else null
	if a == null:
		a = AStarGrid2D.new()
		a.region = Rect2i(0, 0, BattleGrid.WIDTH, BattleGrid.HEIGHT)
		a.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
		a.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
		a.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
		a.update()
	for z in BattleGrid.HEIGHT:
		for x in BattleGrid.WIDTH:
			var c := Vector2i(x, z)
			a.set_point_solid(c, not grid.can_enter(c, mover))
	_grids[mover] = {"astar": a, "version": grid.version, "grid": grid}
	return a

static func route(grid: BattleGrid, start: Vector2i, goal: Vector2i, mover: int) -> Array[Vector2i]:
	calls += 1
	var empty: Array[Vector2i] = []
	if not grid.can_enter(start, mover):
		return empty
	var a := _astar_for(grid, mover)
	var target := goal
	if not grid.contains(target) or a.is_point_solid(target):
		target = _nearest_open(grid, a, goal)
		if target.x < 0:
			return empty
	var ids := a.get_id_path(start, target, true)
	var out: Array[Vector2i] = []
	out.assign(ids)
	return out

static func _nearest_open(grid: BattleGrid, a: AStarGrid2D, goal: Vector2i) -> Vector2i:
	for r in range(1, 24):
		for dx in range(-r, r + 1):
			for dz in [-r, r]:
				for c in [goal + Vector2i(dx, dz), goal + Vector2i(dz, dx)]:
					if grid.contains(c) and not a.is_point_solid(c):
						return c
	return Vector2i(-1, -1)
