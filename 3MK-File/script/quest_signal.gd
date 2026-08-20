@tool
class_name QuestSignal extends Node2D

# a radio beacon for a quest spot. drop one where the puzzle lives and the
# radio picks it up by distance. MAIN ones wake the radio on their own,
# SIDE ones only exist on the dial where the player tunes into them.
#
# this is the bare beacon. for a signal that also DOES something when the
# player finds it, use RadioMaker/radio_signal.tscn instead — it extends this
# one and is set up from a window instead of from here.

enum Type { MAIN, SIDE }

## MAIN opens the radio by itself once the player walks in range.
## SIDE stays silent until the dial lands within 30 Hz of `frequency`.
@export var quest_type: Type = Type.MAIN

## A GameState id. Once that puzzle is solved this beacon stops broadcasting.
## Leave empty and it broadcasts forever.
@export var puzzle_id: String = ""

## Where this sits on the dial. Only matters for SIDE. Must be a multiple of
## 10 or the player can never land on it — the tuning keys move in 10s.
@export_range(530, 1700, 10) var frequency: int = 630

## How far the signal carries, in pixels. Full strength at the middle, fading
## to nothing at the edge.
@export var signal_radius: float = 400.0

## MAIN only. The lowest-numbered unfinished MAIN is the one that broadcasts,
## so quest 2 stays quiet until quest 1 is done.
@export var order: int = 0


func _ready() -> void:
	add_to_group("quest_signal")


func strength_at(pos: Vector2) -> float:
	var d: float = global_position.distance_to(pos)
	return clampf(1.0 - d / signal_radius, 0.0, 1.0)
