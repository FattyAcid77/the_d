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
		if not child is TileMapLayer:
			continue
		if child.is_in_group("ignore_bounds"):
			continue
		var grid_rect: Rect2i = child.get_used_rect()
		if grid_rect.size == Vector2i.ZERO:
			continue
		var tile_size: Vector2i = child.tile_set.tile_size
		# to_global converts tile-local coords → world coords,
		# accounting for this node's position in the parent scene.
		var world_pos = child.to_global(Vector2(grid_rect.position * tile_size))
		var world_size = Vector2(grid_rect.size * tile_size)
		var layer_rect = Rect2(world_pos, world_size)

		if not found_layers:
			master_rect = layer_rect
			found_layers = true
		else:
			master_rect = master_rect.merge(layer_rect)

	if found_layers:
		map_bounds_data.set_bounds(master_rect)
