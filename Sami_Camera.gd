extends Camera2D
# Drag the EXACT SAME Resource file (.tres) here
@export var map_bounds_data: MapBoundsData
@export var Map_Multiplayer: float = 0.04
func _ready():
	limit_smoothed = false  # hard clamp, no easing past the edge
	
	if map_bounds_data:
		map_bounds_data.bounds_updated.connect(_on_bounds_updated)
		
		if map_bounds_data.current_bounds.size != Vector2.ZERO:
			_on_bounds_updated(map_bounds_data.current_bounds)

func _on_bounds_updated(new_bounds: Rect2):
	# Expand limits outward by half the viewport so the camera can roam the
	# full room. Void may be visible at edges, which is intentional.
	var half_view: Vector2 = get_viewport_rect().size / zoom * Map_Multiplayer

	limit_left   = int(new_bounds.position.x - half_view.x)
	limit_top    = int(new_bounds.position.y - half_view.y)
	limit_right  = int(new_bounds.position.x + new_bounds.size.x + half_view.x)
	limit_bottom = int(new_bounds.position.y + new_bounds.size.y + half_view.y)

	reset_smoothing()
