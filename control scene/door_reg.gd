class_name Door_reg extends Area2D

signal  player_entered_door(door: Door_reg, transition_type:String)

@export_enum("north", "east", "south", "west") var entery_direction
@export var push_distance:int = 16
@export var new_scene_path:String
@export var door_name:String


func _on_body_entered(body: Node2D) -> void:
	if not body is Sami:
		return
	player_entered_door.emit(self)
	SceneManager.load_new_scene(new_scene_path)
	queue_free()



func get_player_entry_vector() -> Vector2:
	var vector:Vector2 = Vector2.LEFT
	match entery_direction:
		0:
			vector = Vector2.UP
		1:
			vector = Vector2.RIGHT
		2:
			vector = Vector2.DOWN
	return (vector * push_distance) + self.position
	
func get_move_dir() -> Vector2:
	var dir:Vector2 = Vector2.RIGHT
	match entery_direction:
		0:
			dir = Vector2.DOWN
		1:
			dir = Vector2.LEFT
		2:
			dir = Vector2.UP
	return dir
