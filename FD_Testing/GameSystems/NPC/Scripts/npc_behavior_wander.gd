class_name NPCBehaviorWander extends NPCBehavior
## Random short walks around where the NPC started, with pauses in between.

## How far from the start point the NPC is allowed to roam.
@export var wander_radius: float = 80.0
## How long one walk lasts (seconds, random between min/max).
@export var walk_time_min: float = 0.6
@export var walk_time_max: float = 1.6
## How long the NPC stands still between walks.
@export var wait_time_min: float = 1.0
@export var wait_time_max: float = 3.0

var _home: Vector2
var _timer: float = 0.0
var _walking: bool = false
var _walk_dir: Vector2 = Vector2.ZERO


func setup(owner_npc: NPC) -> void:
	super.setup(owner_npc)
	_home = npc.global_position
	_timer = randf_range(wait_time_min, wait_time_max)


func tick(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_walking = not _walking
		if _walking:
			_walk_dir = _pick_direction()
			_timer = randf_range(walk_time_min, walk_time_max)
		else:
			_timer = randf_range(wait_time_min, wait_time_max)
	npc.direction = _walk_dir if _walking else Vector2.ZERO


func _pick_direction() -> Vector2:
	# if we drifted too far from home, walk back; otherwise pick random
	var away := npc.global_position - _home
	if away.length() > wander_radius:
		return (-away).normalized()
	return Vector2.from_angle(randf() * TAU)
