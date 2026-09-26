@tool
extends EditorProperty
## A flag or id field: the text box stays, plus the pick list and a mark that
## says whether the flag is set somewhere, or whether the id exists.

const NameRow := preload("name_row.gd")

var row: NameRow


func _init(p_tools, p_kind: String) -> void:
	row = NameRow.new(p_tools, p_kind)
	add_child(row)
	add_focusable(row.line)
	row.committed.connect(_commit)


func _update_property() -> void:
	var v = get_edited_object().get(get_edited_property())
	row.set_text(str(v) if v != null else "")


func _commit(text: String) -> void:
	if text == str(get_edited_object().get(get_edited_property())):
		return
	emit_changed(get_edited_property(), text)
