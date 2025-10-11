extends Control


@onready var r_1: Button = $R1
@onready var l_1: Button = $L1
@onready var r_2: Button = $R2
@onready var l_2: Button = $L2

@onready var wave_canvas: Control = $Center/WaveCanvas

# Gamepad increments
const AMP_STEP: float = 10.0
const FREQ_STEP: float = 0.1

func _ready() -> void:
	# Optional: tell user controls in Output
	pass

func _process(delta: float) -> void:
	_handle_input()

func _handle_input() -> void:
	# R1 increases amplitude
	if Input.is_action_just_pressed("Amp_U"):
		wave_canvas.amplitude += AMP_STEP

	# L1 decreases amplitude
	if Input.is_action_just_pressed("Amp_D"):
		wave_canvas.amplitude = max(0.0, wave_canvas.amplitude - AMP_STEP)

	# R2 increases wavelength → means lower frequency
	if Input.is_action_just_pressed("Freq_U"):
		wave_canvas.frequency = max(0.1, wave_canvas.frequency - FREQ_STEP)

	# L2 decreases wavelength → higher frequency
	if Input.is_action_just_pressed("Freq_D"):
		wave_canvas.frequency += FREQ_STEP


func _on_r_1_pressed() -> void:
	wave_canvas.amplitude += AMP_STEP


func _on_l_1_pressed() -> void:
	wave_canvas.amplitude = max(0.0, wave_canvas.amplitude - AMP_STEP)


func _on_r_2_pressed() -> void:
	wave_canvas.frequency = max(0.1, wave_canvas.frequency - FREQ_STEP)


func _on_l_2_pressed() -> void:
	wave_canvas.frequency += FREQ_STEP
