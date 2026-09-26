class_name ItemSocket extends Area2D
## A slot that wants one specific item: a fuse box, a keyhole, a card reader.
## Interact with the item in the Bag and it goes in; the sprite changes;
## a flag is set. Without the item, nothing happens except a sound and a
## signal you can hang a line of dialog on.
##
## The fuse box version: empty -> filled (red light) -> flickers red/green a
## few times -> green -> solved.
##
##   ItemSocket (Area2D)
##   ├── CollisionShape2D
##   ├── Sprite               AnimatedSprite2D with animations named below
##   │                        (or a Sprite2D and the three textures below)
##   └── Prompt               shown while the player is in range (optional)

signal needs_item(item_type: String)
signal inserted(item_type: String)
signal solved

@export_group("What goes in")
## The item type from its MedicalItem .tres.
@export var item_type: String = "fuse"
@export var amount: int = 1
## Take it out of the Bag when it goes in.
@export var consume: bool = true

@export_group("Flags")
## Set the moment the item goes in.
@export var inserted_flag: String = ""
## Set when the light turns green. This is the one the rest of the puzzle waits for.
@export var solved_flag: String = "fusebox_solved"
## Only works once this flag is set. Empty = always.
@export var require_flag: String = ""

@export_group("Looks (AnimatedSprite2D)")
@export var anim_empty: String = "empty"
@export var anim_red: String = "red"
@export var anim_green: String = "green"
@export_group("Looks (Sprite2D)")
@export var texture_empty: Texture2D
@export var texture_red: Texture2D
@export var texture_green: Texture2D

@export_group("The flicker")
## Red/green swaps before it settles on green. 0 = straight to green.
@export var flicker_count: int = 4
@export var flicker_seconds: float = 0.15
## Pause on red before the flicker starts.
@export var red_hold_seconds: float = 0.6

@export_group("Sounds")
## Ids from the sound library. Empty = the SoundMap entry for the moment.
@export var insert_sound_id: String = ""
@export var flicker_sound_id: String = ""
@export var solved_sound_id: String = ""
@export var missing_sound_id: String = ""

@export_group("The player")
@export var player_group: String = "Player"

var is_solved := false
var is_filled := false
var _player_in := false
var _busy := false
@onready var prompt: Node2D = get_node_or_null("Prompt")
@onready var _sprite: Node = get_node_or_null("Sprite")


func _ready() -> void:
	SoundLink.attach(self)
	body_entered.connect(_on_entered)
	body_exited.connect(_on_exited)
	if prompt:
		prompt.visible = false
	# come back from a checkpoint in the right state
	var flags := get_node_or_null("/root/Flags")
	if flags and solved_flag != "" and flags.is_set(solved_flag):
		is_filled = true
		is_solved = true
		_show("green")
	elif flags and inserted_flag != "" and flags.is_set(inserted_flag):
		is_filled = true
		_show("red")
	else:
		_show("empty")


func _process(_delta: float) -> void:
	if _busy or is_filled or not _player_in:
		return
	if InputAccess.just_pressed():
		_try_insert()


func _try_insert() -> void:
	var flags := get_node_or_null("/root/Flags")
	if flags and require_flag != "" and not flags.is_set(require_flag):
		return
	var bag := get_node_or_null("/root/Bag")
	var has: bool = bag != null and bag.has_method("has") and bag.has(item_type)
	if not has:
		_play(missing_sound_id, "ItemSocket.needs_item")
		needs_item.emit(item_type)
		return
	if consume and bag.has_method("remove"):
		bag.remove(item_type, amount)
	insert()


## Put the item in from code (a dialog action, a cutscene) - no Bag check.
func insert() -> void:
	if is_filled:
		return
	is_filled = true
	_busy = true
	var flags := get_node_or_null("/root/Flags")
	if flags and inserted_flag != "":
		flags.set_flag(inserted_flag)
	_play(insert_sound_id, "")
	inserted.emit(item_type)
	_show("red")
	await get_tree().create_timer(red_hold_seconds).timeout
	for i in flicker_count:
		_show("green" if i % 2 == 0 else "red")
		_play(flicker_sound_id, "")
		await get_tree().create_timer(flicker_seconds).timeout
	_show("green")
	is_solved = true
	_busy = false
	if flags and solved_flag != "":
		flags.set_flag(solved_flag)
	_play(solved_sound_id, "")
	solved.emit()


func _show(state: String) -> void:
	if _sprite == null:
		return
	if _sprite is AnimatedSprite2D:
		var a: String = {"empty": anim_empty, "red": anim_red, "green": anim_green}[state]
		var sp := _sprite as AnimatedSprite2D
		if sp.sprite_frames and sp.sprite_frames.has_animation(a):
			sp.play(a)
	elif _sprite is Sprite2D:
		var t: Texture2D = {"empty": texture_empty, "red": texture_red, "green": texture_green}[state]
		if t:
			(_sprite as Sprite2D).texture = t


func _play(id: String, moment: String) -> void:
	var snd := get_node_or_null("/root/Sound")
	if snd == null:
		return
	if id != "":
		snd.play_from(id, self)
	elif moment != "":
		snd.event(moment, self)


func _is_player(body: Node2D) -> bool:
	return body != null and body.is_in_group(player_group)


func _on_entered(body: Node2D) -> void:
	if _is_player(body):
		_player_in = true
		if prompt:
			prompt.visible = not is_filled


func _on_exited(body: Node2D) -> void:
	if _is_player(body):
		_player_in = false
		if prompt:
			prompt.visible = false
