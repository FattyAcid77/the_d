class_name ChaseObstacle extends CharacterBody2D

# A crate sitting in the corridor. It does nothing on its own.
#
# The boss shoves it toward you; you either dodge around it, eat it, or parry
# it back down the corridor. Crates are hazards on contact whether or not the
# boss touched them — the shove just repositions one into your path.

signal parried

enum Mode { IDLE, WINDUP, FLYING }

const SHOVE_TRAVEL: float = 48.0       # 3 tiles
const SHOVE_TIME: float = 0.30
const WINDUP_TIME: float = 0.45        # the tell — it rattles before it moves
const PARRY_REACH: float = 44.0
const REVERSE_DISTANCE: float = 320.0  # 48px would never reach the boss
const REVERSE_TIME: float = 0.56       # ~570 px/s, much faster than the shove

const COLOR_IDLE := Color(1.0, 1.0, 1.0)
const COLOR_WINDUP := Color(1.0, 0.55, 0.55)
const COLOR_LIVE := Color(1.0, 0.75, 0.55)     # thrown at you = parryable
const COLOR_PARRIED := Color(1.0, 0.85, 0.3)
const COLOR_SPENT := Color(0.45, 0.45, 0.45, 0.7)

var fly_direction: Vector2 = Vector2.ZERO

var _mode: int = Mode.IDLE
var _reversed: bool = false
var _spent: bool = false
var _live: bool = false     # the boss has grabbed us — only now can we be parried
var _t: float = 0.0
var _from: Vector2 = Vector2.ZERO
var _distance: float = 0.0
var _fly_time: float = 0.0
var _windup_left: float = 0.0
var _rest_pos: Vector2 = Vector2.ZERO
var _aim_point: Vector2 = Vector2.INF   # locked in at grab time, see set_aim()

@onready var hitbox: Area2D = $HitBox
@onready var art: Polygon2D = $Body
@onready var art_edge: Line2D = $Edge

var _runner: Node2D = null


func _ready() -> void:
	add_to_group("chase_obstacle")
	_rest_pos = position
	hitbox.body_entered.connect(_on_hitbox_body_entered)


# Tint the art, not the whole node. modulate on the root would also wash out
# the parry ring drawn in _draw(), and then "you can hit this now" would come
# out orange instead of green.
func _set_tint(c: Color) -> void:
	art.modulate = c
	art_edge.modulate = c


func _runner_ref() -> Node2D:
	if _runner == null or not is_instance_valid(_runner):
		_runner = get_tree().get_first_node_in_group("chase_runner")
	return _runner


func is_idle() -> bool:
	return _mode == Mode.IDLE

func is_flying() -> bool:
	return _mode == Mode.FLYING

func is_spent() -> bool:
	return _spent


## Only a crate the boss has actually thrown can be parried — "if the player
## hits what the boss is throwing". Plain scenery crates still hurt on contact,
## but you have to dodge those, not swat them. Without this you could farm the
## corridor furniture and kill the boss without ever engaging with its attack.
func is_live() -> bool:
	return _live and not _spent


## The boss grabs us. We rattle in place first so the player gets a warning.
func begin_windup() -> void:
	if _mode != Mode.IDLE or _spent:
		return
	_mode = Mode.WINDUP
	_live = true
	_windup_left = WINDUP_TIME
	_rest_pos = position
	_set_tint(COLOR_WINDUP)


## Called by the runner on a successful parry. Sends us back at whoever shoved us.
func reverse_toward(target: Node2D) -> void:
	if _spent or target == null:
		return
	_reversed = true
	_set_tint(COLOR_PARRIED)      # it's yours now — readable at a glance
	_launch(global_position.direction_to(target.global_position), REVERSE_DISTANCE, REVERSE_TIME)
	parried.emit()


## Shove us toward a point. Direction is whatever points at the player, so a
## crate sitting below you gets driven upward and one off to the side slides
## into your lane — one rule, both readings of "move it near the player".
func shove_toward(point: Vector2) -> void:
	_launch(global_position.direction_to(point), SHOVE_TRAVEL, SHOVE_TIME)


func _physics_process(delta: float) -> void:
	match _mode:
		Mode.WINDUP:
			_do_windup(delta)
		Mode.FLYING:
			_advance(delta)
	if _live and not _spent:
		queue_redraw()      # the ring pulses and changes colour, so redraw it


# The "hit here" indicator.
#
# A ring at exactly PARRY_REACH around a live crate, so the parry window is a
# thing you can see rather than a number you have to feel out. It goes green
# and solid the moment you're actually close enough — that's your cue to press
# Space, and it turns a hidden timing check into a visible one.
#
# Drawn on the crate itself, so it renders under the crate art and over the
# floor. Only live crates get one; ordinary scenery crates can't be parried
# and showing a ring on them would be a lie.
func _draw() -> void:
	if not is_live():
		return

	var r: Node2D = _runner_ref()
	var in_reach: bool = r != null \
		and global_position.distance_to(r.global_position) <= PARRY_REACH
	var pulse: float = 0.5 + 0.5 * sin(float(Time.get_ticks_msec()) / 80.0)

	if in_reach:
		draw_arc(Vector2.ZERO, PARRY_REACH, 0.0, TAU, 40,
			Color(0.35, 1.0, 0.5, 0.95), 2.5, true)
		draw_arc(Vector2.ZERO, PARRY_REACH * (0.5 + 0.12 * pulse), 0.0, TAU, 28,
			Color(0.35, 1.0, 0.5, 0.4), 1.5, true)
	else:
		draw_arc(Vector2.ZERO, PARRY_REACH, 0.0, TAU, 40,
			Color(1.0, 0.75, 0.25, 0.2 + 0.3 * pulse), 1.5, true)


func _do_windup(delta: float) -> void:
	_windup_left -= delta
	# purely a tell, no gameplay effect
	position = _rest_pos + Vector2(randf_range(-1.5, 1.5), randf_range(-1.5, 1.5))
	if _windup_left > 0.0:
		return
	position = _rest_pos
	# stays tinted while it's live, so you can tell at a glance which crate is
	# the one you're allowed to parry
	_set_tint(COLOR_LIVE)
	if _aim_point != Vector2.INF:
		shove_toward(_aim_point)


## The boss tells us where to go before the windup starts, so the aim is locked
## in at grab time and doesn't snake toward the player mid-flight.
func set_aim(point: Vector2) -> void:
	_aim_point = point


func _launch(dir: Vector2, distance: float, duration: float) -> void:
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
	var eased: float = f * f * (3.0 - 2.0 * f)      # smoothstep

	var target: Vector2 = _from + fly_direction * _distance * eased
	var collision := move_and_collide(target - global_position)
	if collision != null or f >= 1.0:
		_land()


func _land() -> void:
	_mode = Mode.IDLE
	_reversed = false
	_aim_point = Vector2.INF
	_rest_pos = position
	velocity = Vector2.ZERO


# A crate that has already clipped someone stops being a threat, otherwise a
# slowed player sitting on top of one would get chewed up by repeat triggers.
func _spend() -> void:
	_spent = true
	_mode = Mode.IDLE
	_set_tint(COLOR_SPENT)
	hitbox.set_deferred("monitoring", false)
	queue_redraw()   # one last pass to clear the ring; nothing redraws us after this


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
