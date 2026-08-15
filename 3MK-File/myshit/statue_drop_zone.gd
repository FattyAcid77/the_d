extends Area2D
#---------------------------Drop Checker---------------------------#

var Done: bool = false
@export_category("Statue Side")
@export_enum("All", "Left", "Right", "Up", "Down") var required_side: String = "All"

func _physics_process(_delta: float) -> void:
	if Done:
		return

	for body in get_overlapping_bodies():
		if body.is_in_group("Statue"):
			if Input.is_action_just_released("drag"):
				if correct_side(body) == true:
					lock_statue(body)
				else:
					print("NT!")
					break


func lock_statue(statue):
	Done = true
	
	statue.global_position = global_position
	statue.freeze = true
	


func correct_side(statue):
	if required_side == "All":
		return true
	var statue_side = statue.get_node("Statue")
	var distance = statue.global_position - global_position
	
	if required_side == "Left" and statue_side.current_direction == 1:
		return true
	if required_side == "Right" and statue_side.current_direction == 3:
		return true
	if required_side == "Up" and statue_side.current_direction == 2:
		return true
	if required_side == "Down" and statue_side.current_direction == 0:
		return true
	return false
