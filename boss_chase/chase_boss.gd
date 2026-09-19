class_name ChaseBoss extends CharacterBody2D

# Runs up the corridor behind you at exactly your speed, so the gap only moves
# when something slows you down. Every attack it has exists to make that happen.

signal health_changed(current: int)
signal defeated
signal caught

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

const LANE_SPEED: float = 70.0       # how fast it drifts to line up under you

# Tuning. ChaseArena writes all of these on _ready from its own inspector — edit
# them there, not here.

var run_speed: float = 90.0          # same as the runner — a steady gap by design
var recover_speed: float = 40.0      # staggered after a parry, you gain ground

## The "short range" gate. The boss can only grab bins within this radius, so
## the closer it gets the more it can attack — and after a parry pushes the gap
## open it cannot reach far enough ahead of you to shove anything. It has to
## span the gap behind you AND the lead ahead of you, since the bins it wants
## are on the far side of the runner.
var telekinesis_range: float = 380.0

## How far ahead of you a bin has to be before the cat sends it. Any closer and
## it arrives on top of you with no time to react.
var roll_lead_min: float = 150.0

var shove_cooldown: float = 2.2
var wave_cooldown: float = 4.0

## Deliberately longer than telekinesis_range. The two moves cover different
## distances: up close it shoves a bin at you (which you can parry and kill it
## with), further out it fires the lane strike. So knocking it back with a parry
## no longer makes it harmless — it just switches weapons. Keep it under the
## beam's own LENGTH so a cast always actually reaches you.
var wave_range: float = 420.0

## Minimum breathing room between any two moves. Longer than the 1.2s attack
## animation on purpose: the cat finishes one slam and stands there a beat
## before it can start another, so slams never cut each other short.
var move_gap: float = 1.5
var recover_time: float = 0.9

## Close the gap to this and it has you. Measured along the corridor rather than
## as a radius: the cat is wide enough to fill the lane, so drawing level with
## it anywhere across the corridor is the same as being caught — and a plain
## "has it reached me yet" test can't let it slide past you the way an overlap
## check could when a slowed runner fell behind.
var catch_lead: float = 24.0

## Stamped onto every shockwave the cat casts.
var wave_fire_time: float = 0.25
var wave_lane_width: float = 56.0
var wave_damage: int = 1

@export var stats: HealthData
@export var runner: Node2D
@export var wave_scene: PackedScene

## Seconds into the lunge when the paw actually hits the floor — frame 3 of the
## 8-frame attack at 6.667 fps. The lane aims for exactly this long, so the
## strike goes off on the slam. Move it and the two drift apart again.
var slam_impact: float = 0.45

@onready var sprite: AnimatedSprite2D = $Sprite2D

var active: bool = true

var _move: int = Move.CHASE
var _shove_cd: float = 0.0
var _wave_cd: float = 2.0    # don't open with a wave
var _gap: float = 0.0
var _recover_left: float = 0.0
var _was_in_range: bool = false
var _caught: bool = false


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

	if _check_catch():
		return

	_tick_timers(delta)
	_update_range_edge()

	if _move == Move.CHASE and _gap <= 0.0:
		_pick_move()

	var forward: float = recover_speed if _move == Move.RECOVER else run_speed
	velocity.y = RUN_DIR.y * forward
	# drift sideways to stay under the runner, so its shoves have a clean line
	var dx: float = runner.global_position.x - global_position.x
	velocity.x = clampf(dx, -1.0, 1.0) * LANE_SPEED

	move_and_slide()


# The one way the chase actually ends in the cat's favour. Once it has you the
# run is over — it never chips your health and it never slides past you.
func _check_catch() -> bool:
	if _caught:
		return true
	if runner.global_position.y - global_position.y > catch_lead:
		return false
	_caught = true
	velocity = Vector2.ZERO
	sprite.play(ANIM_ATTACK)
	caught.emit()
	return true


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
	var in_range: bool = global_position.distance_to(runner.global_position) <= telekinesis_range
	if in_range and not _was_in_range:
		_shove_cd = 0.0      # crossing the line arms the shove immediately
	_was_in_range = in_range


func _pick_move() -> void:
	# Shove first: it's the close-range punish, and it's the only move that
	# gives the player something to parry.
	#
	# It deliberately does NOT slam. The cat only has the one attack pose, and
	# using it for both moves made every shove look like a shockwave that failed
	# to come out. The slam belongs to the wave alone now, so it always means the
	# same thing; the bin rolling at you is the shove's own tell.
	if _shove_cd <= 0.0:
		var crate: Node2D = _find_crate()
		if crate != null:
			crate.roll_up()
			_shove_cd = shove_cooldown
			_gap = move_gap
			return

	# Otherwise close the gap the only way it can — slow them down.
	if _wave_cd <= 0.0 and global_position.distance_to(runner.global_position) <= wave_range:
		_lunge_then_wave()
		_wave_cd = wave_cooldown
		_gap = move_gap


# The bin has to be three things: ours to reach, still standing, and AHEAD of
# the runner — a rolled bin comes back up the corridor, so only one below them
# can ever meet them head-on.
#
# Of those, take the one closest to the runner's own lane. A bin rolling up
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
		if global_position.distance_to(c.global_position) > telekinesis_range:
			continue

		var lead: float = c.global_position.y - runner.global_position.y
		if lead < roll_lead_min:
			continue

		var lane_gap: float = absf(c.global_position.x - runner.global_position.x)
		if lane_gap < best_lane_gap:
			best_lane_gap = lane_gap
			best = c

	return best


# play() will not rewind an attack that is already running, so a second slam
# arriving before the first has played out would never show its impact frame.
func _slam() -> void:
	sprite.play(ANIM_ATTACK)
	sprite.set_frame_and_progress(0, 0.0)


## The lane lights up the moment the cat rears back and fires on the slam
## itself. Casting it on the slam instead left the paw landing on nothing while
## the lane sat there glowing for the whole of its aim — the strike read as
## arriving late because it was.
func _lunge_then_wave() -> void:
	_slam()
	_cast_wave()
	await get_tree().create_timer(_anim_time(ANIM_ATTACK)).timeout
	if active and sprite.animation == ANIM_ATTACK:
		sprite.play(ANIM_CHASE)


func _cast_wave() -> void:
	if wave_scene == null:
		return
	var wave := wave_scene.instantiate()
	wave.global_position = global_position
	wave.aim_time = maxf(slam_impact, 0.0)
	wave.fire_time = wave_fire_time
	wave.lane_width = wave_lane_width
	wave.damage = wave_damage
	# same deferred add as task_area.gd:90 — never reparent mid-physics
	get_parent().call_deferred("add_child", wave)


func take_parry_hit() -> void:
	if stats == null or stats.current_health <= 0:
		return
	stats.current_health -= 1
	health_changed.emit(stats.current_health)

	# stagger — this is the player's reward, the gap opens and the boss drops
	# out of telekinesis range for a beat
	_move = Move.RECOVER
	_recover_left = recover_time
	_gap = move_gap
	sprite.modulate = Color(0.55, 0.55, 0.55)

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
