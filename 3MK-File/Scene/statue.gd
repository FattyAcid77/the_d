extends Sprite2D

class_name statue

# 1. Track if the player is allowed to interact
var _is_player_near: bool = false

# 2. Track which way we are facing (0 = North, 1 = East, 2 = South, 3 = West)
var current_direction: int = 0 



# --- DETECTION LOGIC ---
func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.name == "Sami":
		_is_player_near = true



func _on_area_2d_body_exited(body: Node2D) -> void:
	if body.name == "Sami":
		_is_player_near = false

# --- INTERACTION LOGIC ---
func _input(event):
	# Check if the player is near AND they pressed your interact button
	if _is_player_near and event.is_action_pressed("action"):
		_turn_statue()

# --- ROTATION LOGIC ---
func _turn_statue():
	# 3. Add 1 to the direction. 
	# The "% 4" is a math trick that forces the number to wrap back to 0!
	# It goes: 0, 1, 2, 3, 0, 1, 2, 3...
	current_direction = (current_direction + 1) % 4
	
	# 4. Physically rotate the entire Area2D (and its Sprite) by 90 degrees
	rotation_degrees = current_direction * 90.0
	
	print("Statue turned: ", current_direction)
