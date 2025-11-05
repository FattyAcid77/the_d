extends Button

var path_to_scene:String = "res://Main Scenes/lvl_1_Lobby.tscn"



func _on_button_up() -> void:
	SceneManager.load_new_scene(path_to_scene)
