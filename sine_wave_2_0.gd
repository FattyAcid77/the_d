extends Control

# Reference to the local visualizer (just for drawing)
@onready var wave_canvas: Control = $"Center/WaveCanvas-2_0"

@onready var amp: Label = $"../../Player_wave/ColorRect4/AMP"
@onready var length: Label = $"../../Player_wave/ColorRect5/LENGTH"
@onready var frequancy: Label = $"../../Player_wave/ColorRect2/Frequancy"

const AMP_STEP = 10.0
const WL_STEP  = 15.0

func _process(delta):
	# 1. SYNC LOCAL VISUALIZER TO GLOBAL DATA
	# This ensures what you see matches what the Task checks
	wave_canvas.amplitude = WaveCanvas20.amplitude
	wave_canvas.wavelength = WaveCanvas20.wavelength

	# 2. UPDATE LABELS FROM GLOBAL DATA
	# Note: Use WaveCanvas20 here too
	if WaveCanvas20.wavelength != 0:
		var freq = WaveCanvas20.amplitude / WaveCanvas20.wavelength
		frequancy.text = "Hz: " + str(int(freq))
	
	amp.text = "Amp: " + str(int(WaveCanvas20.amplitude))
	length.text = "WL: " + str(int(WaveCanvas20.wavelength))

# === BUTTONS UPDATE THE GLOBAL (WaveCanvas20) ===

func _on_r_1_pressed() -> void:
	WaveCanvas20.amplitude += AMP_STEP

func _on_r_2_pressed() -> void:
	WaveCanvas20.wavelength += WL_STEP

func _on_l_1_pressed() -> void:
	WaveCanvas20.amplitude = max(10.0, WaveCanvas20.amplitude - AMP_STEP)

func _on_l_2_pressed() -> void:
	WaveCanvas20.wavelength = max(20.0, WaveCanvas20.wavelength - WL_STEP)
