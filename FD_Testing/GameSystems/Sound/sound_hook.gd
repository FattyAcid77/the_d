class_name SoundHook extends Node
## Drop under any node, list signal -> sound id in the inspector. Connects
## itself at runtime. For nodes we don't own (the player).

@export var target_path: NodePath

## signal name on the target -> sound id from Sound/Library/
@export var hooks: Dictionary[String, String] = {}

@export_group("Where the sound comes from")
## Play from the target's position in the world (pans + fades with distance)
@export var positional: bool = false

@export_group("Debug")
## Print each hook as it connects and each time one fires.
@export var debug_log: bool = false

var _target: Node


func _ready() -> void:
	_target = get_node_or_null(target_path) if not target_path.is_empty() else get_parent()
	if _target == null:
		push_warning("SoundHook '%s': no target node." % name)
		return
	var snd := get_node_or_null("/root/Sound")
	if snd == null:
		push_warning("SoundHook '%s': no Sound autoload." % name)
		return
	for sig in hooks.keys():
		var id := str(hooks[sig])
		if id == "":
			continue
		var ok := SoundLink.connect_any_arity(_target, str(sig), _on_fired.bind(id))
		if ok:
			if debug_log:
				print("SoundHook '%s': %s.%s -> '%s'" % [name, _target.name, sig, id])
		else:
			var names := PackedStringArray()
			for s in _target.get_signal_list():
				names.append(str(s["name"]))
			push_warning("SoundHook '%s': target '%s' has no signal '%s'. It has: %s"
					% [name, _target.name, sig, ", ".join(names)])


func _on_fired(_args: Array, id: String) -> void:
	var snd := get_node_or_null("/root/Sound")
	if snd == null:
		return
	if debug_log:
		print("SoundHook '%s': fired '%s'" % [name, id])
	# from the target: FloorSurface variants apply
	snd.play_from(id, _target, positional)
