###Dialog.gd

extends Resource

class_name Dialog

@export var dialogs = {}

##this Func gonna load the JSON file to the class, to get all the dialogs we need in the dictionary
func load_from_json(file_path):
	## gona load and read the file as a raw string to get all the Data in it
	var data = FileAccess.get_file_as_string(file_path)
	## This makes the File data makes senes in a programing way, make the Data into Var, Arrays, dictionary, as needed
	var parsed_data = JSON.parse_string(data)
	# Checks if it not null, and make the dictionary hold all the data in the memory, as needed for the npc
	if parsed_data:
		dialogs = parsed_data
	else:
		print("Failed to parse: ", parsed_data)

## this Func to get the Data from a specifc Npc id, each NPC should have a uniqe id.
##[br][br]
## as trees is gonna be in array from the json file to read all the NPC branches as needed, from its uniqe ID 
func get_npc_dialog(npc_id):
	if npc_id in dialogs:
		return dialogs[npc_id]["trees"]
	else:
		return[]
