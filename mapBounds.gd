extends Resource
class_name MapBoundsData

signal bounds_updated(new_bounds: Rect2)

@export var current_bounds: Rect2 = Rect2()

func set_bounds(new_bounds: Rect2) -> void:
	current_bounds = new_bounds
	bounds_updated.emit(new_bounds)
