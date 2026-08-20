extends Area2D

enum RewardType { SPAWN_ITEM, CHANGE_SCENE }

@export_group("Task Settings")
@export var puzzle_name: String = ""
@export var required_amplitude: float = 120.0
@export var required_wavelength: float = 150.0
@export var tolerance: float = 2.0

@export var puzzle_id: String = ""

@export_group("Reward Behavior")
@export var reward_action: RewardType = RewardType.SPAWN_ITEM

@export_subgroup("Spawn Settings")
@export var reward_scene: PackedScene
@export var spawn_point: Marker2D

@export_subgroup("Transition Settings")
@export_file("*.tscn") var next_world_path: String = ""

var is_solved: bool = false
var player_inside: bool = false

func _ready() -> void:

	
	if puzzle_id != "" and GameState.is_solved(puzzle_id):
		is_solved = true
		_apply_solved_state()

func _on_body_entered(body: Node2D) -> void:
	if body is Sami:
		player_inside = true
		if puzzle_id != "":
			GameState.enter_puzzle(puzzle_id, puzzle_name)
		# If the puzzle is already solved and it's a portal, teleport them instantly
		if is_solved and reward_action == RewardType.CHANGE_SCENE:
			go_to_next_world()

func _on_body_exited(body: Node2D) -> void:
	if body is Sami:
		player_inside = false

func _process(_delta: float) -> void:
	# Stop checking if it's already solved
	if is_solved:
		return
		
	# Only check the waves if the player is currently standing inside
	if player_inside:
		check_puzzle_completion()

func check_puzzle_completion() -> void:
	var amp_ok = abs(WaveCanvas20.amplitude - required_amplitude) <= tolerance
	var wave_ok = abs(WaveCanvas20.wavelength - required_wavelength) <= tolerance
	
	if amp_ok and wave_ok:
		is_solved = true
		execute_reward()

func execute_reward() -> void:
	if puzzle_id != "":
		GameState.solve_puzzle(puzzle_id)
		
	match reward_action:
		RewardType.SPAWN_ITEM:
			spawn_reward()
		RewardType.CHANGE_SCENE:
			go_to_next_world()

func _apply_solved_state() -> void:
	match reward_action:
		RewardType.SPAWN_ITEM:
			spawn_reward()
		RewardType.CHANGE_SCENE:
			pass # Do nothing yet; wait for the player to walk into the area to teleport

func spawn_reward() -> void:
	if reward_scene == null:
		push_warning("Reward Scene not assigned on puzzle: " + puzzle_id)
		return
		
	var instance = reward_scene.instantiate()
	instance.global_position = spawn_point.global_position if spawn_point else global_position
	
	# call_deferred is safer when adding nodes during signal/physics processing
	get_tree().current_scene.call_deferred("add_child", instance)

func go_to_next_world() -> void:
	if next_world_path == "":
		push_warning("Next World Path not assigned on puzzle: " + puzzle_id)
		return
	var scene_path := get_tree().current_scene.scene_file_path
	for mirror in get_tree().get_nodes_in_group("beam_mirror"):
		GameState.save_mirror(scene_path, mirror.name, mirror.global_position, mirror.rotation)
	SceneManager.load_new_scene(next_world_path)
