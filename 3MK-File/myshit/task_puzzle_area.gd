extends Area2D
class_name TaskPuzzleArea

# marks the puzzle room: reports entry to GameState for quest tracking, and
# once the door has fully finished opening, sweeps the beam gear away so only
# the door is left. assumes one beam puzzle + one door per scene. mirrors
# handle their own radio visibility (see unlock_frequency on the mirror
# scripts).

@export var puzzle_id: String = ""
@export var puzzle_name: String = ""

var _cleared: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	for door in get_tree().get_nodes_in_group("puzzle_door"):
		if door.required_puzzle_id == puzzle_id:
			door.door_finished_opening.connect(_on_door_finished_opening)
			break
	# coming back into an already solved room: gear is long gone
	if puzzle_id != "" and GameState.is_solved(puzzle_id):
		_clear_beam_pieces.call_deferred(true)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player") and puzzle_id != "":
		GameState.enter_puzzle(puzzle_id, puzzle_name)

func _on_door_finished_opening() -> void:
	_clear_beam_pieces(false)

func _clear_beam_pieces(instant: bool) -> void:
	if _cleared:
		return
	_cleared = true
	var pieces: Array = []
	pieces.append_array(get_tree().get_nodes_in_group("beam_emitter"))
	pieces.append_array(get_tree().get_nodes_in_group("beam_mirror"))
	pieces.append_array(get_tree().get_nodes_in_group("beam_receiver"))
	for p in pieces:
		if instant or not p is CanvasItem:
			p.queue_free()
		else:
			var tw := create_tween()
			tw.tween_property(p, "modulate:a", 0.0, 1.0)
			tw.tween_callback(p.queue_free)
