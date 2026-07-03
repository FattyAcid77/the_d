extends Node

## Plays a sound when the player enters a puzzle.
## Also sets up a "PuzzleSFX" audio bus with a SpectrumAnalyzer
## so puzzle_wave_visualizer.gd can read real frequency data.

@export var enter_sound: AudioStream
@export var use_positional_audio: bool = false

const BUS_NAME := "PuzzleSFX"

var _player: Node

func _ready() -> void:
	_setup_bus()
	if use_positional_audio:
		_player = AudioStreamPlayer2D.new()
	else:
		_player = AudioStreamPlayer.new()
	_player.bus = BUS_NAME
	add_child(_player)
	GameState.puzzle_entered.connect(_on_puzzle_entered)

func _setup_bus() -> void:
	if AudioServer.get_bus_index(BUS_NAME) != -1:
		return
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, BUS_NAME)
	AudioServer.set_bus_send(idx, "Master")
	var effect := AudioEffectSpectrumAnalyzer.new()
	effect.buffer_length = 0.1
	AudioServer.add_bus_effect(idx, effect)

func _on_puzzle_entered(_puzzle_id: String, _puzzle_name: String) -> void:
	if enter_sound:
		_player.stream = enter_sound
		_player.play()
