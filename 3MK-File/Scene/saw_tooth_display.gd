extends Control
class_name SawtoothDisplay

# 1. YOUR PUZZLE NUMBERS (The ones the player changes)
var amplitude: float = 200.0
var wavelength: float = 150.0

# 2. YOUR PUZZLE LIMITS (Set these in the Inspector!)
# Tell the script what the MAXIMUM possible numbers are for your puzzle.
@export var max_puzzle_amplitude: float = 200.0
@export var max_puzzle_wavelength: float = 500.0

@export var samples: int = 512
@export var line_thickness: float = 3.0
@export var scroll_speed: float = 50.0 

var phase_offset: float = 0.0

func _process(delta: float) -> void:
	phase_offset += delta * scroll_speed 
	queue_redraw()

func _draw() -> void:
	# Get the exact physical pixel size of whatever UI box this is inside
	var box_size = get_size()
	var mid_y = box_size.y / 2.0

	# --- AUTOMATIC HEIGHT CALCULATION ---
	# Find out what percentage the current amplitude is compared to the maximum.
	var amp_percent = clamp(amplitude / max_puzzle_amplitude, 0.0, 1.0)
	# Apply that percentage to the physical height of the screen (minus line thickness for safety)
	var display_amp = (mid_y - line_thickness) * amp_percent

	# --- AUTOMATIC MULTIPLE-TOOTH (WIDTH) CALCULATION ---
	# Map the puzzle wavelength to a percentage of the screen width.
	# This guarantees you will always see multiple teeth, no matter how small the screen is!
	var wave_percent = clamp(wavelength / max_puzzle_wavelength, 0.01, 1.0)
	var display_wavelength = box_size.x * wave_percent

	var line_segments := PackedVector2Array()
	var prev_x = 0.0
	var prev_y = 0.0
	var is_first_point = true

	for i in range(samples):
		var x = (float(i) / (samples - 1)) * box_size.x
		
		# We now use the automatically calculated 'display_wavelength'
		var decimal_progress = fmod(x + phase_offset, display_wavelength) / display_wavelength
		var saw = (decimal_progress * 2.0) - 1.0
		
		# We now use the automatically calculated 'display_amp'
		var y = mid_y - (saw * display_amp)

		if not is_first_point:
			# Sever the ugly vertical pillar
			if abs(y - prev_y) > display_amp:
				pass 
			else:
				line_segments.append(Vector2(prev_x, prev_y))
				line_segments.append(Vector2(x, y))

		prev_x = x
		prev_y = y
		is_first_point = false

	draw_multiline(line_segments, Color.WHITE, line_thickness, false)
