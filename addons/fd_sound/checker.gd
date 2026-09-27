@tool
extends RefCounted
## Check project: reads every level, resource and dialog, and lists what will
## break (red), what's probably a mistake (yellow) and what's missing from the
## translations. Each problem says where it is, so the dock can open it.

const Library := preload("library.gd")
const Names := preload("names.gd")
const RED := "red"
const YELLOW := "yellow"
const TRANSLATION := "translation"
## Fields that hold text the player reads (same list as translation_audit.gd).
const TEXT_FIELDS := ["text", "label", "note", "title", "display_name",
		"effect", "result_title", "result_text", "board_title", "topic_label"]
## Verbs whose first arg is a name, and the kind of name.
const ARG_KINDS := {
	"open_window": "window", "close_window": "window",
	"give_item": "item", "take_item": "item",
	"kill": "death", "progress_stage": "state",
}

var library  # library.gd
var names  # names.gd
## {level, text, path, node}. node: the node's path in the scene ("" = the file).
var problems: Array = []
var _seen := {}
var _texts := {}  # player-visible text -> where


func run() -> Array:
	problems.clear()
	_seen.clear()
	_texts.clear()
	library.scan()
	names.scan()
	var files: Array[String] = []
	var root := EditorInterface.get_resource_filesystem().get_filesystem()
	if root:
		_collect(root, files)
	for path in files:
		if path.ends_with(".tscn"):
			_check_scene(path)
		elif path.ends_with(".tres"):
			_check_resource_file(path)
	_check_library()
	_check_unread_flags()
	_check_checkpoints()
	_check_translations()
	var order := {RED: 0, YELLOW: 1, TRANSLATION: 2}
	problems.sort_custom(func(a, b):
		if a.level != b.level:
			return order[a.level] < order[b.level]
		return str(a.path) + str(a.node) < str(b.path) + str(b.node))
	return problems


func count(level: String) -> int:
	return problems.filter(func(p): return p.level == level).size()


func _add(level: String, text: String, path: String, node := "") -> void:
	var key := level + text + path + node
	if _seen.has(key):
		return
	_seen[key] = true
	problems.append({"level": level, "text": text, "path": path, "node": node})


func _collect(dir: EditorFileSystemDirectory, out: Array[String]) -> void:
	var p := dir.get_path()
	if p.begins_with("res://addons/") or p.begins_with("res://.godot"):
		return
	for i in dir.get_file_count():
		out.append(dir.get_file_path(i))
	for s in dir.get_subdir_count():
		_collect(dir.get_subdir(s), out)


# --- files -------------------------------------------------------------------------

func _check_scene(path: String) -> void:
	var ps: PackedScene = load(path) as PackedScene
	if ps == null:
		_add(RED, "This scene doesn't load (it points at a file that's gone?)", path)
		return
	var root := ps.instantiate()
	if root == null:
		_add(RED, "This scene can't be opened", path)
		return
	# only nodes this file owns; a door placed in a level is checked in the door's own file
	var nodes: Array[Node] = [root]
	for n in root.find_children("*", "", true, false):
		if n.owner == root:
			nodes.append(n)
	for n in nodes:
		if n.get_script() != null:
			_check_object(n, path, str(root.get_path_to(n)), {})
	root.free()


func _check_resource_file(path: String) -> void:
	var r: Resource = load(path)
	if r == null:
		_add(RED, "This resource doesn't load (it points at a file that's gone?)", path)
		return
	if r.get_script() != null:
		_check_object(r, path, "", {})


