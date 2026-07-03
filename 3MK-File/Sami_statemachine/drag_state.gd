class_name drag_state extends state

# Hold F next to an object to push/pull it.
# Push = move toward the side you face, pull = move away.

@onready var idle: state = $"../Idle"
@onready var walk: state = $"../Walk"

@export var drag_speed: float = 70.0
const ALIGN_THRESHOLD: float = 0.25   # how aligned input must be to count as push/pull


func Enter() -> void:
	if player.grabbed != null:
		player.face_toward(player.grab_offset)
	player.velocity = Vector2.ZERO
	player.play_push_pull_anim(true)


func Exit() -> void:
	player.end_grab()
	# drag never flips the sprite, so set the flip back for walk/idle
	player.anim.scale.x = -1 if player.cardinal_direction == Vector2.LEFT else 1


func Process(_delta: float) -> state:
	if not Input.is_action_pressed("drag") or player.grabbed == null:
		return walk if player.direction != Vector2.ZERO else idle

	var along: float = player.direction.dot(player.cardinal_direction)
	if along > ALIGN_THRESHOLD:
		player.velocity = player.cardinal_direction * drag_speed     # push
		player.play_push_pull_anim(true)
	elif along < -ALIGN_THRESHOLD:
		player.velocity = -player.cardinal_direction * drag_speed    # pull
		player.play_push_pull_anim(false)
	else:
		player.velocity = Vector2.ZERO   # holding F but not along the axis

	return null


func Physics(_delta: float) -> state:
	player.drag_follow()   # runs after we've moved, so the object matches us
	return null
