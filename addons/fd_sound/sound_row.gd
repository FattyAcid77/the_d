@tool
extends HBoxContainer
## One sound id box: the text, a found/missing mark, the pick list and a play
## button. Used by sound_id fields and by each row of a SoundHook's table.

signal committed(text: String)

const Library := preload("library.gd")

var tools
var music_first := false
var line: LineEdit
var mark: TextureRect
var pick_button: Button
var play_button: Button


func _init(p_tools, p_music_first := false) -> void:
	tools = p_tools
	music_first = p_music_first
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line = LineEdit.new()
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.placeholder_text = "music id" if music_first else "sound id or cue"
	line.text_submitted.connect(func(t): committed.emit(t))
	line.focus_exited.connect(func(): committed.emit(line.text))
	line.text_changed.connect(func(_t): refresh())
	add_child(line)
	mark = TextureRect.new()
	mark.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	mark.custom_minimum_size = Vector2(18, 0)
	add_child(mark)
	pick_button = Button.new()
	pick_button.tooltip_text = "Pick from the sound library"
	pick_button.pressed.connect(open_list)
	add_child(pick_button)
	play_button = Button.new()
	play_button.tooltip_text = "Hear it"
	play_button.pressed.connect(toggle_play)
	add_child(play_button)
	tools.library.changed.connect(refresh)


func _ready() -> void:
	var th := EditorInterface.get_editor_theme()
	pick_button.icon = th.get_icon("Search", "EditorIcons")
	play_button.icon = th.get_icon("Play", "EditorIcons")
	refresh()


func set_text(t: String) -> void:
	line.text = t
	refresh()


func open_list() -> void:
	tools.pick("Sounds (SoundDef)", tools.library.sound_rows(music_first), func(id):
		line.text = id
		committed.emit(id)
		refresh(),
		"No SoundDefs found. Put them under Sounds/Resource or Sound/Library.")


func toggle_play() -> void:
	var id := Library.first_id(line.text)
	if tools.playing_id != "" and tools.playing_id == id:
		tools.stop()
	else:
		tools.play_sound(id)


func is_found() -> bool:
	var id := Library.first_id(line.text)
	return id != "" and tools.library.sounds.has(id)


## Green tick: the id exists. Red cross: it doesn't, and the game will stay silent.
func refresh() -> void:
	if not is_inside_tree():
		return
	var th := EditorInterface.get_editor_theme()
	var id := Library.first_id(line.text)
	var found := is_found()
	play_button.disabled = not found
	if id == "":
		mark.texture = null
		mark.tooltip_text = ""
	elif found:
		mark.texture = th.get_icon("StatusSuccess", "EditorIcons")
		mark.tooltip_text = "%s  (%s)" % [id, tools.library.sounds[id].category]
	else:
		mark.texture = th.get_icon("StatusError", "EditorIcons")
		mark.tooltip_text = "No sound called '%s' in the library. The game stays silent here." % id
