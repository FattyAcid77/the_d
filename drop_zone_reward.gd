extends Node2D
#---------------------------Drop Reward---------------------------#

@export_category("DropZone")
@export var DropZone: Array[Area2D]
@export_category("Rewards")
@export var Spawn: PackedScene

var Reward: bool = false

func _process(delta: float) -> void:
	if Reward == false:
		zone_check()

func zone_check():
	var fill: bool = true
	for zone in DropZone:
		if zone.Done == false:
			fill = false
			break
	if fill == true:
		print("GJ!")
		Reward = true
		
