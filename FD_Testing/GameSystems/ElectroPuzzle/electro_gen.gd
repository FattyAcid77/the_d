class_name ElectroGen extends Area2D
## One electro generator. Walk up, press interact, flip the switch.
##
## The first three (order 0, 1, 2) must be flipped in the RIGHT ORDER. Get
## it wrong and the whole sequence resets with a buzz. Get all three and the
## countdown to the MAIN generator begins.
##
## Scene shape:
##   ElectroGen (Area2D, this script)
##   ├── CollisionShape2D
##   ├── Sprite (AnimatedSprite2D)   optional — anim_off / anim_on / anim_blown
##   ├── Light (Node2D)              optional — shown while it's on
##   └── Prompt (Node2D)             optional — shown when the player is near

signal flipped(gen: ElectroGen)
signal blown(gen: ElectroGen)

## Where this sits in the sequence: 0, 1, 2 for the three switches.
## Set `is_main` instead for the final generator.
@export var order_index: int = 0

## The MAIN generator — the one at the end of the timed run. It ignores
## order_index and can only be used once the run has started.
@export var is_main: bool = false

## Which floor it's on (1, 2, 3). Only for your own bookkeeping / UI.
@export var floor_number: int = 1

@export_group("Main generator only")
## If > 0, the main gen needs the RADIO tuned to this frequency to blow.
## 0 = just press interact. (Must be a multiple of 10, 530..1700.)
@export_range(0, 1700, 10) var required_hz: int = 0
## How close the radio has to be.
@export var hz_tolerance: int = 0

@export_group("Look")
@export var sprite: AnimatedSprite2D
@export var anim_off: String = "off"
@export var anim_on: String = "on"
@export var anim_blown: String = "blown"

var is_on: bool = false
var is_blown: bool = false
var _player_in: bool = false

@onready var light: Node2D = get_node_or_null("Light")
@onready var prompt: Node2D = get_node_or_null("Prompt")


func _ready() -> void:
	body_entered.connect(_on_entered)
	body_exited.connect(_on_exited)
	if prompt:
		prompt.visible = false
	_refresh()


func _process(_delta: float) -> void:
	if not _player_in or is_blown or DialogManager.is_active:
		return
	if InputAccess.just_pressed():
		flip()


## Flip the switch. The puzzle manager decides whether it counted.
func flip() -> void:
	if is_blown:
		return
	is_on = true
	_refresh()
	flipped.emit(self)


## Reset back to off (the manager calls this on a wrong order).
func reset_switch() -> void:
	if is_blown:
		return
	is_on = false
	_refresh()


## Blow it up for good.
func blow() -> void:
	is_blown = true
	is_on = false
	if prompt:
		prompt.visible = false
	_refresh()
	blown.emit(self)


## Is the radio currently tuned close enough to set this one off?
func radio_ok() -> bool:
	if required_hz <= 0:
		return true
	if not RadioLink.available():
		return false
	return RadioLink.is_tuned_to(required_hz, hz_tolerance)


func _refresh() -> void:
	if light:
		light.visible = is_on and not is_blown
	if sprite and sprite.sprite_frames:
		var want := anim_blown if is_blown else (anim_on if is_on else anim_off)
		if sprite.sprite_frames.has_animation(want) and sprite.animation != want:
			sprite.play(want)


func _is_player(body: Node2D) -> bool:
	return body.is_in_group("Player") or body is Player


func _on_entered(body: Node2D) -> void:
	if _is_player(body):
		_player_in = true
		if prompt and not is_blown:
			prompt.visible = true


func _on_exited(body: Node2D) -> void:
	if _is_player(body):
		_player_in = false
		if prompt:
			prompt.visible = false
