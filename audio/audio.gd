# Audio global script.
#
# One place to play music, UI sounds and positional sound effects from anywhere:
#   Audio.play_music(track)
#   Audio.ui_select()
#   Audio.play_spatial_sound(stream, global_position)
#
# Bus layout it expects (audio/default_bus_layout.tres):
#   Master
#   +- EffectPass  (reverb lives here)  -> Master
#   |   +- Music                        -> EffectPass
#   |   +- SFX                          -> EffectPass
#   |       +- PuzzleSFX                -> SFX     (the radio's bus)
#   +- UI                               -> Master
#
# UI deliberately bypasses EffectPass so menu clicks never get reverb on them.

extends Node

enum REVERB_TYPE { NONE, SMALL, MEDIUM, LARGE }

## Emitted when a sound the player caused is played. Anything that should react
## to noise (an enemy that hears you) can listen here instead of polling.
signal player_made_sound(pos: Vector2, volume: float)

const CONFIG_PATH := "user://settings.cfg"
const POOL_SIZE := 32

const DEFAULT_MASTER_VOLUME := 1.0
const DEFAULT_MUSIC_VOLUME := 0.8   # music mixes loud against everything else
const DEFAULT_SFX_VOLUME := 1.0
const DEFAULT_UI_VOLUME := 1.0

@export var ui_focus_audio: AudioStream
@export var ui_select_audio: AudioStream
@export var ui_cancel_audio: AudioStream
@export var ui_success_audio: AudioStream
@export var ui_error_audio: AudioStream

var current_track: int = 0
var music_tweens: Array[Tween] = []
var ui_audio_player: AudioStreamPlaybackPolyphonic
var audio_pool: Array[AudioStreamPlayer2D] = []
var audio_index: int = 0

# Bus indices looked up by name once, rather than hard-coded 1/2/3/4. Reordering
# the bus layout in the editor then can't silently send music out of the SFX
# slider — a bug that is invisible until someone drags a bus.
var _bus_master: int = -1
var _bus_effect: int = -1
var _bus_music: int = -1
var _bus_sfx: int = -1
var _bus_ui: int = -1

@onready var music_1: AudioStreamPlayer = %Music1
@onready var music_2: AudioStreamPlayer = %Music2
@onready var ui: AudioStreamPlayer = %UI


func _ready() -> void:
	_cache_bus_indices()

	# The polyphonic stream only hands out its playback object once it's running,
	# so start it immediately even though there's nothing queued yet.
	ui.play()
	ui_audio_player = ui.get_stream_playback()

	# Pre-made 2D players, reused round-robin. Cheaper than spawning a node per
	# sound, and it caps how many can ever be alive at once.
	for i in POOL_SIZE:
		var player := AudioStreamPlayer2D.new()
		add_child(player)
		player.bus = "SFX"
		audio_pool.append(player)

	load_settings()


func _cache_bus_indices() -> void:
	_bus_master = AudioServer.get_bus_index("Master")
	_bus_effect = AudioServer.get_bus_index("EffectPass")
	_bus_music = AudioServer.get_bus_index("Music")
	_bus_sfx = AudioServer.get_bus_index("SFX")
	_bus_ui = AudioServer.get_bus_index("UI")
	if _bus_music == -1 or _bus_sfx == -1 or _bus_ui == -1:
		push_warning("Audio: bus layout is missing named buses — check that " \
			+ "Project Settings > Audio > Default Bus Layout points at " \
			+ "res://audio/default_bus_layout.tres")


#region /// music

## Crossfades to a new track. Passing the track that's already playing is a
## no-op, so a level can call this on load without restarting its own music.
func play_music(audio: AudioStream) -> void:
	var current_player: AudioStreamPlayer = get_music_player(current_track)
	if current_player.stream == audio:
		return

	var next_track: int = wrapi(current_track + 1, 0, 2)
	var next_player: AudioStreamPlayer = get_music_player(next_track)

	next_player.stream = audio
	next_player.play()

	# Kill any fade still in flight. Without this, walking quickly between two
	# rooms leaves an old fade-out running, and its stop() callback lands after
	# the new track has already faded in — silence for no obvious reason.
	for t in music_tweens:
		t.kill()
	music_tweens.clear()

	fade_track_out(current_player)
	fade_track_in(next_player)

	current_track = next_track


func get_music_player(i: int) -> AudioStreamPlayer:
	return music_1 if i == 0 else music_2


func fade_track_out(player: AudioStreamPlayer) -> void:
	var tween: Tween = create_tween()
	music_tweens.append(tween)
	# slightly slower than the fade-in, so the two overlap rather than dipping
	tween.tween_property(player, "volume_linear", 0.0, 1.5)
	tween.tween_callback(player.stop)


func fade_track_in(player: AudioStreamPlayer) -> void:
	var tween: Tween = create_tween()
	music_tweens.append(tween)
	tween.tween_property(player, "volume_linear", 1.0, 1.0)

