@tool
extends EditorProperty
## A list of flags (set_flags, clear_flags, require_flags...): one name row
## per flag, each with its pick list and mark, plus add and remove.

const NameRow := preload("name_row.gd")

var tools
var kind := ""
var box: VBoxContainer
var rows: Array = []  # NameRow per entry
var add_button: Button


func _init(p_tools, p_kind: String) -> void:
	tools = p_tools
	kind = p_kind
	box = VBoxContainer.new()
	add_child(box)
	set_bottom_editor(box)


func _update_property() -> void:
	_rebuild()


func _values() -> Array[String]:
	var out: Array[String] = []
	var v = get_edited_object().get(get_edited_property())
	if v != null:
		for s in v:
			out.append(str(s))
	return out


func _rebuild() -> void:
	for c in box.get_children():
		c.queue_free()
	rows.clear()
	var values := _values()
	for i in values.size():
		var line := HBoxContainer.new()
		box.add_child(line)
		var r := NameRow.new(tools, kind)
		line.add_child(r)
		r.set_text(values[i])
		var idx := i
		r.committed.connect(func(t): set_at(idx, t))
		var remove := Button.new()
		remove.icon = EditorInterface.get_editor_theme().get_icon("Remove", "EditorIcons")
		remove.tooltip_text = "Remove"
		remove.pressed.connect(func(): remove_at(idx))
		line.add_child(remove)
		rows.append(r)
	add_button = Button.new()
	add_button.text = "Add flag"
	add_button.icon = EditorInterface.get_editor_theme().get_icon("Add", "EditorIcons")
	add_button.pressed.connect(add_flag)
	box.add_child(add_button)


func add_flag() -> void:
	var values := _values()
	values.append("")
	emit_changed(get_edited_property(), values)


func set_at(i: int, text: String) -> void:
	var values := _values()
	if i >= values.size() or values[i] == text:
		return
	values[i] = text
	emit_changed(get_edited_property(), values)


func remove_at(i: int) -> void:
	var values := _values()
	if i < values.size():
		values.remove_at(i)
		emit_changed(get_edited_property(), values)
