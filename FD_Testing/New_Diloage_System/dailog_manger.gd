extends Node2D

@onready var dialog_ui: Control = $DialogUi

var npc: Node = null

##Show Dialog With Data
func show_dialog(npc, text = "", options = {}):
	if text != "":
		dialog_ui.show_dailog(npc.npc_name, text, options)
	else:
		var dialog = npc.get_current_dialog()
		if dialog == null:
			return
		dialog_ui.show_dialog(npc.npc_name, dialog["text"], dialog["options"])

func hide_dialog():
	dialog_ui.hide_dialog()


##This need to be changed if there are more option that opens new systems
func handle_dialog_choice(option):
	var current_dialog = npc.get_current_dialog()
	if current_dialog == null:
		return
	
	#updated the state
	var next_state = current_dialog["options"].get(option, "start")
	npc.set_dialog_state(next_state)
	
	##When the State is end, we go to the next beanch, the branch that would be diffrint from the current branch, not a diffrint npc or diffrint state, no a whole diffrint branch with its own states and everything
	if next_state == "end":
		if npc.current_index < npc.dialog_resource.get_npc_dialog(npc.npc_id).size() -1:
			npc.set_dialog_tree(npc.current_index + 1)
		hide_dialog()
	elif next_state == "exit":
		npc.set_dialog_state("start")
		hide_dialog()
	elif next_state == "give_quests":
		pass
	else:
		show_dialog(npc)
	
	
	
