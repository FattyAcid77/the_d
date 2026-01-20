extends Node2D

@export_category("Task Settings")
@export var task_scene: PackedScene 
@export var required_amplitude: float = 120.0
@export var required_wavelength: float = 150.0

@onready var animated_sprite_2d: AnimatedSprite2D = $"../AnimatedSprite2D"
@onready var rig: RigidBody2D = $"../RigidBody2D"

var is_active: bool = false

func _ready() -> void:
	rig.get_parent().remove_child(rig)
	
	if task_scene:
		var new_task = task_scene.instantiate()
		new_task.position = Vector2.ZERO
		new_task.required_amplitude = required_amplitude
		new_task.required_wavelength = required_wavelength
		new_task.task_completed.connect(_on_task_completed)
		add_child(new_task)
	else:
		print("❌ Error: Task Scene not assigned!")

func _process(_delta: float) -> void:
	var condition_met = required_amplitude == WaveCanvas20.amplitude and required_wavelength == WaveCanvas20.wavelength
	
	if condition_met and not is_active:
		is_active = true
		add_child(rig)
		_on_task_completed()
	elif not condition_met and is_active:
		is_active = false
		remove_child(rig)
		animated_sprite_2d.stop()

func _on_task_completed() -> void:
	animated_sprite_2d.play("default")
