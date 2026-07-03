class_name walk_state extends state

@onready var idle: state = $"../Idle"
@onready var drag: state = get_node_or_null("../Drag")
@onready var rotate: state = get_node_or_null("../Rotate")

@export var move_speed: float = 69

## What happens when the player enters this State?
func Enter() -> void:
	player.UpdateAnimation("Walk")

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
	# If the player stopped, switch back to the Idle state.
	if player.direction == Vector2.ZERO:
		return idle
	# Keep walking: face the right way, play the walk anim, and move.
	if player.SetDirection():
		player.UpdateAnimation("Walk")
	player.velocity = player.direction * move_speed
	return null

## What happens during the _physics_process update in this State?
func Physics( _delta : float ) -> state:
	return null

## What happens with input events in this State?
func HandleInput( _event: InputEvent ) -> state:
	return null
