extends Control

# Increase this number to make your peaks as high as you want!
@export var amplitude: float = 200.0 
@export var wavelength: float = 150.0
@export var samples: int = 512
@export var line_thickness: float = 3.0

var phase_offset: float = 0.0

func _process(delta: float) -> void:
	# Controls scroll speed. 50.0 means 50 pixels per second.
	phase_offset += delta * 50.0 
	queue_redraw()

func _draw() -> void:
	var box_size = get_size()
	var mid_y = box_size.y / 2.0

	var pts := PackedVector2Array()
	pts.resize(samples)

	for i in range(samples):
		# 1. Exact X pixel position
		var x = (float(i) / (samples - 1)) * box_size.x
		
		# 2. Perfect distance-based modulo math for the sawtooth
		var decimal_progress = fmod(x + phase_offset, wavelength) / wavelength
		var saw = (decimal_progress * 2.0) - 1.0
		
		# 3. Apply the raw amplitude directly to the Y axis (NO CLAMPING)
		var y = mid_y - (saw * amplitude)

		pts[i] = Vector2(x, y)

	draw_polyline(pts, Color.WHITE, line_thickness, true)
