class_name BoardSettings extends Control
## The SETTINGS tab.
##
## Language works properly and saves. Everything else is drawn as a visible,
## clearly-labelled row that says it isn't wired up yet — so you can see the
## shape of the finished menu while you build it, and nobody is fooled into
## thinking a dead slider does something.
##
## To make a row real: set its `live` to true in `_rows()` and handle it in
## `_on_row_changed()`. That's the only place you have to touch.

@export_group("Where it sits on the 640x360 canvas")
## The usable area inside the clipboard.
@export var content_rect: Rect2 = Rect2(248, 100, 150, 180)
@export var row_height: float = 16.0
@export var row_gap: float = 5.0
@export var label_width: float = 62.0

@export_group("Words")
@export var heading: String = "SETTINGS"
@export var footer_note: String = "Sound and controls are not wired up yet."
@export var heading_size: int = 10
@export var label_size: int = 7
@export var note_size: int = 6
@export var font: Font

@export_group("Colours")
@export var heading_color: Color = Color(0.22, 0.20, 0.15)
@export var label_color: Color = Color(0.28, 0.26, 0.20)
@export var dead_color: Color = Color(0.45, 0.43, 0.36)
@export var note_color: Color = Color(0.45, 0.43, 0.36)
@export var rule_color: Color = Color(0.35, 0.33, 0.26, 0.35)

@export_group("Debug")
## Outline the content area and every row while you line them up.
@export var show_layout: bool = false

var _lang: LanguageSetting
var _controls: Array = []


## The menu, top to bottom. `live` = it actually does something.
func _rows() -> Array:
	return [
		{"key": "language", "label": "Language",    "live": true,  "kind": "dropdown"},
		{"key": "master",   "label": "Volume",      "live": false, "kind": "slider"},
		{"key": "music",    "label": "Music",       "live": false, "kind": "slider"},
		{"key": "sfx",      "label": "Effects",     "live": false, "kind": "slider"},
		{"key": "fullscr",  "label": "Fullscreen",  "live": false, "kind": "check"},
		{"key": "controls", "label": "Controls",    "live": false, "kind": "button"},
	]


func _ready() -> void:
	# Sized to the 640x360 art canvas, NOT the viewport. The Board scales and
	# centres the canvas, so drawing and mouse coordinates are both in plain
	# art pixels — which is what makes the slots clickable at any resolution.
	position = Vector2.ZERO
	size = Vector2(640, 360)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()


func _build() -> void:
	var y := content_rect.position.y + float(heading_size) + 8.0
	for row in _rows():
		var x := content_rect.position.x + label_width
		var w := content_rect.size.x - label_width
		var c: Control = null

		match row["kind"]:
			"dropdown":
				_lang = LanguageSetting.new()
				_lang.label_text = ""
				_lang.label_min_width = 0.0
				c = _lang
			"slider":
				var sl := HSlider.new()
				sl.min_value = 0.0
				sl.max_value = 100.0
				sl.value = 80.0
				c = sl
			"check":
				var cb := CheckBox.new()
				cb.text = ""
				c = cb
			"button":
				var b := Button.new()
				b.text = tr("Not yet")
				b.add_theme_font_size_override("font_size", label_size)
				c = b

		if c == null:
			y += row_height + row_gap
			continue

		c.position = Vector2(x, y)
		c.size = Vector2(w, row_height)
		c.mouse_filter = Control.MOUSE_FILTER_STOP if row["live"] \
				else Control.MOUSE_FILTER_IGNORE
		# A dead control is visibly dead: greyed out and unclickable, so it
		# reads as "coming soon" rather than "broken".
		c.modulate = Color(1, 1, 1, 1) if row["live"] else Color(1, 1, 1, 0.4)
		if not row["live"]:
			c.set_process_input(false)
		add_child(c)
		# LanguageSetting builds its own OptionButton at the default font
		# size, which is huge next to these small rows. Shrink it to match.
		if row["kind"] == "dropdown":
			_shrink_text(c)
		_controls.append({"row": row, "node": c, "y": y})
		y += row_height + row_gap


## Makes every Label/Button inside a control use this menu's font size.
func _shrink_text(node: Node) -> void:
	if node is Label or node is Button or node is OptionButton:
		node.add_theme_font_size_override("font_size", label_size)
		if font:
			node.add_theme_font_override("font", font)
	for c in node.get_children():
		_shrink_text(c)


func refresh() -> void:
	queue_redraw()


## Where a real setting would report in. Only `language` reaches here today,
## and LanguageSetting handles that itself.
func _on_row_changed(key: String, value) -> void:
	match key:
		_:
			push_warning("BoardSettings: '%s' isn't wired up yet (value %s)."
					% [key, value])


func _draw() -> void:
	var f := font if font else ThemeDB.fallback_font

	draw_string(f, content_rect.position + Vector2(0, float(heading_size)),
			tr(heading), HORIZONTAL_ALIGNMENT_LEFT, -1, heading_size, heading_color)
	var rule_y := content_rect.position.y + float(heading_size) + 3.0
	draw_line(Vector2(content_rect.position.x, rule_y),
			Vector2(content_rect.position.x + content_rect.size.x, rule_y),
			rule_color, 1.0)

	for entry in _controls:
		var row: Dictionary = entry["row"]
		var y: float = entry["y"]
		var col: Color = label_color if row["live"] else dead_color
		draw_string(f, Vector2(content_rect.position.x, y + row_height * 0.72),
				tr(row["label"]), HORIZONTAL_ALIGNMENT_LEFT, label_width - 4.0,
				label_size, col)

	var last: float = content_rect.position.y
	if not _controls.is_empty():
		last = float(_controls[_controls.size() - 1]["y"]) + row_height
	draw_string(f, Vector2(content_rect.position.x, last + 14.0),
			tr(footer_note), HORIZONTAL_ALIGNMENT_LEFT, content_rect.size.x,
			note_size, note_color)

	if show_layout:
		draw_rect(content_rect, Color(0, 1, 0, 0.8), false, 1.0)
		for entry2 in _controls:
			draw_rect(Rect2(content_rect.position.x, float(entry2["y"]),
					content_rect.size.x, row_height), Color(1, 0.5, 0, 0.7), false, 1.0)
