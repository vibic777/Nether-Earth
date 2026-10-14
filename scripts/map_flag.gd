# Контрибьютор: vibic777
class_name MapFlag
extends Node3D

var cell := Vector2i.ZERO
var mark := ""

func setup(grid: BattleGrid, at: Vector2i, label: String) -> void:
	cell = at
	mark = label
	var origin := grid.cell_center(at)
	origin.y = 0.0
	position = origin
	var pole := CylinderMesh.new()
	pole.top_radius = 0.035
	pole.bottom_radius = 0.035
	pole.height = 1.15
	pole.radial_segments = 6
	var pole_node := MeshInstance3D.new()
	pole_node.mesh = pole
	pole_node.position = Vector3(0.0, 0.58, 0.0)
	var pole_mat := StandardMaterial3D.new()
	pole_mat.albedo_color = Color("d7d2c4")
	pole_mat.metallic = 0.4
	pole_mat.roughness = 0.45
	pole_node.material_override = pole_mat
	add_child(pole_node)
	var cloth := BoxMesh.new()
	cloth.size = Vector3(0.46, 0.28, 0.04)
	var flag := MeshInstance3D.new()
	flag.mesh = cloth
	flag.position = Vector3(0.24, 1.02, 0.0)
	var cloth_mat := StandardMaterial3D.new()
	cloth_mat.albedo_color = Color("d24a3a")
	cloth_mat.roughness = 0.7
	flag.material_override = cloth_mat
	add_child(flag)
	var text := Label3D.new()
	text.text = label
	text.font_size = 48
	text.pixel_size = 0.01
	text.position = Vector3(0.24, 1.02, 0.05)
	text.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	text.no_depth_test = true
	text.outline_size = 8
	text.modulate = Color("fff4d2")
	add_child(text)
