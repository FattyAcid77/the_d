class_name MapBoundsData 
extends Resource

# We emit this signal whenever a new map calculates its bounds
signal bounds_updated(new_bounds: Rect2)

@export var current_bounds: Rect2 :
	set(value):
		current_bounds = value
		# Automatically tell anything listening (the camera) that the bounds changed
		bounds_updated.emit(current_bounds)
