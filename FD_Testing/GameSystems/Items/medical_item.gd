class_name MedicalItem extends Resource
## Defines a medical item (bandage, scalpel...) in a way the existing
## inventory understands. That inventory stores items as Dictionaries with the
## keys: texture / quantity / name / type / effect - `to_dict()` builds
## exactly that shape, so nothing in their code has to change.

enum MedAction {
	NOTHING,  # just an object
	BANDAGE,  # stops the bleeding
	CUT,  # opens a wound so Sami bleeds
	HEAL,  # gives health back
	FULL_HEAL,  # health back and stops the bleeding
}

@export var action: MedAction = MedAction.NOTHING

@export_group("Inventory fields")
## Shown in the slot.
@export var type: String = "bandage"
## Shown in the slot.
@export var display_name: String = "Bandage"
## The inventory's `effect` text (shown in the details panel).
@export var effect: String = "Stops bleeding"
@export var texture: Texture2D
@export var quantity: int = 1

## how many fit in one slot.
@export var max_stack: int = 1

## on = this only ever goes in one of the two big slots at the bottom of the bag.
@export var needs_big_slot: bool = false

## The line shown under the name when the mouse hovers over it in the bag.
@export_multiline var description: String = ""

@export_group("How it looks ON SAMI (the avatar paperdoll)")
## The overlay drawn on Sami in the inventory board when he's carrying this.
@export var avatar_layer: Texture2D

## Stacking order, low drawn first.
@export var avatar_order: int = 5


@export_group("How it looks in the world")
## the fix for scaling.
@export var world_size_px: float = 0.0
## Plain multiplier.
@export var world_scale: Vector2 = Vector2.ONE
## Nudge the sprite off the pickup's origin (e.g.
@export var world_offset: Vector2 = Vector2.ZERO
## Pixel art stays crisp.
@export var pixel_perfect: bool = true
## Tint the world sprite (the inventory icon is untouched).
@export var world_modulate: Color = Color(1, 1, 1, 1)


@export_group("Sounds")
## Played when this item is picked up.
@export var pickup_sound_id: String = ""
## Played when this item is used.
@export var use_sound_id: String = ""

@export_group("Numbers")
## For heal / FULL_HEAL.
@export var heal_amount: float = 1.0
## For cut: which DeathCause is blamed if this bleeding kills him.
@export var cut_cause: String = "bleeding"
## Flag set the first time it's used (dialog can react to it).
@export var use_flag: String = ""

## Flag raised the moment this item is picked up, anywhere in the game.
@export var pickup_flag: String = ""

## Flag raised only the first time it's ever picked up.
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
func sprite_scale() -> Vector2:
	if world_size_px > 0.0 and texture != null:
		var h := float(texture.get_height())
		if h > 0.0:
			var f := world_size_px / h
			return Vector2(f, f)
	return world_scale


## The words shown in the hover tooltip.
func tooltip_text() -> String:
	return description if description.strip_edges() != "" else effect
