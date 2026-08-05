extends Node

# watches every QuestSignal beacon and turns the strongest one into radio
# behavior: soundwave hum + wave size from distance, auto-open on MAIN,
# tune-the-dial-to-catch on SIDE. radio_ui reads display_strength/side_locked.

signal side_signal_caught(frequency: int)

const SOUNDWAVE := preload("res://3MK-File/soundwave.ogg")
# preload instead of the QuestSignal class_name — autoloads parse before the
# editor rebuilds the global class cache, so the name may not resolve here
const QSig := preload("res://3MK-File/script/quest_signal.gd")
const BUS_NAME := "PuzzleSFX"

# side signals: full strength inside FULL, fades out completely at EDGE
const BAND_FULL: float = 30.0
const BAND_EDGE: float = 90.0

var display_strength: float = 0.0   # 0..1, radio_ui scales the wave with this
var side_locked: bool = false       # true while the dial sits on a side quest

var _hum: AudioStreamPlayer
var _was_in_main_range: bool = false
var _auto_opened: bool = false
var _caught: Dictionary = {}   # frequency → true, sticks for the whole session


func _ready() -> void:
	_ensure_bus()
	_hum = AudioStreamPlayer.new()
	_hum.stream = SOUNDWAVE
	_hum.bus = BUS_NAME
	_hum.finished.connect(_hum.play)   # loop
	add_child(_hum)


func _process(_delta: float) -> void:
	side_locked = false
	var player := get_tree().get_first_node_in_group("Player")
	var panel := get_tree().get_first_node_in_group("radio_panel")
	if player == null:
		_was_in_main_range = false
		_set_strength(0.0)
		return

	var pos: Vector2 = player.global_position
	var main_sig: Node2D = _active_main()
	var main_strength: float = main_sig.strength_at(pos) if main_sig != null else 0.0

	# the radio wakes itself when the active main quest comes in range, and
	# puts itself away again when the signal is gone. edge-triggered so the
	# player can still close it with Q without it fighting back.
	var in_range: bool = main_strength > 0.0
	if panel != null:
		if in_range and not _was_in_main_range and not panel.is_on():
			panel.set_radio_on(true)
			_auto_opened = true
		elif not in_range and _auto_opened:
			if panel.is_on():
				panel.set_radio_on(false)
			_auto_opened = false
	_was_in_main_range = in_range

	# no radio, no signal
	if panel == null or not panel.is_on():
		_set_strength(0.0)
		return

	# side quests never announce themselves — only audible when the dial is close
	var side_strength: float = 0.0
	for s in get_tree().get_nodes_in_group("quest_signal"):
		if s.quest_type != QSig.Type.SIDE or GameState.is_solved(s.puzzle_id):
			continue
		if _caught.get(s.frequency, false):
			continue   # caught signals go quiet — that's the player's feedback
		var audible: float = s.strength_at(pos) * _tuning_match(s.frequency)
		side_strength = maxf(side_strength, audible)
		if audible > 0.0 and absf(RadioGlobal.radio - s.frequency) <= BAND_FULL:
			side_locked = true
			_caught[s.frequency] = true
			side_signal_caught.emit(s.frequency)

	_set_strength(maxf(main_strength, side_strength))


# only the lowest-order unfinished MAIN broadcasts, so quest 2 stays silent
# until quest 1 is done
func _active_main() -> Node2D:
	var best: Node2D = null
	for s in get_tree().get_nodes_in_group("quest_signal"):
		if s.quest_type != QSig.Type.MAIN or GameState.is_solved(s.puzzle_id):
			continue
		if best == null or s.order < best.order:
			best = s
	return best


# mirrors check this on ready so a caught signal survives scene reloads
func is_caught(freq: int) -> bool:
	return _caught.get(freq, false)


func _tuning_match(freq: int) -> float:
	var diff: float = absf(RadioGlobal.radio - freq)
	if diff <= BAND_FULL:
		return 1.0
	if diff >= BAND_EDGE:
		return 0.0
	return 1.0 - (diff - BAND_FULL) / (BAND_EDGE - BAND_FULL)


func _set_strength(s: float) -> void:
	display_strength = s
	if s <= 0.0:
		if _hum.playing:
			_hum.stop()
		return
	_hum.volume_db = linear_to_db(clampf(s, 0.001, 1.0))
	if not _hum.playing:
		_hum.play()


# same idempotent setup as puzzle_wave_visualizer, so whichever loads first wins
func _ensure_bus() -> void:
	var idx := AudioServer.get_bus_index(BUS_NAME)
	if idx == -1:
		AudioServer.add_bus()
		idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, BUS_NAME)
		AudioServer.set_bus_send(idx, "Master")
	for i in AudioServer.get_bus_effect_count(idx):
		if AudioServer.get_bus_effect(idx, i) is AudioEffectSpectrumAnalyzer:
			return
	var effect := AudioEffectSpectrumAnalyzer.new()
	effect.buffer_length = 0.1
	AudioServer.add_bus_effect(idx, effect)
