extends Control
@onready var grid_container: GridContainer = $GridContainer

var dragged_slot = null


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	inventory.Inventory_UI.connect(Inventory_updates)
	Inventory_updates()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass


func Inventory_updates():
	clear_grid()
	for item in inventory.inventory:
		var slot = inventory.invntory_slot.instantiate()
		slot.drag_start.connect(_on_drag_start)
		slot.drag_end.connect(_on_drag_end)
		grid_container.add_child(slot)
		if item != null:
			slot.set_item(item)
		else:
			slot.set_empty()
			
func clear_grid():
	while grid_container.get_child_count() > 0:
		var child = grid_container.get_child(0)
		grid_container.remove_child(child)
		child.queue_free()


func _on_drag_start(slot_control: Control):
	dragged_slot = slot_control
	print("Drag started from slot: ", dragged_slot)


func _on_drag_end():
	var target_slot = get_slot_under_mouse()
	if target_slot and dragged_slot != target_slot:
		drop_slot(dragged_slot, target_slot)
		dragged_slot = null



# Get the current mouse position in the grid_container's coordinates
func get_slot_under_mouse() -> Control:
	var mouse_position = get_global_mouse_position()
	for slot in grid_container.get_children():
		var slot_rect = Rect2(slot.global_position, slot.size)
		if slot_rect.has_point(mouse_position):
			return slot
	return null



func get_slot_index(slot: Control) -> int:
	for i in range(grid_container.get_child_count()):
		if grid_container.get_child(i) == slot:
			# Valid slot found
			return i
	# Invalid slot
	return -1

func drop_slot(slot1: Control, slot2: Control):
	var slot1_index = get_slot_index(slot1)
	var slot2_index = get_slot_index(slot2)
	if slot1_index == -1 or slot2_index == -1:
		print("Invalid slots found")
		return
	else:
		if inventory.swap_inventory_items(slot1_index, slot2_index):
			print("Dropping slot items: ", slot1, slot2_index)
			Inventory_updates()
