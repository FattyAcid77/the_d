extends Node
## Profile. What the game remembers about this player between launches, outside
## of saves: display settings, whether the first-run setup is done, whether
## they finished the game, and which music they have heard (for the menu radio).

signal display_changed
signal finished
signal heard(id: String)

const PATH := "user://profile.cfg"

## Setting this flag anywhere (dialog set_flags, a checkpoint) marks the game finished for good.
const FINISHED_FLAG := "game_finished"

var _cfg := ConfigFile.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_cfg.load(PATH)
	_apply_display()
	var flags := get_node_or_null("/root/Flags")
	if flags and flags.has_signal("flag_changed"):
		flags.flag_changed.connect(_on_flag_changed)
	var snd := get_node_or_null("/root/Sound")
	if snd:
		snd.music_changed.connect(_on_music_changed)
		snd.sound_started.connect(_on_sound_started)


# --- first run -----------------------------------------------------------------

func needs_first_run() -> bool:
	return not bool(_cfg.get_value("menu", "first_run_done", false))


func mark_first_run_done() -> void:
	_store("menu", "first_run_done", true)


# --- finished the game -----------------------------------------------------------

func is_finished() -> bool:
	return bool(_cfg.get_value("menu", "finished", false))


func mark_finished() -> void:
	if is_finished():
		return
	_store("menu", "finished", true)
	finished.emit()


func _on_flag_changed(flag_name: String, value: Variant) -> void:
	# only ever turns on; New Game clearing the flags doesn't undo an ending
	if flag_name == FINISHED_FLAG and value != null and value != false:
		mark_finished()


# --- music heard in game ------------------------------------------------------------

func has_heard(id: String) -> bool:
	return id in PackedStringArray(_cfg.get_value("radio", "heard", PackedStringArray()))


func mark_heard(id: String) -> void:
	if id == "" or has_heard(id):
		return
	var list := PackedStringArray(_cfg.get_value("radio", "heard", PackedStringArray()))
	list.append(id)
	_store("radio", "heard", list)
	heard.emit(id)


## Remembered by id and by file, so a radio track can name either.
func _on_music_changed(stream: AudioStream) -> void:
	if stream == null:
		return
	mark_heard(stream.resource_path)
	var snd := get_node_or_null("/root/Sound")
	for d in snd.defs:
		if d.stream == stream:
			mark_heard(d.id)


func _on_sound_started(id: String, found: bool) -> void:
	if not found:
		return
	var d = get_node("/root/Sound").get_def(id)
	if d and d.category == "Music":
		mark_heard(id)
		if d.stream:
			mark_heard(d.stream.resource_path)


# --- display -----------------------------------------------------------------------

func fullscreen() -> bool:
	var mode := DisplayServer.window_get_mode()
	return mode == DisplayServer.WINDOW_MODE_FULLSCREEN \
			or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN


func set_fullscreen(on: bool) -> void:
	_store("display", "fullscreen", on)
	_apply_fullscreen(on)
	display_changed.emit()


## Only what the player chose is applied; until then the project settings rule.
func _apply_display() -> void:
	if _cfg.has_section_key("display", "fullscreen"):
		_apply_fullscreen(bool(_cfg.get_value("display", "fullscreen")))


func _apply_fullscreen(on: bool) -> void:
	# borderless fullscreen, not exclusive: the popup windows are real OS windows
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN
			if on else DisplayServer.WINDOW_MODE_WINDOWED)


# --- file ----------------------------------------------------------------------------

func _store(section: String, key: String, value: Variant) -> void:
	_cfg.set_value(section, key, value)
	_cfg.save(PATH)


## Wipes everything this remembers, so the next launch is a first launch (testing).
func forget_all() -> void:
	_cfg = ConfigFile.new()
	_cfg.save(PATH)
