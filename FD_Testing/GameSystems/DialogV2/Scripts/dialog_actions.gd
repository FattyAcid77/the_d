class_name DialogActions
## The list of things a DialogLine can DO, straight from the Inspector.
##
## On a DialogLine, fill in:
##     action_name  = "give_item"
##     action_args  = ["bandage", 2]
##
## DialogManager runs it. Anything NOT in this list is still emitted as
## `action_requested`, exactly as before, so your own custom actions keep
## working — nothing you already wired up breaks.
##
## A line with EMPTY text and an action becomes a pure "do something" step:
## no box appears, it just happens and moves on.
##
## Full documented list with examples: DialogV2/ACTIONS.md
##
## This is a plain static helper — NOT an autoload, nothing to register.

## Every built-in verb. Used by run() and by the docs.
const VERBS := [
	"set_flag", "clear_flag", "toggle_flag",
	"give_item", "take_item",
	"open_window", "close_window", "close_all_windows",
	"log_entry", "log_open",
	"heal", "hurt", "bleed", "stop_bleeding",
	"kill",
	"radio_tune", "radio_open",
	"progress_stage",
	"play_cutscene",
	"wait",
	"end_dialog",
]


## Returns TRUE if it handled the action itself.
## Returns FALSE for anything unknown, so the caller emits action_requested.
static func run(tree: SceneTree, verb: String, args: Array) -> bool:
	if verb == "" or not VERBS.has(verb):
		return false

	var root := tree.root

	match verb:
		# --- flags ---------------------------------------------------------
		"set_flag":
			var f := _node(root, "Flags")
			if f and args.size() > 0:
				f.set_flag(str(args[0]))
		"clear_flag":
			var f2 := _node(root, "Flags")
			if f2 and args.size() > 0 and f2.has_method("clear_flag"):
				f2.clear_flag(str(args[0]))
		"toggle_flag":
			var f3 := _node(root, "Flags")
			if f3 and args.size() > 0:
				var n := str(args[0])
				if f3.is_set(n):
					if f3.has_method("clear_flag"):
						f3.clear_flag(n)
				else:
					f3.set_flag(n)

		# --- items ---------------------------------------------------------
		"give_item":
			_give_item(root, args)
		"take_item":
			_take_item(root, args)

		# --- windows -------------------------------------------------------
		"open_window":
			var pw := _node(root, "PopupWindows")
			if pw and args.size() > 0:
				pw.open_id(str(args[0]))
		"close_window":
			var pw2 := _node(root, "PopupWindows")
			if pw2 and args.size() > 0 and pw2.has_method("close_id"):
				pw2.close_id(str(args[0]))
		"close_all_windows":
			var pw3 := _node(root, "PopupWindows")
			if pw3 and pw3.has_method("close_all"):
				pw3.close_all()

		# --- logbook -------------------------------------------------------
		"log_entry":
			# LogBook has no "unlock" call — entries are gated by FLAGS.
			# So this raises the flag the entry is waiting on, which is the
			# real way the logbook works.
			var f4 := _node(root, "Flags")
			if f4 and args.size() > 0:
				f4.set_flag(str(args[0]))
		"log_open":
			var lb2 := _node(root, "LogBook")
			if lb2 and lb2.has_method("open"):
				lb2.open()

		# --- health / blood ------------------------------------------------
		"heal":
			var w := _wound(root)
			if w:
				w.heal(float(args[0]) if args.size() > 0 else 1.0)
		"hurt":
			var w2 := _wound(root)
			if w2:
				w2.take_damage(float(args[0]) if args.size() > 0 else 1.0,
						str(args[1]) if args.size() > 1 else "")
		"bleed":
			var w3 := _wound(root)
			if w3:
				w3.cut(str(args[0]) if args.size() > 0 else "")
		"stop_bleeding":
			var w4 := _wound(root)
			if w4:
				w4.stop_bleeding()
		"kill":
			var dd := _node(root, "Deaths")
			if dd and dd.has_method("kill"):
				dd.kill(str(args[0]) if args.size() > 0 else "")

		# --- radio ---------------------------------------------------------
		"radio_tune":
			var rl := _node(root, "RadioLink")
			if rl and args.size() > 0 and rl.has_method("set_frequency"):
				rl.set_frequency(float(args[0]))
		"radio_open":
			# RadioLink is a READ-ONLY window onto the other developer's radio
			# for power/open state — we can tune it, but only their code opens
			# and closes it. So this raises a flag their side can watch.
			var f5 := _node(root, "Flags")
			if f5:
				f5.set_flag("radio_should_open")

		# --- story ---------------------------------------------------------
		"progress_stage":
			var gp := _node(root, "GameProgress")
			if gp and args.size() > 0 and gp.has_method("goto_state"):
				gp.goto_state(str(args[0]))
		"play_cutscene":
			var cs := _node(root, "Cutscene")
			if cs and args.size() > 0:
				var a = args[0]
				if a is Comic and cs.has_method("play_comic"):
					cs.play_comic(a)
				elif cs.has_method("play"):
					cs.play(str(a))            # a res:// path to a video

		# --- flow ----------------------------------------------------------
		"wait":
			# handled by the caller, which knows how to pause the box
			return true
		"end_dialog":
			var dm := _node(root, "DialogManager")
			if dm and dm.has_method("stop"):
				dm.stop()

	return true


