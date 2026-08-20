extends Node
## Bag — the inventory. Add as an Autoload named "Bag".
##
## WHY IT'S CALLED "Bag" AND NOT "Inventory"
## The other developer already has an autoload called `inventory`. Naming
## this one `Inventory` would put two nearly identical names in the same
## project and we'd be chasing that mix-up for months. `Bag` can never be
## confused with theirs. Their system is left completely alone.
##
## WHAT IT HOLDS
## A fixed grid of slots (5 x 5 by default = 25). Each slot holds one kind
## of MedicalItem and a count. Items that can stack pile up in one slot;
## items that can't take a slot each.
##
## WHEN IT'S FULL, PICKUPS FAIL. Walk over an item with a full bag and it
## stays on the floor, exactly as you asked.
##
##     Bag.add(item)              -> how many actually went in
##     Bag.has("bandage")         -> true / false
##     Bag.count_of("bandage")    -> 3
##     Bag.use_slot(4)
##     Bag.drop_slot(4)
##     Bag.unique_items()         -> one of each, for drawing the avatar

signal changed                                   ## anything at all moved
signal item_added(type: String, amount: int)
signal item_removed(type: String, amount: int)
signal bag_full(type: String)                    ## a pickup was refused
signal item_used(type: String)

@export_group("Size")
## The SMALL slots at the top, matching the art: 4 across, 3 down.
@export var columns: int = 4
@export var rows: int = 3

## The BIG slots underneath, for the main things he carries (the axe, the
## radio). These are the LAST slots in the list, so with 4x3 above them
## slot 12 is the left big one and slot 13 is the right big one.
@export var big_slots: int = 2

@export_group("Dropping")
## What a dropped item becomes in the world. Leave empty and one is built
## in code (an Area2D with the ItemPickup script), which is usually fine.
@export var pickup_scene: PackedScene
## How far in front of Sami a dropped item lands.
@export var drop_distance: float = 24.0
## Which group Sami is in, so dropping knows where to put things.
@export var player_group: String = "Player"

@export_group("Debug")
@export var debug_log: bool = false

## One entry per slot: either null, or {"item": MedicalItem, "count": int}.
var slots: Array = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_resize()


func _resize() -> void:
	var want := slot_count()
	slots.resize(want)
	for i in want:
		if not (slots[i] is Dictionary):
			slots[i] = null


func slot_count() -> int:
	return columns * rows + big_slots


## How many of the small slots there are. Anything at or past this index is
## one of the big ones.
func small_count() -> int:
	return columns * rows


func is_big_slot(i: int) -> bool:
	return i >= small_count() and i < slot_count()


# --- reading ---------------------------------------------------------------

func is_empty_slot(i: int) -> bool:
	return i < 0 or i >= slots.size() or slots[i] == null


func item_at(i: int) -> MedicalItem:
	if is_empty_slot(i):
		return null
	return slots[i]["item"]


func count_at(i: int) -> int:
	if is_empty_slot(i):
		return 0
	return int(slots[i]["count"])


func has(type: String) -> bool:
	return count_of(type) > 0


func count_of(type: String) -> int:
	var n := 0
	for s in slots:
		if s != null and s["item"] and s["item"].type == type:
			n += int(s["count"])
	return n


## One of each KIND of item currently held, sorted by avatar_order.
## This is what the avatar paperdoll draws — a stack of three bandages
## still puts exactly one bandage on Sami.
func unique_items() -> Array[MedicalItem]:
	var out: Array[MedicalItem] = []
	var seen := {}
	for s in slots:
		if s == null or s["item"] == null:
			continue
		var it: MedicalItem = s["item"]
		if seen.has(it.type):
			continue
		seen[it.type] = true
		out.append(it)
	out.sort_custom(func(a, b): return a.avatar_order < b.avatar_order)
	return out


## Every filled slot as {index, item, count}. For the grid.
func filled() -> Array:
	var out := []
	for i in slots.size():
		if slots[i] != null:
			out.append({"index": i, "item": slots[i]["item"], "count": slots[i]["count"]})
	return out


func is_full() -> bool:
	for s in slots:
		if s == null:
			return false
	return true


# --- adding ----------------------------------------------------------------

## Could this many fit right now? Used by ItemPickup before it disappears.
func can_add(item: MedicalItem, amount: int = 1) -> bool:
	return _room_for(item) >= amount


func _room_for(item: MedicalItem) -> int:
	if item == null:
		return 0
	var room := 0
	var cap: int = maxi(1, item.max_stack)
	for i in _slot_order(item):
		var sl = slots[i]
		if sl == null:
			room += cap
		elif sl["item"] and sl["item"].type == item.type:
			room += maxi(0, cap - int(sl["count"]))
	return room


## Which slots this item may use, in the order it should try them.
func _slot_order(item: MedicalItem) -> Array:
	var small := small_count()
	var order: Array = []
	if item and item.needs_big_slot:
		for i in range(small, slot_count()):
			order.append(i)            # big slots only
		return order
	for i in small:
		order.append(i)                # small first
	for i in range(small, slot_count()):
		order.append(i)                # then big, only if it has to
	return order


