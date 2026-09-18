class_name idle_state extends state

@onready var walk: state = $"../Walk"
@onready var drag: state = get_node_or_null("../Drag")
@onready var rotate: state = get_node_or_null("../Rotate")

## What happens when the player enters this State?
func Enter() -> void:
	player.UpdateAnimation("Idle")

## What happens when the player exits this State?
func Exit() -> void:
	pass

## What happens during the _process update in this State?
func Process( _delta : float ) -> state:
	# hold F to grab and push/pull
	if drag != null and Input.is_action_pressed("drag") and player.focus_grabbable != null:
		if player.try_start_grab():
			return drag
	# hold E to rotate
	if rotate != null and Input.is_action_pressed("action") and player.focus_grabbable != null:
		return rotate
	# If the player starts moving, switch to the Walk state.
	if player.direction != Vector2.ZERO:
		return walk
	# Otherwise stand still.
	player.velocity = Vector2.ZERO
	return null

## What happens during the _physics_process update in this State?
func Physics( _delta : float ) -> state:
	return null

## What happens with input events in this State?
func HandleInput( _event: InputEvent ) -> state:
	return null
