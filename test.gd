# chest.gd
extends Node
class_name Chest

# 1. SIGNAL: We define a custom event to broadcast when opened.
signal opened(item_name)

func _ready():
	# 2. METADATA: We attach hidden data to this specific chest instance.
	# In a real game, you could easily set these in the editor inspector 
	# without changing the code for different chests.
	set_meta("contains", "Magic Sword")
	set_meta("is_locked", false)

# The function we want to trigger when the player clicks/presses 'E'
func interact():
	if get_meta("is_locked"):
		print("The chest is locked!")
		return

	# Retrieve the metadata we stored earlier
	var item = get_meta("contains")
	print("Chest opened! Revealing: ", item)
	
	# Emit the signal so the player (or a UI script) can react to it
	opened.emit(item)
