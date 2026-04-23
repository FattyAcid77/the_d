extends Node

@onready var invntory_slot = preload("res://inventory_slot.tscn")

var Player_ch: Node = null

signal Inventory_UI

var inventory = []

func _ready():
	inventory.resize(16)


func add_item(item):
	for i in range(inventory.size()):
		# Check if the item exists in the inventory and matches both type and effect
		if inventory[i] != null and inventory[i]["type"] == item["type"] and inventory[i]["effect"] == item["effect"]:
			inventory[i]["quantity"] += item["quantity"]
			Inventory_UI.emit()
			return true
		elif inventory[i] == null:
			inventory[i] = item
			Inventory_UI.emit()
			return true
			
	# Note how this is now outside the loop (only one indent level)
	return false


func Remove_item(item_type,item_effect):
	for i in range(inventory.size()):
		if inventory[i] != null and inventory[i]["type"] == item_type and inventory[i]["effect"] == item_effect:
			inventory[i]["quantity"] -= 1
			if inventory[i]["quantity"] <= 0:
				inventory[i] = null
			Inventory_UI.emit()
			return true
	return false

func player_ref(Sami):
	Player_ch = Sami


# Renamed from drop_position to calculate_drop_position
func calculate_drop_position(target_position):
	var radius = 50
	var items_drop = get_tree().get_nodes_in_group("Item")
	for item in items_drop:
		if item.global_position.distance_to(target_position) < radius:
			var random_offset = Vector2(randf_range(-radius, radius), randf_range(-radius, radius))
			target_position += random_offset
			break
	return target_position

# Renamed the variables inside to match
func drop_item(item_data, target_position):
	print("TRYING TO LOAD: ", item_data["scene_path"])
	var item_scene = load(item_data["scene_path"])
	var item_instance = item_scene.instantiate()
	
	item_instance.set_item_data(item_data)
	
	# Use the newly renamed function
	target_position = calculate_drop_position(target_position)
	item_instance.global_position = target_position
	
	get_tree().current_scene.add_child(item_instance)





# Let's say 'item_to_use' is the dictionary you created in pickable()
func use_item(item_to_use):
	# Check if this item actually heals
	if item_to_use.has("heal_amount") and item_to_use["heal_amount"] > 0:
		
		# Grab Sami (Player_ch), access his stats, and add the health!
		Player_ch.stats.current_health += item_to_use["heal_amount"]
		print("Sami healed for ", item_to_use["heal_amount"], " points!")
		
		# FIX: Actually remove the item from the inventory list!
		Remove_item(item_to_use["type"], item_to_use["effect"])




# Swaps items in the inventory based on their indices
func swap_inventory_items(index1, index2):
	if index1 < 0 or index1 > inventory.size() or index2 < 0 or index2 > inventory.size():
		return false
	var temp = inventory[index1]
	inventory[index1] = inventory[index2]
	inventory[index2] = temp
	Inventory_UI.emit()
	return true
