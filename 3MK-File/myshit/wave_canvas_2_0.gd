extends Control



@export var amplitude: float = 200
@export var wavelength: float = 150.0
@export var samples: int = 512

var phase: float = 0.0




func _process(delta):
	phase += delta * 1.5
	queue_redraw()

func _draw():
	var rect = get_rect()
	var mid_y = rect.size.y / 2.0

	var pts := PackedVector2Array()
	pts.resize(samples)

	for i in range(samples):
		var t = float(i) / (samples - 1)
		var x = t * rect.size.x

		var freq = amplitude / wavelength
		var ang = TAU * freq * t + phase
		var wrapped = fmod(ang, TAU)
		if wrapped < 0: wrapped += TAU

		var saw = (wrapped / TAU) * 2.0 - 1.0
		var y = mid_y - saw * amplitude

		pts[i] = Vector2(x, y)

	draw_polyline(pts, Color(1, 1, 1), 3.0, true)
