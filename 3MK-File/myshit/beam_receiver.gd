extends Area2D
class_name BeamReceiver

## How many unique mirrors the beam must bounce off before this receiver activates.
@export var required_mirror_count: int = 1

## Optional: set to auto-solve a puzzle when beam hits this receiver.
@export var puzzle_id: String = ""

signal beam_activated
signal beam_deactivated

var is_hit: bool = false
var _timeout: float = 0.0

func _ready() -> void:
	add_to_group("beam_receiver")

func _physics_process(delta: float) -> void:
	if not is_hit:
		return
	_timeout -= delta
	if _timeout <= 0.0:
		is_hit = false
		beam_deactivated.emit()
		queue_redraw()

## Called by BeamEmitter every frame the beam lands on this receiver.
## `mirror_count` = how many unique mirrors the beam bounced off to get here.
func on_beam_hit(mirror_count: int = 0) -> void:
	if mirror_count < required_mirror_count:
		return  # not enough mirrors used → ignore the hit
	_timeout = 0.05
	if not is_hit:
		is_hit = true
		beam_activated.emit()
		if puzzle_id != "":
			GameState.solve_puzzle(puzzle_id)
		queue_redraw()

func _draw() -> void:
	var col := Color(0.2, 1.0, 0.4, 0.9) if is_hit else Color(0.45, 0.45, 0.45, 0.8)
	var ring := Color(1.0, 1.0, 1.0, 0.5) if is_hit else Color(0.6, 0.6, 0.6, 0.5)
	draw_circle(Vector2.ZERO, 18.0, col)
	draw_circle(Vector2.ZERO, 11.0, Color(0.05, 0.05, 0.05, 0.7))
	draw_circle(Vector2.ZERO, 5.0, col)
	draw_arc(Vector2.ZERO, 18.0, 0.0, TAU, 32, ring, 2.0)
