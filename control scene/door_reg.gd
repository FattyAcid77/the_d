class_name Door_reg extends Area2D

signal  player_entered(door: Door_reg, transition_type:String)

@export var new_scene_path:String
@export var door_name:String




func _on_body_entered(body: Node2D) -> void:
	SceneManaager.load_new_scene(new_scene_path)
