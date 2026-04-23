extends Node2D


@export var map_bounds_data: MapBoundsData 

func _ready():
	calculate_master_bounds()

func calculate_master_bounds():
	if not map_bounds_data:
		push_error("MapBoundsData resource is missing from the level!")
		return

	var master_rect = Rect2()
	var found_layers = false

	
	for child in get_children():
		if child is TileMapLayer:
			
			var grid_rect: Rect2i = child.get_used_rect()
			var tile_size: Vector2i = child.tile_set.tile_size
			
			
			var world_pos = Vector2(grid_rect.position * tile_size)
			var world_size = Vector2(grid_rect.size * tile_size)
			var layer_rect = Rect2(world_pos, world_size)
			
			
			if not found_layers:
				master_rect = layer_rect
				found_layers = true
			else:
				master_rect = master_rect.merge(layer_rect)
	
	
	if found_layers:
		map_bounds_data.current_bounds = master_rect
