class_name RadioSpeaker extends Area2D
## One of the statue's speakers. It's dead on its own - the radio drives it.

signal tuned(speaker_index: int, hz: int)
signal player_entered(speaker_index: int)
signal player_exited(speaker_index: int)

## 0..3 - which speaker this is.
@export var speaker_index: int = 0

## What it reads before the player has ever tuned it.
@export var starting_hz: int = -1

## Show the frequency on the speaker itself?
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
	SoundLink.attach(self)  # every signal here becomes a SoundMap moment
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


## The other dev's tuning keys only work while the radio UI is open
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
