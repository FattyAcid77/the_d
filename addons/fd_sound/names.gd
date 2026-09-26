@tool
extends RefCounted
## Every name the team picks instead of typing: flags (who sets them, who
## reads them) and ids (death causes, items, windows, rooms, progress states).
## Read from the project's files as text, so nothing is loaded or run.

signal changed

const USE := "use"
const SET := "set"
const CLEAR := "clear"
## Where each id kind lives: the autoload, its folder constant, the class and
## the field that holds the id.
const KINDS := {
	"death": ["Deaths", "CAUSES_DIR", "DeathCause", "id"],
	"item": ["MedicalItems", "ITEMS_DIR", "MedicalItem", "type"],
	"window": ["PopupWindows", "DEFS_DIR", "PopupWindowDef", "id"],
	"room": ["MapRooms", "ROOMS_DIR", "MapRoomDef", "id"],
}
## Flags the game makes by itself from an id: "item:" + every item type...
const FAMILIES := {
	"item": ["item:", "picking it up or getting it"],
	"death": ["died_of:", "dying of it"],
	"window": ["window_seen:", "the window opening"],
}

## name -> {set: [where], use: [where], clear: [where]}
var flags := {}
## "topic_seen:" -> where. Any flag that starts with it is made by the game.
var prefixes := {}
## kind -> {id: where}. Kinds: death, item, window, room, state.
var ids := {"death": {}, "item": {}, "window": {}, "room": {}, "state": {}}
var _dirs := {}


## What a flag field does with its flag, from its name. "" = not a flag field.
static func flag_role(prop: String) -> String:
	if not prop.contains("flag") or prop.contains("prefix") or prop == "flag_layers":
		return ""
	if prop.begins_with("clear"):
		return CLEAR
	for p in ["require", "hide", "show", "reveal", "unlock", "active", "disabled", "blocked", "auto_advance_when"]:
		if prop.begins_with(p):
			return USE
	if prop == "close_flag" or prop == "flag":
		return USE
	return SET


## Which id kind a field holds, from its name. "" = none.
static func id_kind(prop: String) -> String:
	if prop.contains("death_cause") or prop == "cause_id":
		return "death"
	if prop == "item_type":
		return "item"
	if prop.ends_with("window_id"):
		return "window"
	if prop == "room_id":
		return "room"
	if prop == "state_name" or prop == "next_state":
		return "state"
	return ""


func scan() -> void:
	flags.clear()
	prefixes.clear()
	for k in ids:
		ids[k] = {}
	_read_dirs()
	var files: Array[String] = []
	var root := EditorInterface.get_resource_filesystem().get_filesystem()
	if root:
		_collect(root, files)
	for path in files:
		match path.get_extension():
			"tscn", "tres":
				_scan_text_resource(path)
			"gd":
				_scan_script(path)
	_add_families()
	changed.emit()


# --- asking ------------------------------------------------------------------

## Is anything setting this flag? (a field, a dialog action, a script, the game)
func is_set_somewhere(flag: String) -> bool:
	if flags.has(flag) and not flags[flag][SET].is_empty():
		return true
	for p in prefixes:
		if flag.begins_with(p):
			return true
	return false


func is_read_somewhere(flag: String) -> bool:
	return flags.has(flag) and not flags[flag][USE].is_empty()


## [status, tooltip] for a value in a field. status: ok, warn, bad or "".
func check(kind: String, value: String) -> Array:
	var v := value.strip_edges()
	if v == "":
		return ["", ""]
	if kind.begins_with("flag:"):
		var role := kind.substr(5)
		if role == SET:
			if is_read_somewhere(v):
				return ["ok", "Read by:\n" + _where(v, USE)]
			return ["", "Nothing reads '%s' yet." % v]
		if is_set_somewhere(v):
			return ["ok", "Set by:\n" + _where(v, SET)]
		return ["warn", "Nothing sets '%s', so this waits forever. A typo, or a step that's missing.\n(A script that builds the name at runtime can't be seen; if that's the case it's fine.)" % v]
	var known: Dictionary = ids.get(kind, {})
	if known.has(v):
		return ["ok", "%s  (%s)" % [v, known[v]]]
	return ["bad", "No %s called '%s'. Pick one from the list, or make it first." % [_kind_name(kind), v]]


