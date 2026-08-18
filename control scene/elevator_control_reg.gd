class_name Elevator_Control_reg extends Area2D

@onready var E_C: Elevator_control_UI = $"../ElevatorControl"
@onready var sami: Player = $"../Sami_Doctor_test"

var player_inside:bool = false

func _process(_delta: float) -> void:
	if player_inside and Input.is_action_just_pressed("action"):
		open_Elevetor_Control_UI()

func open_Elevetor_Control_UI() -> void:
	sami.disable()
	E_C.visible = true


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		player_inside = true
		SceneManager.player_in_area = true


func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		player_inside = true
		SceneManager.player_in_area = true
	
