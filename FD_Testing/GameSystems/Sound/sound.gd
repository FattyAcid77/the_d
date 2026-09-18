extends Node
## Sound autoload. Buses, the sound library (SoundDef by id), music, zones,
## ducking, the breath muffle, and the SoundMap events. Register as "Sound".
## Buses are reused by name if the project already has them; only missing ones
## get created.

signal volume_changed(category: String, value: float)
signal music_changed(stream: AudioStream)

## where sounds live.
const LIBRARY_DIRS := [
	"res://FD_Testing/GameSystems/Sound/Library",
	"res://Sounds/Resource",
]
const LIBRARY_DIR := LIBRARY_DIRS[0]  # kept for older messages/docs
const MAP_PATH := "res://FD_Testing/GameSystems/Sound/sound_map.tres"
## MusicSets are found the same way: these roots, recursively.
const SETS_DIRS := [
	"res://FD_Testing/GameSystems/Sound/Sets",
	"res://Sounds/Resource",
]
const SETS_DIR := SETS_DIRS[0]
const SETTINGS_PATH := "user://sound.cfg"

## Autoloads whose signals become SoundMap moments, by autoload name.
const EVENT_AUTOLOADS := ["Bag", "MedicalItems", "Deaths", "Board", "MapRooms",
	"Prescription", "GameProgress", "DialogManager", "PopupWindows", "Loc",
	"Cutscene", "RadioLink", "BloodWorld", "LogBook"]

## Signals that fire every frame (or are pure plumbing) - never sound moments
const SKIP_SIGNALS := ["ToxicArea.warning", "ElectroPuzzle.run_tick",
	"RadioLink.frequency_changed", "Bag.changed", "WoundComponent.health_changed",
	"PuzzleSpeaker.value_changed", "DialogManager.action_requested",
	"BossFight.boss_damaged"]

## The categories, in slider order.
const CATEGORIES := ["Master", "Music", "Ambience", "SFX", "UI", "Dialog"]

@export_group("Music")
## Default crossfade when none is given.
@export var default_fade: float = 1.5

@export_group("Dialog ducking")
## Dip the Music bus while a dialog runs, back up when it ends.
@export var duck_music_in_dialog: bool = true
## How far the music dips, in dB (negative = quieter).
@export var duck_db: float = -10.0
## Seconds for the dip down / back up.
@export var duck_fade: float = 0.4

@export_group("Breath muffle")
## While Sami holds his breath the whole world goes underwater
@export var breath_muffle: bool = true
## The filter at full muffle.
@export var muffle_min_cutoff_hz: float = 500.0
## Volume dip at full muffle, in dB.
@export var muffle_volume_db: float = -14.0
## >1 = the effect stays gentle at first and bites at the end.
@export var muffle_curve: float = 1.6
## Seconds for the world to come back when he breathes out.
@export var muffle_release: float = 0.6

@export_group("Debug")
@export var debug_log: bool = false

var defs: Array[SoundDef] = []
var map: SoundMap = null  # the production team's moment -> id table
var sets: Array[MusicSet] = []  # every MusicSet in Sound/Sets/
var beds: SoundBeds = null  # the layered music / ambience engine
var event_names: Array[String] = []  # every moment attached so far, for the docs

