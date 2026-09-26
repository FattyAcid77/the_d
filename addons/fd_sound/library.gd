@tool
extends RefCounted
## Every SoundDef and MusicSet in the folders the game itself loads from
## (Sound's LIBRARY_DIRS and SETS_DIRS), walked through the editor's file index.

signal changed

## id -> {path, category, stream, volume_db, pitch_min, pitch_max}
var sounds := {}
## id -> {path, category, layers: [{name, stream, volume_db, on}]}
var sets := {}
## ids that exist twice; the game uses the first one it finds
var duplicates: Array[String] = []
## id -> every file that uses it, for the ids in duplicates
var duplicate_paths := {}
var sound_dirs: Array = []
var set_dirs: Array = []


func scan() -> void:
	_read_dirs()
	sounds.clear()
	sets.clear()
	duplicates.clear()
	duplicate_paths.clear()
	var root := EditorInterface.get_resource_filesystem().get_filesystem()
	if root:
		_walk(root)
	changed.emit()


## The Sound autoload's own folder lists, so there is one place to change them.
func _read_dirs() -> void:
	sound_dirs = []
	set_dirs = []
	var path := str(ProjectSettings.get_setting("autoload/Sound", "")).trim_prefix("*")
	var script: Script = load(path) if path != "" and ResourceLoader.exists(path) else null
	if script:
		var c := script.get_script_constant_map()
		sound_dirs = c.get("LIBRARY_DIRS", [])
		set_dirs = c.get("SETS_DIRS", [])


func _walk(dir: EditorFileSystemDirectory) -> void:
	var files: Array[String] = []
	for i in dir.get_file_count():
		files.append(dir.get_file_path(i))
	files.sort()  # same order the game loads them in, so the same duplicate wins
	for path in files:
		if not path.get_extension() in ["tres", "res"]:
			continue
		var in_sounds := _inside(path, sound_dirs)
		var in_sets := _inside(path, set_dirs)
		if not (in_sounds or in_sets):
			continue
		var r: Resource = load(path)
		var cls := class_of(r)
		if cls == "SoundDef" and in_sounds:
			_add_sound(path, r)
		elif cls == "MusicSet" and in_sets:
			_add_set(path, r)
	for s in dir.get_subdir_count():
		_walk(dir.get_subdir(s))


func _inside(path: String, roots: Array) -> bool:
	for r in roots:
		if path.begins_with(str(r).trim_suffix("/") + "/"):
			return true
	return false


func _add_sound(path: String, r: Resource) -> void:
	var id := str(r.get("id"))
	if id == "":
		return
	if sounds.has(id):
		if not duplicates.has(id):
			duplicates.append(id)
			duplicate_paths[id] = [sounds[id].path]
		duplicate_paths[id].append(path)
		return
	sounds[id] = {
		"path": path,
		"category": str(r.get("category")),
		"stream": r.get("stream"),
		"volume_db": float(r.get("volume_db")),
		"pitch_min": float(r.get("pitch_min")),
		"pitch_max": float(r.get("pitch_max")),
	}


func _add_set(path: String, r: Resource) -> void:
	var id := str(r.get("id"))
	if id == "" or sets.has(id):
		return
	sets[id] = {"path": path, "category": str(r.get("category")), "layers": layers_of(r)}


## A MusicSet's stems as plain dictionaries. Works on unsaved edits too.
static func layers_of(music_set: Resource) -> Array:
	var out := []
	if music_set == null:
		return out
	for l in music_set.get("layers"):
		if l == null:
			continue
		var n := str(l.get("name"))
		if n == "":
			continue
		out.append({"name": n, "stream": l.get("stream"),
				"volume_db": float(l.get("volume_db")), "on": bool(l.get("on_by_default"))})
	return out


## "SoundDef" for a resource or node whose script (or a base of it) has that class_name.
static func class_of(obj: Object) -> String:
	var s: Script = obj.get_script() if obj else null
	while s:
		if s.get_global_name() != "":
			return s.get_global_name()
		s = s.get_base_script()
	return ""


static func is_a(obj: Object, cls: String) -> bool:
	var s: Script = obj.get_script() if obj else null
	while s:
		if s.get_global_name() == cls:
			return true
		s = s.get_base_script()
	return false


## First id in a cue: "delay(1) scream, loop drone" -> "scream".
static func first_id(cue: String) -> String:
	var parts := cue.split(",", false)
	if parts.is_empty():
		return ""
	var words := parts[0].strip_edges().split(" ", false)
	return words[words.size() - 1] if not words.is_empty() else ""


## List rows for the picker: sounds, music first when asked.
func sound_rows(music_first := false) -> Array:
	var ids: Array = sounds.keys()
	ids.sort()
	var rows := []
	if music_first:
		var music := ids.filter(func(i): return sounds[i].category == "Music")
		var rest := ids.filter(func(i): return sounds[i].category != "Music")
		ids = music + rest
	for id in ids:
		rows.append({"id": id, "note": sounds[id].category})
	return rows


func set_rows(category := "") -> Array:
	var ids: Array = sets.keys()
	ids.sort()
	var rows := []
	for id in ids:
		if category == "" or sets[id].category == category:
			rows.append({"id": id, "note": "%s, %d layers" % [sets[id].category, sets[id].layers.size()]})
	return rows


## Layer names across every set of a category, "choir" with its set as the note.
func layer_rows(category: String) -> Array:
	var rows := []
	var ids: Array = sets.keys()
	ids.sort()
	for id in ids:
		if sets[id].category != category:
			continue
		for l in sets[id].layers:
			rows.append({"id": l.name, "note": id})
	return rows


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


## What a SoundHook can listen to on this node, in dropdown order:
## [{key, label, section}]. Same keys SoundHook reads at runtime.
static func hook_choices(target: Node) -> Array:
	var out := []
	if target == null:
		return out
	var seen := {}
	var s: Script = target.get_script()
	if s:
		for sig in s.get_script_signal_list():
			if not seen.has(sig.name):
				seen[sig.name] = true
				out.append({"key": sig.name, "label": sig.name, "section": "Its signals"})
	var sprites := []
	var players := []
	find_animators(target, sprites, players)
	for sp in sprites:
		var sf: SpriteFrames = sp.sprite_frames
		if sf == null:
			continue
		for anim in sf.get_animation_names():
			_add_choice(out, seen, "anim:" + anim, "%s  starts" % anim)
			for f in range(1, sf.get_frame_count(anim)):
				_add_choice(out, seen, "frame:%s:%d" % [anim, f], "%s  frame %d" % [anim, f])
			if not sf.get_animation_loop(anim):
				_add_choice(out, seen, "anim_end:" + anim, "%s  finishes" % anim)
	for p in players:
		for anim in p.get_animation_list():
			_add_choice(out, seen, "anim:" + anim, "%s  starts" % anim)
			_add_choice(out, seen, "anim_end:" + anim, "%s  finishes" % anim)
	# the engine's own signals, minus Object/Node housekeeping
	var cls := target.get_class()
	while cls != "" and cls != "Node" and cls != "Object":
		for sig in ClassDB.class_get_signal_list(cls, true):
			if not seen.has(sig.name):
				seen[sig.name] = true
				out.append({"key": sig.name, "label": sig.name, "section": "Built in (%s)" % cls})
		cls = ClassDB.get_parent_class(cls)
	return out


static func _add_choice(out: Array, seen: Dictionary, key: String, label: String) -> void:
	if seen.has(key):
		return
	seen[key] = true
	out.append({"key": key, "label": label, "section": "Animations"})
