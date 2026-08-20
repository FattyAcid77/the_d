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

@export_group("Look")
## Take the sprite's texture AND its size from the MedicalItem .tres.
## This is what makes scaling work from the resource. Turn it OFF only if
## you want to hand-place a special one-off sprite in this scene.
@export var use_item_look: bool = true
## Extra per-pickup multiplier ON TOP of the item's size, for the odd
## "this one giant scalpel" moment. Leave at 1 normally.
@export var extra_scale: Vector2 = Vector2.ONE
## If there is no Sprite2D child, make one automatically.
@export var create_sprite_if_missing: bool = true

@export_group("Flags")
## Always raise a flag named "item:<type>" on pickup, e.g. "item:bandage".
## Costs nothing and means dialog can check for any item without you having
## to name a flag first.
@export var auto_type_flag: bool = true

## Only exists once this flag is set. Empty = always there.
@export var require_flag: String = ""
## Gone once this flag is set (e.g. already taken in a past life).
@export var hide_flag: String = ""
## Flag set when taken.
@export var taken_flag: String = ""

var _player_in := false
var sprite: Sprite2D = null
@onready var prompt: Node2D = get_node_or_null("Prompt")


func _ready() -> void:
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
##
## THE OLD BUG: the texture was copied from the item but the SCALE was left
## to whatever the Sprite2D node happened to be set to in that scene. So the
## same item looked different in every level, and any item whose source image
## wasn't the same pixel size as the placeholder came out wrong. Everything
## visual now comes from the .tres.
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


## Re-reads the item's look at runtime. Call it after swapping `item`.
func refresh_look() -> void:
	_apply_look()


func _refresh_visible() -> void:
	var should_show := true
	if require_flag != "" and not Flags.is_set(require_flag):
		should_show = false
	if hide_flag != "" and Flags.is_set(hide_flag):
		should_show = false
	if taken_flag != "" and Flags.is_set(taken_flag):
		should_show = false
	visible = should_show
	set_deferred("monitoring", should_show)


func _take() -> void:
	if item == null:
		push_warning("ItemPickup: no MedicalItem assigned.")
		return
	# THE BAG IS THE INVENTORY NOW. A full bag refuses the item and it stays
	# on the floor — nothing disappears into nowhere.
	var bag := get_node_or_null("/root/Bag")
	if bag:
		if bag.add(item, amount) <= 0:
			return                      # full: leave it where it is
	elif not _add_to_inventory(item.to_dict(amount)):
		return
	# 1. this particular pickup node's own flag (per-level)
	if taken_flag != "":
		Flags.set_flag(taken_flag)

	# 2. the item's own flags. Bag raises these itself when it accepts an
	#    item, so this only runs when there's no Bag autoload.
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
