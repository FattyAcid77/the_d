class_name DialogActions
## The list of things a DialogLine can do, straight from the Inspector. On a
## DialogLine, fill in: action_name = "give_item" action_args = ["bandage", 2]
## DialogManager runs it.

const VERBS := [
	"set_flag", "clear_flag", "toggle_flag",
	"give_item", "take_item",
	"open_window", "close_window", "close_all_windows",
	"log_entry", "log_open",
	"heal", "hurt", "bleed", "stop_bleeding",
	"kill",
	"radio_tune", "radio_open",
	"play_sound", "play_music", "stop_music",
	"play_set", "stop_set", "music_layer", "ambience_layer",
	"progress_stage",
	"wait", "delay",
	"end_dialog",
]


## Returns true if it handled the action itself.
static func run(tree: SceneTree, verb: String, args: Array) -> bool:
	verb = DialogActionStep.verb_of(verb, "")
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
			# LogBook has no "unlock" call - entries are gated by flags.
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
			# RadioLink is a read-only window onto the other developer's radio for power/open state
			var f5 := _node(root, "Flags")
			if f5:
				f5.set_flag("radio_should_open")

		"play_sound":
			var snd := _node(root, "Sound")
			if snd and args.size() > 0 and snd.has_method("cue"):
				snd.cue(str(args[0]))  # full cue syntax: "delay(1) scream, loop drone"
		"play_music":
			var snd2 := _node(root, "Sound")
			if snd2 and args.size() > 0 and snd2.has_method("play_music"):
				var fade := float(args[1]) if args.size() > 1 else -1.0
				snd2.play_music(str(args[0]), fade)
		"stop_music":
			var snd3 := _node(root, "Sound")
			if snd3 and snd3.has_method("stop_music"):
				snd3.stop_music(float(args[0]) if args.size() > 0 else -1.0)
		"play_set":
			var snd4 := _node(root, "Sound")
			if snd4 and args.size() > 0 and snd4.has_method("play_set"):
				var mix: Array = []
				if args.size() > 1:
					for l in str(args[1]).split(",", false):
						mix.append(l.strip_edges())
				snd4.play_set(str(args[0]), mix)
		"stop_set":
			var snd5 := _node(root, "Sound")
			if snd5 and snd5.has_method("stop_set"):
				snd5.stop_set(str(args[0]) if args.size() > 0 else "Music")
		"music_layer", "ambience_layer":
			var snd6 := _node(root, "Sound")
			if snd6 and args.size() > 0 and snd6.has_method("set_layer"):
				var cat := "Ambience" if verb == "ambience_layer" else "Music"
				var st = null
				if args.size() > 1:
					var w := str(args[1]).to_lower()
					st = true if w in ["on", "true", "1"] else (false if w in ["off", "false", "0"] else null)
				snd6.set_layer(cat, str(args[0]), st)

		# --- story ---------------------------------------------------------
		"progress_stage":
			var gp := _node(root, "GameProgress")
			if gp and args.size() > 0 and gp.has_method("goto_state"):
				gp.goto_state(str(args[0]))

		# --- flow ----------------------------------------------------------
		"wait", "delay":
			# handled by DialogManager, which owns the box and the clock
			return true
		"end_dialog":
			var dm := _node(root, "DialogManager")
			if dm and dm.has_method("stop"):
				dm.stop()

	return true


static func _node(root: Node, autoload_name: String) -> Node:
	return root.get_node_or_null(autoload_name)


## The player's WoundComponent - the thing that actually owns health and bleeding.
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


## Puts the item in the Bag (the same route ItemPickup uses). Falls back to
## an "inventory" autoload if there is no Bag in the project.
static func _give_item(root: Node, args: Array) -> void:
	if args.is_empty():
		return
	var mi := root.get_node_or_null("MedicalItems")
	if mi == null or not mi.has_method("get_item"):
		push_warning("DialogActions: give_item needs the MedicalItems autoload.")
		return
	var item = mi.get_item(str(args[0]))
	if item == null:
		push_warning("DialogActions: no MedicalItem with type '%s'. Known types: %s"
				% [str(args[0]), mi.type_names() if mi.has_method("type_names") else "?"])
		return
	var amount := int(args[1]) if args.size() > 1 else 1
	var bag := root.get_node_or_null("Bag")
	if bag and bag.has_method("add"):
		bag.add(item, amount)  # Bag raises pickup_flag and item:<type> itself
		return
	var inv := root.get_node_or_null("inventory")
	if inv == null:
		push_warning("DialogActions: give_item found neither the Bag nor an 'inventory' autoload.")
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
	var amount := int(args[1]) if args.size() > 1 else 1
	var bag := root.get_node_or_null("Bag")
	if bag and bag.has_method("remove"):
		var type := str(args[0])
		var mi := root.get_node_or_null("MedicalItems")
		if mi and mi.has_method("get_item"):
			var item = mi.get_item(type)
			if item:
				type = item.type  # so "Radio" and "radio" both hit the same stack
		if bag.remove(type, amount) <= 0:
			push_warning("DialogActions: take_item - Sami has no '%s'." % type)
		return
	var inv := root.get_node_or_null("inventory")
	if inv == null:
		return
	for m in ["Remove_item", "remove_item", "RemoveItem", "remove", "take", "drop"]:
		if inv.has_method(m):
			inv.call(m, str(args[0]), amount)
			return
	push_warning("DialogActions: couldn't find a remove function on the inventory.")