## Checks every stored property of a node or resource by what its name says
## it holds, then dives into built-in sub-resources (a dialog's lines...).
func _check_object(obj: Object, path: String, node: String, visited: Dictionary) -> void:
	if visited.has(obj.get_instance_id()):
		return
	visited[obj.get_instance_id()] = true
	var here := _label(obj)
	for p in obj.get_property_list():
		# placeholder scripts in the editor don't flag their variables as
		# script variables, so go by "saved in the file" and the name
		if not (int(p["usage"]) & PROPERTY_USAGE_STORAGE):
			continue
		var prop: String = p["name"]
		var value: Variant = obj.get(prop)
		if value == null:
			continue
		# only what someone typed in: a default isn't in the file, so the flag
		# index can't see the other side of it either (a false red)
		if _is_default(obj, prop, value):
			continue
		# sounds
		if value is String and (prop == "sound_id" or prop.ends_with("_sound_id") or prop == "music_id"):
			_check_cue(value, "%s%s " % [here, prop], path, node)
		# flags
		var role := Names.flag_role(prop)
		if role == Names.USE or role == Names.CLEAR:
			for f in _as_strings(value):
				if f != "" and not names.is_set_somewhere(f):
					var near := _near(f, _set_flags())
					var hint := "; did you mean '%s'?" % near if near != "" else ""
					if role == Names.USE:
						_add(RED, "%s%s '%s': nothing ever sets this flag, so it waits forever%s" % [here, prop, f, hint], path, node)
					else:
						_add(YELLOW, "%s%s '%s': clears a flag nothing ever sets%s" % [here, prop, f, hint], path, node)
		# ids
		var kind := Names.id_kind(prop)
		if kind != "" and value is String and value != "" and not names.ids[kind].has(value):
			_missing_id(kind, "%s%s" % [here, prop], value, path, node)
		# player-visible text, for the translation check
		if value is String and prop in TEXT_FIELDS and not path.contains("/Prescription/"):
			var t: String = value.strip_edges()
			if t != "" and not t.is_valid_int() and not _texts.has(t):
				_texts[t] = [path, node]
		# built-in sub-resources: dialog branches, lines, action steps...
		if value is Resource:
			_dive(value, path, node, visited)
		elif value is Array:
			for v in value:
				if v is Resource:
					_dive(v, path, node, visited)
	if Library.is_a(obj, "SoundHook"):
		_check_hook(obj, path, node)
	if Library.is_a(obj, "MusicZone"):
		_check_zone(obj, path, node)
	if Library.is_a(obj, "SoundMap"):
		var events: Dictionary = obj.get("events")
		for moment in events:
			_check_cue(str(events[moment]), "%s -> " % moment, path, node)
	if Library.is_a(obj, "DialogLine"):
		_check_action(str(obj.get("action_name")), obj.get("action_args"), here, path, node)
		for m in RegEx.create_from_string("\\[sfx:([^\\]]+)\\]").search_all(str(obj.get("text"))):
			_check_cue(m.get_string(1), "%s[sfx:] in the text: " % here, path, node)
	if Library.is_a(obj, "DialogActionStep"):
		_check_action(str(obj.get("action")), obj.get("args"), here, path, node)


func _is_default(obj: Object, prop: String, value: Variant) -> bool:
	var s: Script = obj.get_script()
	var def: Variant = null
	if s:
		def = s.get_property_default_value(prop)
	if def == null:
		def = ClassDB.class_get_property_default_value(obj.get_class(), prop)
	if def == null:
		return value is String and value == ""
	return typeof(def) == typeof(value) and def == value


func _dive(r: Resource, path: String, node: String, visited: Dictionary) -> void:
	# a file of its own is checked on its own
	if r.resource_path != "" and not r.resource_path.contains("::"):
		return
	if r.get_script() != null:
		_check_object(r, path, node, visited)


## "line 'Hello there...' " for dialog lines, "" otherwise, to say where inside a file.
func _label(obj: Object) -> String:
	if Library.is_a(obj, "DialogLine"):
		var t := str(obj.get("text")).strip_edges().replace("\n", " ")
		return "line '%s': " % (t.substr(0, 28) + ("..." if t.length() > 28 else ""))
	return ""


func _as_strings(v: Variant) -> Array:
	if v is String:
		return [v]
	if v is Array or v is PackedStringArray:
		return Array(v).map(func(x): return str(x))
	return []


# --- what each thing needs ---------------------------------------------------------

## Every id in a cue ("delay(1) scream, loop(0.5) drone") has to exist.
func _check_cue(cue: String, what: String, path: String, node: String) -> void:
	for part in cue.split(",", false):
		var words := part.strip_edges().split(" ", false)
		if words.is_empty():
			continue
		var id := words[words.size() - 1]
		if not library.sounds.has(id):
			_add(RED, "%s'%s': no sound with this id, so it stays silent" % [what, id], path, node)


func _check_action(verb_text: String, args: Variant, here: String, path: String, node: String) -> void:
	var verb := verb_text.strip_edges().get_slice(" ", 0)
	var list: Array = _as_strings(args) if args != null else []
	var first: String = list[0] if not list.is_empty() else ""
	if verb == "" or first == "":
		return
	match verb:
		"play_sound", "play_music":
			_check_cue(first, "%s%s " % [here, verb], path, node)
		"play_set":
			if not library.sets.has(first):
				_add(RED, "%splay_set '%s': no music set with this id" % [here, first], path, node)
		"music_layer", "ambience_layer":
			var cat := "Music" if verb == "music_layer" else "Ambience"
			if not library.layer_rows(cat).any(func(r): return r.id == first):
				_add(RED, "%s%s '%s': no %s set has this layer" % [here, verb, first, cat], path, node)
		_:
			var kind: String = ARG_KINDS.get(verb, "")
			if kind != "" and not names.ids[kind].has(first):
				_missing_id(kind, "%s%s" % [here, verb], first, path, node)