var _volumes := {}  # category -> 0..1
var _baselines := {}  # category -> the bus db their layout set
var _music_a: AudioStreamPlayer  # the two crossfade decks
var _music_b: AudioStreamPlayer
var _music_front: AudioStreamPlayer = null  # whichever is playing now
var _music_tween: Tween
var _manual_stream: AudioStream = null  # what play_music asked for
var _zone_stack: Array = []  # MusicZones Sami is inside, newest last
var _duck_tween: Tween
var _ducked := false
var _warned_ids := {}  # id -> true, so each id warns once
var _extra_db := {}  # category -> temporary dB offset (muffle)
var _surfaces := {}  # body (Node) -> Array of FloorSurface, newest last
var _loops := {}  # key -> AudioStreamPlayer (looping sounds)
var _muffle := 0.0  # the applied amount
var _muffle_target := 0.0
var _lowpass: AudioEffectLowPassFilter = null
var _lowpass_index := -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_buses()
	_load_library()
	_load_settings()
	_apply_all_volumes()

	_music_a = AudioStreamPlayer.new()
	_music_b = AudioStreamPlayer.new()
	for p in [_music_a, _music_b]:
		p.bus = _bus("Music")
		add_child(p)

	_load_map()
	_load_sets()
	beds = SoundBeds.new()
	beds.name = "Beds"
	add_child(beds)
	_install_muffle_filter()

	# The other autoloads may sit after us in the autoload order
	_connect_dialog.call_deferred()
	_attach_autoloads.call_deferred()


func _process(delta: float) -> void:
	if _muffle == _muffle_target:
		return
	if _muffle_target > _muffle:
		_muffle = _muffle_target  # tightening is continuous
	else:
		_muffle = move_toward(_muffle, _muffle_target,
				delta / maxf(0.05, muffle_release))  # breathing out fades back
	_apply_muffle()


func _exit_tree() -> void:
	# leave the other developer's Master bus exactly as we found it
	if _lowpass_index != -1 and _lowpass_index < AudioServer.get_bus_effect_count(0):
		if AudioServer.get_bus_effect(0, _lowpass_index) == _lowpass:
			AudioServer.remove_bus_effect(0, _lowpass_index)


func _connect_dialog() -> void:
	var dm := get_node_or_null("/root/DialogManager")
	if dm == null:
		return
	if dm.has_signal("dialog_started"):
		dm.dialog_started.connect(_on_dialog_started)
	if dm.has_signal("dialog_finished"):
		dm.dialog_finished.connect(_on_dialog_finished)


# --- the SoundMap / events --------------------------------------------------

func _load_map() -> void:
	if ResourceLoader.exists(MAP_PATH):
		var r := load(MAP_PATH)
		if r is SoundMap:
			map = r
	if map == null:
		map = SoundMap.new()
		if debug_log:
			print("Sound: no sound_map.tres — every moment is silent.")


func _load_sets() -> void:
	sets.clear()
	# ResList: works in the editor and in an exported build; recursive.
	for root in SETS_DIRS:
		for path in ResList.tres_files_recursive(root):
			var r := load(path)
			if r is MusicSet and get_set(r.id) == null:
				sets.append(r)
	if debug_log:
		print("Sound: loaded %d music sets." % sets.size())


func get_set(id: String) -> MusicSet:
	for s in sets:
		if s.id == id:
			return s
	return null


# --- beds (layered music / ambience) ------------------------------------------

## Start a set by id with a base mix.
func play_set(set_id: String, layers: Array = [], align: int = SoundBeds.ALIGN_BAR) -> void:
	var s := get_set(set_id)
	if s == null:
		if not _warned_ids.has("set:" + set_id):
			_warned_ids["set:" + set_id] = true
			push_warning("Sound: no MusicSet with id '%s' (looked in %s)." % [set_id, SETS_DIRS])
		return
	beds.play_set(s, layers, align)


func stop_set(category: String = "Music", fade: float = -1.0) -> void:
	beds.stop_set(category, fade)


## Manual layer override on the running bed: true / false / null (auto).
func set_layer(category: String, layer: String, state, align: int = SoundBeds.ALIGN_BAR) -> void:
	beds.set_layer(category, layer, state, align)


func _attach_autoloads() -> void:
	for autoload_name in EVENT_AUTOLOADS:
		var n := get_node_or_null("/root/" + autoload_name)
		if n:
			attach(n, autoload_name)


