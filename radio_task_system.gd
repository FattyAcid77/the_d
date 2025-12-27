extends Node

@export var target_amplitude: float = 120.0
@export var target_wavelength: float = 180.0

@export var min_amp: float = 40.0
@export var max_amp: float = 160.0
@export var min_wl: float = 80.0
@export var max_wl: float = 260.0

func generate_task():
	target_amplitude = randf_range(min_amp, max_amp)
	target_wavelength = randf_range(min_wl, max_wl)

func is_match(player_amp: float, player_wl: float) -> bool:
	return abs(player_amp - target_amplitude) <= 10.0 and \
		   abs(player_wl - target_wavelength) <= 10.0
