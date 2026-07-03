extends Control

@onready var wave_canvas: Control = $"Center/WaveCanvas-2_0"
@onready var frequancy: Label  = $"../../Player_wave/ColorRect2/Frequancy"
@onready var _visualizer = $"../../PuzzleWaveVisualizer"
@onready var _ding: AudioStreamPlayer = $"../../DingPlayer"

const FINE_STEP:   int = 10   # R1 / L1
const COARSE_STEP: int = 100  # R2 / L2

## The frequency the player must tune to, and how close (+/-) still counts.
@export var target_hz: int = 1000
@export var tolerance: int = 10

var _was_hit: bool = false

func _process(_delta: float) -> void:
	# Drive the visual wave from RadioGlobal.radio
	# Map 530->1700 Hz to wavelength 260->20 (higher freq = tighter wave)
	var wl := remap(RadioGlobal.radio, RadioGlobal.RADIO_MIN, RadioGlobal.RADIO_MAX, 260.0, 20.0)
	WaveCanvas20.wavelength = wl
	wave_canvas.wavelength  = wl
	wave_canvas.amplitude   = WaveCanvas20.amplitude

	# Show the real frequency
	frequancy.text = "%d Hz" % RadioGlobal.radio

	# Did the player just land on the required frequency? Fire once on entry.
	var hit: bool = abs(RadioGlobal.radio - target_hz) <= tolerance
	if hit and not _was_hit:
		_on_target_hit()
	_was_hit = hit

func _on_target_hit() -> void:
	# Play the sound on the analyzed bus, then flash the spectrum drawn from it.
	if _ding and _ding.stream:
		_ding.play()
	if _visualizer:
		_visualizer.burst()

# R1 / L1 -> fine tune +/-10 Hz
func _on_r_1_pressed() -> void:
	RadioGlobal.radio += FINE_STEP

func _on_l_1_pressed() -> void:
	RadioGlobal.radio -= FINE_STEP

# R2 / L2 -> coarse tune +/-100 Hz
func _on_r_2_pressed() -> void:
	RadioGlobal.radio += COARSE_STEP

func _on_l_2_pressed() -> void:
	RadioGlobal.radio -= COARSE_STEP
