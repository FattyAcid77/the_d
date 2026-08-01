class_name NPCBehaviorPatrol extends NPCBehavior
## Walks between patrol points in order, waiting at each one, then loops.
##
## Setup: add Marker2D nodes as CHILDREN of this Patrol node and move them
## where you want the stops. IMPORTANT: after placing them, they stay where
## they are in the world (the script converts to global positions on start,
## so they don't follow the NPC around).

## Seconds to stand at each point before moving on.
@export var wait_at_point: float = 1.5
## How close counts as "arrived" (pixels).
@export var arrive_distance: float = 6.0

var _points: Array[Vector2] = []
var _index: int = 0
var _waiting: float = 0.0


func setup(owner_npc: NPC) -> void:
	super.setup(owner_npc)
	for child in get_children():
		if child is Marker2D:
			_points.append(child.global_position)
	if _points.is_empty():
		push_warning("Patrol behavior on '%s' has no Marker2D points." % npc.name)


func tick(_delta: float) -> void:
	if _points.is_empty():
		npc.direction = Vector2.ZERO
		return

	if _waiting > 0.0:
		_waiting -= _delta
		npc.direction = Vector2.ZERO
		return

	var target := _points[_index]
	var to_target := target - npc.global_position
	if to_target.length() <= arrive_distance:
		_index = (_index + 1) % _points.size()
		_waiting = wait_at_point
		npc.direction = Vector2.ZERO
		return

	npc.direction = to_target.normalized()
