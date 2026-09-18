extends ColorRect
class_name WaveDisplayRegion

# --- PUZZLE DATA (Handed down by your Controller) ---
var amplitude: float = 200.0
var wavelength: float = 150.0

# --- MAX LIMITS (Set in Inspector) ---
@export var max_puzzle_amplitude: float = 200.0
@export var max_puzzle_wavelength: float = 500.0

# --- VISUALS ---
@export var line_thickness: float = 4.0
@export var scroll_speed: float = 50.0

var phase_offset: float = 0.0

func _process(delta: float) -> void:
	# Scroll the wave left smoothly
	phase_offset -= delta * scroll_speed 
	queue_redraw()

func _draw() -> void:
	# 1. The region calculates its own exact size
	var w = size.x
	var h = size.y
	var mid_y = h / 2.0

	# 2. Scale the puzzle numbers to fit exactly inside this region's box
	var amp_percent = clamp(amplitude / max_puzzle_amplitude, 0.0, 1.0)
	var display_amp = (mid_y - line_thickness) * amp_percent

	var wave_percent = clamp(wavelength / max_puzzle_wavelength, 0.01, 1.0)
	var display_wl = w * wave_percent

	# --- 3. DRAW PERFECT GEOMETRIC TEETH ---
	# wrapf guarantees the first tooth always starts just off-screen to the left. 
	# This completely fixes that weird "floating" broken line you saw!
	var start_x = wrapf(phase_offset, -display_wl, 0.0)

	var current_x = start_x

	# Keep drawing teeth until we hit the right side of the box
	while current_x < w + display_wl:
		# Calculate the bottom-left of the tooth
		var bottom_point = Vector2(current_x, mid_y + display_amp)
		# Calculate the top-right of the tooth
		var top_point = Vector2(current_x + display_wl, mid_y - display_amp)

		# Draw one solid diagonal line
		draw_line(bottom_point, top_point, Color.WHITE, line_thickness, true)

		# Move forward to draw the next tooth
		current_x += display_wl
