class_name ChaseSlowEffect extends Node

# The one place that knows "how slow am I right now".
#
# Anything that wants to slow the runner just calls apply() — every frame if
# it's an ongoing thing like the wave, once with a long hold if it's a one-off
# hit. Nothing else needs to know how the runner moves.
#
# The _timeout countdown is the same "am I still being hit?" trick that
# beam_receiver.gd:19-26 uses to notice when the beam stopped touching it.

const SLOW_FLOOR: float = 0.40   # hardest possible slow, as a speed multiplier

@export var recover_time: float = 0.6

var _strength: float = 0.0   # 0 = normal speed, 1 = fully slowed
var _timeout: float = 0.0
var _floor: float = 0.0      # permanent damage to your legs — see add_permanent()


## amount 0..1, hold = seconds at full before it starts decaying.
func apply(amount: float, hold: float = 0.10) -> void:
	_strength = maxf(_strength, clampf(amount, 0.0, 1.0))
	_timeout = maxf(_timeout, hold)


## A one-way ratchet. Raises a floor the slow can never decay back below, so
## the second crate really does leave you worse off than the first — you don't
## walk it off. This is the damage spiral the boss is trying to start, and it's
## why eating two crates is usually fatal even though you have three hearts.
##
## One-way by design: nothing lowers _floor except a restart.
func add_permanent(amount: float) -> void:
	_floor = clampf(_floor + amount, 0.0, 1.0)
	_strength = maxf(_strength, _floor)


func permanent() -> float:
	return _floor


func speed_multiplier() -> float:
	return lerpf(1.0, SLOW_FLOOR, _strength)


func strength() -> float:
	return _strength


func clear() -> void:
	_strength = 0.0
	_timeout = 0.0
	_floor = 0.0


func _physics_process(delta: float) -> void:
	if _timeout > 0.0:
		_timeout -= delta
		return
	# nobody is slowing us any more — ease off instead of snapping back, so the
	# recovery is something you can feel and plan around. We only recover down
	# to _floor, never past it.
	_strength = maxf(_strength - delta / recover_time, _floor)
