class_name PowerLights extends CanvasLayer
## The room going dark and the lights stuttering during the run — plus the
## countdown bar and Haji's shouts (which do NOT pause the game).
##
## Drop this in the level and hand it to the ElectroPuzzle's `lights` slot.

@export_group("Flicker")
## How dark the room gets when the power is failing (1 = normal, 0 = black).
@export var dark_level: float = 0.25
## How often it stutters back to full brightness.
@export var flicker_min: float = 0.05
@export var flicker_max: float = 0.35
## Colour of the darkness.
@export var dark_color := Color(0.02, 0.02, 0.05)

@export_group("Countdown")
@export var show_timer: bool = true
@export var timer_warn_seconds: float = 10.0

var flickering: bool = false

var _dark: ColorRect
var _bar: ProgressBar
var _time_label: Label
var _callout: Label
var _callout_left: float = 0.0
var _next_flicker: float = 0.0
var _bright: bool = false
var _total: float = 1.0


func _ready() -> void:
	layer = 60
	_build()


func _build() -> void:
	_dark = ColorRect.new()
	_dark.color = dark_color
	_dark.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dark.modulate.a = 0.0
	add_child(_dark)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	box.position = Vector2(-140, 18)
	box.custom_minimum_size = Vector2(280, 0)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)

	_time_label = Label.new()
	_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_time_label.add_theme_font_size_override("font_size", 26)
	box.add_child(_time_label)

	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(280, 12)
	_bar.show_percentage = false
	_bar.max_value = 1.0
	box.add_child(_bar)

	_callout = Label.new()
	_callout.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_callout.position = Vector2(-260, -90)
	_callout.custom_minimum_size = Vector2(520, 0)
	_callout.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_callout.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_callout.add_theme_font_size_override("font_size", 20)
	_callout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_callout.visible = false
	add_child(_callout)

	_set_timer_visible(false)


func _process(delta: float) -> void:
	if _callout_left > 0.0:
		_callout_left -= delta
		if _callout_left <= 0.0:
			_callout.visible = false

	if not flickering:
		return
	_next_flicker -= delta
	if _next_flicker <= 0.0:
		_bright = not _bright
		_next_flicker = randf_range(flicker_min, flicker_max)
		_dark.modulate.a = 0.0 if _bright else (1.0 - dark_level)


# --- called by ElectroPuzzle ----------------------------------------------

func start_flicker() -> void:
	flickering = true
	_bright = false
	_next_flicker = 0.0
	_dark.modulate.a = 1.0 - dark_level
	_set_timer_visible(show_timer)


func stop_flicker() -> void:
	flickering = false
	_dark.modulate.a = 0.0
	_set_timer_visible(false)
	_callout.visible = false


## Wire ElectroPuzzle.run_started -> this
func on_run_started(seconds: float) -> void:
	_total = maxf(0.001, seconds)
	_bar.value = 1.0


## Wire ElectroPuzzle.run_tick -> this
func on_run_tick(time_left: float) -> void:
	_bar.value = clampf(time_left / _total, 0.0, 1.0)
	_time_label.text = "%0.1f" % maxf(0.0, time_left)
	var warn := time_left <= timer_warn_seconds
	_time_label.modulate = Color(1, 0.35, 0.3) if warn else Color(1, 1, 1)


## Haji shouting — appears over the game without pausing it.
func show_callout(text: String, seconds: float = 3.0) -> void:
	_callout.text = text
	_callout.visible = true
	_callout_left = seconds


func _set_timer_visible(v: bool) -> void:
	if _bar:
		_bar.visible = v
	if _time_label:
		_time_label.visible = v
