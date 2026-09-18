extends Node2D
#---------------------------Drop Reward---------------------------#

@export_category("DropZone")
@export var DropZone: Array[Area2D]

@export_category("Rewards")
@export var Spawn: PackedScene

var Reward: bool = false

func _process(_delta: float) -> void:
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
		
		# 1. Instantiate the blueprint into a new local variable called 'spawn'
		var spawn = Spawn.instantiate()
		
		# 2. Set its position to match this Node2D
		spawn.global_position = global_position
		
		# 3. Add it to the game world
		get_tree().current_scene.add_child(spawn)
