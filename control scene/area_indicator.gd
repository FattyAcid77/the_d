class_name area_indicator extends Node2D

@onready var E_icon: Sprite2D = $Sprite2D


func show_E() -> void:
	E_icon.visible = true

func hide_E() -> void:
	E_icon.visible = false
