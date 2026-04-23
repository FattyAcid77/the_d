extends Control
@onready var AP: AnimationPlayer = $AnimationPlayer

# --- NODE REFERENCES ---
@onready var frequancy_label: Label = $Radio_txt/Frequancy

# --- 1. YOUR PUZZLE LIMITS ---
@export var max_puzzle_amplitude: float = 200.0
@export var max_puzzle_wavelength: float = 500.0

# --- 2. VISUAL CONFIGURATION ---
@export var samples: int = 512
@export var line_thickness: float = 3.0
@export var scroll_speed: float = 50.0 
@export var STEP_SPEED: float = 100.0 # Tuning speed

var phase_offset: float = 0.0

func _process(delta: float) -> void:
	# --- 1. AMPLITUDE INPUT & ANIMATION ---
	var is_amp_moving = false
	
	# Only allow Up if we haven't hit the max limit
	if Input.is_action_pressed("Amp_U") and WaveCanvas20.amplitude < max_puzzle_amplitude:
		WaveCanvas20.amplitude += STEP_SPEED * delta
		AP.play("amp")
		is_amp_moving = true
		
	# Only allow Down if we haven't hit the floor (0.0)
	elif Input.is_action_pressed("Amp_D") and WaveCanvas20.amplitude > 0.0:
		WaveCanvas20.amplitude -= STEP_SPEED * delta
		AP.play_backwards("amp")
		is_amp_moving = true

	# --- 2. WAVELENGTH INPUT & ANIMATION ---
	var is_wl_moving = false
	
	# Only allow Down (wider) if we haven't hit the max limit
	if Input.is_action_pressed("Freq_D") and WaveCanvas20.wavelength < max_puzzle_wavelength:
		WaveCanvas20.wavelength += STEP_SPEED * delta
		AP.play_backwards("wl")
		is_wl_moving = true
		
	# Only allow Up (narrower) if we haven't hit the floor (10.0)
	elif Input.is_action_pressed("Freq_U") and WaveCanvas20.wavelength > 10.0:
		WaveCanvas20.wavelength -= STEP_SPEED * delta
		AP.play("wl")
		is_wl_moving = true

	# --- 3. FREEZE KNOBS WHEN KEYS ARE RELEASED (OR WHEN LIMIT IS HIT!) ---
	# If we hit a limit, the code above skips, these remain false, and the knob freezes perfectly.
	if not is_amp_moving and AP.current_animation == "amp":
		AP.pause()
	if not is_wl_moving and AP.current_animation == "wl":
		AP.pause()

	# --- 4. CLAMP THE GLOBAL LIMITS DIRECTLY ---
	# (Safety net to ensure delta math doesn't push us 0.001 over the line)
	WaveCanvas20.amplitude = clamp(WaveCanvas20.amplitude, 0.0, max_puzzle_amplitude)
	WaveCanvas20.wavelength = clamp(WaveCanvas20.wavelength, 10.0, max_puzzle_wavelength) 

	# --- 5. UPDATE THE LABEL ---
	if frequancy_label != null and WaveCanvas20.wavelength > 0:
		var hz = (WaveCanvas20.amplitude / WaveCanvas20.wavelength) * 10.0
		frequancy_label.text = "KHz: %.1f" % hz

	# --- 6. SCROLLING ---
	phase_offset += delta * scroll_speed 
	queue_redraw()

func _draw() -> void:
	var box_size = get_size()
	var mid_y = box_size.y / 2.0

	# --- ALL MATH NOW USES THE GLOBAL AUTOLOAD EXCLUSIVELY ---
	var amp_percent = clamp(WaveCanvas20.amplitude / max_puzzle_amplitude, 0.0, 1.0)
	var display_amp = (mid_y - line_thickness) * amp_percent

	var wave_percent = clamp(WaveCanvas20.wavelength / max_puzzle_wavelength, 0.01, 1.0)
	var display_wavelength = box_size.x * wave_percent

	var line_segments := PackedVector2Array()
	var prev_x = 0.0
	var prev_y = 0.0
	var is_first_point = true

	for i in range(samples):
		var x = (float(i) / (samples - 1)) * box_size.x
		
		var decimal_progress = fmod(x + phase_offset, display_wavelength) / display_wavelength
		var saw = (decimal_progress * 2.0) - 1.0
		
		var y = mid_y - (saw * display_amp)

		if not is_first_point:
			if abs(y - prev_y) > display_amp:
				pass 
			else:
				line_segments.append(Vector2(prev_x, prev_y))
				line_segments.append(Vector2(x, y))

		prev_x = x
		prev_y = y
		is_first_point = false

	draw_multiline(line_segments, Color.WHITE, line_thickness, false)
