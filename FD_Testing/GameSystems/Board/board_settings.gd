class_name BoardSettings extends Control
## Settings page: language dropdown, the six volume sliders and fullscreen,
## drawn on the 640x360 art canvas. The Board's tab and the main menu both use
## it. The controls row is a placeholder.

@export_group("Where it sits on the 640x360 canvas")
## The usable area inside the clipboard.
@export var content_rect: Rect2 = Rect2(248, 96, 150, 190)
@export var row_height: float = 13.0
@export var row_gap: float = 4.0
@export var label_width: float = 62.0

@export_group("Words")
@export var heading: String = "SETTINGS"
@export var footer_note: String = "Controls are not wired up yet."
@export var heading_size: int = 10
@export var label_size: int = 7
@export var note_size: int = 6
@export var font: Font

@export_group("Rows")
## Show only these rows, by key (language, Master, Music, Ambience, SFX, UI, Dialog, fullscreen, controls). Empty shows all.
@export var only_rows: PackedStringArray = []

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
		{"key": "fullscreen", "label": "Fullscreen", "live": true, "kind": "check"},
		{"key": "controls", "label": "Controls",   "live": false, "kind": "button"},
	]


func _ready() -> void:
	# Sized to the 640x360 art canvas, not the viewport.
	layout_direction = Control.LAYOUT_DIRECTION_LTR
	position = Vector2.ZERO
	size = Vector2(640, 360)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	# stay honest if something else changes a volume
	var snd := get_node_or_null("/root/Sound")
	if snd and snd.has_signal("volume_changed"):
		snd.volume_changed.connect(_on_external_volume)
	var prof := get_node_or_null("/root/Profile")
	if prof:
		prof.display_changed.connect(_on_display_changed)


func _build() -> void:
	var snd := get_node_or_null("/root/Sound")
	var prof := get_node_or_null("/root/Profile")
	var y := content_rect.position.y + float(heading_size) + 8.0
	for row in _rows():
		if not only_rows.is_empty() and not only_rows.has(row["key"]):
			continue
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
				if prof:
					cb.button_pressed = prof.call(row["key"])
					cb.toggled.connect(_on_check_toggled.bind(row["key"]))
				else:
					live = false
				_style_check(cb)
				c = cb
			"button":
				var b := Button.new()
				b.text = tr("Not yet")
				b.add_theme_font_size_override("font_size", label_size)
				c = b

		if c == null:
			y += row_height + row_gap
			continue

		# into the tree first, then placed: a button made off-tree has already
		# cached the window's direction, and in Arabic its position gets mirrored
		# off-canvas even with LTR set on it
		c.layout_direction = Control.LAYOUT_DIRECTION_LTR
		add_child(c)
		c.position = Vector2(x, y)
		c.size = Vector2(w, row_height)
		c.mouse_filter = Control.MOUSE_FILTER_STOP if live \
				else Control.MOUSE_FILTER_IGNORE
		# A dead control is visibly dead: greyed out and unclickable
		c.modulate = Color(1, 1, 1, 1) if live else Color(1, 1, 1, 0.4)
		if not live:
			c.set_process_input(false)
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


## Same ink as the sliders: an empty box, filled when on
func _style_check(cb: CheckBox) -> void:
	var side := int(row_height) - 5
	var off := Image.create(side, side, false, Image.FORMAT_RGBA8)
	var on := Image.create(side, side, false, Image.FORMAT_RGBA8)
	for py in side:
		for px in side:
			var edge := px == 0 or py == 0 or px == side - 1 or py == side - 1
			var inner := px > 1 and py > 1 and px < side - 2 and py < side - 2
			off.set_pixel(px, py, slider_ink if edge else Color(0, 0, 0, 0))
			on.set_pixel(px, py, slider_ink if edge or inner else Color(0, 0, 0, 0))
	var off_tex := ImageTexture.create_from_image(off)
	var on_tex := ImageTexture.create_from_image(on)
	for icon in ["unchecked", "unchecked_disabled"]:
		cb.add_theme_icon_override(icon, off_tex)
	for icon in ["checked", "checked_disabled"]:
		cb.add_theme_icon_override(icon, on_tex)
	var empty := StyleBoxEmpty.new()
	for box in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
		cb.add_theme_stylebox_override(box, empty)


func _on_check_toggled(on: bool, key: String) -> void:
	var prof := get_node_or_null("/root/Profile")
	if prof:
		prof.call("set_" + key, on)


func _on_display_changed() -> void:
	var prof := get_node_or_null("/root/Profile")
	for entry in _controls:
		if entry["row"]["kind"] == "check" and prof:
			(entry["node"] as CheckBox).set_pressed_no_signal(prof.call(entry["row"]["key"]))


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


func _is_rtl() -> bool:
	var loc := get_node_or_null("/root/Loc")
	return loc != null and loc.has_method("is_rtl") and loc.is_rtl(loc.current())


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

	var rtl := _is_rtl()
	for entry in _controls:
		var row: Dictionary = entry["row"]
		var y: float = entry["y"]
		var col: Color = label_color if row["live"] else dead_color
		# Arabic reads toward the slider, so its label sits against it
		draw_string(f, Vector2(content_rect.position.x, y + row_height * 0.72),
				tr(row["label"]),
				HORIZONTAL_ALIGNMENT_RIGHT if rtl else HORIZONTAL_ALIGNMENT_LEFT,
				label_width - 4.0, label_size, col)

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
