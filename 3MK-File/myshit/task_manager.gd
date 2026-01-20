extends Node2D
@onready var animated_sprite_2d: AnimatedSprite2D = $"../AnimatedSprite2D"
@onready var rig: RigidBody2D = $"../RigidBody2D"



@export_category("Task Settings")
@export var task_scene: PackedScene 
@export var required_amplitude: float = 120.0
@export var required_wavelength: float = 150.0

func _ready():
	remove_child(rig)
	if task_scene == null:
		print("❌ Error: Task Scene not assigned!")
		return

# Example: player changed controls



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


func _process(delta: float) -> void:
	if required_amplitude == WaveCanvas20.amplitude:
		if required_wavelength == WaveCanvas20.wavelength:
			_on_task_completed()
			add_child(rig)
	else:
		animated_sprite_2d.stop()
		remove_child(rig)

func _on_task_completed():
	animated_sprite_2d.play("default")
	
