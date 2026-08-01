class_name PuzzleSpeaker extends Area2D
## One speaker of the statue puzzle. Walk up, press "interact" to cycle the
## number 1 -> 2 -> ... -> max_value -> 1. The statue (PuzzleStatue) listens
## and reacts.
##
## Scene children this script uses (all optional except the collision):
##   CollisionShape2D          player detection
##   NumberLabel (Label)       shows the current number
##   Prompt (Node2D)           shown when the player is in range
##   Hum (AudioStreamPlayer2D) played when this speaker becomes correct

signal value_changed(speaker: PuzzleSpeaker)

## Shown in editor warnings and useful for debugging (1..4 like your sketch).
@export var speaker_id: int = 1

## The number cycles 1..max_value.
@export var max_value: int = 6
@export var start_value: int = 1

## Tell settings (the statue turns these on/off through set_correct):
@export var tell_color: Color = Color(0.55, 1.0, 0.6)   ## number tint when correct
@export var hum_stream: AudioStream                       ## optional short hum

var value: int = 1
var is_correct: bool = false
var locked: bool = false          ## the statue locks speakers once solved

var _player_in: bool = false
@onready var number_label: Label = get_node_or_null("NumberLabel")
@onready var prompt: Node2D = get_node_or_null("Prompt")
@onready var hum: AudioStreamPlayer2D = get_node_or_null("Hum")
var _base_color: Color = Color.WHITE


func _ready() -> void:
	value = clampi(start_value, 1, max_value)
	if number_label:
		_base_color = number_label.get_theme_color("font_color")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if prompt:
		prompt.visible = false
	_refresh()


func _process(_delta: float) -> void:
	if locked or not _player_in:
		return
	if DialogManager.is_active:
		return
	if Input.is_action_just_pressed("interact"):
		value = (value % max_value) + 1
		_refresh()
		value_changed.emit(self)


## Called by the statue after every evaluation.
## `show_tell` mirrors the statue's per-speaker-tell setting.
func set_correct(correct: bool, show_tell: bool) -> void:
	var was := is_correct
	is_correct = correct
	if not show_tell:
		correct = false   # visuals stay neutral when tells are disabled
	if number_label:
		number_label.add_theme_color_override("font_color", tell_color if correct else _base_color)
	if correct and not was and hum and hum_stream:
		hum.stream = hum_stream
		hum.play()


func lock() -> void:
	locked = true
	if prompt:
		prompt.visible = false


func _refresh() -> void:
	if number_label:
		number_label.text = str(value)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player") or body is Player:
		_player_in = true
		if prompt and not locked:
			prompt.visible = true


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("Player") or body is Player:
		_player_in = false
		if prompt:
			prompt.visible = false