## Make every signal on `node`'s script a SoundMap moment named "<prefix>.<signal>".
func attach(node: Node, prefix: String = "") -> void:
	if node == null:
		return
	if prefix == "":
		prefix = SoundLink.prefix_for(node)
	for sig in SoundLink.script_signals(node):
		var ev := prefix + "." + sig
		if SKIP_SIGNALS.has(ev):
			continue
		if not event_names.has(ev):
			event_names.append(ev)
		SoundLink.connect_any_arity(node, sig, _on_event_signal.bind(ev, node))
	if debug_log:
		print("Sound: attached %s (%d moments)." % [prefix, SoundLink.script_signals(node).size()])


func _on_event_signal(args: Array, ev: String, source: Node) -> void:
	_fire(ev, source, args)


## Fire a moment by hand from code that has no signal for it: Sound.event
func event(name: String, source: Node = null) -> void:
	_fire(name, source, [])


## Play a library sound from a node - positional if the def says so and the node is in the world
func play_from(id: String, source: Node, force_positional: bool = false) -> void:
	id = _surface_variant(id, source)
	var d := _resolve(id)
	if d == null:
		return
	if (d.positional or force_positional) and source is Node2D:
		sfx_at(id, (source as Node2D).global_position)
	else:
		play(id)


# --- floor surfaces --------------------------------------------------------- FloorSurface

func _surface_enter(body: Node, zone: Node) -> void:
	var list: Array = _surfaces.get(body, [])
	list.erase(zone)
	list.append(zone)
	_surfaces[body] = list


func _surface_exit(body: Node, zone: Node) -> void:
	if not _surfaces.has(body):
		return
	var list: Array = _surfaces[body]
	list.erase(zone)
	if list.is_empty():
		_surfaces.erase(body)


## The surface name under a node ("" = none).
func surface_of(node: Node) -> String:
	var n := node
	while n:
		if _surfaces.has(n):
			var list: Array = _surfaces[n]
			for i in range(list.size() - 1, -1, -1):
				var z = list[i]
				if is_instance_valid(z) and "surface" in z:
					return str(z.surface)
		n = n.get_parent()
	return ""


func _surface_variant(id: String, source: Node) -> String:
	if source == null:
		return id
	var d := get_def(id)
	if d == null or d.surface_variants.is_empty():
		return id
	var s := surface_of(source)
	if s != "" and d.surface_variants.has(s):
		var alt := str(d.surface_variants[s])
		if alt != "":
			return alt
	return id


# --- loops ------------------------------------------------------------------ A sound

func start_loop(key: String, id: String, fade: float = 0.4) -> void:
	if _loops.has(key) and is_instance_valid(_loops[key]):
		return
	var d := _resolve(id)
	if d == null:
		return
	var p := AudioStreamPlayer.new()
	p.stream = d.stream
	p.bus = _bus(d.category)
	p.volume_db = -60.0
	p.pitch_scale = d.random_pitch()
	add_child(p)
	p.play()
	# a stream set to loop on its Import tab never finishes
	p.finished.connect(func(): if is_instance_valid(p) and _loops.get(key) == p: p.play())
	create_tween().tween_property(p, "volume_db", d.volume_db, fade)
	_loops[key] = p


func stop_loop(key: String, fade: float = 0.6) -> void:
	if not _loops.has(key):
		return
	var p: AudioStreamPlayer = _loops[key]
	_loops.erase(key)
	if not is_instance_valid(p):
		return
	var t := create_tween()
	t.tween_property(p, "volume_db", -60.0, fade)
	t.tween_callback(p.queue_free)


# --- breath muffle ----------------------------------------------------------

## Puts our low-pass filter at the end of the Master bus chain, disabled.
func _install_muffle_filter() -> void:
	if not breath_muffle:
		return
	_lowpass = AudioEffectLowPassFilter.new()
	_lowpass.cutoff_hz = 20000.0
	_lowpass.resource_name = "GameSystems breath muffle"
	_lowpass_index = AudioServer.get_bus_effect_count(0)
	AudioServer.add_bus_effect(0, _lowpass, _lowpass_index)
	AudioServer.set_bus_effect_enabled(0, _lowpass_index, false)


