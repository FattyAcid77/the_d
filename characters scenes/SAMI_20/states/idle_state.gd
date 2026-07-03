class_name IdleState extends GroundedState

## Standing still. Waits for a movement key, then hands off to Move.


func enter() -> void:
	player.velocity = Vector2.ZERO
	player.play_idle()
	# Keep the interaction ray aimed where we last faced, so we can talk
	# to NPCs / pick up items while standing.
	player.aim_raycast()


func _ground_physics(_delta: float) -> void:
	if player.get_input_direction() != Vector2.ZERO:
		transitioned.emit("move")
		return

	player.velocity = Vector2.ZERO
	player.move_and_slide()
