class_name WallClues extends Node2D
## Dates written on the wall. All of them random, one of them - also picked
## at random - is the one the radio wants. No tell: the player gambles. A
## wrong pick costs the mini-game; dying there restores a checkpoint, the
## scene reloads and the wall rolls fresh. reshuffle() rolls it by hand.
##
##   WallClues (Node2D)
##   ├── Slot1   Marker2D   one per date (three by default)
##   ├── Slot2   Marker2D
##   └── Slot3   Marker2D
##
## RadioCheck asks answer_frequency() for the number, so nothing is typed
## anywhere: 23 December shows as "23.12" on the radio.

signal rolled

@export_group("Art")
## Index 0..9 -> the digit PNG.
@export var digits: Array[Texture2D] = []
## Index 0..11 -> January..December.
@export var months: Array[Texture2D] = []
## Show "05" rather than "5".
@export var two_digit_days: bool = true
## Space between the digits, and between the day and the month, in pixels.
@export var digit_gap: float = 2.0
@export var month_gap: float = 8.0
@export var piece_scale: Vector2 = Vector2.ONE

@export_group("The roll")
## Days roll between 1 and this.
@export_range(1, 31) var day_max: int = 28
## Empty = on the wall from the start. Set a flag to hide it until then.
@export var reveal_flag: String = ""

@export_group("Sounds")
## Id from the sound library. Empty = the SoundMap entry for the moment.
@export var roll_sound_id: String = ""

## The dates on the wall right now, as [day, month], in slot order.
var current: Array = []
## Which slot holds the right one.
var answer_index := -1
var is_revealed := false
var _slots: Array[Node2D] = []
var _pieces: Array[Node2D] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	SoundLink.attach(self)
	_rng.randomize()
	for c in get_children():
		if c is Marker2D:
			_slots.append(c)
	var flags := get_node_or_null("/root/Flags")
	if reveal_flag == "" or (flags and flags.is_set(reveal_flag)):
		reveal()
	elif flags and flags.has_signal("flag_changed"):
		flags.flag_changed.connect(_on_flag)


func _on_flag(flag: String, value) -> void:
	if not is_revealed and flag == reveal_flag and value:
		reveal()


## The right date as the radio reads it: 23 December -> 23.12
func answer_frequency() -> float:
	if answer_index < 0 or answer_index >= current.size():
		return 0.0
	var a: Array = current[answer_index]
	return float(a[0]) + float(a[1]) / 100.0


func answer() -> Array:
	return current[answer_index] if answer_index >= 0 else []


func reveal() -> void:
	if is_revealed:
		return
	is_revealed = true
	_roll(false)


## New dates, new answer. Called on a lost mini-game with no death.
func reshuffle() -> void:
	if not is_revealed:
		return
	_roll(true)


func _roll(with_sound: bool) -> void:
	for p in _pieces:
		p.queue_free()
	_pieces.clear()
	var n := maxi(1, _slots.size())
	current = []
	while current.size() < n:
		var d := [_rng.randi_range(1, day_max), _rng.randi_range(1, 12)]
		if not current.has(d):
			current.append(d)
	answer_index = _rng.randi_range(0, n - 1)
	for i in n:
		if i < _slots.size():
			var piece := _make_piece(current[i][0], current[i][1])
			piece.position = _slots[i].position
			add_child(piece)
			_pieces.append(piece)
	if with_sound:
		var snd := get_node_or_null("/root/Sound")
		if snd and roll_sound_id != "":
			snd.play_from(roll_sound_id, self)
	rolled.emit()


func _make_piece(day: int, month: int) -> Node2D:
	var root := Node2D.new()
	root.scale = piece_scale
	var x := 0.0
	var day_text := ("%02d" % day) if two_digit_days else str(day)
	for ch in day_text:
		var n := int(ch)
		if n < digits.size() and digits[n]:
			var s := Sprite2D.new()
			s.texture = digits[n]
			s.centered = false
			s.position.x = x
			root.add_child(s)
			x += digits[n].get_width() + digit_gap
	x += month_gap - digit_gap
	var m := month - 1
	if m >= 0 and m < months.size() and months[m]:
		var ms := Sprite2D.new()
		ms.texture = months[m]
		ms.centered = false
		ms.position.x = x
		root.add_child(ms)
	return root