## 0 = clear, 1 = fully underwater.
func set_muffle(amount: float) -> void:
	_muffle_target = clampf(amount, 0.0, 1.0)
	if _muffle_target > _muffle:
		_muffle = _muffle_target
		_apply_muffle()


func muffle() -> float:
	return _muffle


func _apply_muffle() -> void:
	if _lowpass == null:
		return
	var k := pow(_muffle, muffle_curve)
	var on := k > 0.001
	AudioServer.set_bus_effect_enabled(0, _lowpass_index, on)
	# perceptually even sweep: interpolate in log-frequency
	_lowpass.cutoff_hz = exp(lerpf(log(20000.0), log(maxf(50.0, muffle_min_cutoff_hz)), k))
	_extra_db["Master"] = muffle_volume_db * k
	_apply_volume("Master")


func _fire(ev: String, source: Node, args: Array) -> void:
	# 1) the specific wins: a resource riding on the signal with its own sound_id
	var id := _resource_sound(ev, args)
	if id != "":
		_fire_one(id, source, args)
		return
	# 2) otherwise the production team's map.
	var value := map.sound_for(ev) if map else ""
	if value == "":
		return  # unmapped = silent
	cue(value, source, args)


## Run a cue string. Same syntax in the SoundMap, a DialogLine's sound_id,
## [sfx:...] inside dialog text, and the play_sound verb:
##   paper                     play once
##   paper, jingle             both
##   loop drone                start a loop        loop(0.5) drone   0.5s fade in
##   stop drone                end it              stop(0.3) drone   0.3s fade out
##   delay(1) scream           wait 1s first       delay(2) loop drone  combine freely
func cue(text: String, source: Node = null, args: Array = []) -> void:
	for entry in text.split(",", false):
		var words := entry.strip_edges().split(" ", false)
		if words.is_empty():
			continue
		var id := words[words.size() - 1]
		var mode := "play"
		var fade := -1.0
		var delay := 0.0
		for w in words.slice(0, words.size() - 1):
			var m := _CUE_RE.search(w)
			if m == null:
				continue
			var num := m.get_string(2)
			match m.get_string(1).to_lower():
				"delay": delay = float(num) if num != "" else 1.0
				"loop":
					mode = "loop"
					if num != "": fade = float(num)
				"stop":
					mode = "stop"
					if num != "": fade = float(num)
		if id.to_lower() in ["loop", "stop", "delay"] or _CUE_RE.search(id) and id.contains("("):
			continue  # a modifier with no id after it
		_run_cue(id, mode, fade, delay, source, args)


var _CUE_RE := RegEx.create_from_string("^(delay|loop|stop)(?:\\(([0-9]*\\.?[0-9]+)\\))?$")


func _run_cue(id: String, mode: String, fade: float, delay: float, source: Node, args: Array) -> void:
	if delay > 0.0:
		# process_always timer: dialog and the Board pause the tree
		await get_tree().create_timer(delay, true).timeout
	match mode:
		"loop": start_loop(id, id, fade if fade >= 0.0 else 0.4)
		"stop": stop_loop(id, fade if fade >= 0.0 else 0.6)
		_: _fire_one(id, source, args)


## One one-shot from a moment: surface variant, then positional or global.
func _fire_one(id: String, source: Node, args: Array) -> void:
	# a Vector2 on the signal (BloodWorld.spilled carries one) is where it happened
	id = _surface_variant(id, source)
	var d := _resolve(id)
	if d == null:
		return
	if d.positional:
		for a in args:
			if a is Vector2:
				sfx_at(id, a)
				return
		if source is Node2D:
			sfx_at(id, (source as Node2D).global_position)
			return
	play(id)


