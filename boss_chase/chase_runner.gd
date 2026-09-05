class_name ChaseRunner extends CharacterBody2D

# The auto-runner. Forward speed is out of your hands — you only steer sideways
# and parry. The corridor is the clock.
#
# Deliberately NOT built on Sami_statemachine: its base state class holds
# `static var player` (3MK-File/Sami_statemachine/state.gd:3), so calling
# Initialize() here would re-point every state node in the game and hijack the
# real Sami. Plain functions instead, like Main_Stuff/sami_doctor_test.gd.

signal health_changed(current: int)
signal died

const RUN_SPEED: float = 90.0
const DODGE_SPEED: float = 120.0

# Animation names, exactly as they are spelled in rat_frames.tres.
const ANIM_NOTICE := "Notice"
const ANIM_RUN := "run"
const ANIM_RUN_LEFT := "Run-Left"
const ANIM_RUN_RIGHT := "Run-right"
const ANIM_HURT := "hurt"

const PARRY_BUFFER: float = 0.15    # press this early and it still lands
const PARRY_LOCKOUT: float = 0.40   # whiffing on empty air costs you this

const CRATE_SLOW_STRENGTH: float = 0.85
const CRATE_SLOW_HOLD: float = 1.5
# every crate that lands permanently costs you this much top speed, forever
const CRATE_PERMANENT_SLOW: float = 0.30
const FLASH_TIME: float = 0.25

@export var stats: HealthData
@export var boss: Node2D

@onready var slow: ChaseSlowEffect = $Slow
@onready var sprite: AnimatedSprite2D = $Sprite2D

var input_enabled: bool = true

var _parry_buffer: float = 0.0
var _parry_lockout: float = 0.0
var _flash: float = 0.0


func _ready() -> void:
	add_to_group("chase_runner")
	# Reset explicitly. The .tres is resource_local_to_scene so a reload should
	# hand us a fresh copy anyway, but HealthData is a Resource and this project
	# already has one that got its damage saved to disk
	# (3MK-File/Resources/PlayerHealth.tres:7 reads current_health = 2).
	if stats != null:
		stats.current_health = stats.max_health


func _physics_process(delta: float) -> void:
	_tick_timers(delta)
	if not input_enabled:
		velocity = Vector2.ZERO
		return

	_handle_parry(delta)

	# Forward is automatic and unstoppable — that's the whole premise.
	# We run DOWN the corridor (+y) with the cat above us, which is why the bins
	# it sends come rolling down onto us from behind.
	velocity.y = RUN_SPEED * slow.speed_multiplier()
	var lean: float = Input.get_axis("left", "right")
	velocity.x = lean * DODGE_SPEED
	_run_anim(lean)
	move_and_slide()


# Leaning into the turn. Same run, three poses.
func _run_anim(lean: float) -> void:
	var want: String = ANIM_RUN
	if lean < 0.0:
		want = ANIM_RUN_LEFT
	elif lean > 0.0:
		want = ANIM_RUN_RIGHT
	if sprite.animation != want:
		sprite.play(want)


func _tick_timers(delta: float) -> void:
	_parry_lockout = maxf(_parry_lockout - delta, 0.0)
	if _flash > 0.0:
		_flash = maxf(_flash - delta, 0.0)
		sprite.modulate = Color(1.0, 0.4, 0.4) if _flash > 0.0 else Color.WHITE


# An input buffer, not an instant check. Pressing slightly early is the most
# common way a parry "should" have worked, so we remember the press for a beat
# and keep re-checking. That's what makes it feel fair rather than fussy.
func _handle_parry(delta: float) -> void:
	if Input.is_action_just_pressed("interact") \
			and _parry_lockout <= 0.0 and _parry_buffer <= 0.0:
		_parry_buffer = PARRY_BUFFER

	if _parry_buffer <= 0.0:
		return

	var crate: Node2D = _crate_in_reach()
	if crate != null:
		crate.reverse_toward(boss)
		_parry_buffer = 0.0
		return

	_parry_buffer -= delta
	if _parry_buffer <= 0.0:
		_parry_lockout = PARRY_LOCKOUT   # buffer ran out with nothing to hit


# Anything rolling within reach, in front or behind. Bins come down the
# corridor from behind now, so the old "must be ahead of us" rule would rule out
# every single one of them.
func _crate_in_reach() -> Node2D:
	for c in get_tree().get_nodes_in_group("chase_obstacle"):
		if not c.is_live():
			continue
		if c.global_position.distance_to(global_position) <= c.PARRY_REACH:
			return c
	return null


## Anything that wants to slow us goes through here — the wave calls it every
## frame you're inside the ring, a crate calls it once with a long hold.
func apply_slow(strength: float, hold: float) -> void:
	slow.apply(strength, hold)


## The boss's lane strike. Unlike a crate this one is dodgeable on reaction, so
## it costs a heart but does NOT ratchet your speed permanently — the one-way
## slow stays the crate's signature.
func on_wave_hit(strength: float, hold: float, damage: int) -> void:
	apply_slow(strength, hold)
	take_damage(damage)


func on_crate_hit() -> void:
	apply_slow(CRATE_SLOW_STRENGTH, CRATE_SLOW_HOLD)
	slow.add_permanent(CRATE_PERMANENT_SLOW)   # one-way, you never get it back
	take_damage(1)


func take_damage(amount: int) -> void:
	if stats == null or stats.current_health <= 0:
		return
	stats.current_health -= amount
	_flash = FLASH_TIME
	health_changed.emit(stats.current_health)
	if stats.current_health <= 0:
		sprite.play("hurt")
		died.emit()


func stop() -> void:
	input_enabled = false
	velocity = Vector2.ZERO
	slow.clear()


#region /// the opening beat, driven by ChaseArena

## Frozen, waiting for the opening to play out.
func hold() -> void:
	input_enabled = false
	velocity = Vector2.ZERO


## Looks back, sees the cat. Await it — it returns when the look is over.
func notice() -> void:
	sprite.play(ANIM_NOTICE)
	await get_tree().create_timer(_anim_time(ANIM_NOTICE)).timeout


## Go. From here the corridor is the clock.
func go() -> void:
	sprite.play(ANIM_RUN)
	input_enabled = true


## How long one pass of an animation takes. Read from the frames themselves, so
## it stays right when you re-cut them, and it does not care whether the
## animation is set to loop.
func _anim_time(anim: String) -> float:
	var frames: SpriteFrames = sprite.sprite_frames
	if frames == null or not frames.has_animation(anim):
		return 0.0
	return frames.get_frame_count(anim) / maxf(frames.get_animation_speed(anim), 0.001)

#endregion
