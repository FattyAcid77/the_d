extends Control

@onready var wave_canvas = $WaveCanvas
@export var task_data: Node = null  # Loaded externally

const AMP_STEP = 10.0
const WL_STEP  = 15.0

func _ready():
	if task_data:
		wave_canvas.amplitude = task_data.target_amplitude
		wave_canvas.wavelength = task_data.target_wavelength

func _process(delta):
	if Input.is_action_just_pressed("Amp_U"):
		wave_canvas.amplitude += AMP_STEP

	if Input.is_action_just_pressed("Amp_D"):
		wave_canvas.amplitude = max(10, wave_canvas.amplitude - AMP_STEP)

	if Input.is_action_just_pressed("Freq_U"):
		wave_canvas.wavelength += WL_STEP

	if Input.is_action_just_pressed("Freq_D"):
		wave_canvas.wavelength = max(20, wave_canvas.wavelength - WL_STEP)
