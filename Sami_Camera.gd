extends Camera2D

# Drag the EXACT SAME Resource file (.tres) here
@export var map_bounds_data: MapBoundsData

func _ready():
	if map_bounds_data:
		# Connect to the resource's signal
		map_bounds_data.bounds_updated.connect(_on_bounds_updated)
		
		# If the map loaded before the camera, apply bounds immediately
		if map_bounds_data.current_bounds != Rect2():
			_on_bounds_updated(map_bounds_data.current_bounds)

func _on_bounds_updated(new_bounds: Rect2):
	# Apply the merged bounding box to the camera limits
	limit_left = int(new_bounds.position.x)
	limit_top = int(new_bounds.position.y)
	limit_right = int(new_bounds.position.x + new_bounds.size.x)
	limit_bottom = int(new_bounds.position.y + new_bounds.size.y)
