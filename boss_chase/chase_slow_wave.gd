class_name ChaseSlowWave extends Node2D

# The boss's ranged move: a telegraphed rectangular strike straight down one
# lane of the corridor.
#
# It locks onto whatever column you're standing in, paints that lane red for
# AIM_TIME so you get a fair chance to step out, then fires. Caught in it and
# you're slowed AND you lose a heart.
#
# Locking the lane at cast time is the whole point — if it tracked you it would
# be undodgeable, and if it fired instantly it would be unfair. You dodge with
# A/D, the same two keys as everything else.
#
# Pure Node2D with a rect test and _draw(), no Area2D. A rectangle overlap is
# four comparisons and you can print the numbers when it misbehaves; a
# CollisionShape2D would need building, sizing and enabling across three phases.

enum Phase { AIM, FIRE, FADE }

const LANE_WIDTH: float = 56.0    # 3.5 tiles — real threat, but clearly leaveable
const LENGTH: float = 520.0       # reaches well past the player
const AIM_TIME: float = 0.6       # your window to move. tune this first if it feels unfair
const FIRE_TIME: float = 0.25
const FADE_TIME: float = 0.25

const SLOW_STRENGTH: float = 0.9
const SLOW_HOLD: float = 1.2
const DAMAGE: int = 1

var _phase: int = Phase.AIM
var _t: float = 0.0
var _hit_done: bool = false
var _lane_x: float = 0.0          # locked at spawn, never updated


func _ready() -> void:
	var r: Node2D = get_tree().get_first_node_in_group("chase_runner")
	_lane_x = r.global_position.x if r != null else global_position.x


func _physics_process(delta: float) -> void:
	_t += delta
	match _phase:
		Phase.AIM:
			if _t >= AIM_TIME:
				_advance(Phase.FIRE)
		Phase.FIRE:
			_try_hit()
			if _t >= FIRE_TIME:
				_advance(Phase.FADE)
		Phase.FADE:
			if _t >= FADE_TIME:
				queue_free()
	queue_redraw()


func _advance(next: int) -> void:
	_phase = next
	_t = 0.0


# Checked every frame it's live, not just the first — stepping INTO the beam
# while it's firing should still catch you.
func _try_hit() -> void:
	if _hit_done:
		return
	for r in get_tree().get_nodes_in_group("chase_runner"):
		if not covers(r.global_position):
			continue
		if r.has_method("on_wave_hit"):
			r.on_wave_hit(SLOW_STRENGTH, SLOW_HOLD, DAMAGE)
		_hit_done = true
		return


## Is this world point inside the lane? Public so the boss (or a future
## smarter dodge AI) can ask the same question the beam answers.
func covers(pos: Vector2) -> bool:
	return absf(pos.x - _lane_x) <= LANE_WIDTH * 0.5 \
		and pos.y >= global_position.y \
		and pos.y <= global_position.y + LENGTH


# in local space, since we're parked at the boss's cast position
func _lane_rect() -> Rect2:
	return Rect2(
		(_lane_x - global_position.x) - LANE_WIDTH * 0.5, 0.0,
		LANE_WIDTH, LENGTH)


func _draw() -> void:
	var r: Rect2 = _lane_rect()

	match _phase:
		Phase.AIM:
			# The fill deepens as the timer runs down, so "about to go off" is
			# something you read at a glance instead of counting in your head.
			var p: float = clampf(_t / AIM_TIME, 0.0, 1.0)
			draw_rect(r, Color(1.0, 0.2, 0.2, 0.10 + 0.20 * p), true)
			draw_rect(r, Color(1.0, 0.4, 0.4, 0.5 + 0.5 * p), false, 2.0)
			# a line that sweeps the length of the lane and arrives exactly when
			# it fires — the precise "now" cue
			var y: float = r.size.y * p
			draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y),
				Color(1.0, 0.65, 0.35, 0.95), 2.0)
		Phase.FIRE:
			draw_rect(r, Color(1.0, 0.8, 0.45, 0.55), true)
			draw_rect(r, Color(1.0, 1.0, 0.85, 0.95), false, 3.0)
		Phase.FADE:
			var a: float = 1.0 - clampf(_t / FADE_TIME, 0.0, 1.0)
			draw_rect(r, Color(1.0, 0.7, 0.4, 0.45 * a), true)
