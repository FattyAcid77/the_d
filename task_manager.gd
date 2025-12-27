extends Node2D

@export_category("Task Settings")
@export var task_scene: PackedScene 
@export var required_amplitude: float = 100.0
@export var required_wavelength: float = 150.0

func _ready():
	if task_scene == null:
		print("❌ Error: Task Scene not assigned!")
		return

	# Create the task
	var new_task = task_scene.instantiate()
	
	# Set position to (0,0) so it appears exactly where THIS node is
	new_task.position = Vector2.ZERO 
	
	# Set the values from the Inspector
	new_task.required_amplitude = required_amplitude
	new_task.required_wavelength = required_wavelength
	
	# Connect the success signal
	new_task.task_completed.connect(_on_task_completed)
	
	add_child(new_task)

func _on_task_completed():
	print("--------------------------------")
	print("🏆 Task at ", global_position, " COMPLETE!")
	print("🎁 REWARD GIVEN")
	print("--------------------------------")