#endregion


#region /// reverb

## Swap the room tone. Sits on EffectPass, so it colours music and SFX but
## never the UI.
func set_reverb(type: REVERB_TYPE) -> void:
	if _bus_effect == -1:
		return
	var reverb_fx := AudioServer.get_bus_effect(_bus_effect, 0) as AudioEffectReverb
	if reverb_fx == null:
		return

	AudioServer.set_bus_effect_enabled(_bus_effect, 0, true)
	match type:
		REVERB_TYPE.NONE:
			AudioServer.set_bus_effect_enabled(_bus_effect, 0, false)
		REVERB_TYPE.SMALL:
			reverb_fx.room_size = 0.2
		REVERB_TYPE.MEDIUM:
			reverb_fx.room_size = 0.5
		REVERB_TYPE.LARGE:
			reverb_fx.room_size = 0.8

#endregion


#region /// spatial sound

## Play a sound at a world position, so it pans and falls off with distance.
## Set ignore_pool for something that must never be cut off by later sounds.
func play_spatial_sound(
		audio: AudioStream,
		pos: Vector2,
		ignore_pool: bool = false,
		was_player: bool = false,
		volume: float = 0.5) -> void:
	if ignore_pool:
		var ap := AudioStreamPlayer2D.new()
		add_child(ap)
		ap.bus = "SFX"
		ap.global_position = pos
		ap.stream = audio
		ap.finished.connect(ap.queue_free)
		ap.play()
	else:
		var ap: AudioStreamPlayer2D = audio_pool[audio_index]
		ap.global_position = pos
		ap.stream = audio
		ap.play()
		audio_index = wrapi(audio_index + 1, 0, POOL_SIZE)

	if was_player:
		player_made_sound.emit(pos, volume)

#endregion


#region /// ui audio

## Uses an AudioStreamPolyphonic, so several UI sounds can overlap. A plain
## AudioStreamPlayer would cut the previous sound every time the stream changed.
func play_ui_audio(audio: AudioStream) -> void:
	if ui_audio_player != null and audio != null:
		ui_audio_player.play_stream(audio)


## Wire every Button under a node to the standard click/focus sounds in one
## call, instead of connecting two signals per button by hand.
func setup_button_audio(node: Node) -> void:
	for c in node.find_children("*", "Button"):
		if not c.pressed.is_connected(ui_select):
			c.pressed.connect(ui_select)
		if not c.focus_entered.is_connected(ui_focus_change):
			c.focus_entered.connect(ui_focus_change)


func ui_focus_change() -> void:
	play_ui_audio(ui_focus_audio)


func ui_select() -> void:
	play_ui_audio(ui_select_audio)


func ui_cancel() -> void:
	play_ui_audio(ui_cancel_audio)


func ui_success() -> void:
	play_ui_audio(ui_success_audio)


func ui_error() -> void:
	play_ui_audio(ui_error_audio)

#endregion


#region /// settings persistence

func get_bus_volume(bus: int) -> float:
	return AudioServer.get_bus_volume_linear(bus) if bus != -1 else 1.0


func set_bus_volume(bus: int, value: float) -> void:
	if bus != -1:
		AudioServer.set_bus_volume_linear(bus, value)


## Master sits above all the others, so this one slider scales everything.
func master_bus() -> int: return _bus_master
func music_bus() -> int: return _bus_music
func sfx_bus() -> int: return _bus_sfx
func ui_bus() -> int: return _bus_ui


func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "master", get_bus_volume(_bus_master))
	config.set_value("audio", "music", get_bus_volume(_bus_music))
	config.set_value("audio", "sfx", get_bus_volume(_bus_sfx))
	config.set_value("audio", "ui", get_bus_volume(_bus_ui))
	config.save(CONFIG_PATH)


func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(CONFIG_PATH) != OK:
		# First run. Apply the defaults and write them out, so the file always
		# exists afterwards and the settings screen has something to read.
		_apply_volumes(DEFAULT_MASTER_VOLUME, DEFAULT_MUSIC_VOLUME,
			DEFAULT_SFX_VOLUME, DEFAULT_UI_VOLUME)
		save_settings()
		return

	_apply_volumes(
		config.get_value("audio", "master", DEFAULT_MASTER_VOLUME),
		config.get_value("audio", "music", DEFAULT_MUSIC_VOLUME),
		config.get_value("audio", "sfx", DEFAULT_SFX_VOLUME),
		config.get_value("audio", "ui", DEFAULT_UI_VOLUME))


func _apply_volumes(master: float, music: float, sfx: float, ui_vol: float) -> void:
	set_bus_volume(_bus_master, master)
	set_bus_volume(_bus_music, music)
	set_bus_volume(_bus_sfx, sfx)
	set_bus_volume(_bus_ui, ui_vol)

#endregion
