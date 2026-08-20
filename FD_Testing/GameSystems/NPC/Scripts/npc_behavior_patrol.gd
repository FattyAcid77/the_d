class_name NPCBehaviorPatrol extends NPCBehavior
## Walks between patrol points in order, waiting at each one, then loops.
##
## Setup: add Marker2D nodes as CHILDREN of this Patrol node and move them
## where you want the stops. Their world positions are read once at start,
## so they stay put (they don't follow the NPC).

## Seconds to stand at each point before moving on.
@export var wait_at_point: float = 1.5
## How close counts as "arrived" (pixels).
@export var arrive_distance: float = 6.0
## If something (the player) blocks the way this long, skip to the next
## point instead of pushing into them forever.
@export var give_up_after: float = 1.5

var _points: Array[Vector2] = []
var _index: int = 0
var _waiting: float = 0.0
var _blocked_time: float = 0.0


func setup(owner_npc: NPC) -> void:
	super.setup(owner_npc)
	for child in get_children():
		if child is Marker2D:
			_points.append(child.global_position)
	if _points.is_empty():
		push_warning("Patrol behavior on '%s' has no Marker2D points." % npc.name)


func tick(delta: float) -> void:
	if _points.is_empty():
		npc.direction = Vector2.ZERO
		return

	if _waiting > 0.0:
		_waiting -= delta
		npc.direction = Vector2.ZERO
		return

	var target := _points[_index]
	var to_target := target - npc.global_position
	if to_target.length() <= arrive_distance:
		_next_point()
		return

	# blocked by the player/another NPC for too long -> move on
	if npc.is_blocked:
		_blocked_time += delta
		if _blocked_time >= give_up_after:
			_next_point()
			return
	else:
		_blocked_time = 0.0

	npc.direction = to_target.normalized()


func _next_point() -> void:
	_index = (_index + 1) % _points.size()
	_waiting = wait_at_point
	_blocked_time = 0.0
	npc.direction = Vector2.ZERO
