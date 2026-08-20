class_name MedicalItem extends Resource
## Defines a medical item (bandage, scalpel...) in a way the EXISTING
## inventory understands. That inventory stores items as Dictionaries with
## the keys: texture / quantity / name / type / effect — `to_dict()` builds
## exactly that shape, so nothing in their code has to change.
##
## Make one .tres per item in GameSystems/Items/.

## What it does when used. This is the part MedicalItems acts on.
## Named MedAction rather than Action — 'Action' is a common global
## class/enum name and would collide across a shared project.
enum MedAction {
	NOTHING,       ## just an object
	BANDAGE,       ## stops the bleeding
	CUT,           ## opens a wound so Sami bleeds on purpose
	HEAL,          ## gives health back
	FULL_HEAL,     ## health back AND stops the bleeding
}

@export var action: MedAction = MedAction.NOTHING

@export_group("Inventory fields")
## Shown in the slot. Also what MedicalItems matches on — keep it unique.
@export var type: String = "bandage"
## Shown in the slot. (Called display_name, not `name`, because `name` is a
## loaded word on Godot objects — the dictionary key is still "name".)
@export var display_name: String = "Bandage"
## The inventory's `effect` text (shown in the details panel).
@export var effect: String = "Stops bleeding"
@export var texture: Texture2D
@export var quantity: int = 1

## HOW MANY FIT IN ONE SLOT. This is the field that makes items stack.
##   1   never stacks — every one takes a whole slot (right for an axe)
##   10  ten bandages sit in one slot with a little "10" in the corner
## Leaving it at 1 is why five bandages would fill five boxes.
@export var max_stack: int = 1

## ON = this only ever goes in one of the two BIG slots at the bottom of the
## bag. For the main things he carries — the axe, the radio.
@export var needs_big_slot: bool = false

## The line shown under the name when the mouse hovers over it in the bag.
## Leave empty and `effect` is used instead.
@export_multiline var description: String = ""

@export_group("How it looks ON SAMI (the avatar paperdoll)")
## The overlay drawn on Sami in the inventory board when he's carrying this.
## Author it on the SAME 640x360 canvas as the avatar — put the axe where
## the axe goes, the radio on his belt — and it lines up by itself. No
## positioning needed anywhere.
##
## Drawn ONCE however many he's carrying: three bandages, one bandage on Sami.
@export var avatar_layer: Texture2D

## Stacking order, low drawn first. Sami's body is 0, so:
##   -10  behind him   (the axe on his back)
##     5  on his front (the radio on his belt)
##    10  in front     (the cigarette in his mouth)
@export var avatar_order: int = 5


@export_group("How it looks in the world")
## THE FIX FOR SCALING. Set the size HERE, on the item, and every ItemPickup
## in every level that uses this .tres gets it automatically — you never
## touch the Sprite2D node again.
##
## HOW TO CHOOSE:
##   world_size_px  — the reliable one. "Make this item N pixels tall on
##                    screen, whatever the source image happens to be."
##                    A 512px scalpel and a 32px bandage both come out right.
##   world_scale    — the raw multiplier, used only when world_size_px is 0.
##
## Leave world_size_px at 0 and world_scale at (1,1) to keep whatever the
## Sprite2D node in the scene is already set to.
@export var world_size_px: float = 0.0
## Plain multiplier. Ignored unless world_size_px is 0.
@export var world_scale: Vector2 = Vector2.ONE
## Nudge the sprite off the pickup's origin (e.g. lift it off the floor).
@export var world_offset: Vector2 = Vector2.ZERO
## Pixel art stays crisp. Turn OFF for smooth/photographic art.
@export var pixel_perfect: bool = true
## Tint the world sprite (the inventory icon is untouched).
@export var world_modulate: Color = Color(1, 1, 1, 1)


@export_group("Numbers")
## For HEAL / FULL_HEAL.
@export var heal_amount: float = 1.0
## For CUT: which DeathCause is blamed if this bleeding kills him.
@export var cut_cause: String = "bleeding"
## Flag set the first time it's used (dialog can react to it).
@export var use_flag: String = ""

## Flag raised the moment this item is PICKED UP, anywhere in the game.
## Set it here on the .tres and every ItemPickup using this item raises it —
## you don't have to remember to fill it in on each pickup node.
## Dialog branches, windows and blockers can all read it.
@export var pickup_flag: String = ""

## Flag raised only the FIRST time it's ever picked up. Leave empty to skip.
## Use this for "he has seen a scalpel before" story memory, when pickup_flag
## is being cleared and reused.
@export var first_pickup_flag: String = ""


## Builds the exact Dictionary the existing inventory expects.
func to_dict(amount: int = -1) -> Dictionary:
	return {
		"texture": texture,
		"quantity": amount if amount > 0 else quantity,
		"name": tr(display_name),
		"type": type,
		"effect": tr(effect),
	}


## Works out the Sprite2D scale for this item, given its texture.
## ItemPickup calls this — you don't need to.
func sprite_scale() -> Vector2:
	if world_size_px > 0.0 and texture != null:
		var h := float(texture.get_height())
		if h > 0.0:
			var f := world_size_px / h
			return Vector2(f, f)
	return world_scale


## The words shown in the hover tooltip. Falls back to `effect` so old
## items that predate `description` still say something useful.
func tooltip_text() -> String:
	return description if description.strip_edges() != "" else effect
