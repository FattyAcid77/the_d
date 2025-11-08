extends Node
@onready var save: Button = $Save
@onready var load: Button = $Load
@onready var player: CharacterBody2D = $"../CharacterBody2D"


const save_location = "user://Save.json"



var contents_to_save: Dictionary = {}

func _ready():
	print("Player node is:", player)



func _save():
	await get_tree().process_frame
	contents_to_save = {"player.position": player.position}
	var file := FileAccess.open_encrypted_with_pass(save_location, FileAccess.WRITE,"f3c0b6f0e7844dc19a062f3e74b6de6aOAS")
	file.store_var(contents_to_save.duplicate())
	file.close()
	print(contents_to_save)


func _load():
	if FileAccess.file_exists(save_location):
		var file = FileAccess.open_encrypted_with_pass(save_location, FileAccess.READ,"f3c0b6f0e7844dc19a062f3e74b6de6aOAS")
		var data = file.get_var()
		file.close()
		var save_data = data.duplicate()
		player.position = data["player.position"]
		print(data)

func _on_save_pressed() -> void:
	_save()


func _on_load_pressed() -> void:
	_load()
	
