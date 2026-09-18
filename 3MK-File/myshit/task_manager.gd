extends Area2D

class_name Task_Manger

# --- TASK SETTINGS ---
@export_group("Task Settings")
@export var required_amplitude: float = 120.0
@export var required_wavelength: float = 150.0
@export var tolerance: float = 2.0 # Allows the player to be slightly off and still win

# --- THE REWARD ---
@export_group("The Reward")
@export var reward_scene: PackedScene
@export var spawn_point: Marker2D # Optional: A specific node to spawn the reward at

var is_solved: bool = false

func _process(_delta: float) -> void:
	# If the puzzle is already solved, don't keep checking
	if is_solved:
		return
		
	check_puzzle_completion()

func check_puzzle_completion() -> void:
	# Grab the live values from your Autoload
	var current_amp = WaveCanvas20.amplitude
	var current_wave = WaveCanvas20.wavelength
	
	# Check if the player's values are within the acceptable tolerance range
	var amp_is_correct = abs(current_amp - required_amplitude) <= tolerance
	var wave_is_correct = abs(current_wave - required_wavelength) <= tolerance
	
	# If both are correct, trigger the win state!
	if amp_is_correct and wave_is_correct:
		spawn_reward()

func spawn_reward() -> void:
	is_solved = true
	print("Radio Frequency Matched! Spawning Reward...")
	
	# Safety check to make sure you dragged the scene into the inspector
	if reward_scene == null:
		push_warning("Wait! You forgot to assign the Reward Scene in the Inspector!")
		return
		
	# 1. Create a new instance of the reward
	var reward_instance = reward_scene.instantiate()
	
	# 2. Figure out where to put it
	if spawn_point != null:
		reward_instance.global_position = spawn_point.global_position
	else:
		# Defaults to the center of the Task_area if no spawn point is assigned
		reward_instance.global_position = global_position 
		
	# 3. Add it to the game world (we add it to the main scene root so it isn't stuck inside the Area2D)
	get_tree().current_scene.add_child(reward_instance)
	
	# Optional: Play a success sound effect here!
