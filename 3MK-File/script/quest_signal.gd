class_name QuestSignal extends Node2D

# a radio beacon for a quest spot. drop one where the puzzle lives and the
# radio picks it up by distance. MAIN ones wake the radio on their own,
# SIDE ones only exist on the dial where the player tunes into them.

enum Type { MAIN, SIDE }

@export var quest_type: Type = Type.MAIN
@export var puzzle_id: String = ""      # matches GameState ids, goes silent once solved
@export_range(530, 1700) var frequency: int = 630   # dial spot, matters for SIDE
@export var signal_radius: float = 400.0
@export var order: int = 0              # MAIN only: lowest order broadcasts first


func _ready() -> void:
	add_to_group("quest_signal")


func strength_at(pos: Vector2) -> float:
	var d: float = global_position.distance_to(pos)
	return clampf(1.0 - d / signal_radius, 0.0, 1.0)
