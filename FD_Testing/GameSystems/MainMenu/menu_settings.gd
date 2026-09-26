class_name MenuSettings extends Control
## The settings panel the dominoes open, and the first-run setup that walks
## the same rows one page at a time: language, volume, display. The rows are
## BoardSettings, so the menu and the Board's tab always match.

signal opened
signal closed
signal first_run_done
signal step_changed(step: int)

enum Step { LANGUAGE, VOLUME, DISPLAY }

const VOLUME_ROWS := ["Master", "Music", "Ambience", "SFX", "UI", "Dialog"]
const DISPLAY_ROWS := ["fullscreen"]
const SETTINGS_ROWS := ["language", "Master", "Music", "Ambience", "SFX", "UI", "Dialog",
		"fullscreen"]

@export_group("Art")
## The artist's settings panel, a full 640x360 image. Empty = a plain dark panel.
@export var background: Texture2D
## Where the panel sits on the art. Rows and buttons are laid out inside it.
@export var panel_rect: Rect2 = Rect2(190, 60, 260, 240)
## Space between the panel edge and its contents.
@export var margin: float = 16.0
@export var panel_color: Color = Color(0.06, 0.05, 0.04, 0.97)
@export var border_color: Color = Color(0.5, 0.4, 0.26)

@export_group("Text")
@export var heading_color: Color = Color(0.95, 0.88, 0.72)
@export var text_color: Color = Color(0.85, 0.8, 0.68)
## Sliders, check boxes and button outlines.
@export var ink_color: Color = Color(0.8, 0.68, 0.45)
@export var heading_size: int = 11
@export var label_size: int = 8
@export var row_height: float = 14.0
## Width of the word column left of the sliders.
@export var label_width: float = 80.0
## Empty = the main menu hands over its font.
@export var font: Font

@export_group("Words")
@export var settings_heading: String = "SETTINGS"
## Shown before a language is chosen, so it's written in both.
@export var language_heading: String = "Language  /  اللغة"
@export var volume_heading: String = "VOLUME"
@export var display_heading: String = "DISPLAY"
@export var back_text: String = "Back"
@export var next_text: String = "Next"
@export var done_text: String = "Done"

@export_group("Sounds")
## Played by every button on the panel.
@export var button_sound_id: String = ""

var first_run := false
var step: int = Step.LANGUAGE

var _page: Control


func _ready() -> void:
	SoundLink.attach(self)  # every signal here becomes a SoundMap moment
	layout_direction = Control.LAYOUT_DIRECTION_LTR
	position = Vector2.ZERO
	size = Vector2(640, 360)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	var loc := get_node_or_null("/root/Loc")
	if loc:
		loc.language_changed.connect(_on_language_changed)


func open_settings() -> void:
	first_run = false
	visible = true
	_build()
	opened.emit()


func start_first_run() -> void:
	first_run = true
	step = Step.LANGUAGE
	visible = true
	_build()
	opened.emit()


func close() -> void:
	if not visible:
		return
	visible = false
	_clear()
	closed.emit()


