extends Control

@export var amplitude: float = 120.0
@export var frequency: float = 1.0
@export var phase_radians: float = 0.0
@export var offset_y: float = 0.0
@export var speed_rps: float = 1.5
@export var samples: int = 512

var axis_color: Color = Color(0.9, 0.9, 0.95, 0.35)
var wave_color: Color = Color(0.95, 0.95, 0.95, 1.0)
var wave_width: float = 3.0

func _process(delta: float) -> void:
	phase_radians += speed_rps * delta
	queue_redraw()

func _draw() -> void:
	var r: Rect2 = get_rect()
	var w: float = r.size.x
	var h: float = r.size.y
	var mid_y: float = h * 0.5

	# Axis centered in this Control's rect
	draw_line(Vector2(0, mid_y), Vector2(w, mid_y), axis_color, 2.0, true)

	# Sawtooth wave fully inside this rect
	var pts := PackedVector2Array()
	pts.resize(samples)
	var x0: float = 0.0
	var x1: float = w

	var safe_amp: float = min(amplitude, (h * 0.5) - 2.0)

	for i in range(samples):
		var t: float = float(i) / max(1.0, float(samples - 1))
		var x: float = lerp(x0, x1, t)

		# Calculate the angle (phase)
		var ang: float = TAU * frequency * t + phase_radians

		# 1. Normalize the phase/angle to the range [0, TAU] (one full cycle)
		# fmod(a, b) computes the remainder of a / b.
		var wrapped_phase: float = fmod(ang, TAU)
		if wrapped_phase < 0:
			wrapped_phase += TAU # Ensure the result is non-negative

		# 2. Scale this wrapped phase from [0, TAU] to [-1, 1] for the wave amplitude
		# ((wrapped_phase / TAU) * 2.0) is in [0, 2]
		# ((wrapped_phase / TAU) * 2.0) - 1.0 is the normalized sawtooth value in [-1, 1]
		var sawtooth_value: float = ((wrapped_phase / TAU) * 2.0) - 1.0

		# 3. Apply the sawtooth value to the y-coordinate
		var y: float = mid_y + offset_y - sawtooth_value * safe_amp
		
		pts[i] = Vector2(x, y)

	draw_polyline(pts, wave_color, wave_width, true)
