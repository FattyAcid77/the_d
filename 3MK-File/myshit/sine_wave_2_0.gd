extends Control


# References
@onready var wave_canvas: Control = $"Center/WaveCanvas-2_0"
@onready var frequancy: Label = $"../../Player_wave/ColorRect2/Frequancy"


const AMP_STEP = 10.0
const WL_STEP  = 10.0

func _process(_delta: float) -> void:
	# 1. SYNC VISUALIZER
	wave_canvas.amplitude = WaveCanvas20.amplitude
	wave_canvas.wavelength = WaveCanvas20.wavelength

	# 2. UPDATE LABELS
	if WaveCanvas20.wavelength != 0:
		# Create a "fake" radio frequency based on the wavelength. 
		# (e.g., 1000 / 10 = 100.0 Hz)
		var display_freq: float = 1000.0 / WaveCanvas20.wavelength
		
		# "%.1f" tells Godot to format the number with exactly 1 decimal point
		frequancy.text = "Hz: %.1f" % display_freq

# === BUTTONS UPDATE THE GLOBAL ===

func _on_r_1_pressed() -> void:
	WaveCanvas20.amplitude += AMP_STEP

func _on_r_2_pressed() -> void:
	WaveCanvas20.wavelength += WL_STEP

func _on_l_1_pressed() -> void:
	# Prevent amplitude from going completely flat
	WaveCanvas20.amplitude = max(10.0, WaveCanvas20.amplitude - AMP_STEP)

func _on_l_2_pressed() -> void:
	# Prevent wavelength from becoming 0 (which causes a crash when dividing!)
	WaveCanvas20.wavelength = max(20.0, WaveCanvas20.wavelength - WL_STEP)