static func _node(root: Node, autoload_name: String) -> Node:
	return root.get_node_or_null(autoload_name)


## The player's WoundComponent — the thing that actually owns health and
## bleeding. Found by searching the player, then the whole tree.
static func _wound(root: Node) -> Node:
	var tree := root.get_tree()
	var player := tree.get_first_node_in_group("Player") as Node2D
	if player:
		for c in player.get_children():
			if c is WoundComponent:
				return c
	var found := tree.get_first_node_in_group("wound_component")
	if found:
		return found
	return _find_type(root, "WoundComponent")


static func _find_type(node: Node, type_name: String) -> Node:
	for c in node.get_children():
		if c.get_script() and c.get_script().get_global_name() == type_name:
			return c
		var deep := _find_type(c, type_name)
		if deep:
			return deep
	return null


## Adds an item to the existing inventory, by the same route ItemPickup uses,
## so both go through the other developer's code the same way.
static func _give_item(root: Node, args: Array) -> void:
	if args.is_empty():
		return
	var mi := root.get_node_or_null("MedicalItems")
	if mi == null or not mi.has_method("get_item"):
		return
	var item = mi.get_item(str(args[0]))
	if item == null:
		push_warning("DialogActions: no MedicalItem with type '%s'." % str(args[0]))
		return
	var amount := int(args[1]) if args.size() > 1 else 1
	var inv := root.get_node_or_null("inventory")
	if inv == null:
		push_warning("DialogActions: give_item needs the 'inventory' autoload.")
		return
	for m in ["Add_item", "add_item", "AddItem", "add", "pick_up", "collect"]:
		if inv.has_method(m):
			inv.call(m, item.to_dict(amount))
			var flags := root.get_node_or_null("Flags")
			if flags:
				if item.pickup_flag != "":
					flags.set_flag(item.pickup_flag)
				flags.set_flag("item:" + item.type)
			return
	push_warning("DialogActions: couldn't find an add function on the inventory.")


static func _take_item(root: Node, args: Array) -> void:
	if args.is_empty():
		return
	var inv := root.get_node_or_null("inventory")
	if inv == null:
		return
	var amount := int(args[1]) if args.size() > 1 else 1
	for m in ["Remove_item", "remove_item", "RemoveItem", "remove", "take", "drop"]:
		if inv.has_method(m):
			inv.call(m, str(args[0]), amount)
			return
	push_warning("DialogActions: couldn't find a remove function on the inventory. "
			+ "Tell me its real name and I'll wire it exactly.")
