class_name SoundHook extends Node
## Drop under any node: hooks list what should make a sound. A signal, or an
## animation starting, finishing or reaching a frame. For nodes we don't own.
## With the FD Sound plugin every hook is picked from lists.

## The node to listen to. Empty = the parent.
@export var target_path: NodePath

## What happens -> sound id. Keys: a signal name, or anim:open (starts),
## anim_end:open (finishes), frame:open:3 (reaches frame 3).
@export var hooks: Dictionary[String, String] = {}

@export_group("Where the sound comes from")
## Play from the target's position in the world (pans + fades with distance)
@export var positional: bool = false

@export_group("Debug")
## Print each hook as it connects and each time one fires.
@export var debug_log: bool = false

var _target: Node
var _sprites: Array[AnimatedSprite2D] = []
var _players: Array[AnimationPlayer] = []
var _start_hooks := {}  # animation -> sound id, for sprites (players use their signal)
var _was := {}  # sprite -> [animation, playing, frame] last frame


func _ready() -> void:
	_target = get_node_or_null(target_path) if not target_path.is_empty() else get_parent()
	if _target == null:
		push_warning("SoundHook '%s': no target node." % name)
		return
	if get_node_or_null("/root/Sound") == null:
		push_warning("SoundHook '%s': no Sound autoload." % name)
		return
	find_animators(_target, _sprites, _players)
	for key in hooks.keys():
		var id := str(hooks[key])
		if id != "":
			_hook(str(key), id)
	set_process(not _start_hooks.is_empty())


## Every AnimatedSprite2D and AnimationPlayer at or under a node, stopping at
## other scenes placed inside it (a hook on a level doesn't grab every door).
static func find_animators(node: Node, sprites: Array, players: Array, top := true) -> void:
	if not top and node.scene_file_path != "":
		return
	if node is AnimatedSprite2D:
		sprites.append(node)
	elif node is AnimationPlayer:
		players.append(node)
	for c in node.get_children():
		find_animators(c, sprites, players, false)


func _hook(key: String, id: String) -> void:
	var parts := key.split(":")
	var ok := false
	match parts[0] if parts.size() > 1 else "":
		"anim":
			ok = _hook_start(parts[1], id)
		"anim_end":
			ok = _hook_end(parts[1], id)
		"frame":
			ok = parts.size() == 3 and _hook_frame(parts[1], int(parts[2]), id)
		_:
			ok = SoundLink.connect_any_arity(_target, key, _on_fired.bind(id))
			if not ok:
				var names := PackedStringArray()
				for s in _target.get_signal_list():
					names.append(str(s["name"]))
				push_warning("SoundHook '%s': target '%s' has no signal '%s'. It has: %s"
						% [name, _target.name, key, ", ".join(names)])
				return
	if not ok and parts.size() > 1:
		push_warning("SoundHook '%s': no animation '%s' on '%s' or under it. It has: %s"
				% [name, parts[1], _target.name, ", ".join(animation_names())])
		return
	if debug_log:
		print("SoundHook '%s': %s.%s -> '%s'" % [name, _target.name, key, id])


func _hook_start(anim: String, id: String) -> bool:
	var found := false
	for p in _players:
		if p.has_animation(anim):
			p.animation_started.connect(func(n): if n == anim: _on_fired([], id))
			found = true
	for s in _sprites:
		if s.sprite_frames and s.sprite_frames.has_animation(anim):
			found = true
	if found:
		_start_hooks[anim] = id
	return found


func _hook_end(anim: String, id: String) -> bool:
	var found := false
	for p in _players:
		if p.has_animation(anim):
			p.animation_finished.connect(func(n): if n == anim: _on_fired([], id))
			found = true
	for s in _sprites:
		if s.sprite_frames and s.sprite_frames.has_animation(anim):
			s.animation_finished.connect(func(): if s.animation == anim: _on_fired([], id))
			found = true
	return found


func _hook_frame(anim: String, frame: int, id: String) -> bool:
	var found := false
	for s in _sprites:
		if s.sprite_frames and s.sprite_frames.has_animation(anim):
			s.frame_changed.connect(func(): if s.animation == anim and s.frame == frame and s.is_playing(): _on_fired([], id))
			found = true
	return found


# A sprite has no "started" signal, so watch it: it counts as started when it
# begins playing, switches to the animation, or jumps back to the start.
func _process(_delta: float) -> void:
	for s in _sprites:
		if not is_instance_valid(s):
			continue
		var now := [String(s.animation), s.is_playing(), s.frame]
		var was: Array = _was.get(s, ["", false, 0])
		_was[s] = now
		if not now[1] or not _start_hooks.has(now[0]):
			continue
		var looping: bool = s.sprite_frames.get_animation_loop(now[0])
		var forward := s.get_playing_speed() >= 0.0
		var jumped_back: bool = now[2] < was[2] if forward else now[2] > was[2]
		var restarted := jumped_back and not looping
		if not was[1] or now[0] != was[0] or restarted:
			_on_fired([], _start_hooks[now[0]])


## Animation names on the target and under it, for warnings and the plugin.
func animation_names() -> PackedStringArray:
	var out := PackedStringArray()
	for s in _sprites:
		if s.sprite_frames:
			for n in s.sprite_frames.get_animation_names():
				if not out.has(n):
					out.append(n)
	for p in _players:
		for n in p.get_animation_list():
			if not out.has(n):
				out.append(n)
	return out


func _on_fired(_args: Array, id: String) -> void:
	var snd := get_node_or_null("/root/Sound")
	if snd == null:
		return
	if debug_log:
		print("SoundHook '%s': fired '%s'" % [name, id])
	# from the target: FloorSurface variants apply
	snd.play_from(id, _target, positional)