## Rows for the pick list: [{id, note}].
func rows(kind: String) -> Array:
	var out := []
	if kind.begins_with("flag"):
		var names: Array = flags.keys()
		names.sort()
		for n in names:
			var f: Dictionary = flags[n]
			var sets := int(f[SET].size())
			var reads := int(f[USE].size())
			var note := "set %d, read %d" % [sets, reads]
			if sets == 0 and not is_set_somewhere(n):
				note = "never set, read %d" % reads
			out.append({"id": n, "note": note})
		return out
	var known: Dictionary = ids.get(kind, {})
	var keys: Array = known.keys()
	keys.sort()
	for k in keys:
		out.append({"id": k, "note": str(known[k]).get_file()})
	return out


func title(kind: String) -> String:
	if kind.begins_with("flag"):
		return "Flags"
	return {"death": "Death causes", "item": "Items", "window": "Popup windows",
			"room": "Map rooms", "state": "Progress states"}.get(kind, kind)


func _kind_name(kind: String) -> String:
	return {"death": "death cause", "item": "item type", "window": "popup window",
			"room": "map room", "state": "progress state"}.get(kind, kind)


func _where(flag: String, role: String) -> String:
	var lines: PackedStringArray = []
	if flags.has(flag):
		for w in flags[flag][role]:
			lines.append("  " + str(w))
	if role == SET:
		for p in prefixes:
			if flag.begins_with(p):
				lines.append("  the game (%s...)" % p)
	if lines.size() > 8:
		var more := lines.size() - 8
		lines = lines.slice(0, 8)
		lines.append("  and %d more" % more)
	return "\n".join(lines)


# --- reading the project -----------------------------------------------------

func _read_dirs() -> void:
	_dirs.clear()
	for kind in KINDS:
		var k: Array = KINDS[kind]
		var path := str(ProjectSettings.get_setting("autoload/" + k[0], "")).trim_prefix("*")
		if path == "" or not ResourceLoader.exists(path):
			continue
		var script: Script = load(path)
		var dir := str(script.get_script_constant_map().get(k[1], ""))
		if dir != "":
			_dirs[kind] = dir.trim_suffix("/") + "/"


func _collect(dir: EditorFileSystemDirectory, out: Array[String]) -> void:
	var p := dir.get_path()
	if p.begins_with("res://addons/") or p.begins_with("res://.godot"):
		return
	for i in dir.get_file_count():
		out.append(dir.get_file_path(i))
	for s in dir.get_subdir_count():
		_collect(dir.get_subdir(s), out)


func _add(flag: String, role: String, where: String) -> void:
	if flag == "":
		return
	if not flags.has(flag):
		flags[flag] = {SET: [], USE: [], CLEAR: []}
	var list: Array = flags[flag][role]
	if not list.has(where):
		list.append(where)


func _add_families() -> void:
	for kind in FAMILIES:
		var fam: Array = FAMILIES[kind]
		for id in ids[kind]:
			_add(str(fam[0]) + str(id), SET, "the game, on %s" % fam[1])
	# map rooms use MapRooms' own prefix
	var mr := str(ProjectSettings.get_setting("autoload/MapRooms", "")).trim_prefix("*")
	if mr != "" and FileAccess.file_exists(mr):
		var m := RegEx.create_from_string("flag_prefix\\s*:\\s*String\\s*=\\s*\"([^\"]*)\"").search(FileAccess.get_file_as_string(mr))
		if m:
			for id in ids["room"]:
				_add(m.get_string(1) + str(id), SET, "the game, on discovering the room")


## Splits a .tscn/.tres into sections and reads each one's properties.
func _scan_text_resource(path: String) -> void:
	var text := FileAccess.get_file_as_string(path)
	if text == "":
		return
	var file_class := ""
	var head := RegEx.create_from_string("script_class=\"([^\"]+)\"").search(text.get_slice("\n", 0))
	if head:
		file_class = head.get_string(1)
	var ext := {}  # ext_resource id -> path
	var section := ""
	var label := ""
	var props := {}
	var key := ""
	var value := ""
	var depth := 0
	var in_str := false
	for raw in text.split("\n"):
		var line: String = raw
		if key != "":
			value += "\n" + line
			var st := _balance(line, depth, in_str)
			depth = st[0]
			in_str = st[1]
			if depth <= 0 and not in_str:
				props[key] = value
				key = ""
			continue
		if line.begins_with("["):
			_section_done(path, file_class, section, label, props, ext)
			props = {}
			section = line.get_slice(" ", 0).trim_prefix("[").trim_suffix("]")
			label = _attr(line, "name")
			if section == "node":
				var parent := _attr(line, "parent")
				label = label if parent == "" or parent == "." else parent + "/" + label
			elif section == "ext_resource":
				ext[_attr(line, "id")] = _attr(line, "path")
			continue
		var eq := line.find(" = ")
		if eq <= 0:
			continue
		var k := line.substr(0, eq)
		var v := line.substr(eq + 3)
		var st := _balance(v, 0, false)
		if st[0] > 0 or st[1]:
			key = k
			value = v
			depth = st[0]
			in_str = st[1]
		else:
			props[k] = v
	_section_done(path, file_class, section, label, props, ext)


