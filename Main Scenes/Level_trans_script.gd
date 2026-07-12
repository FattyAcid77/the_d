class_name Level extends Node2D

@export var player: Player
@export var doors: Array[Door_reg]

var data: LevelDataHandoff

func _ready() -> void:
	#player.disable()
	#player.visible = false
	#if data == null:
	enter_level()
		

func enter_level() -> void:
	print("you have entered a level")
	if data != null:
		print("player location initiated")
		init_player_location()
	player.enable()
	_connect_to_doors()

func init_player_location() -> void:
	if data != null:
		print ("you checked that leveldatahandoff is not empty")
		for door in doors:
			print("the door name is : " , door.target_door_name)
			print(" the data door name is: " , data.target_door_name)
			if door.this_door_name == data.target_door_name:
				print("you reached the door check")
				#player.position = door.position
				player.position = door.get_player_entry_vector()
		player.orient(data.move_dir)

func _on_player_entered_door(door:Door_reg) -> void:
	_disconnect_from_doors()
	player.disable()
	#player.queue_free()
	data = LevelDataHandoff.new()
	print("you reached the mark where the new door name is written")
	#هنا إحنا بنكتب اسم الباب اللي نبغا نروحله
	data.target_door_name = door.target_door_name
	print(door.target_door_name)
	data.move_dir = door.position
	print(data.move_dir)
	set_process(false)

func _connect_to_doors() -> void:
	for door in doors:
		if not door.player_entered_door.is_connected(_on_player_entered_door):
			door.player_entered_door.connect(_on_player_entered_door)
			print("you reached the point where door is connected")

func _disconnect_from_doors() -> void:
	for door in doors:
		if door.player_entered_door.is_connected(_on_player_entered_door):
			door.player_entered_door.disconnect(_on_player_entered_door)
