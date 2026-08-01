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

@export_group("Numbers")
## For HEAL / FULL_HEAL.
@export var heal_amount: float = 1.0
## For CUT: which DeathCause is blamed if this bleeding kills him.
@export var cut_cause: String = "bleeding"
## Flag set the first time it's used (dialog can react to it).
@export var use_flag: String = ""


## Builds the exact Dictionary the existing inventory expects.
func to_dict(amount: int = -1) -> Dictionary:
	return {
		"texture": texture,
		"quantity": amount if amount > 0 else quantity,
		"name": display_name,
		"type": type,
		"effect": effect,
	}