func _check_hook(hook: Object, path: String, node: String) -> void:
	var n := hook as Node
	var tp: NodePath = hook.get("target_path")
	var target := n.get_node_or_null(tp) if not tp.is_empty() else n.get_parent()
	var hooks: Dictionary = hook.get("hooks")
	if target == null:
		if not hooks.is_empty():
			_add(RED, "SoundHook has no node to listen to (Target Path points at nothing)", path, node)
		return
	var keys: Array = Library.hook_choices(target).map(func(c): return c.key)
	for k in hooks:
		if not keys.has(str(k)):
			_add(RED, "SoundHook: '%s' isn't a signal or animation of %s any more" % [k, target.name], path, node)
		if str(hooks[k]) != "":
			_check_cue(str(hooks[k]), "SoundHook %s -> " % k, path, node)


func _check_zone(zone: Object, path: String, node: String) -> void:
	var s: Resource = zone.get("music_set")
	if s == null:
		return
	var have: Array = Library.layers_of(s).map(func(l): return l.name)
	var wanted: Array = Array(zone.get("layers"))
	wanted += Array(Dictionary(zone.get("delayed_layers")).keys())
	wanted += Array(Dictionary(zone.get("flag_layers")).keys())
	for l in wanted:
		if not have.has(str(l)):
			_add(RED, "layer '%s' isn't in the music set '%s'" % [l, s.get("id")], path, node)


# --- project-wide ----------------------------------------------------------------------

func _check_library() -> void:
	for id in library.duplicates:
		var paths: Array = library.duplicate_paths.get(id, [])
		for p in paths.slice(1):
			_add(RED, "Two SoundDefs use the id '%s'; the game plays %s" % [id, str(paths[0]).get_file()], p)
	for id in library.sounds:
		if library.sounds[id].stream == null:
			_add(RED, "SoundDef '%s' has no audio file" % id, library.sounds[id].path)
	for id in library.sets:
		var seen := {}
		for l in library.sets[id].layers:
			if l.stream == null:
				_add(RED, "Music set '%s': layer '%s' has no audio file" % [id, l.name], library.sets[id].path)
			if seen.has(l.name):
				_add(RED, "Music set '%s': two layers are called '%s'" % [id, l.name], library.sets[id].path)
			seen[l.name] = true


## A missing progress state is only yellow: a checkpoint can name a state that
## no level reacts to, and that's allowed. Every other missing id breaks.
func _missing_id(kind: String, what: String, value: String, path: String, node: String) -> void:
	var near := _near(value, names.ids[kind].keys())
	var hint := "; did you mean '%s'?" % near if near != "" else ""
	if kind == "state":
		_add(YELLOW, "%s '%s': no ProgressState node has this name in any level (fine if nothing needs to react)%s" % [what, value, hint], path, node)
	else:
		_add(RED, "%s '%s': there's no %s with this id%s" % [what, value, names._kind_name(kind), hint], path, node)


## A flag that's set but never read, when a flag that IS read is spelled almost
## the same: that's a typo on one side. Unread flags on their own are normal
## (used_medkit, checkpoint story flags...), so they aren't listed.
func _check_unread_flags() -> void:
	var read: Array = names.flags.keys().filter(func(f): return names.is_read_somewhere(f))
	for f in names.flags:
		var sets: Array = names.flags[f][Names.SET]
		if sets.is_empty() or names.is_read_somewhere(f):
			continue
		var first := str(sets[0])
		if first.begins_with("the game"):
			continue
		var near := _near(f, read)
		if near == "":
			continue
		var at := _where_to_path(first)
		_add(YELLOW, "Flag '%s' is set but nothing reads it; '%s' is read. A typo on one side?" % [f, near], at[0], at[1])


func _set_flags() -> Array:
	return names.flags.keys().filter(func(f): return names.is_set_somewhere(f))