## Puts items in. Returns HOW MANY ACTUALLY WENT IN — 0 means the bag was
## full and the item should stay on the floor.
func add(item: MedicalItem, amount: int = 1) -> int:
	if item == null or amount <= 0:
		return 0

	var cap: int = maxi(1, item.max_stack)
	var left := amount

	# top up existing stacks first
	if cap > 1:
		for i in slots.size():
			if left <= 0:
				break
			if slots[i] != null and slots[i]["item"] and slots[i]["item"].type == item.type:
				var space: int = cap - int(slots[i]["count"])
				if space > 0:
					var put: int = mini(space, left)
					slots[i]["count"] = int(slots[i]["count"]) + put
					left -= put

	# then empty slots. An item marked `needs_big_slot` ONLY goes in a big
	# one; everything else fills the small slots first and only spills into
	# the big ones if the small ones are full, so the two big slots stay
	# free for the things that matter.
	for i in _slot_order(item):
		if left <= 0:
			break
		if slots[i] == null:
			var put2: int = mini(cap, left)
			slots[i] = {"item": item, "count": put2}
			left -= put2

	var added := amount - left

	if added > 0:
		_raise_flags(item)
		item_added.emit(item.type, added)
		changed.emit()
		if debug_log:
			print("Bag: +%d %s" % [added, item.type])

	if left > 0:
		bag_full.emit(item.type)
		if debug_log:
			print("Bag: FULL — %d %s refused." % [left, item.type])

	return added


func _raise_flags(item: MedicalItem) -> void:
	var flags := get_node_or_null("/root/Flags")
	if flags == null:
		return
	if item.pickup_flag != "":
		flags.set_flag(item.pickup_flag)
	if item.first_pickup_flag != "" and not flags.is_set(item.first_pickup_flag):
		flags.set_flag(item.first_pickup_flag)
	if item.type != "":
		flags.set_flag("item:" + item.type)


# --- removing --------------------------------------------------------------

## Takes items out by type. Returns how many were actually removed.
func remove(type: String, amount: int = 1) -> int:
	var left := amount
	for i in range(slots.size() - 1, -1, -1):       # newest stacks first
		if left <= 0:
			break
		if slots[i] != null and slots[i]["item"] and slots[i]["item"].type == type:
			var take: int = mini(int(slots[i]["count"]), left)
			slots[i]["count"] = int(slots[i]["count"]) - take
			left -= take
			if int(slots[i]["count"]) <= 0:
				slots[i] = null
	var gone := amount - left
	if gone > 0:
		item_removed.emit(type, gone)
		changed.emit()
	return gone


func remove_at(i: int, amount: int = 1) -> int:
	if is_empty_slot(i):
		return 0
	var type: String = slots[i]["item"].type
	var take: int = mini(int(slots[i]["count"]), amount)
	slots[i]["count"] = int(slots[i]["count"]) - take
	if int(slots[i]["count"]) <= 0:
		slots[i] = null
	item_removed.emit(type, take)
	changed.emit()
	return take


func clear() -> void:
	for i in slots.size():
		slots[i] = null
	changed.emit()


# --- using and dropping ----------------------------------------------------

## Uses the item in that slot, through MedicalItems so the existing effects
## (heal, cut, bandage) all still run. Consumes one on success.
func use_slot(i: int) -> bool:
	var it := item_at(i)
	if it == null:
		return false

	var mi := get_node_or_null("/root/MedicalItems")
	var worked := true
	if mi and mi.has_method("use"):
		worked = bool(mi.use(it))

	if worked:
		var flags := get_node_or_null("/root/Flags")
		if flags and it.use_flag != "":
			flags.set_flag(it.use_flag)
		item_used.emit(it.type)
		# Deferred: this is called from a button press, and freeing or
		# rebuilding the grid mid-callback is how you crash Godot.
		remove_at.call_deferred(i, 1)
	return worked


## Puts one back on the floor at Sami's feet.
func drop_slot(i: int) -> bool:
	var it := item_at(i)
	if it == null:
		return false

	var player := get_tree().get_first_node_in_group(player_group) as Node2D
	if player == null:
		push_warning("Bag: nothing in the '%s' group — can't drop." % player_group)
		return false

	var where: Vector2 = player.global_position + Vector2(0, drop_distance)
	_spawn_pickup.call_deferred(it, where)
	remove_at.call_deferred(i, 1)
	return true


func _spawn_pickup(item: MedicalItem, where: Vector2) -> void:
	var node: Node2D
	if pickup_scene:
		node = pickup_scene.instantiate()
		if "item" in node:
			node.item = item
	else:
		# build one by hand — an Area2D with the ItemPickup script
		var a := Area2D.new()
		a.set_script(load("res://FD_Testing/GameSystems/Items/item_pickup.gd"))
		a.item = item
		var cs := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 10.0
		cs.shape = circle
		a.add_child(cs)
		node = a

	node.global_position = where
	var level := get_tree().current_scene
	if level:
		level.add_child(node)
	if debug_log:
		print("Bag: dropped %s at %s" % [item.type, where])