func go_to(s: int) -> void:
	step = clampi(s, Step.LANGUAGE, Step.DISPLAY)
	_build()
	step_changed.emit(step)


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event.is_action_pressed("ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	if not first_run:
		_click(close)
	elif step > Step.LANGUAGE:
		_click(go_to.bind(step - 1))


# --- pages -------------------------------------------------------------------

func _build() -> void:
	_clear()
	_page = Control.new()
	_page.layout_direction = Control.LAYOUT_DIRECTION_LTR
	_page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page.size = size
	add_child(_page)
	queue_redraw()

	if not first_run:
		_add_rows(SETTINGS_ROWS, settings_heading)
		_add_buttons([[back_text, close]])
		return
	match step:
		Step.LANGUAGE:
			_add_language_choice()
		Step.VOLUME:
			_add_rows(VOLUME_ROWS, volume_heading)
			_add_buttons([[back_text, go_to.bind(Step.LANGUAGE)], [next_text, go_to.bind(Step.DISPLAY)]])
		Step.DISPLAY:
			_add_rows(DISPLAY_ROWS, display_heading)
			_add_buttons([[back_text, go_to.bind(Step.VOLUME)], [done_text, _finish]])


func _clear() -> void:
	if _page:
		_page.queue_free()
		_page = null


func _inner() -> Rect2:
	return panel_rect.grow(-margin)


func _add_rows(keys: Array, heading: String) -> void:
	var rows := BoardSettings.new()
	rows.only_rows = PackedStringArray(keys)
	rows.content_rect = _inner()
	rows.heading = heading
	rows.footer_note = ""
	rows.row_height = row_height
	rows.label_width = label_width
	rows.heading_size = heading_size
	rows.label_size = label_size
	rows.font = font
	rows.heading_color = heading_color
	rows.label_color = text_color
	rows.rule_color = Color(ink_color, 0.35)
	rows.slider_ink = ink_color
	_page.add_child(rows)
	_focus_first(rows)


func _add_language_choice() -> void:
	var inner := _inner()
	var codes: Array = []
	var loc := get_node_or_null("/root/Loc")
	if loc:
		codes = loc.available()
	var h := row_height * 1.8
	var y := inner.position.y + heading_size + 24.0
	var first: Button = null
	for code in codes:
		var b := _button(loc.language_name(code), Rect2(inner.position.x + 30.0, y,
				inner.size.x - 60.0, h), label_size + 3)
		b.pressed.connect(_click.bind(_pick_language.bind(code)))
		if first == null:
			first = b
		y += h + 8.0
	if first:
		first.grab_focus.call_deferred()


func _pick_language(code: String) -> void:
	get_node("/root/Loc").set_language(code)
	go_to(Step.VOLUME)


func _finish() -> void:
	first_run = false
	visible = false
	_clear()
	first_run_done.emit()


## Buttons along the bottom of the panel. Back sits where reading starts, the
## way forward where it ends, so in Arabic the two swap sides.
func _add_buttons(list: Array) -> void:
	var inner := _inner()
	var w := 64.0
	var h := row_height + 2.0
	var y := inner.end.y - h
	var rtl := _is_rtl()
	for i in list.size():
		var forward := i == list.size() - 1 and list.size() > 1
		var right_side := forward != rtl
		var x := inner.end.x - w if right_side else inner.position.x
		var b := _button(list[i][0], Rect2(x, y, w, h), label_size)
		b.pressed.connect(_click.bind(list[i][1]))


func _button(text: String, rect: Rect2, text_size: int) -> Button:
	var b := Button.new()
	b.text = tr(text)
	b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	b.focus_mode = Control.FOCUS_ALL
	# placed after it's in the tree, or Arabic mirrors it off the panel
	b.layout_direction = Control.LAYOUT_DIRECTION_LTR
	_page.add_child(b)
	b.position = rect.position
	b.size = rect.size
	b.add_theme_font_size_override("font_size", text_size)
	if font:
		b.add_theme_font_override("font", font)
	for c in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
		b.add_theme_color_override(c, heading_color if c != "font_color" else text_color)
	b.add_theme_stylebox_override("normal", _box(Color(ink_color, 0.0), Color(ink_color, 0.6)))
	b.add_theme_stylebox_override("hover", _box(Color(ink_color, 0.18), ink_color))
	b.add_theme_stylebox_override("pressed", _box(Color(ink_color, 0.3), ink_color))
	b.add_theme_stylebox_override("focus", _box(Color(ink_color, 0.18), ink_color))
	return b


func _box(fill: Color, edge: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = edge
	sb.set_border_width_all(1)
	return sb


func _click(then: Callable) -> void:
	var snd := get_node_or_null("/root/Sound")
	if button_sound_id != "" and snd:
		snd.play(button_sound_id)
	then.call()


## Keyboard and controller players need something focused to start from.
func _focus_first(node: Node) -> void:
	var c := _first_focusable(node)
	if c:
		c.grab_focus.call_deferred()


func _first_focusable(node: Node) -> Control:
	for c in node.get_children():
		if c is Control and (c as Control).focus_mode == Control.FOCUS_ALL \
				and (c as Control).mouse_filter != Control.MOUSE_FILTER_IGNORE:
			return c
		var inner := _first_focusable(c)
		if inner:
			return inner
	return null


func _is_rtl() -> bool:
	var loc := get_node_or_null("/root/Loc")
	return loc != null and loc.is_rtl()


func _on_language_changed(_code: String) -> void:
	if visible and not (first_run and step == Step.LANGUAGE):
		_build()


func _draw() -> void:
	if background:
		draw_texture(background, Vector2.ZERO)
	else:
		draw_rect(panel_rect, panel_color)
		draw_rect(panel_rect, border_color, false, 1.0)
	if first_run and step == Step.LANGUAGE:
		var f := font if font else ThemeDB.fallback_font
		var inner := _inner()
		draw_string(f, Vector2(inner.position.x, inner.position.y + heading_size),
				language_heading, HORIZONTAL_ALIGNMENT_CENTER, inner.size.x, heading_size,
				heading_color)