## The closest name within two letters (or only different in case), "" if none.
func _near(word: String, candidates: Array) -> String:
	var best := ""
	var best_d := 3
	var lw := word.to_lower()
	for c in candidates:
		var cs := str(c)
		if cs == word or absi(cs.length() - word.length()) > 2:
			continue
		var d := 0 if cs.to_lower() == lw else _distance(lw, cs.to_lower())
		if d < best_d:
			best_d = d
			best = cs
	return best if word.length() >= 4 else ""


func _distance(a: String, b: String) -> int:
	var prev := range(b.length() + 1)
	for i in a.length():
		var cur := [i + 1]
		for j in b.length():
			cur.append(mini(mini(cur[j] + 1, prev[j + 1] + 1), prev[j] + (0 if a[i] == b[j] else 1)))
		prev = cur
	return prev[b.length()]


## "level.tscn > Door/Hook" or "door.gd:12" -> [res path, node path]
func _where_to_path(where: String) -> Array:
	var file := where.get_slice(" > ", 0).get_slice(":", 0)
	var node := where.get_slice(" > ", 1) if where.contains(" > ") else ""
	for path in _find_file(file):
		return [path, node]
	return [file, node]


func _find_file(file_name: String) -> Array:
	var out := []
	var root := EditorInterface.get_resource_filesystem().get_filesystem()
	var stack := [root]
	while not stack.is_empty():
		var d: EditorFileSystemDirectory = stack.pop_back()
		var i := d.find_file_index(file_name)
		if i >= 0:
			out.append(d.get_file_path(i))
			return out
		for s in d.get_subdir_count():
			stack.append(d.get_subdir(s))
	return out


func _check_checkpoints() -> void:
	var path := str(ProjectSettings.get_setting("autoload/Prescription", "")).trim_prefix("*")
	if path == "" or not ResourceLoader.exists(path):
		return
	var dir := str((load(path) as Script).get_script_constant_map().get("CHECKPOINTS_DIR", ""))
	if dir == "":
		return
	var by_number := {}
	var files: Array[String] = []
	var root := EditorInterface.get_resource_filesystem().get_filesystem_path(dir)
	if root:
		_collect(root, files)
	for f in files:
		if not f.ends_with(".tres"):
			continue
		var r: Resource = load(f)
		if r == null or not Library.is_a(r, "PrescriptionCheckpoint"):
			continue
		var n := int(r.get("number"))
		if by_number.has(n):
			_add(RED, "Two checkpoints are number %d (%s and %s); a code would open either" % [n, str(by_number[n]).get_file(), f.get_file()], f)
		else:
			by_number[n] = f
	var nums: Array = by_number.keys()
	nums.sort()
	for i in range(1, nums.size()):
		if nums[i] - nums[i - 1] > 1:
			var gap := "%d" % (nums[i - 1] + 1) if nums[i] - nums[i - 1] == 2 else "%d-%d" % [nums[i - 1] + 1, nums[i] - 1]
			_add(YELLOW, "Checkpoint numbers skip %s. Fine if on purpose; never renumber after release" % gap, by_number[nums[i]])


## Text the player reads that isn't in translations.csv, or has no Arabic yet.
func _check_translations() -> void:
	var csv_path := _csv_path()
	var f := FileAccess.open(csv_path, FileAccess.READ)
	if f == null:
		return
	var header := f.get_csv_line()
	var ar_col := 2
	for i in header.size():
		if header[i].strip_edges().to_lower() == "ar":
			ar_col = i
	var csv := {}
	while not f.eof_reached():
		var row := f.get_csv_line()
		if row.size() == 0 or row[0].strip_edges() == "":
			continue
		csv[row[0]] = row[ar_col] if row.size() > ar_col else ""
	for t in _texts:
		var at: Array = _texts[t]
		var short: String = str(t).replace("\n", " ")
		short = short.substr(0, 50) + ("..." if short.length() > 50 else "")
		if not csv.has(t):
			_add(TRANSLATION, "'%s' isn't in translations.csv" % short, at[0], at[1])
		elif str(csv[t]).strip_edges() == "":
			_add(TRANSLATION, "'%s' has no Arabic yet" % short, at[0], at[1])


## translations.csv next to the .translation files the project uses.
func _csv_path() -> String:
	var list: PackedStringArray = ProjectSettings.get_setting("internationalization/locale/translations", PackedStringArray())
	for t in list:
		var p := str(t)
		var csv := p.get_base_dir().path_join(p.get_file().get_slice(".", 0) + ".csv")
		if FileAccess.file_exists(csv):
			return csv
	return ""
