### QuestItem.gd
# this will let us see the Texure while in the Edtior
@tool
extends Area2D

@onready var sprite_2d: Sprite2D = $Sprite2D

@export var item_id: String = ""
@export var item_name: String = ""
@export var item_amount: int = 1
@export var item_icon: Texture2D

func _ready() -> void:
	#this is using The @tool, to show us the Texure while still in the game running
	if not Engine.is_editor_hint():
		sprite_2d.texture = item_icon

func _process(delta: float) -> void:
	#this is using The @tool, to show us the Texure while still in the edtior and no need to run to check the sprite
	if Engine.is_editor_hint():
		sprite_2d.texture = item_icon

func start_interact():
	print("you picked in item")
