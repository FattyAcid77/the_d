extends RigidBody2D
class_name StatueBeamMirror

# --- SETTINGS ---
@export var snap_degrees: float = 90.0 # Defaulted to 90 for the statue directions
@export var target_player_name: String = "Sami"

# --- STATE ---
var _is_player_near: bool = false
var current_step: int = 0
var total_steps: int

func _ready() -> void:
	# Add to the group so the beam emitter recognizes it
	add_to_group("beam_mirror")
	
	# Physics dampening gives it that heavy, pushable statue feel
	linear_damp = 8.0
	angular_damp = 15.0
	
	# Calculate how many turns make a full circle (e.g., 360 / 90 = 4 steps)
	total_steps = int(360.0 / snap_degrees)
	
	# Connect the interaction zone signals
	$InteractZone.body_entered.connect(_on_interact_zone_body_entered)
	$InteractZone.body_exited.connect(_on_interact_zone_body_exited)

# --- INTERACTION LOGIC ---
func _input(event: InputEvent) -> void:
	if not _is_player_near:
		return
		
	if event.is_action_pressed("action"):
		_turn_statue()

# --- ROTATION LOGIC ---
func _turn_statue() -> void:
	# Move to the next step and wrap around (0, 1, 2, 3, 0...) using the math trick
	current_step = (current_step + 1) % total_steps
	
	# Physically rotate the entire RigidBody2D
	rotation_degrees = current_step * snap_degrees
	
	# Stop any random spinning caused by the player bumping into the rigid body
	angular_velocity = 0.0
	
	print("Statue turned to step: ", current_step, " (", rotation_degrees, " degrees)")

# --- DETECTION LOGIC ---
func _on_interact_zone_body_entered(body: Node) -> void:
	# Checks if the body is a player CharacterBody2D OR specifically named "Sami"
	if body is CharacterBody2D or body.name == target_player_name:
		_is_player_near = true

func _on_interact_zone_body_exited(body: Node) -> void:
	if body is CharacterBody2D or body.name == target_player_name:
		_is_player_near = false
