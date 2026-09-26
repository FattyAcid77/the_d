class_name MenuRadio extends Node
## The radio on the menu table. Pressing it switches it on and off, the knobs
## step through the stations. A station the player hasn't heard in game yet
## plays static, so they know there's more to find.

signal turned_on
signal turned_off
signal tuned(index: int, locked: bool)

## The stations, in knob order.
@export var tracks: Array[RadioTrack] = []
## Library id of the static a locked station plays.
@export var static_sound_id: String = ""
## Or the static audio file itself, no SoundDef needed.
@export var static_stream: AudioStream
## Loudness trim for `static_stream`, in dB.
@export var static_volume_db: float = 0.0
## Click of the switch going on.
@export var on_sound_id: String = ""
## Click of the switch going off.
@export var off_sound_id: String = ""
## Played as a knob turns.
@export var knob_sound_id: String = ""
## Seconds for the sound to come up and die down.
@export var fade_seconds: float = 0.25
## Print what every station change plays, and why, to Output.
@export var debug_log: bool = true

var is_on := false
var index := 0

var _player: AudioStreamPlayer
var _level_db := 0.0
var _tween: Tween
var _warned := {}


func _ready() -> void:
	SoundLink.attach(self)  # every signal here becomes a SoundMap moment
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = AudioStreamPlayer.new()
	add_child(_player)
	# the Music slider owns the radio
	BusRoute.use(_player, "Music")
	_player.finished.connect(_on_finished)


func toggle() -> void:
	if is_on:
		turn_off()
	else:
		turn_on()


func turn_on() -> void:
	if is_on:
		return
	is_on = true
	_sfx(on_sound_id)
	turned_on.emit()
	_play_current()


func turn_off(quiet: bool = false) -> void:
	if not is_on:
		return
	is_on = false
	if not quiet:
		_sfx(off_sound_id)
	_fade_to(-60.0, true)
	turned_off.emit()


## -1 for the left knob, 1 for the right. A knob on a silent radio switches it on.
func step(dir: int) -> void:
	_sfx(knob_sound_id)
	if not is_on:
		turn_on()
		return
	if not tracks.is_empty():
		index = posmod(index + dir, tracks.size())
	_play_current()


func is_locked(i: int) -> bool:
	if i < 0 or i >= tracks.size() or tracks[i] == null:
		return true
	var t := tracks[i]
	if not t.locked_until_heard:
		return false
	var prof := get_node_or_null("/root/Profile")
	if prof == null:
		return false
	for k in t.keys():
		if prof.has_heard(k):
			return false
	return true


func _play_current() -> void:
	var locked := tracks.is_empty() or is_locked(index)
	var picked := _static_sound() if locked else _track_sound(index)
	_log(locked, picked)
	if picked.is_empty():
		_player.stop()
	else:
		_player.stream = picked[0]
		_level_db = picked[1]
		_player.volume_db = -60.0
		_player.play()
		_fade_to(_level_db, false)
	tuned.emit(index, locked)


## [stream, dB] for a station, or empty with a warning that says why.
func _track_sound(i: int) -> Array:
	var t := tracks[i]
	if t.stream:
		return [t.stream, t.volume_db]
	var d = _def(t.sound_id)
	if d:
		return [d.stream, d.volume_db]
	_warn("track %d" % i, "MenuRadio: station %d is silent. %s" % [i + 1, _why_missing(t.sound_id)])
	return []


func _static_sound() -> Array:
	if static_stream:
		return [static_stream, static_volume_db]
	var d = _def(static_sound_id)
	if d:
		return [d.stream, d.volume_db]
	if static_sound_id != "":
		_warn("static", "MenuRadio: the static is silent. %s" % _why_missing(static_sound_id))
	return []


func _why_missing(id: String) -> String:
	var snd := get_node_or_null("/root/Sound")
	if id == "":
		return "It has no sound_id and no stream."
	if snd == null:
		return "The Sound autoload is missing."
	if snd.get_set(id):
		return "'%s' is a MusicSet (stems); the radio plays one SoundDef or an audio file." % id
	var music := []
	for d in snd.defs:
		if d.category == "Music":
			music.append(d.id)
	return "No SoundDef has the id '%s'. The id is the `id` field inside the SoundDef, not its file name. Music ids loaded: %s" % [id, music]


func _log(locked: bool, picked: Array) -> void:
	if not debug_log:
		return
	var n := "station %d/%d" % [index + 1, tracks.size()] if not tracks.is_empty() else "no stations in tracks"
	var what := ""
	if tracks.is_empty() or tracks[index] == null:
		what = "static" if not picked.is_empty() else "silent (no static sound set)"
	elif locked:
		var t := tracks[index]
		var label := t.sound_id if t.sound_id != "" else (t.stream.resource_path.get_file() if t.stream else "?")
		what = "%s: '%s' is locked until the player hears it in game" % [
				"static" if not picked.is_empty() else "silent (no static sound set)", label]
	elif picked.is_empty():
		what = "silent, see the warning"
	else:
		var t := tracks[index]
		what = "'%s'" % (t.sound_id if t.stream == null else t.stream.resource_path.get_file())
	print("MenuRadio: %s -> %s" % [n, what])


func _def(id: String):
	var snd := get_node_or_null("/root/Sound")
	if id == "" or snd == null:
		return null
	var d = snd.get_def(id)
	return d if d and d.stream else null


## A song that ends moves on to the next station that isn't static; static just loops.
func _on_finished() -> void:
	if not is_on:
		return
	if tracks.is_empty() or is_locked(index):
		_player.play()
		return
	for i in range(1, tracks.size() + 1):
		var j := posmod(index + i, tracks.size())
		if not is_locked(j):
			index = j
			break
	_play_current()


func _fade_to(db: float, stop_after: bool) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_player, "volume_db", db, fade_seconds)
	if stop_after:
		_tween.tween_callback(_player.stop)


func _sfx(id: String) -> void:
	var snd := get_node_or_null("/root/Sound")
	if id != "" and snd:
		snd.play(id)


func _warn(key: String, text: String) -> void:
	if _warned.has(key):
		return
	_warned[key] = true
	push_warning(text)
