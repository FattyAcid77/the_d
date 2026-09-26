class_name PcClock extends Control
## The taskbar clock. Draws the player's real hours and minutes from a 0-9
## digit strip, either side of the colon that is already in the art.

## Ten digits side by side, 0 to 9, all the same width.
@export var digits: Texture2D
## Where the colon starts, from this node's left edge.
@export var colon_x: int = 17
## How wide the colon is.
@export var colon_width: int = 2
## Pixels between the digits and the colon.
@export var colon_gap: int = 2
## Pixels between two digits.
@export var spacing: int = 1

## Set by the PC screen.
var use_24_hour: bool = false

var _hours := ""
var _minutes := ""


func _process(_delta: float) -> void:
	var t := Time.get_time_dict_from_system()
	var h: int = t.hour
	var hours := "%02d" % h
	if not use_24_hour:
		h = h % 12
		hours = str(12 if h == 0 else h)
	var minutes := "%02d" % t.minute
	if hours != _hours or minutes != _minutes:
		_hours = hours
		_minutes = minutes
		queue_redraw()


func _draw() -> void:
	if digits == null or _hours == "":
		return
	var w := int(digits.get_width() / 10.0)
	var h := digits.get_height()
	var y := floorf((size.y - h) * 0.5)
	var x := colon_x - colon_gap - _width_of(_hours, w)
	_draw_number(_hours, x, y, w, h)
	_draw_number(_minutes, colon_x + colon_width + colon_gap, y, w, h)


func _width_of(number: String, w: int) -> int:
	return number.length() * w + (number.length() - 1) * spacing


func _draw_number(number: String, x: float, y: float, w: int, h: int) -> void:
	for c in number:
		var region := Rect2(int(c) * w, 0, w, h)
		draw_texture_rect_region(digits, Rect2(x, y, w, h), region)
		x += w + spacing
