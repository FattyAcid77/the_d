## It Holds all the Stuff that the NPCs needs to talk/Give Quests to the player
##
## this is the Class that Will hold the NPCs info that will be needed in the GDscripts side
##[br][br]
## Its gonna Interact with the Player and the Diloug/Quest Manger/Json File Updating what it needs to Get the new
##Diloug for each new branch


class_name NPC extends CharacterBody2D


@onready var dialog_manger: Node2D = $DialogManger




##npc id to make each Npc uniqe and can refere to them as needed
##[br][br]
##the naming of the ID gonna be NPC_[Name Of The Charcter]
@export var npc_id: String
##The Name of NPC talking, it should be writin and not change much
@export var npc_name: String
##Gets the Dialog class thats holds all the methods that can read of the Json file
@export var dialog_resource: Dialog
##Keep track in What States we are in, The begin of each state is start, and the finle state is end
var current_state: String = "start"
##Keep track of what index of the array we are in, Each array holds diffrint state, like a whole new branch with new states and arrays.
var current_index: int = 0


func _ready() -> void:
	#Load the data from the JSON file
	dialog_resource.load_from_json("res://FD_Testing/New_Diloage_System/Recources/Dialoge/dialog_data.json")
	dialog_manger.npc = self

## Start Each time the Player interact with the NPC as needed
##, starting the UI for the Diloug
func start_dialog():
	var npc_dialog = dialog_resource.get_npc_dialog(npc_id)
	if npc_dialog.is_empty():
		return
	dialog_manger.show_dialog(self)
	

##Gets the npc data from the Dialog Class, that reads all the data from the Json file.
##[br][br]
##It sees the Current Index that we have, then checks if is there data to be read from it,
## or states that we can check for anything, then retruns the dialog is needed
func get_current_dialog():
	var npc_dialog = dialog_resource.get_npc_dialog(npc_id)
	if current_index < npc_dialog.size():
		for dialog in npc_dialog[current_index]["dialogs"]:
			if dialog["state"] == current_state:
				return dialog
	return

##Updates the index of the array, so we can go to the next set of branch
func set_dialog_tree(branch_index):
	current_index = branch_index
	current_state = "start"

##Updates the states from the choise of the player, to get the new text or dialog as needed
func set_dialog_state(state):
	current_state = state
