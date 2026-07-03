class_name GroundedState extends State

## Shared behaviour for the two "on foot" states: Idle and Move.
##
## Both of them can:
##   - get frozen by an outside system (dialog, elevator, cutscene) -> Interact
##   - start dragging the object in front of us                     -> Drag
##   - start talking / interacting with whatever we're facing       -> Interact
##
## The walking/standing differences live in `_ground_physics`, which Idle and
## Move override. This keeps the common transitions written in ONE place.


func physics_update(_delta: float) -> void:
	# An outside system took control of the player this frame.
	if not player.can_control():
		transitioned.emit("interact")
		return

	_ground_physics(_delta)


func handle_input(event: InputEvent) -> void:
	if not player.can_control():
		return

	# Grab the object we're facing.
	if event.is_action_pressed("drag") and player.try_grab():
		transitioned.emit("drag")
		return

	# Talk to / interact with whatever the raycast is pointing at.
	if event.is_action_pressed("ui_accept") and player.try_interact():
		transitioned.emit("interact")


## Overridden by Idle and Move. Runs only while the player has control.
func _ground_physics(_delta: float) -> void:
	pass