func _section_done(path: String, file_class: String, section: String, label: String,
		props: Dictionary, ext: Dictionary) -> void:
	if props.is_empty():
		return
	var where := path.get_file()
	if section == "node" and label != "":
		where = "%s > %s" % [path.get_file(), label]
	for k in props:
		var role := flag_role(k)
		if role != "":
			for s in _strings(props[k]):
				_add(s, role, where)
		elif k == "flag_layers":
			# layer -> flag: only the flags are names
			for m in RegEx.create_from_string("\"[^\"]*\"\\s*:\\s*\"([^\"]*)\"").search_all(props[k]):
				_add(m.get_string(1), USE, where)
	# dialog actions: set_flag / clear_flag / toggle_flag take the flag as args[0]
	for pair in [["action_name", "action_args"], ["action", "args"]]:
		if props.has(pair[0]) and props.has(pair[1]):
			var verbs := _strings(props[pair[0]])
			var args := _strings(props[pair[1]])
			if not verbs.is_empty() and not args.is_empty():
				var verb := verbs[0].strip_edges().get_slice(" ", 0)
				if verb == "set_flag" or verb == "toggle_flag":
					_add(args[0], SET, where)
				elif verb == "clear_flag":
					_add(args[0], CLEAR, where)
	# ids: the main resource of a definition file inside the game's own folder
	if section == "resource":
		for kind in KINDS:
			var k: Array = KINDS[kind]
			if file_class == k[2] and _dirs.has(kind) and path.begins_with(_dirs[kind]) and props.has(k[3]):
				var id_list := _strings(props[k[3]])
				if not id_list.is_empty() and id_list[0] != "":
					ids[kind][id_list[0]] = path
	# progress states: every ProgressState node, by its name
	if section == "node" and props.has("script"):
		var m := RegEx.create_from_string("ExtResource\\(\"([^\"]+)\"\\)").search(str(props["script"]))
		if m and str(ext.get(m.get_string(1), "")).ends_with("progress_state.gd"):
			ids["state"][label.get_file()] = where


func _scan_script(path: String) -> void:
	var text := FileAccess.get_file_as_string(path)
	if not text.contains("flag") and not text.contains("is_set"):
		return
	var rules := [
		["(?:set_flag|toggle_flag)\\(\\s*\"([^\"\\\\]+)\"\\s*[,)]", SET],
		["clear_flag\\(\\s*\"([^\"\\\\]+)\"\\s*[,)]", CLEAR],
		["is_set\\(\\s*\"([^\"\\\\]+)\"\\s*\\)", USE],
	]
	for r in rules:
		for m in RegEx.create_from_string(r[0]).search_all(text):
			var line := text.substr(0, m.get_start()).count("\n") + 1
			_add(m.get_string(1), r[1], "%s:%d" % [path.get_file(), line])
	for m in RegEx.create_from_string("set_flag\\(\\s*\"([^\"\\\\]+)\"\\s*\\+").search_all(text):
		var line := text.substr(0, m.get_start()).count("\n") + 1
		prefixes[m.get_string(1)] = "%s:%d" % [path.get_file(), line]


## Every quoted string in a property's text value.
func _strings(value: String) -> PackedStringArray:
	var out: PackedStringArray = []
	for m in RegEx.create_from_string("\"((?:[^\"\\\\]|\\\\.)*)\"").search_all(value):
		out.append(m.get_string(1))
	return out


func _attr(line: String, attr: String) -> String:
	# \b: "id=" must not match the end of "uid="
	var m := RegEx.create_from_string("\\b" + attr + "=\"([^\"]*)\"").search(line)
	return m.get_string(1) if m else ""


## [bracket depth, inside a string] after reading one more piece of a value.
func _balance(s: String, depth: int, in_str: bool) -> Array:
	var esc := false
	for c in s:
		if in_str:
			if esc:
				esc = false
			elif c == "\\":
				esc = true
			elif c == "\"":
				in_str = false
		elif c == "\"":
			in_str = true
		elif c in "[{(":
			depth += 1
		elif c in "]})":
			depth -= 1
	return [depth, in_str]
