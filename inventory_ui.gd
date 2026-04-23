extends Control
@onready var grid_container: GridContainer = $GridContainer


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	inventory.Inventory_UI.connect(Inventory_updates)
	Inventory_updates()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func Inventory_updates():
	clear_grid()
	for item in inventory.inventory:
		var slot = inventory.invntory_slot.instantiate()
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
