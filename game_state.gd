extends Node

signal puzzle_entered(puzzle_id: String, puzzle_name: String)
signal puzzle_completed(puzzle_id: String, puzzle_name: String)

var complete: bool = false

var solved_puzzles: Dictionary = {}
var beam_portals: Dictionary = {}
var mirror_states: Dictionary = {}
var _puzzle_names: Dictionary = {}
var _entered_puzzles: Dictionary = {}

func enter_puzzle(puzzle_id: String, puzzle_name: String = "") -> void:
	# Only fire once per puzzle, even if player walks in and out multiple times
	if is_solved(puzzle_id) or _entered_puzzles.has(puzzle_id):
		return
	_entered_puzzles[puzzle_id] = true
	_puzzle_names[puzzle_id] = puzzle_name
	puzzle_entered.emit(puzzle_id, puzzle_name)

func save_mirror(scene_path: String, mirror_name: String, pos: Vector2, rot: float) -> void:
	if not mirror_states.has(scene_path):
		mirror_states[scene_path] = {}
	mirror_states[scene_path][mirror_name] = {"position": pos, "rotation": rot}

func get_mirror_state(scene_path: String, mirror_name: String) -> Dictionary:
	if mirror_states.has(scene_path) and mirror_states[scene_path].has(mirror_name):
		return mirror_states[scene_path][mirror_name]
	return {}

func solve_puzzle(puzzle_id: String) -> void:
	solved_puzzles[puzzle_id] = true
	puzzle_completed.emit(puzzle_id, _puzzle_names.get(puzzle_id, puzzle_id))

func is_solved(puzzle_id: String) -> bool:
	return solved_puzzles.get(puzzle_id, false)

func set_beam_portal(portal_id: String, active: bool, angle: float) -> void:
	beam_portals[portal_id] = {"active": active, "angle": angle}

func get_beam_portal(portal_id: String) -> Dictionary:
	return beam_portals.get(portal_id, {"active": false, "angle": 0.0})
