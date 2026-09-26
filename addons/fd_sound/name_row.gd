@tool
extends HBoxContainer
## One name box for a flag or an id: the text, a mark (set somewhere? exists?)
## and the pick list. The kind decides the list and the mark:
## flag:use, flag:set, flag:clear, death, item, window, room, state.

signal committed(text: String)

var tools
var kind := ""
var line: LineEdit
var mark: TextureRect
var pick_button: Button


func _init(p_tools, p_kind: String) -> void:
	tools = p_tools
	kind = p_kind
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line = LineEdit.new()
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.placeholder_text = "flag" if kind.begins_with("flag") else tools.names.title(kind).to_lower().trim_suffix("s")
	line.text_submitted.connect(func(t): committed.emit(t))
	line.focus_exited.connect(func(): committed.emit(line.text))
	line.text_changed.connect(func(_t): refresh())
	add_child(line)
	mark = TextureRect.new()
	mark.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	mark.custom_minimum_size = Vector2(18, 0)
	mark.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(mark)
	pick_button = Button.new()
	pick_button.tooltip_text = "Pick from the list"
	pick_button.pressed.connect(open_list)
	add_child(pick_button)
	tools.names.changed.connect(refresh)


func _ready() -> void:
	pick_button.icon = EditorInterface.get_editor_theme().get_icon("Search", "EditorIcons")
	refresh()


func set_text(t: String) -> void:
	line.text = t
	refresh()


func open_list() -> void:
	var list_kind := "flag" if kind.begins_with("flag") else kind
	tools.pick(tools.names.title(list_kind), tools.names.rows(list_kind), func(id):
		line.text = id
		committed.emit(id)
		refresh(),
		"Nothing found yet. Save the scene or resource that has them, and they show up here.")


## ok = green tick, warn = yellow sign, bad = red cross. Hover it for where.
func status() -> String:
	return str(tools.names.check(kind, line.text)[0])


func refresh() -> void:
	if not is_inside_tree():
		return
	var r: Array = tools.names.check(kind, line.text)
	var icon := {"ok": "StatusSuccess", "warn": "StatusWarning", "bad": "StatusError"}.get(str(r[0]), "")
	mark.texture = EditorInterface.get_editor_theme().get_icon(icon, "EditorIcons") if icon != "" else null
	mark.tooltip_text = str(r[1])
