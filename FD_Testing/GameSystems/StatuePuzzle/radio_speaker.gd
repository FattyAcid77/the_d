class_name RadioSpeaker extends Area2D
## One of the statue's speakers. It's dead on its own — the RADIO drives it.
##
## While the player stands inside this area, the speaker follows
## RadioGlobal.radio LIVE, so tuning the radio retunes the speaker in real
## time. Walk away and it KEEPS the last frequency it was given.
##
## Scene shape:
##   RadioSpeaker (Area2D, this script)
##   ├── CollisionShape2D
##   ├── Sprite2D          (optional art)
##   ├── HzLabel (Label)   (optional — shows the tuned frequency)
##   └── Ring (Node2D)     (optional — shown while the player is inside)

signal tuned(speaker_index: int, hz: int)
signal player_entered(speaker_index: int)
signal player_exited(speaker_index: int)

## 0..3 — which speaker this is. The statue's responses refer to this.
@export var speaker_index: int = 0

## What it reads before the player has ever tuned it. -1 = silent/unset.
@export var starting_hz: int = -1

## Show the frequency on the speaker itself? (Turn off for a harder puzzle
## where the player has to remember what they set.)
@export var show_hz: bool = true

## Only follow the radio while its UI is actually open on screen.
@export var needs_radio_open: bool = true

## Frozen speakers ignore the radio (used once the puzzle is solved).
var locked: bool = false
var current_hz: int = -1
var player_inside: bool = false

@onready var hz_label: Label = get_node_or_null("HzLabel")
@onready var ring: Node2D = get_node_or_null("Ring")


func _ready() -> void:
	current_hz = starting_hz
	body_entered.connect(_on_entered)
	body_exited.connect(_on_exited)
	if ring:
		ring.visible = false
	_refresh()


func _process(_delta: float) -> void:
	if locked or not player_inside or not _radio_listening():
		return
	var radio := _radio_hz()
	if radio != current_hz:
		current_hz = radio
		_refresh()
		tuned.emit(speaker_index, current_hz)


func _radio_hz() -> int:
	if not RadioLink.available():
		return current_hz
	return RadioLink.frequency()


## The other dev's tuning keys only work while the radio UI is open (that
## script is the node reading them), so by default the speaker only listens
## then. Turn `needs_radio_open` off to let it follow the value regardless.
func _radio_listening() -> bool:
	return (not needs_radio_open) or RadioLink.is_open()


func lock() -> void:
	locked = true
	if ring:
		ring.visible = false


func _refresh() -> void:
	if hz_label:
		hz_label.visible = show_hz
		hz_label.text = ("--" if current_hz < 0 else "%d Hz" % current_hz)


func _is_player(body: Node2D) -> bool:
	return body.is_in_group("Player") or body is Player


func _on_entered(body: Node2D) -> void:
	if not _is_player(body):
		return
	player_inside = true
	if ring and not locked:
		ring.visible = true
	player_entered.emit(speaker_index)
	# take the radio's value immediately on arrival
	if not locked and _radio_listening():
		var radio := _radio_hz()
		if radio != current_hz:
			current_hz = radio
			_refresh()
			tuned.emit(speaker_index, current_hz)


func _on_exited(body: Node2D) -> void:
	if not _is_player(body):
		return
	player_inside = false
	if ring:
		ring.visible = false
	player_exited.emit(speaker_index)
