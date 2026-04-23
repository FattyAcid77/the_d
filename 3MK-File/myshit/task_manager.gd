extends Node2D

class_name Task_Radio_Manger

@export_category("Task Settings")
@export var required_amplitude: float = 120.0
@export var required_wavelength: float = 150.0

@export_category("The Reward")
@export var Reward_Radio: PackedScene
var player: bool = false

var Reward_Finshed: bool = false

func Task():
	if required_amplitude == WaveCanvas20.amplitude:
		if required_wavelength == WaveCanvas20.wavelength:
			Reward()

func _on_task_area_body_entered(body: Node2D) -> void:
	player = true

func Reward():
	var reward_spawn = Reward_Radio.instantiate()
	get_parent().add_child(reward_spawn)
	reward_spawn.global_position = self.global_position
	Reward_Finshed = true

func _process(delta):
	if player and !Reward_Finshed:
		Task()
	if player and Reward_Finshed:
		queue_free()
