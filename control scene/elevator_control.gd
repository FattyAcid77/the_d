class_name Elevator_control_UI extends CanvasLayer

@export var this_scene_path: String

@onready var sami: Sami = $"../Sami"


@export var path_to_scene_1: String 
@export var path_to_scene_2: String 


func _on_button_2_pressed() -> void:
	if path_to_scene_1 == this_scene_path:
		visible = false
		sami.enable()
	else:
		visible = false
		SceneManager.load_new_scene(path_to_scene_1)



func _on_button_pressed() -> void:
	if path_to_scene_2 == this_scene_path:
		visible = false
		sami.enable()
	else:
		visible = false
		SceneManager.load_new_scene(path_to_scene_2)
