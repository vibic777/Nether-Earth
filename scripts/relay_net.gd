# Контрибьютор: vibic777
# Связь: юнит действует, только если его клетка в круге своего штаба, вышки, базы или своей зоны.
# Для сотен юнитов покрытие считается картой клеток на сторону (пересборка раз в 0,5 с или при смене владельца).
class_name RelayNet
extends RefCounted

static var _maps := {}       # side -> {"ms": int, "cells": PackedByteArray}
static var stamp := 0        # растёт при смене владельца узла/зоны

static func covers(tree: SceneTree, world: Vector3) -> bool:
	return covers_side(tree, world, SitePlan.OWNER_PLAYER)

static func exact(tree: SceneTree, world: Vector3, side: int) -> bool:
	for node in tree.get_nodes_in_group("sites"):
		var site := node as CaptureSite
		if site.covers_side(side, world):
			return true
	for node in tree.get_nodes_in_group("zones"):
		if (node as FlagZone).covers_side(side, world):
			return true
	return false

static func covers_side(tree: SceneTree, world: Vector3, side: int) -> bool:
	var e: Dictionary = _maps.get(side, {})
	var now := Time.get_ticks_msec()
	if e.is_empty() or (int(e["stamp"]) != stamp) or int(e["w"]) != BattleGrid.WIDTH * 10000 + BattleGrid.HEIGHT:
		e = _build(tree, side)
		_maps[side] = e
	var cell := Vector2i(floori(world.x / BattleGrid.TILE), floori(world.z / BattleGrid.TILE))
	if cell.x < 0 or cell.y < 0 or cell.x >= BattleGrid.WIDTH or cell.y >= BattleGrid.HEIGHT:
		return exact(tree, world, side)
	var v: int = (e["cells"] as PackedByteArray)[cell.y * BattleGrid.WIDTH + cell.x]
	if v == 2:
		return true
	if v == 0:
		return false
	return exact(tree, world, side)   # клетка на границе круга — точная проверка

# 0 — точно нет, 2 — точно да (вся клетка в круге), 1 — граница.
static func _build(tree: SceneTree, side: int) -> Dictionary:
	var w := BattleGrid.WIDTH
	var h := BattleGrid.HEIGHT
	var cells := PackedByteArray()
	cells.resize(w * h)
	var t := BattleGrid.TILE
	var half := t * 0.7072
	var circles: Array = []
	for node in tree.get_nodes_in_group("sites"):
		var site := node as CaptureSite
		if site.team == side and site.radius > 0.0:
			circles.append([site._center, site.radius])
	for node in tree.get_nodes_in_group("zones"):
		var z := node as FlagZone
		if z.owner_side == side:
			circles.append([z.position, FlagZone.cfg("relay_radius", 14.0) * t * 0.5 + z.radius * t])
	for c in circles:
		var center: Vector3 = c[0]
		var r: float = c[1]
		var x0 := maxi(0, floori((center.x - r) / t) - 1)
		var x1 := mini(w - 1, floori((center.x + r) / t) + 1)
		var z0 := maxi(0, floori((center.z - r) / t) - 1)
		var z1 := mini(h - 1, floori((center.z + r) / t) + 1)
		for z in range(z0, z1 + 1):
			for x in range(x0, x1 + 1):
				var i := z * w + x
				if cells[i] == 2:
					continue
				var d := Vector2((x + 0.5) * t - center.x, (z + 0.5) * t - center.z).length()
				if d + half <= r:
					cells[i] = 2
				elif d - half <= r:
					cells[i] = 1
	return {"ms": Time.get_ticks_msec(), "cells": cells, "stamp": stamp, "w": w * 10000 + h}
