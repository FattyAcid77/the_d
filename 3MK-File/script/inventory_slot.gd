extends Control
@onready var item_icon: Sprite2D = $Item_Icon
@onready var item_quantity: Label = $Item_Quantity
@onready var details_panel: ColorRect = $Details_Panel
@onready var item_name: Label = $Details_Panel/Item_name
@onready var item_type: Label = $Details_Panel/Item_Type
@onready var item_effect: Label = $Details_Panel/Item_effect
@onready var usage_panel: ColorRect = $Usage_panel


var item = null
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_item_button_focus_entered() -> void:
	if item != null:
		usage_panel.visible = false
		details_panel.visible = true


func _on_item_button_focus_exited() -> void:
	details_panel.visible = false


func _on_item_button_mouse_entered() -> void:
	if item != null:
		usage_panel.visible = false
		details_panel.visible = true


func _on_item_button_mouse_exited() -> void:
	details_panel.visible = false


func set_empty():
	item_icon.texture = null
	item_quantity.text = ""

func set_item(new_item):
	item = new_item
	item_icon.texture = new_item["texture"]
	item_quantity.text = str(item["quantity"])
	item_name.text = str(item["name"])
	item_type.text = str(item["type"])
	if item["effect"] != "":
		item_effect.text = str(item["effect"])
	else:
		item_effect.text = ""


func _on_drop_button_pressed() -> void:
	if item != null:
		var drop_position = inventory.Player_ch.global_position
		var drop_offset = Vector2(0, 50)
		drop_offset = drop_offset.rotated(inventory.Player_ch.rotation)
		inventory.drop_item(item, drop_position + drop_offset)
		inventory.Remove_item(item["type"], item["effect"])
		usage_panel.visible = !usage_panel.visible

func _on_use_button_pressed() -> void:
	pass # Replace with function body.
