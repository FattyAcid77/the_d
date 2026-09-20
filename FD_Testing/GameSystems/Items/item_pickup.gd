class_name ItemPickup extends Area2D
## A medical item lying in the world. Walk over it (or press interact) and it
## goes into the existing inventory.

signal picked_up(type: String)

## Which item this is.
@export var item: MedicalItem
@export var amount: int = 1

## on = picked up by walking into it.
@export var auto_pickup: bool = true

@export_group("Look")
## Take the sprite's texture and its size from the MedicalItem .tres.
@export var use_item_look: bool = true
## Extra per-pickup multiplier on top of the item's size
@export var extra_scale: Vector2 = Vector2.ONE
## If there is no Sprite2D child, make one automatically.
@export var create_sprite_if_missing: bool = true

@export_group("Flags")
## Always raise a flag named "item:<type>" on pickup, e.g.
@export var auto_type_flag: bool = true

## Only exists once this flag is set.
@export var require_flag: String = ""
## Gone once this flag is set (e.g.
@export var hide_flag: String = ""
## Flag set when taken.
@export var taken_flag: String = ""

var _player_in := false
var sprite: Sprite2D = null
@onready var prompt: Node2D = get_node_or_null("Prompt")


func _ready() -> void:
	SoundLink.attach(self)  # every signal here becomes a SoundMap moment
	sprite = get_node_or_null("Sprite2D")
	_apply_look()
	body_entered.connect(_on_entered)
	body_exited.connect(_on_exited)
	if prompt:
		prompt.visible = false
	_refresh_visible()


func _process(_delta: float) -> void:
	if not visible:
		return
	if _player_in and not auto_pickup and InputAccess.just_pressed():
		_take()


## Pulls texture, scale, offset, filtering and tint off the MedicalItem.
func _apply_look() -> void:
	if not use_item_look or item == null:
		return

	if sprite == null and create_sprite_if_missing:
		sprite = Sprite2D.new()
		sprite.name = "Sprite2D"
		add_child(sprite)

	if sprite == null:
		return

	if item.texture != null:
		sprite.texture = item.texture

	sprite.scale = item.sprite_scale() * extra_scale
	sprite.position = item.world_offset
	sprite.modulate = item.world_modulate
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if item.pixel_perfect \
			else CanvasItem.TEXTURE_FILTER_LINEAR


## Re-reads the item's look at runtime.
func refresh_look() -> void:
	_apply_look()


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
	# the bag is the inventory now.
	var bag := get_node_or_null("/root/Bag")
	if bag:
		if bag.add(item, amount) <= 0:
			return  # full: leave it where it is
	elif not _add_to_inventory(item.to_dict(amount)):
		return
	# 1. this particular pickup node's own flag (per-level)
	if taken_flag != "":
		Flags.set_flag(taken_flag)

	# 2.
	if bag == null:
		if item.pickup_flag != "":
			Flags.set_flag(item.pickup_flag)
		if item.first_pickup_flag != "" and not Flags.is_set(item.first_pickup_flag):
			Flags.set_flag(item.first_pickup_flag)
		if auto_type_flag and item.type != "":
			Flags.set_flag("item:" + item.type)

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
