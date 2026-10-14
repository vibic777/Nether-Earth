extends SceneTree
var n := 0
func _initialize():
	LoadingScreen.open(self)
	BattleGrid.staged = true
	change_scene_to_file("res://scenes/main.tscn")
func _process(_d):
	n += 1
	if n == 400:
		print("loaded=", current_scene.loaded, " loader=", LoadingScreen.active(), " units=", get_nodes_in_group("units").size())
		quit()
	return false