## Resource sounds riding on the moment.
func _resource_sound(ev: String, args: Array) -> String:
	for a in args:
		if a is Resource and "sound_id" in a and str(a.sound_id) != "":
			return str(a.sound_id)
	var s0 := str(args[0]) if args.size() > 0 else ""
	match ev:
		"NPC.footstep":
			if args.size() > 0 and args[0] is Resource and "footstep_sound_id" in args[0]:
				return str(args[0].footstep_sound_id)
		"Bag.item_added", "ItemPickup.picked_up":
			var mi := get_node_or_null("/root/MedicalItems")
			if mi and mi.has_method("get_item"):
				var item = mi.get_item(s0)
				if item and "pickup_sound_id" in item:
					return str(item.pickup_sound_id)
		"Bag.item_used", "MedicalItems.item_used":
			var mi2 := get_node_or_null("/root/MedicalItems")
			if mi2 and mi2.has_method("get_item"):
				var item2 = mi2.get_item(s0)
				if item2 and "use_sound_id" in item2:
					return str(item2.use_sound_id)
		"Deaths.player_died", "WoundComponent.died":
			var de := get_node_or_null("/root/Deaths")
			if de and de.has_method("get_cause"):
				var cause = de.get_cause(s0)
				if cause and "sound_id" in cause:
					return str(cause.sound_id)
		"MapRooms.room_discovered":
			var mr := get_node_or_null("/root/MapRooms")
			if mr and mr.has_method("get_room"):
				var room = mr.get_room(s0)
				if room and "sound_id" in room:
					return str(room.sound_id)
		"Prescription.checkpoint_applied", "Prescription.checkpoint_reached":
			var pr := get_node_or_null("/root/Prescription")
			if pr and pr.has_method("get_checkpoint") and args.size() > 0:
				var cp = pr.get_checkpoint(int(args[0]))
				if cp and "sound_id" in cp:
					return str(cp.sound_id)
	return ""


# --- buses ------------------------------------------------------------------

## Where a bus we create should send its signal
const PREFERRED_SEND := {
	"Music": ["EffectPass", "Master"],
	"Ambience": ["EffectPass", "Master"],  # same reverb as their SFX
	"SFX": ["EffectPass", "Master"],
	"UI": ["Master"],
	"Dialog": ["Master"],  # speech stays dry
}


## Look every category bus up by name; reuse what exists (their layout, untouched)
func _ensure_buses() -> void:
	for cat in CATEGORIES:
		if AudioServer.get_bus_index(cat) != -1:
			if debug_log:
				print("Sound: reusing existing bus '%s'." % cat)
			continue
		if cat == "Master":
			continue  # bus 0 always exists, whatever its name
		var i := AudioServer.bus_count
		AudioServer.add_bus(i)
		AudioServer.set_bus_name(i, cat)
		var send := "Master"
		for want in PREFERRED_SEND.get(cat, ["Master"]):
			if AudioServer.get_bus_index(want) != -1 and want != cat:
				send = want
				break
		AudioServer.set_bus_send(i, send)
		if debug_log:
			print("Sound: created bus '%s' -> %s." % [cat, send])

	for cat in CATEGORIES:
		var bi := AudioServer.get_bus_index(cat)
		if bi != -1:
			_baselines[cat] = AudioServer.get_bus_volume_db(bi)


## The real bus name to play a category on.
func _bus(category: String) -> String:
	if AudioServer.get_bus_index(category) != -1:
		return category
	if AudioServer.get_bus_index("Master") != -1:
		return "Master"
	return AudioServer.get_bus_name(0)


# --- volumes ----------------------------------------------------------------

func get_volume(category: String) -> float:
	return float(_volumes.get(category, 1.0))


## `value` is 0..1.
func set_volume(category: String, value: float) -> void:
	value = clampf(value, 0.0, 1.0)
	_volumes[category] = value
	_apply_volume(category)
	_save_settings()
	volume_changed.emit(category, value)


func _apply_all_volumes() -> void:
	for cat in CATEGORIES:
		_apply_volume(cat)


