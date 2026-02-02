class_name bgrd_node extends Node2D

@onready var bgrd_asset: Sprite2D = $Sprite2D
@onready var texture_pos = bgrd_asset.position

@onready var half_length: Vector2 = Vector2(bgrd_asset.texture.get_size().x / 2.0, 0)
@onready var half_height: Vector2 = Vector2(0, bgrd_asset.texture.get_size().y / 2.0)

@onready var right_limits: int = int(texture_pos.x + half_length.x)
@onready var bottom_limits :int = int(texture_pos.y + half_height.y)
@onready var left_limits: int = int(texture_pos.x - half_length.x)
@onready var top_limits: int = int(texture_pos.y - half_height.y)
