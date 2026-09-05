class_name ChaseBoss extends CharacterBody2D

# Runs up the corridor behind you at exactly your speed, so the gap only moves
# when something slows you down. Every attack it has exists to make that happen.

signal health_changed(current: int)
signal defeated

enum Move { CHASE, RECOVER }

# The corridor runs DOWNWARD and the boss chases from above. That's what makes
# a shove throw the crate *upward* into the player — the crate sits ahead of
# them (further down) and gets yanked back up the corridor into their face.
const RUN_DIR := Vector2.DOWN

# Animation names, exactly as they are spelled in cat_frames.tres.
const ANIM_NOTICE := "Notice"
const ANIM_WAIT := "Notice-2"
const ANIM_ATTACK := "attack"
const ANIM_CHASE := "chase"

const RUN_SPEED: float = 90.0        # same as the runner — a steady gap by design
const RECOVER_SPEED: float = 40.0    # staggered after a parry, you gain ground
const LANE_SPEED: float = 70.0       # how fast it drifts to line up under you

# The "short range" gate. The boss can only grab crates within this radius, so
# the closer it gets the more it can attack — and after a parry pushes the gap
# open it literally cannot reach far enough ahead of you to shove anything.
const TELEKINESIS_RANGE: float = 270.0

# How far behind you a bin has to be before the cat sends it. Any closer and it
# lands on top of you with no time to move.
const ROLL_LEAD_MIN: float = 150.0

const SHOVE_COOLDOWN: float = 2.2
const WAVE_COOLDOWN: float = 4.0
# Deliberately much longer than TELEKINESIS_RANGE. The two moves now cover
# different distances: up close it shoves a crate at you (which you can parry
# and kill it with), further out it fires the lane strike. So knocking it back
# with a parry no longer makes it harmless — it just switches weapons.
# Capped below the beam's own LENGTH so a cast always actually reaches you.
const WAVE_RANGE: float = 420.0
const MOVE_GAP: float = 0.8          # minimum breathing room between any 2 moves
const RECOVER_TIME: float = 0.9
const TOUCH_DAMAGE_COOLDOWN: float = 1.0

@export var stats: HealthData
@export var runner: Node2D
@export var wave_scene: PackedScene

## Seconds into the lunge when the paw actually hits the floor. The shockwave
## leaves on that beat, so nudge it up if the wave still runs ahead of the slam.
@export var wave_delay: float = 0.45

@onready var touch_box: Area2D = $TouchBox
@onready var sprite: AnimatedSprite2D = $Sprite2D

var active: bool = true

var _move: int = Move.CHASE
var _shove_cd: float = 0.0
var _wave_cd: float = 2.0    # don't open with a wave
var _gap: float = 0.0
var _recover_left: float = 0.0
var _touch_cd: float = 0.0
var _was_in_range: bool = false


func _ready() -> void:
	add_to_group("chase_boss")
	if stats != null:
		stats.current_health = stats.max_health
	# Opening grace. We spawn already inside telekinesis range, and without
	# these two the edge-trigger below would fire an attack on frame one.
	_shove_cd = 1.5
	_was_in_range = true


func _physics_process(delta: float) -> void:
	if not active or runner == null:
		velocity = Vector2.ZERO
		return

	_tick_timers(delta)
	_update_range_edge()

	if _move == Move.CHASE and _gap <= 0.0:
		_pick_move()

	var forward: float = RECOVER_SPEED if _move == Move.RECOVER else RUN_SPEED
	velocity.y = RUN_DIR.y * forward
	# drift sideways to stay under the runner, so its shoves have a clean line
	var dx: float = runner.global_position.x - global_position.x
	velocity.x = clampf(dx, -1.0, 1.0) * LANE_SPEED

	move_and_slide()
	_check_touch_damage(delta)


func _tick_timers(delta: float) -> void:
	_shove_cd = maxf(_shove_cd - delta, 0.0)
	_wave_cd = maxf(_wave_cd - delta, 0.0)
	_gap = maxf(_gap - delta, 0.0)
	if _move == Move.RECOVER:
		_recover_left -= delta
		if _recover_left <= 0.0:
			_move = Move.CHASE
			sprite.modulate = Color.WHITE


# Walking into range should feel like an ambush, not like waiting out a timer.
# Same _was_in_main_range trick as radio_signal_manager.gd:56 — act on the
# change, not on the state.
func _update_range_edge() -> void:
	var in_range: bool = global_position.distance_to(runner.global_position) <= TELEKINESIS_RANGE
	if in_range and not _was_in_range:
		_shove_cd = 0.0      # crossing the line arms the shove immediately
	_was_in_range = in_range


