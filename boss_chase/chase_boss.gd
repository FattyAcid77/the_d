class_name ChaseBoss extends CharacterBody2D

# Runs up the corridor behind you at exactly your speed, so the gap only moves
# when something slows you down. Every attack it has exists to make that happen.

signal health_changed(current: int)
signal defeated

enum Move { CHASE, RECOVER }

# preload rather than the class_name, because autoloads and freshly-added
# scripts can parse before the editor rebuilds the global class cache — the
# same workaround radio_signal_manager.gd:10-12 and grab_mirror.gd:14-15 use.
const RunnerScript := preload("res://boss_chase/chase_runner.gd")
const ObstacleScript := preload("res://boss_chase/chase_obstacle.gd")

# The corridor runs DOWNWARD and the boss chases from above. That's what makes
# a shove throw the crate *upward* into the player — the crate sits ahead of
# them (further down) and gets yanked back up the corridor into their face.
const RUN_DIR := Vector2.DOWN

const RUN_SPEED: float = 90.0        # same as the runner — a steady gap by design
const RECOVER_SPEED: float = 40.0    # staggered after a parry, you gain ground
const LANE_SPEED: float = 70.0       # how fast it drifts to line up under you

# The "short range" gate. The boss can only grab crates within this radius, so
# the closer it gets the more it can attack — and after a parry pushes the gap
# open it literally cannot reach far enough ahead of you to shove anything.
const TELEKINESIS_RANGE: float = 270.0

# Where a shoved crate has to land relative to you: far enough ahead to be
# dodgeable, close enough to still threaten. 0.9s-1.4s of reaction time.
const LEAD_MIN: float = 80.0
const LEAD_MAX: float = 130.0
const LANE_TOLERANCE: float = 20.0   # crate half-width + your radius, roughly

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

@onready var touch_box: Area2D = $TouchBox
@onready var sprite: Sprite2D = $Sprite2D

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
			crate.set_aim(_aim_point())
			crate.begin_windup()
			_shove_cd = SHOVE_COOLDOWN
			_gap = MOVE_GAP
			return

	# Otherwise close the gap the only way it can — slow them down.
	if _wave_cd <= 0.0 and global_position.distance_to(runner.global_position) <= WAVE_RANGE:
		_cast_wave()
		_wave_cd = WAVE_COOLDOWN
		_gap = MOVE_GAP


# Where the runner will be once the crate lands, not where they are now.
func _aim_point() -> Vector2:
	return runner.global_position \
		+ RUN_DIR * RunnerScript.RUN_SPEED * ObstacleScript.SHOVE_TIME


# Two gates, not one:
#   - the crate has to be something WE can reach (TELEKINESIS_RANGE)
#   - after the shove it has to land in the runner's path, in the LEAD window
# Testing only boss->runner distance is the classic mistake: the boss is in
# range, but the crate it grabbed is way off to one side and the shove
# accomplishes nothing except burning the cooldown.
func _find_crate() -> Node2D:
	var aim: Vector2 = _aim_point()
	var best: Node2D = null
	var best_lead: float = 1e9

	for c in get_tree().get_nodes_in_group("chase_obstacle"):
		if c.is_spent() or not c.is_idle():
			continue
		if global_position.distance_to(c.global_position) > TELEKINESIS_RANGE:
			continue

		# simulate the shove and judge where it ends up
		var landed: Vector2 = c.global_position \
			+ c.global_position.direction_to(aim) * c.SHOVE_TRAVEL
		# we run downward, so "ahead of the runner" is a bigger y
		var lead: float = landed.y - runner.global_position.y
		if lead < LEAD_MIN or lead > LEAD_MAX:
			continue
		if absf(landed.x - runner.global_position.x) > LANE_TOLERANCE:
			continue

		if lead < best_lead:
			best_lead = lead
			best = c

	return best


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


func stop() -> void:
	active = false
	velocity = Vector2.ZERO
