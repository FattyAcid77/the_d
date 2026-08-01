extends Node
## MedicalItems — add as an Autoload named "MedicalItems".
## Turns inventory items into medical effects: bandages stop the bleeding,
## a scalpel opens a wound so Sami can bleed on purpose for the blood puzzle.
##
## ============================================================
## ONE LINE TO ADD IN THE OTHER DEV'S inventory.gd
## ============================================================
## Their `use_item(item)` is what the Use button calls. Add this as the
## FIRST line of that function:
##
##     func use_item(item):
##         if MedicalItems.use(item): return     # <-- add this line
##         ...their existing code...
##
## That's the only change needed anywhere in their code. `use()` returns
## true when it recognised and handled the item, false otherwise — so all
## their own items keep working exactly as before.
##
## (If their inventory emits a signal when an item is used, connect that to
## MedicalItems.use instead and you don't have to touch their file at all.)

signal item_used(type: String)
signal bandage_used
signal cut_used

## All MedicalItem .tres files live here and are loaded automatically.
const ITEMS_DIR := "res://FD_Testing/GameSystems/Items"

## Remove one from the inventory after a successful use?
## Their inventory may already do this — if items vanish twice, turn it OFF.
@export var consume_on_use: bool = true

## Prints what happened, useful while wiring this up.
@export var debug_log: bool = true

var items: Array[MedicalItem] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_items()


func _load_items() -> void:
	items.clear()
	var dir := DirAccess.open(ITEMS_DIR)
	if dir == null:
		return
	for file in dir.get_files():
		if file.get_extension() == "tres" or file.get_extension() == "res":
			var r := load(ITEMS_DIR + "/" + file)
			if r is MedicalItem:
				items.append(r)


## Look up a definition by its `type` string.
func get_item(type: String) -> MedicalItem:
	for i in items:
		if i.type == type:
			return i
	return null


# ==========================================================================
# the hook
# ==========================================================================

## Call this with an inventory item Dictionary.
## Returns TRUE if it was a medical item and the effect was applied.
func use(item) -> bool:
	if item == null or not (item is Dictionary):
		return false
	var type: String = str(item.get("type", ""))
	var def := get_item(type)
	if def == null:
		return false                     # not one of ours — let their code run
	var applied := _apply(def)
	if applied:
		if def.use_flag != "":
			Flags.set_flag(def.use_flag)
		item_used.emit(type)
		if consume_on_use:
			_consume(item)
	return applied


func _apply(def: MedicalItem) -> bool:
	var wounds := _wounds()
	match def.action:
		MedicalItem.MedAction.BANDAGE:
			if wounds == null:
				return false
			if not wounds.is_bleeding:
				if debug_log:
					print("MedicalItems: '%s' used but nothing is bleeding." % def.display_name)
				return false             # don't waste it
			wounds.bandage()
			bandage_used.emit()
			if debug_log:
				print("MedicalItems: bandaged — bleeding stopped.")
			return true
		MedicalItem.MedAction.CUT:
			if wounds == null:
				return false
			wounds.cut(def.cut_cause)
			cut_used.emit()
			if debug_log:
				print("MedicalItems: cut opened — Sami is bleeding on purpose.")
			return true
		MedicalItem.MedAction.HEAL:
			if wounds == null:
				return false
			wounds.heal(def.heal_amount)
			return true
		MedicalItem.MedAction.FULL_HEAL:
			if wounds == null:
				return false
			wounds.full_heal()
			return true
		_:
			return false


## Finds Sami's Wounds component.
func _wounds() -> Node:
	var p := get_tree().get_first_node_in_group("Player")
	if p == null:
		push_warning("MedicalItems: no node in the 'Player' group.")
		return null
	var w := p.get_node_or_null("Wounds")
	if w == null:
		push_warning("MedicalItems: Sami has no 'Wounds' child (WoundComponent).")
	return w


## Takes one off the stack using the existing inventory's own function.
##
## IMPORTANT: this is DEFERRED on purpose. use_item() is called from the
## slot's Use button, and removing an item rebuilds the whole grid — which
## queue_free()s the very slot whose button handler is still running. Doing
## it immediately crashes with "instance is null / freed". Deferring lets
## their button handler finish first, then the grid rebuilds safely.
func _consume(item: Dictionary) -> void:
	var inv := get_node_or_null("/root/inventory")
	if inv == null:
		return
	var type_v = item.get("type", "")
	var effect_v = item.get("effect", "")
	if inv.has_method("Remove_item"):
		inv.call_deferred("Remove_item", type_v, effect_v)
	elif inv.has_method("remove_item"):
		inv.call_deferred("remove_item", type_v, effect_v)
	else:
		push_warning("MedicalItems: inventory has no Remove_item() — "
				+ "turn OFF consume_on_use and let their code handle it.")