func _pick_move() -> void:
	# Shove first: it's the close-range punish, and it's the only move that
	# gives the player something to parry.
	if _shove_cd <= 0.0:
		var crate: Node2D = _find_crate()
		if crate != null:
			crate.roll_down()
			_lunge()
			_shove_cd = SHOVE_COOLDOWN
			_gap = MOVE_GAP
			return

	# Otherwise close the gap the only way it can — slow them down.
	if _wave_cd <= 0.0 and global_position.distance_to(runner.global_position) <= WAVE_RANGE:
		_lunge_then_wave()
		_wave_cd = WAVE_COOLDOWN
		_gap = MOVE_GAP


# The bin has to be three things: ours to reach, still standing, and BEHIND the
# runner — a bin rolls straight down the corridor, so only one above them can
# ever catch up with them.
#
# Of those, take the one closest to the runner's own lane. A bin rolling down
# an empty lane is a free pass, and burning the cooldown on one is the classic
# way for the cat to look busy while doing nothing.
func _find_crate() -> Node2D:
	var best: Node2D = null
	var best_lane_gap: float = 1e9

	for c in get_tree().get_nodes_in_group("chase_obstacle"):
		if not c.rolls:
			continue                      # scenery, it just sits there
		if c.is_spent() or not c.is_idle():
			continue
		if global_position.distance_to(c.global_position) > TELEKINESIS_RANGE:
			continue

		var lead: float = runner.global_position.y - c.global_position.y
		if lead < ROLL_LEAD_MIN:
			continue

		var lane_gap: float = absf(c.global_position.x - runner.global_position.x)
		if lane_gap < best_lane_gap:
			best_lane_gap = lane_gap
			best = c

	return best


## The lunge, then back to chasing. Nothing waits on it — it is only the pose.
func _lunge() -> void:
	sprite.play(ANIM_ATTACK)
	await get_tree().create_timer(_anim_time(ANIM_ATTACK)).timeout
	if active and sprite.animation == ANIM_ATTACK:
		sprite.play(ANIM_CHASE)


## The shockwave leaves the cat on the slam - `wave_delay` into the lunge - and
## the rest of the lunge plays out after it.
func _lunge_then_wave() -> void:
	sprite.play(ANIM_ATTACK)
	await get_tree().create_timer(maxf(wave_delay, 0.0)).timeout
	if not active:
		return
	_cast_wave()
	await get_tree().create_timer(maxf(_anim_time(ANIM_ATTACK) - wave_delay, 0.0)).timeout
	if active and sprite.animation == ANIM_ATTACK:
		sprite.play(ANIM_CHASE)


func _cast_wave() -> void:
	if wave_scene == null:
		return
	var wave := wave_scene.instantiate()
	wave.global_position = global_position
	# same deferred add as task_area.gd:90 — never reparent mid-physics
	get_parent().call_deferred("add_child", wave)


# body_entered fires once, but the boss ends up standing ON you — so poll the
# overlap with a cooldown instead. That cooldown IS your i-frames.
func _check_touch_damage(delta: float) -> void:
	_touch_cd = maxf(_touch_cd - delta, 0.0)
	if _touch_cd > 0.0:
		return
	for body in touch_box.get_overlapping_bodies():
		if body.is_in_group("chase_runner") and body.has_method("take_damage"):
			body.take_damage(1)
			_touch_cd = TOUCH_DAMAGE_COOLDOWN
			return


func take_parry_hit() -> void:
	if stats == null or stats.current_health <= 0:
		return
	stats.current_health -= 1
	health_changed.emit(stats.current_health)

	# stagger — this is the player's reward, the gap opens and the boss drops
	# out of telekinesis range for a beat
	_move = Move.RECOVER
	_recover_left = RECOVER_TIME
	_gap = MOVE_GAP
	sprite.modulate = Color(1.0, 0.5, 0.5)

	if stats.current_health <= 0:
		defeated.emit()


#region /// the opening beat, driven by ChaseArena

## Not yet a threat.
func hold() -> void:
	active = false
	velocity = Vector2.ZERO


## Gets up, then waits in place until the chase is started.
func notice() -> void:
	sprite.play(ANIM_NOTICE)
	await get_tree().create_timer(_anim_time(ANIM_NOTICE)).timeout
	if not active:
		sprite.play(ANIM_WAIT)


## The chase is on.
func go() -> void:
	sprite.play(ANIM_CHASE)
	active = true


## One pass of an animation, in seconds. See the twin in chase_runner.gd.
func _anim_time(anim: String) -> float:
	var frames: SpriteFrames = sprite.sprite_frames
	if frames == null or not frames.has_animation(anim):
		return 0.0
	return frames.get_frame_count(anim) / maxf(frames.get_animation_speed(anim), 0.001)

#endregion


func stop() -> void:
	active = false
	velocity = Vector2.ZERO
