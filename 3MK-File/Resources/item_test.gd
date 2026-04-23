@tool

extends Area2D



var item_type: String
var item_name: String
var item_effect: String
var item_texture: Texture2D


var player_range: bool

@export_category("Item_data")
@export var item_config: Item_confg 


@onready var icon: Sprite2D = $Sprite2D



var scene_2_path : String = "res://3MK-File/Scene/inventory.tscn"

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if not Engine.is_editor_hint():
		icon.texture = item_config.icon


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		icon.texture = item_config.icon
	if player_range and Input.is_action_just_pressed("action"):
		pickable()
		print("worked!")


func pickable():
	var item = {
		"quantity": 1,
		"type": item_config.item_type,
		"effect": item_config.item_effect,
		"name": item_config.item_name,
		"scene_path": scene_2_path,
		"texture": item_config.icon
	}
	
	if inventory.Player_ch != null:
		inventory.add_item(item)
		self.queue_free()
	else:
		print("ERROR: Could not pick up! Player_ch is null in the Global inventory!")

func _on_body_entered(body: Node2D) -> void:
	if body.name == "Sami":
		player_range = true


func _on_body_exited(body: Node2D) -> void:
	if body.name == "Sami":
		player_range = false


func set_item_data(data):
	item_type = data["type"]
	item_name = data["name"]
	item_effect = data["effect"]
	item_texture = data["texture"]
