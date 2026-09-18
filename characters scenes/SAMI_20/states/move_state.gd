class_name MoveState extends GroundedState

## Free 4-direction walking when nothing is being dragged.


func _ground_physics(_delta: float) -> void:
	var direction := player.get_input_direction()

	# No keys held -> drop back to Idle.
	if direction == Vector2.ZERO:
		transitioned.emit("idle")
		return

	player.look_direction = direction
	player.velocity = direction * player.speed
	player.play_directional_anim(Sami20.AnimState.NORMAL, direction)
	player.aim_raycast()
	player.move_and_slide()
