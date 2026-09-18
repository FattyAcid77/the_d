extends RigidBody2D

var thrust = 500.0

func _physics_process(delta):
	var force_direction = Vector2.ZERO
	
	# Check for arrow key / WASD input
	if Input.is_action_pressed("right"):
		force_direction.x += 1
	if Input.is_action_pressed("left"):
		force_direction.x -= 1
	if Input.is_action_pressed("down"):
		force_direction.y += 1
	if Input.is_action_pressed("up"):
		force_direction.y -= 1
		
	# Push the object in the input direction
	apply_central_force(force_direction.normalized() * thrust)
