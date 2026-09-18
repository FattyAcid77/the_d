class_name BoardSettings extends Control
## Settings tab: language dropdown and the six volume sliders, drawn on the
## 640x360 art canvas. Fullscreen/controls rows are placeholders.

@export_group("Where it sits on the 640x360 canvas")
## The usable area inside the clipboard.
@export var content_rect: Rect2 = Rect2(248, 96, 150, 190)
@export var row_height: float = 13.0
@export var row_gap: float = 4.0
@export var label_width: float = 62.0

@export_group("Words")
@export var heading: String = "SETTINGS"
@export var footer_note: String = "Fullscreen and controls are not wired up yet."
@export var heading_size: int = 10
@export var label_size: int = 7
@export var note_size: int = 6
@export var font: Font

@export_group("Sound")
## Preview blip when a volume slider is released
@export var preview_sound_id: String = "slider_preview"

@export_group("Colours")
@export var heading_color: Color = Color(0.22, 0.20, 0.15)
@export var label_color: Color = Color(0.28, 0.26, 0.20)
@export var dead_color: Color = Color(0.45, 0.43, 0.36)
@export var note_color: Color = Color(0.45, 0.43, 0.36)
@export var rule_color: Color = Color(0.35, 0.33, 0.26, 0.35)
## The ink the slider tracks and grabbers are drawn
@export var slider_ink: Color = Color(0.28, 0.26, 0.20)

@export_group("Debug")
## Outline the content area and every row while you line them up.
@export var show_layout: bool = false

var _lang: LanguageSetting
var _controls: Array = []


## The menu, top to bottom.
func _rows() -> Array:
	return [
		{"key": "language", "label": "Language",   "live": true,  "kind": "dropdown"},
		{"key": "Master",   "label": "Volume",     "live": true,  "kind": "volume"},
		{"key": "Music",    "label": "Music",      "live": true,  "kind": "volume"},
		{"key": "Ambience", "label": "Ambience",   "live": true,  "kind": "volume"},
		{"key": "SFX",      "label": "Effects",    "live": true,  "kind": "volume"},
		{"key": "UI",       "label": "Interface",  "live": true,  "kind": "volume"},
		{"key": "Dialog",   "label": "Dialog",     "live": true,  "kind": "volume"},
		{"key": "fullscr",  "label": "Fullscreen", "live": false, "kind": "check"},
		{"key": "controls", "label": "Controls",   "live": false, "kind": "button"},
	]


func _ready() -> void:
	# Sized to the 640x360 art canvas, not the viewport.
	position = Vector2.ZERO
	size = Vector2(640, 360)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	# stay honest if something else changes a volume
	var snd := get_node_or_null("/root/Sound")
	if snd and snd.has_signal("volume_changed"):
		snd.volume_changed.connect(_on_external_volume)


func _build() -> void:
	var snd := get_node_or_null("/root/Sound")
	var y := content_rect.position.y + float(heading_size) + 8.0
	for row in _rows():
		var x := content_rect.position.x + label_width
		var w := content_rect.size.x - label_width
		var c: Control = null
		var live: bool = row["live"]

		match row["kind"]:
			"dropdown":
				_lang = LanguageSetting.new()
				_lang.label_text = ""
				_lang.label_min_width = 0.0
				c = _lang
			"volume":
				var sl := HSlider.new()
				sl.min_value = 0.0
				sl.max_value = 1.0
				sl.step = 0.01
				if snd:
					sl.value = snd.get_volume(row["key"])
					sl.value_changed.connect(_on_volume_changed.bind(row["key"]))
					sl.drag_ended.connect(_on_volume_released.bind(row["key"]))
				else:
					# no Sound autoload = the sliders show but are honest about being dead
					sl.value = 1.0
					live = false
				_style_slider(sl)
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
		c.mouse_filter = Control.MOUSE_FILTER_STOP if live \
				else Control.MOUSE_FILTER_IGNORE
		# A dead control is visibly dead: greyed out and unclickable
		c.modulate = Color(1, 1, 1, 1) if live else Color(1, 1, 1, 0.4)
		if not live:
			c.set_process_input(false)
		add_child(c)
		# LanguageSetting builds its own OptionButton at the default font size
		if row["kind"] == "dropdown":
			_shrink_text(c)
		_controls.append({"row": row, "node": c, "y": y})
		y += row_height + row_gap


## Ink-on-paper look for the sliders, drawn in code so it works today and swaps for art later
func _style_slider(sl: HSlider) -> void:
	var track := StyleBoxFlat.new()
	track.bg_color = Color(slider_ink, 0.35)
	track.content_margin_top = 2.0
	track.content_margin_bottom = 2.0
	var filled := StyleBoxFlat.new()
	filled.bg_color = slider_ink
	filled.content_margin_top = 2.0
	filled.content_margin_bottom = 2.0
	sl.add_theme_stylebox_override("slider", track)
	sl.add_theme_stylebox_override("grabber_area", filled)
	sl.add_theme_stylebox_override("grabber_area_highlight", filled)
	var grab := GradientTexture2D.new()
	grab.width = 6
	grab.height = 10
	var g := Gradient.new()
	g.colors = PackedColorArray([slider_ink, slider_ink])
	grab.gradient = g
	sl.add_theme_icon_override("grabber", grab)
	sl.add_theme_icon_override("grabber_highlight", grab)
	sl.add_theme_icon_override("grabber_disabled", grab)


func _on_volume_changed(value: float, category: String) -> void:
	var snd := get_node_or_null("/root/Sound")
	if snd:
		snd.set_volume(category, value)


func _on_volume_released(_moved: bool, category: String) -> void:
	var snd := get_node_or_null("/root/Sound")
	if snd == null or not snd.has_sound(preview_sound_id):
		return
	var d = snd.get_def(preview_sound_id)
	if category == "Music":
		snd.ui(preview_sound_id)  # don't stomp the actual music
	elif d:
		snd.play_stream(d.stream, category, d.volume_db)


func _on_external_volume(category: String, value: float) -> void:
	for entry in _controls:
		if entry["row"].get("kind") == "volume" and entry["row"]["key"] == category:
			var sl: HSlider = entry["node"]
			if absf(sl.value - value) >= 0.005:
				sl.set_value_no_signal(value)
			return


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


## Where a real setting would report in.
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
