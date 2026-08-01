class_name ItemPickup extends Area2D
## A medical item lying in the world. Walk over it (or press interact) and
## it goes into the existing inventory.
##
## Scene shape:
##   ItemPickup (Area2D, this script)
##   ├── CollisionShape2D
##   └── Sprite2D          (optional — auto-filled from the item's texture)
##
## NOTE: this calls the other dev's inventory to add the item. Their add
## function's name is guessed from the usual suspects; if the item doesn't
## appear, check the Output panel — it prints the method names it tried.

signal picked_up(type: String)

## Which item this is. Drag a MedicalItem .tres here.
@export var item: MedicalItem
@export var amount: int = 1

## ON = picked up by walking into it. OFF = needs the interact key.
@export var auto_pickup: bool = true

## Only exists once this flag is set. Empty = always there.
@export var require_flag: String = ""
## Gone once this flag is set (e.g. already taken in a past life).
@export var hide_flag: String = ""
## Flag set when taken.
@export var taken_flag: String = ""

var _player_in := false
@onready var sprite: Sprite2D = get_node_or_null("Sprite2D")
@onready var prompt: Node2D = get_node_or_null("Prompt")


func _ready() -> void:
	if item and sprite and sprite.texture == null:
		sprite.texture = item.texture
	body_entered.connect(_on_entered)
	body_exited.connect(_on_exited)
	if prompt:
		prompt.visible = false
	_refresh_visible()


func _process(_delta: float) -> void:
	if not visible:
		return
	if _player_in and not auto_pickup and Input.is_action_just_pressed("interact"):
		_take()


func _refresh_visible() -> void:
	var show := true
	if require_flag != "" and not Flags.is_set(require_flag):
		show = false
	if hide_flag != "" and Flags.is_set(hide_flag):
		show = false
	if taken_flag != "" and Flags.is_set(taken_flag):
		show = false
	visible = show
	set_deferred("monitoring", show)


func _take() -> void:
	if item == null:
		push_warning("ItemPickup: no MedicalItem assigned.")
		return
	if not _add_to_inventory(item.to_dict(amount)):
		return
	if taken_flag != "":
		Flags.set_flag(taken_flag)
	picked_up.emit(item.type)
	queue_free()


## Adds to the existing inventory autoload, trying the usual function names.
func _add_to_inventory(dict: Dictionary) -> bool:
	var inv := get_node_or_null("/root/inventory")
	if inv == null:
		push_warning("ItemPickup: no 'inventory' autoload found.")
		return false
	for m in ["Add_item", "add_item", "AddItem", "add", "pick_up", "collect"]:
		if inv.has_method(m):
			inv.call(m, dict)
			return true
	push_warning("ItemPickup: couldn't find an add function on the inventory. "
			+ "Tried: Add_item, add_item, AddItem, add, pick_up, collect. "
			+ "Tell me the real name and I'll wire it exactly.")
	return false


func _on_entered(body: Node2D) -> void:
	if not (body.is_in_group("Player") or body is Player):
		return
	_player_in = true
	if auto_pickup:
		_take()
	elif prompt:
		prompt.visible = true


func _on_exited(body: Node2D) -> void:
	if body.is_in_group("Player") or body is Player:
		_player_in = false
		if prompt:
			prompt.visible = false
