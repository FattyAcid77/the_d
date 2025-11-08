extends CharacterBody2D



const SPEED = 300.0

func _physics_process(delta: float) -> void:
	var input_vector = Vector2.ZERO

	# Get input in 4 directions
	input_vector.x = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
	input_vector.y = Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")

	# Normalize diagonal movement (no faster diagonals)
	if input_vector.length() > 0:
		input_vector = input_vector.normalized()

	# Apply velocity
	velocity = input_vector * SPEED

	move_and_slide()

@export var rad:PackedScene 
