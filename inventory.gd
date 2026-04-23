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


func drop_position(position):
	var radius = 50
	var items_drop = get_tree().get_nodes_in_group("Item")
	for item in items_drop:
		if item.global_position.distance_to(position) < radius:
			var random_offset = Vector2(randf_range(-radius, radius), randf_range(-radius, radius))
			position += random_offset
			break
	return position


func drop_item(item_data, drop_position):
	var item_scene = load(item_data["scene_path"])
	var item_instance = item_scene.instantiate()
	item_instance.set_item_data(item_data)
	drop_position = drop_position(drop_position)
	item_instance.global_position = drop_position
	get_tree().current_scene.add_child(item_instance)
