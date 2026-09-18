class_name DragState extends State

## Holding an object through the PinJoint.
##
## Movement is locked to the axis we're facing:
##   - press TOWARD the object  -> push  (move forward)
##   - press AWAY from it        -> pull  (move backward)
##   - press sideways / nothing  -> stand still
## Releasing the "drag" action lets go and returns to Idle.


func enter() -> void:
	player.velocity = Vector2.ZERO


func handle_input(event: InputEvent) -> void:
	if event.is_action_released("drag"):
		player.release_grab()
		transitioned.emit("idle")


func physics_update(_delta: float) -> void:
	# The object disappeared or was freed elsewhere.
	if player.dragged_object == null:
		transitioned.emit("idle")
		return

	# An outside system froze us mid-drag: drop the object and freeze.
	if not player.can_control():
		player.release_grab()
		transitioned.emit("interact")
		return

	var input_dir := player.get_input_direction()
	var look := player.look_direction

	if input_dir == Vector2.ZERO:
		# No key held: wait for the player.
		player.velocity = Vector2.ZERO
		player.play_idle()
	else:
		var alignment := input_dir.dot(look)
		if alignment > 0.0:
			# Pressing toward the object -> push.
			player.velocity = look * player.drag_speed
			player.play_directional_anim(Sami20.AnimState.PUSH, look)
		elif alignment < 0.0:
			# Pressing away from the object -> pull.
			player.velocity = -look * player.drag_speed
			player.play_directional_anim(Sami20.AnimState.PULL, look)
		else:
			# Perpendicular press (e.g. Left while facing Up): stand still.
			player.velocity = Vector2.ZERO
			player.play_idle()

	player.aim_raycast()
	player.move_and_slide()
