extends Node2D





func enter_level() -> void:
	if data != null:
		init_player_location()
	player.enable()
	_connect_to_doors()

func init_player_location() -> void:
	
	if data != null:
		for door in doors:
			if door.name == data.entry_door_name:
				player.position = door.get_player_entery_vector()
		player.orient(data.move_dir)

func _on_player_entered_door(door:Door) -> void:
	_disconnect_from_doors()
	player.disable()
	player.queue_free()
	data = LevelDataHandoff.new()
	data.entery_door_name = door.entry_door_name
	data.move_dir = door

func _connect_to_doors() -> void:
	for door in doors:
		if not door.player_entered_door.is_connected(_on_player_entered_door):
			door.player_entered_door.connect(_on_player_entered_door)

func _disconnect_from_doors() -> void:
	if door in doors:
		if door.player_entered_door.is_connected(_on_player_entered_door):
			door.player_entered_door.disconnect(_on_player_entered_door)
