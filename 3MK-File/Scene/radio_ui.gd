extends Control
@onready var AP: AnimationPlayer = $AnimationPlayer

@onready var frequancy_label: Label = $Radio_txt/Frequancy

# --- Visual config ---
@export var samples: int = 512
@export var line_thickness: float = 3.0
@export var scroll_speed: float = 50.0

# --- Tuning steps ---
const FINE_STEP:   int = 10   # Freq_U / Freq_D
const COARSE_STEP: int = 100  # Amp_U  / Amp_D

# --- Display range mapping (for the visual wave) ---
@export var max_visual_wavelength: float = 80.0
@export var min_visual_wavelength: float = 10.0
@export var visual_amplitude: float = 80.0
@export var idle_wave_scale: float = 0.3   # wave size with no quest signal around

var phase_offset: float = 0.0

func _process(delta: float) -> void:
	# Fine tune
	if Input.is_action_just_pressed("Freq_U"):
		RadioGlobal.radio += FINE_STEP
		AP.play("wl")
	elif Input.is_action_just_pressed("Freq_D"):
		RadioGlobal.radio -= FINE_STEP
		AP.play_backwards("wl")

	# Coarse tune
	if Input.is_action_just_pressed("Amp_U"):
		RadioGlobal.radio += COARSE_STEP
		AP.play("amp")
	elif Input.is_action_just_pressed("Amp_D"):
		RadioGlobal.radio -= COARSE_STEP
		AP.play_backwards("amp")

	# Freeze the knob the moment the key is released
	if Input.is_action_just_released("Freq_U") or Input.is_action_just_released("Freq_D"):
		if AP.current_animation == "wl":
			AP.pause()
	if Input.is_action_just_released("Amp_U") or Input.is_action_just_released("Amp_D"):
		if AP.current_animation == "amp":
			AP.pause()

	# Derive the visual wave from the radio value
	var wl := remap(RadioGlobal.radio,
		RadioGlobal.RADIO_MIN, RadioGlobal.RADIO_MAX,
		max_visual_wavelength, min_visual_wavelength)
	WaveCanvas20.wavelength = wl
	# quest signal strength grows the wave as the player gets closer
	WaveCanvas20.amplitude  = visual_amplitude * lerpf(idle_wave_scale, 1.0, RadioSignals.display_strength)

	# Label. goes green while the dial sits on a side quest signal
	if frequancy_label != null:
		frequancy_label.text = "%d Hz" % RadioGlobal.radio
		frequancy_label.modulate = Color(0.4, 1.0, 0.5) if RadioSignals.side_locked else Color.WHITE

	phase_offset += delta * scroll_speed
	queue_redraw()

func _draw() -> void:
	var box_size = get_size()
	var mid_y = box_size.y / 2.0

	var amp_percent = clamp(WaveCanvas20.amplitude / 200.0, 0.0, 1.0)
	var display_amp = (mid_y - line_thickness) * amp_percent

	var wave_percent = clamp(WaveCanvas20.wavelength / max_visual_wavelength, 0.01, 1.0)
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
