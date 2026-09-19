class_name ChaseObstacle extends CharacterBody2D

# A wheelie bin standing in the corridor. It does nothing on its own.
#
# The ones marked `rolls` can be sent by the cat: it grabs one from further
# down the corridor and rolls it back UP into your face, with no warning of any
# kind — the only cue is the bin itself moving. You run into it head-on, so you
# see it coming. Dodge it, eat it, or swat it up into the cat.
# Every bin hurts on contact, rolling or not.

signal parried

enum Mode { IDLE, FLYING }

# Tuning. ChaseArena writes all of these on spawn from its own inspector — edit
# them there, not here.
#
## How a rolled bin travels: straight back up the corridor at you. It only has
## to cover the ground between you and it — you are running into it, so the two
## of you close much quicker than this speed alone suggests.
var roll_speed: float = 140.0
var roll_distance: float = 260.0

## Tight on purpose: the bin has to be close enough that you see it meet the
## swat. The runner's input buffer is what makes that fair rather than fussy.
var parry_reach: float = 32.0
var reverse_distance: float = 320.0   # 48px would never reach the boss
var reverse_time: float = 0.85        # ~375 px/s, clearly faster than the shove

## Off: scenery, dodge it. On: the boss can grab this one and roll it at you.
@export var rolls: bool = false

# Every bin looks the same standing still, on purpose: you cannot tell which
# one the cat is about to send at you until it moves.
# Over-bright rather than tinted — the whole fight is black and white, so a
# parried bin reads by glowing, not by turning a colour.
const COLOR_PARRIED := Color(1.8, 1.8, 1.8)
const COLOR_SPENT := Color(0.45, 0.45, 0.45, 0.7)

var fly_direction: Vector2 = Vector2.ZERO

var _mode: int = Mode.IDLE
var _reversed: bool = false
var _spent: bool = false
var _live: bool = false     # rolling at you — only now can we be parried
var _linear: bool = false   # a roll keeps its speed; a parry return eases
var _t: float = 0.0
var _from: Vector2 = Vector2.ZERO
var _distance: float = 0.0
var _fly_time: float = 0.0

@onready var hitbox: Area2D = $HitBox
@onready var art: AnimatedSprite2D = $Body


func _ready() -> void:
	add_to_group("chase_obstacle")
	hitbox.body_entered.connect(_on_hitbox_body_entered)


func _set_tint(c: Color) -> void:
	art.modulate = c


func is_idle() -> bool:
	return _mode == Mode.IDLE

func is_flying() -> bool:
	return _mode == Mode.FLYING

func is_spent() -> bool:
	return _spent


## Only a bin that is actually rolling can be parried. A bin standing in the
## corridor still hurts on contact, but you dodge that one, you don't swat it.
func is_live() -> bool:
	return _live and not _spent


## The cat sends us. No rattle, no tell — the first the player knows about it is
## the bin coming back up the corridor at them.
func roll_up() -> void:
	if _mode != Mode.IDLE or _spent or not rolls:
		return
	_live = true
	_launch(Vector2.UP, roll_distance, roll_distance / maxf(roll_speed, 1.0), true)


## Called by the runner on a successful parry. Sends us back at whoever shoved us.
func reverse_toward(target: Node2D) -> void:
	if _spent or target == null:
		return
	_reversed = true
	_set_tint(COLOR_PARRIED)      # it's yours now — readable at a glance
	_launch(global_position.direction_to(target.global_position), reverse_distance, reverse_time)
	parried.emit()


func _physics_process(delta: float) -> void:
	if _mode == Mode.FLYING:
		_advance(delta)


func _launch(dir: Vector2, distance: float, duration: float, linear: bool = false) -> void:
	art.play("roll")
	_linear = linear
	_mode = Mode.FLYING
	fly_direction = dir
	_from = global_position
	_distance = distance
	_fly_time = duration
	_t = 0.0


# Sweep, don't teleport. A raw Tween on global_position walks the crate straight
# through walls; move_and_collide stops it at the surface. Same reason
# rotate_state.gd:88 sweeps instead of assigning.
# This has to live in _physics_process so move_and_collide gets a fixed
# timestep — see the note at rotate_state.gd:63.
func _advance(delta: float) -> void:
	_t += delta / _fly_time
	var f: float = clampf(_t, 0.0, 1.0)
	# a rolling bin keeps its speed; a bin you swatted back eases as it goes
	var eased: float = f if _linear else f * f * (3.0 - 2.0 * f)

	var target: Vector2 = _from + fly_direction * _distance * eased
	var collision := move_and_collide(target - global_position)
	if collision != null or f >= 1.0:
		_land()


func _land() -> void:
	art.play("still")
	_mode = Mode.IDLE
	_reversed = false
	_live = false          # it stopped, there is nothing left to swat
	velocity = Vector2.ZERO


# A crate that has already clipped someone stops being a threat, otherwise a
# slowed player sitting on top of one would get chewed up by repeat triggers.
func _spend() -> void:
	art.play("still")
	_spent = true
	_mode = Mode.IDLE
	_set_tint(COLOR_SPENT)
	hitbox.set_deferred("monitoring", false)


func _on_hitbox_body_entered(body: Node2D) -> void:
	if _spent:
		return
	if _reversed:
		if body.is_in_group("chase_boss") and body.has_method("take_parry_hit"):
			body.take_parry_hit()
			_spend()
		return
	if body.is_in_group("chase_runner") and body.has_method("on_crate_hit"):
		body.on_crate_hit()
		_spend()
