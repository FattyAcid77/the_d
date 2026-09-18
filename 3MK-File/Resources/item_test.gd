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




var scene_2_path : String = "res://3MK-File/Resources/item.tscn"

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if not Engine.is_editor_hint():
		icon.texture = item_config.icon
		
		# FIX: Force check if Sami is already overlapping us when we spawn!
		for body in get_overlapping_bodies():
			if _is_player(body):
				player_range = true


# was a hardcoded `body.name == "Sami"`, which failed in every level where the
# player node is named something else (Sami_Doctor_test). All player scenes are
# in the "Player" group, so match on that instead
func _is_player(body: Node) -> bool:
	return body.is_in_group("Player") or body is Player or body is Sami


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
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
		"texture": item_config.icon,
		"heal_amount": item_config.heal_amount # <-- Add it to the dictionary!
	}
	
	if inventory.Player_ch != null:
		inventory.add_item(item)
		self.queue_free()
	else:
		print("ERROR: Could not pick up! Player_ch is null in the Global inventory!")

func _on_body_entered(body: Node2D) -> void:
	if _is_player(body):
		player_range = true


func _on_body_exited(body: Node2D) -> void:
	if _is_player(body):
		player_range = false


func set_item_data(data):
	item_type = data["type"]
	item_name = data["name"]
	item_effect = data["effect"]
	item_texture = data["texture"]
	if icon != null:
		icon.texture = data["texture"]
	if item_config != null: 
		item_config = item_config.duplicate() 
		item_config.item_name = data["name"]
		item_config.item_type = data["type"]
		item_config.item_effect = data["effect"]
		item_config.icon = data["texture"]
		if data.has("heal_amount"):
			item_config.heal_amount = data["heal_amount"]
	if item_config != null: 
		item_config.item_name = data["name"]
		item_config.item_type = data["type"]
		item_config.item_effect = data["effect"]
		item_config.icon = data["texture"]
