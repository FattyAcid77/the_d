extends Node2D

## A live, audio-reactive waveform. Now lives inside the radio.
## Call burst() to flash it on. It reads real sound off the PuzzleSFX
## audio bus, so whatever plays on that bus is what shapes the wave.

@export var wave_color: Color = Color(0.2, 1.0, 0.5)
@export var line_thickness: float = 2.0
@export var wave_width: float = 60.0
@export var wave_height: float = 12.0
@export var samples: int = 128
@export var min_freq: float = 80.0
@export var max_freq: float = 8000.0
@export var display_duration: float = 3.0

const BUS_NAME := "PuzzleSFX"

var _spectrum: AudioEffectSpectrumAnalyzerInstance
var _visible_timer: float = 0.0
var _smoothed: PackedFloat32Array

func _ready() -> void:
	modulate.a = 0.0
	z_index = 1
	_smoothed.resize(samples)
	_smoothed.fill(0.0)
	_ensure_bus()
	_try_get_spectrum()

## Flash the waveform on for `display_duration` seconds, then it fades out.
## Call this the instant the player hits the target frequency.
func burst() -> void:
	_visible_timer = display_duration
	if _spectrum == null:
		_try_get_spectrum()
	print("[PuzzleWaveVisualizer] burst() fired — spectrum ready: ", _spectrum != null)

func _ensure_bus() -> void:
	var idx := AudioServer.get_bus_index(BUS_NAME)
	if idx == -1:
		AudioServer.add_bus()
		idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, BUS_NAME)
		AudioServer.set_bus_send(idx, "Master")
	# Guarantee the bus carries a spectrum analyzer, even if it already existed.
	for i in AudioServer.get_bus_effect_count(idx):
		if AudioServer.get_bus_effect(idx, i) is AudioEffectSpectrumAnalyzer:
			return
	var effect := AudioEffectSpectrumAnalyzer.new()
	effect.buffer_length = 0.1
	AudioServer.add_bus_effect(idx, effect)

func _try_get_spectrum() -> void:
	var bus_idx := AudioServer.get_bus_index(BUS_NAME)
	if bus_idx == -1:
		return
	for i in AudioServer.get_bus_effect_count(bus_idx):
		if AudioServer.get_bus_effect(bus_idx, i) is AudioEffectSpectrumAnalyzer:
			_spectrum = AudioServer.get_bus_effect_instance(bus_idx, i)
			return

func _process(delta: float) -> void:
	if _visible_timer > 0.0:
		_visible_timer -= delta
		modulate.a = min(modulate.a + delta * 4.0, 1.0)
	else:
		modulate.a = move_toward(modulate.a, 0.0, delta * 2.0)

	if modulate.a > 0.0:
		_update_smoothed(delta)
		queue_redraw()

func _update_smoothed(delta: float) -> void:
	if _spectrum == null:
		for i in samples:
			_smoothed[i] = move_toward(_smoothed[i], 0.0, delta * 3.0)
		return

	for i in samples:
		var t: float = float(i) / samples
		var freq_lo: float = lerp(min_freq, max_freq, t)
		var freq_hi: float = lerp(min_freq, max_freq, t + 1.0 / samples)
		var mag: float = _spectrum.get_magnitude_for_frequency_range(
			freq_lo, freq_hi,
			AudioEffectSpectrumAnalyzerInstance.MAGNITUDE_MAX
		).length()
		var energy: float = clamp((log(mag) / log(10.0)) / 6.0 + 1.0, 0.0, 1.0)
		var speed: float = 12.0 if energy > _smoothed[i] else 4.0
		_smoothed[i] = move_toward(_smoothed[i], energy, delta * speed)

func _draw() -> void:
	var half_w: float = wave_width / 2.0
	var pts_top := PackedVector2Array()
	var pts_bot := PackedVector2Array()
	pts_top.resize(samples)
	pts_bot.resize(samples)

	for i in samples:
		var x: float = lerp(-half_w, half_w, float(i) / (samples - 1))
		var amp: float = _smoothed[i] * wave_height
		pts_top[i] = Vector2(x, -amp)
		pts_bot[i] = Vector2(x,  amp)

	draw_polyline(pts_top, wave_color, line_thickness, true)
	draw_polyline(pts_bot, wave_color, line_thickness, true)
	draw_line(Vector2(-half_w, 0), Vector2(half_w, 0), wave_color * Color(1, 1, 1, 0.2), 1.0)
