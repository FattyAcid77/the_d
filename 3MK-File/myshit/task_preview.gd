extends Control

@export var task: Node = null
@export var wave_speed: float = 300.0
@export var samples: int = 512

var phase = 0.0
var red_color = Color(1, 0.2, 0.2, 1)

func _process(delta):
	phase += delta * 1.5
	queue_redraw()

func _draw():
	if not task:
		return

	var amp = task.target_amplitude
	var wl  = task.target_wavelength

	var r = get_rect()
	var mid_y = r.size.y / 2

	var pts := PackedVector2Array()
	pts.resize(samples)

	for i in range(samples):
		var t = float(i) / (samples - 1)
		var x = t * r.size.x

		var freq = wave_speed / wl
		var ang = TAU * freq * t + phase
		var wrapped = fmod(ang, TAU)
		if wrapped < 0: wrapped += TAU

		var saw = (wrapped / TAU) * 2.0 - 1.0
		var y = mid_y - saw * amp

		pts[i] = Vector2(x, y)

	draw_polyline(pts, red_color, 3, true)
