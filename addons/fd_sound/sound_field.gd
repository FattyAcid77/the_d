@tool
extends EditorProperty
## A sound id field: still a text box (so cues like "delay(1) scream" work),
## plus a pick list, a play button, and a mark that says if the id exists.

const SoundRow := preload("sound_row.gd")

var row: SoundRow
var line: LineEdit
var play_button: Button


func _init(p_tools, p_music_first := false) -> void:
	row = SoundRow.new(p_tools, p_music_first)
	add_child(row)
	line = row.line
	play_button = row.play_button
	add_focusable(line)
	row.committed.connect(_commit)


func _update_property() -> void:
	var v = get_edited_object().get(get_edited_property())
	row.set_text(str(v) if v != null else "")


func _commit(text: String) -> void:
	if text == str(get_edited_object().get(get_edited_property())):
		return
	emit_changed(get_edited_property(), text)


func open_list() -> void:
	row.open_list()


func toggle_play() -> void:
	row.toggle_play()


func is_found() -> bool:
	return row.is_found()
