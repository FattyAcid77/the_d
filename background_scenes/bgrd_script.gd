class_name bgrd_node extends Node2D

@onready var bgrd_asset: Sprite2D = $Sprite2D
@onready var texture_pos = bgrd_asset.position

@onready var half_length: Vector2 = Vector2(bgrd_asset.texture.get_size().x / 2.0, 0)
@onready var half_height: Vector2 = Vector2(0, bgrd_asset.texture.get_size().y / 2.0)

@onready var right_limits: int = int(texture_pos.x + half_length.x)
@onready var bottom_limits :int = int(texture_pos.y + half_height.y)
@onready var left_limits: int = int(texture_pos.x - half_length.x)
@onready var top_limits: int = int(texture_pos.y - half_height.y)



#class_name bgrd_node extends Node2D
#
#@onready var main_sprite: Sprite2D = $Sprite2D
#
#@onready var sprite_pos:Vector2 = main_sprite.position
#
#@onready var texture_height = main_sprite.texture.get_height()
#@onready var texture_width = main_sprite.texture.get_width()
#
#@onready var half_height: int = (texture_height / 2.0)
#@onready var half_width: int = (texture_width / 2.0)
#
#var top_limit = int(sprite_pos.y) + half_height
#var right_limit = int(sprite_pos.x) + half_height
#var bot_limit = int(sprite_pos.y) - half_height
#var left_limit = int(sprite_pos.x) - half_height




#
#@export var map_bounds_data: MapBoundsData
#
#func _ready():
	#calculate_master_bounds()
#
#func calculate_master_bounds():
	#if not map_bounds_data:
		#push_error("MapBoundsData resource is missing from the level!")
		#return
	#var master_rect = Rect2()
	#var found_layers = false
#
	#for child in get_children():
		#if not child is TileMapLayer:
			#continue
		#if child.is_in_group("ignore_bounds"):
			#continue
		#var grid_rect: Rect2i = child.get_used_rect()
		#if grid_rect.size == Vector2i.ZERO:
			#continue
		#var tile_size: Vector2i = child.tile_set.tile_size
		## to_global converts tile-local coords → world coords,
		## accounting for this node's position in the parent scene.
		#var world_pos = child.to_global(Vector2(grid_rect.position * tile_size))
		#var world_size = Vector2(grid_rect.size * tile_size)
		#var layer_rect = Rect2(world_pos, world_size)
#
		#if not found_layers:
			#master_rect = layer_rect
			#found_layers = true
		#else:
			#master_rect = master_rect.merge(layer_rect)
#
	#if found_layers:
		#map_bounds_data.set_bounds(master_rect)
