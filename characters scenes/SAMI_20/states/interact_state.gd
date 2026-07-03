class_name InteractState extends State

## The player is frozen because an outside system has taken over: a dialog,
## an elevator ride, a cutscene, a puzzle, etc.
##
## Entry happens two ways:
##   - we talked to an NPC (try_interact set can_move = false), or
##   - another script flipped can_move / input_enabled (elevator, beam...).
##
## We just hold still until control is handed back, then return to Idle.


func enter() -> void:
	player.velocity = Vector2.ZERO
	player.move_and_slide()
	player.play_idle()


func physics_update(_delta: float) -> void:
	player.velocity = Vector2.ZERO

	# Control was handed back -> resume normal play.
	if player.can_control():
		transitioned.emit("idle")
