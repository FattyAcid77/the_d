extends Control

# --- CONFIGURATION ---
# Set these to the MAX values the player can reach in your puzzle
@export var max_puzzle_amp: float = 200.0
@export var max_puzzle_wl: float = 500.0

@export var line_thickness: float = 2.0
@export var scroll_speed: float = 80.0

var phase: float = 0.0

func _process(delta: float) -> void:
	phase += delta * scroll_speed
	queue_redraw()

func _draw() -> void:
	# 1. Get the physical size of this node in pixels
	var w = size.x
	var h = size.y
	var mid_y = h / 2.0

	# 2. CALCULATE ACCURATE VISUAL SCALING
	# We take the Global values and turn them into a 0.0 - 1.0 percentage
	var amp_ratio = clamp(WaveCanvas20.amplitude / max_puzzle_amp, 0.0, 1.0)
	var wl_ratio = clamp(WaveCanvas20.wavelength / max_puzzle_wl, 0.1, 1.0)

	# Convert that percentage into actual pixels that fit THIS screen
	var visual_amplitude = (mid_y - line_thickness) * amp_ratio
	var visual_wavelength = w * wl_ratio

	# 3. DRAW THE WAVE (Continuous Sawtooth)
	var points = PackedVector2Array()
	# We draw one point per pixel of the node's width for perfect accuracy
	points.resize(int(w))

	for x in range(int(w)):
		# Pure math: (Distance + Scroll) modulo Wavelength
		var progress = fmod(x + phase, visual_wavelength) / visual_wavelength
		var saw = (progress * 2.0) - 1.0
		
		var y = mid_y - (saw * visual_amplitude)
		points[x] = Vector2(x, y)

	draw_polyline(points, Color.WHITE, line_thickness, true)