func _apply_volume(category: String) -> void:
	var i := AudioServer.get_bus_index(category)
	if i == -1:
		return
	var v := get_volume(category)
	# relative to the baseline their layout set: full slider = their mix exactly, lower = quieter.
	var base: float = _baselines.get(category, 0.0) + float(_extra_db.get(category, 0.0))
	AudioServer.set_bus_volume_db(i, base + linear_to_db(v) if v > 0.0 else -80.0)
	AudioServer.set_bus_mute(i, v <= 0.0)


func _load_settings() -> void:
	# 1.0 = "exactly the mix the bus layout ships with"
	for cat in CATEGORIES:
		_volumes[cat] = 1.0
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	for cat in CATEGORIES:
		_volumes[cat] = clampf(float(cfg.get_value("volumes", cat, 1.0)), 0.0, 1.0)


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	for cat in CATEGORIES:
		cfg.set_value("volumes", cat, get_volume(cat))
	cfg.save(SETTINGS_PATH)


# --- the library ------------------------------------------------------------

func _load_library() -> void:
	defs.clear()
	# ResList: works in the editor and in an exported build; recursive, so subfolders are fine.
	for root in LIBRARY_DIRS:
		for path in ResList.tres_files_recursive(root):
			var r := load(path)
			if r is SoundDef:
				if get_def(r.id) != null:
					push_warning("Sound: two SoundDefs share the id '%s' (%s) — the first one wins."
							% [r.id, path])
					continue
				defs.append(r)
	if debug_log:
		print("Sound: loaded %d sound definitions from %s." % [defs.size(), LIBRARY_DIRS])


func _all_ids() -> Array:
	var out := []
	for d in defs:
		out.append(d.id)
	return out


func get_def(id: String) -> SoundDef:
	for d in defs:
		if d.id == id:
			return d
	return null


## True if this id exists and has a stream - use it to skip optional sounds
func has_sound(id: String) -> bool:
	var d := get_def(id)
	return d != null and d.stream != null


func _resolve(id: String) -> SoundDef:
	var d := get_def(id)
	if d == null or d.stream == null:
		if not _warned_ids.has(id):
			_warned_ids[id] = true
			push_warning("Sound: no playable sound with id '%s' — staying silent. (Looked in %s, subfolders included. Loaded ids: %s)"
					% [id, LIBRARY_DIRS, _all_ids()])
		return null
	return d


# --- one-shots --------------------------------------------------------------

## Play a library sound on its own category bus.
func play(id: String) -> void:
	var d := _resolve(id)
	if d == null:
		return
	_one_shot(d.stream, _bus(d.category), d.volume_db, d.random_pitch())


## Shortcuts that force the category, whatever the def says.
func sfx(id: String) -> void:
	var d := _resolve(id)
	if d:
		_one_shot(d.stream, _bus("SFX"), d.volume_db, d.random_pitch())


func ui(id: String) -> void:
	var d := _resolve(id)
	if d:
		_one_shot(d.stream, _bus("UI"), d.volume_db, d.random_pitch())


func ambience(id: String) -> void:
	var d := _resolve(id)
	if d:
		_one_shot(d.stream, _bus("Ambience"), d.volume_db, d.random_pitch())


func dialog(id: String) -> void:
	var d := _resolve(id)
	if d:
		_one_shot(d.stream, _bus("Dialog"), d.volume_db, d.random_pitch())


## No library id - play a raw stream on a category.
func play_stream(stream: AudioStream, category: String = "SFX",
		volume_db: float = 0.0) -> void:
	if stream == null:
		return
	_one_shot(stream, _bus(category), volume_db, 1.0)


func _one_shot(stream: AudioStream, bus_name: String, volume_db: float,
		pitch: float) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.bus = bus_name
	p.volume_db = volume_db
	p.pitch_scale = pitch
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


## positional: the sound comes from a world position
func sfx_at(id: String, world_pos: Vector2) -> void:
	var d := _resolve(id)
	if d == null:
		return
	var scene := get_tree().current_scene
	if scene == null:
		return
	var p := AudioStreamPlayer2D.new()
	p.stream = d.stream
	p.bus = _bus(d.category if d.category != "Master" else "SFX")
	p.volume_db = d.volume_db
	p.pitch_scale = d.random_pitch()
	p.max_distance = d.max_distance
	p.global_position = world_pos
	scene.add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


