class_name rotate_state extends state

# Hold E next to a mirror and push/pull to turn it.
# It turns a few degrees at a time, each step eased so it glides.
# Sami walks around the mirror with it.

@onready var idle: state = $"../Idle"
@onready var walk: state = $"../Walk"

@export var step_degrees: float = 5.0
@export var step_time: float = 0.08      # glide time per step, smaller = faster
const ALIGN_THRESHOLD: float = 0.25

var _mirror: Node = null
var _axis: Vector2 = Vector2.DOWN        # facing locked on enter, keeps push/pull steady while orbiting

# the step we're easing through right now
var _stepping: bool = false
var _t: float = 0.0
var _pivot: Vector2 = Vector2.ZERO
var _from_rot: float = 0.0
var _step_rot: float = 0.0
var _from_offset: Vector2 = Vector2.ZERO   # our spot relative to the pivot when the step started


func Enter() -> void:
	player.velocity = Vector2.ZERO
	_stepping = false
	_mirror = player.focus_grabbable
	if _mirror != null:
		player.face_toward(_mirror.global_position - player.global_position)
		_axis = player.cardinal_direction
		player.add_collision_exception_with(_mirror)   # don't shove each other
		player.play_push_pull_anim(true)


func Exit() -> void:
	if _mirror != null:
		player.remove_collision_exception_with(_mirror)
	_mirror = null
	_stepping = false


func Process(_delta: float) -> state:
	if not Input.is_action_pressed("action") or player.focus_grabbable == null:
		return walk if player.direction != Vector2.ZERO else idle

	_mirror = player.focus_grabbable
	player.velocity = Vector2.ZERO

	if _stepping:
		return null

	# between steps: start the next one if a direction is held
	var along: float = player.direction.dot(_axis)
	if along > ALIGN_THRESHOLD:
		_begin_step(deg_to_rad(step_degrees), true)
	elif along < -ALIGN_THRESHOLD:
		_begin_step(-deg_to_rad(step_degrees), false)
	return null


# the actual motion happens here, not in Process, so move_and_collide gets a
# fixed timestep to work with instead of a variable one
func Physics(_delta: float) -> state:
	if _stepping:
		_advance(_delta)
	return null


func _begin_step(step: float, pushing: bool) -> void:
	_pivot = _mirror.global_position
	_from_rot = _mirror.rotation
	_step_rot = step
	_from_offset = player.global_position - _pivot
	_t = 0.0
	_stepping = true
	player.play_push_pull_anim(pushing)


func _advance(delta: float) -> void:
	_t += delta / step_time
	var f: float = clamp(_t, 0.0, 1.0)
	var eased: float = f * f * (3.0 - 2.0 * f)   # smoothstep

	# sweep toward the arc position instead of teleporting there, so a wall in
	# the way stops us right at the collision instead of clipping through it
	var target: Vector2 = _pivot + _from_offset.rotated(_step_rot * eased)
	var motion: Vector2 = target - player.global_position
	var collision := player.move_and_collide(motion)
	if collision:
		_stepping = false   # blocked mid-arc — stop here, don't force through the wall
		player.face_toward(_mirror.global_position - player.global_position)
		return

	_mirror.rotation = _from_rot + _step_rot * eased
	player.face_toward(_mirror.global_position - player.global_position)

	if f >= 1.0:
		_stepping = false
