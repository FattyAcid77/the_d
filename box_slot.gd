extends Area2D

# Creates a neat dropdown menu in the Inspector!
enum Direction { RIGHT, DOWN, LEFT, UP }

@export var target_statue: RigidBody2D 
@export var snap_distance: float = 20.0 

# Choose the required direction from the dropdown in the Inspector
@export var required_direction: Direction = Direction.UP

# Wiggle room for the angle (Set to 360 to ignore rotation entirely)
@export var rotation_tolerance: float = 10.0 

var is_locked: bool = false
var target_degrees: float = 0.0

func _ready():
	# Convert the chosen word (UP, DOWN, etc.) into math degrees for Godot
	match required_direction:
		Direction.RIGHT: target_degrees = 0.0
		Direction.DOWN: target_degrees = 90.0
		Direction.LEFT: target_degrees = 180.0
		Direction.UP: target_degrees = -90.0

func _physics_process(delta):
	if is_locked or target_statue == null:
		return

	if overlaps_body(target_statue):
		var distance = global_position.distance_to(target_statue.global_position)
		
		if distance <= snap_distance:
			var current_rad = target_statue.rotation
			var target_rad = deg_to_rad(target_degrees)
			var angle_diff = abs(rad_to_deg(angle_difference(current_rad, target_rad)))
			
			if angle_diff <= rotation_tolerance:
				lock_statue()

func lock_statue():
	is_locked = true
	
	# Snap perfectly into place
	target_statue.global_position = global_position
	target_statue.rotation_degrees = target_degrees
	
	# Freeze the physics so it can't be pushed anymore
	target_statue.freeze = true
	
	print("Click! Statue Locked into place facing: ", Direction.keys()[required_direction])
