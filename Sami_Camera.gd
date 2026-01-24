extends Camera2D

#@export var target_node: Sami
@export var smooth_enabled: bool = true
@export var smooth_speed: float = 8.0


func _ready() -> void:
	make_current()
	
	position_smoothing_enabled = smooth_enabled
	position_smoothing_speed = smooth_speed
	
#func _physics_process(delta: float) -> void:
	#var desired_global:= target_node.global_position
	#global_position = desired_global