# --- music ------------------------------------------------------------------

## Play a library id as the current music.
func play_music(id: String, fade: float = -1.0) -> void:
	var d := _resolve(id)
	if d == null:
		return
	play_music_stream(d.stream, fade, d.volume_db)


## Same, from a raw stream.
func play_music_stream(stream: AudioStream, fade: float = -1.0,
		volume_db: float = 0.0) -> void:
	_manual_stream = stream
	if _zone_stack.is_empty():
		_crossfade_to(stream, fade, volume_db)
	# inside a zone: the zone's track keeps playing


func stop_music(fade: float = -1.0) -> void:
	_manual_stream = null
	if _zone_stack.is_empty():
		_crossfade_to(null, fade)


## What's actually coming out of the speakers right now.
func current_music() -> AudioStream:
	return _music_front.stream if _music_front and _music_front.playing else null


func _crossfade_to(stream: AudioStream, fade: float = -1.0,
		volume_db: float = 0.0) -> void:
	if fade < 0.0:
		fade = default_fade
	var front := _music_front
	if front and front.stream == stream and front.playing:
		return  # already playing that - nothing to do

	if _music_tween and _music_tween.is_valid():
		_music_tween.kill()
	_music_tween = create_tween()
	_music_tween.set_parallel(true)

	# fade the old deck out
	if front and front.playing:
		_music_tween.tween_property(front, "volume_db", -60.0, fade)
		_music_tween.chain().tween_callback(front.stop)

	if stream == null:
		_music_front = null
		music_changed.emit(null)
		return

	# fade the other deck in
	var back := _music_b if front == _music_a else _music_a
	back.stream = stream
	back.volume_db = -60.0
	back.play()
	_music_tween.tween_property(back, "volume_db", volume_db, fade)
	_music_front = back
	music_changed.emit(stream)
	if debug_log:
		print("Sound: music -> %s (%.1fs fade)" % [stream.resource_path, fade])


# --- MusicZones ------------------------------------------------------------- Zones call

func _zone_enter(zone: Node, stream: AudioStream, fade: float,
		volume_db: float) -> void:
	_zone_stack.erase(zone)
	_zone_stack.append(zone)
	_crossfade_to(stream, fade, volume_db)


func _zone_exit(zone: Node, fade: float) -> void:
	_zone_stack.erase(zone)
	# clean out zones that were freed while Sami stood in them
	_zone_stack = _zone_stack.filter(func(z): return is_instance_valid(z))
	if not _zone_stack.is_empty():
		var top: Node = _zone_stack.back()
		_crossfade_to(top.zone_stream(), fade, top.music_volume_db)
	else:
		_crossfade_to(_manual_stream, fade)


# --- dialog ducking ---------------------------------------------------------

func _on_dialog_started() -> void:
	if duck_music_in_dialog:
		_duck(true)


func _on_dialog_finished() -> void:
	_duck(false)


func _duck(on: bool) -> void:
	if on == _ducked:
		return
	_ducked = on
	# layered music: only the stems marked ducks_in_dialog dip (the drums)
	if beds:
		beds.duck(on, duck_db, duck_fade)
		if beds.has_bed("Music"):
			return
	var i := AudioServer.get_bus_index("Music")
	if i == -1:
		return
	var vol := get_volume("Music")
	var base: float = _baselines.get("Music", 0.0) \
			+ (linear_to_db(vol) if vol > 0.0 else -80.0)
	var target := base + duck_db if on else base
	if _duck_tween and _duck_tween.is_valid():
		_duck_tween.kill()
	_duck_tween = create_tween()
	_duck_tween.tween_method(
		func(v: float): AudioServer.set_bus_volume_db(i, v),
		AudioServer.get_bus_volume_db(i), target, duck_fade)
