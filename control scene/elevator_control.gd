class_name Elevator_control_UI extends CanvasLayer

var path_to_scene_1: String = "res://Main Scenes/Elevator_2.tscn"
var path_to_scene_2: String = "res://Main Scenes/Elevator_1.tscn"

func _on_button_2_pressed() -> void:
	SceneManager.load_new_scene(path_to_scene_1)



func _on_button_pressed() -> void:
	SceneManager.load_new_scene(path_to_scene_2)
