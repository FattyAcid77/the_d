class_name ResList
## Lists .tres files in a folder so it works in the editor and in an exported
## build (where DirAccess only sees .remap names).

static func tres_files(dir_path: String) -> Array[String]:
	return files_with_extensions(dir_path, ["tres", "res"])


## Same, but for any set of extensions (lowercase, no dot).
static func files_with_extensions(dir_path: String, exts: Array) -> Array[String]:
	var out: Array[String] = []
	for file in _list(dir_path):
		if exts.has(file.get_extension().to_lower()):
			out.append(dir_path.path_join(file))
	out.sort()
	return out


## The raw file names in the folder, with any export ".remap" suffix already stripped
static func _list(dir_path: String) -> Array[String]:
	var seen := {}
	var names: Array[String] = []

	# 1) the export-aware way - sees the original file names inside a .pck
	for f in ResourceLoader.list_directory(dir_path):
		if f.ends_with("/"):
			continue  # subfolder - we don't recurse
		if not seen.has(f):
			seen[f] = true
			names.append(f)

	# 2) plain DirAccess - covers the editor and anything the above missed.
	var dir := DirAccess.open(dir_path)
	if dir:
		dir.list_dir_begin()
		var f2 := dir.get_next()
		while f2 != "":
			if not dir.current_is_dir():
				var clean := f2
				if clean.ends_with(".remap"):
					clean = clean.trim_suffix(".remap")
				if clean.ends_with(".import"):
					clean = ""  # import sidecars are not resources
				if clean != "" and not seen.has(clean):
					seen[clean] = true
					names.append(clean)
			f2 = dir.get_next()
		dir.list_dir_end()

	return names


## Same as tres_files, but walks every subfolder too
static func tres_files_recursive(dir_path: String) -> Array[String]:
	var out: Array[String] = []
	_walk(dir_path, out)
	out.sort()
	return out


static func _walk(dir_path: String, out: Array[String]) -> void:
	for f in tres_files(dir_path):
		out.append(f)
	for sub in _subdirs(dir_path):
		_walk(dir_path.path_join(sub), out)


static func _subdirs(dir_path: String) -> Array[String]:
	var seen := {}
	var names: Array[String] = []
	for f in ResourceLoader.list_directory(dir_path):
		if f.ends_with("/"):
			var n := f.trim_suffix("/")
			if not seen.has(n):
				seen[n] = true
				names.append(n)
	var dir := DirAccess.open(dir_path)
	if dir:
		for d in dir.get_directories():
			if not d.begins_with(".") and not seen.has(d):
				seen[d] = true
				names.append(d)
	return names


## Does the folder exist at all (editor or exported)?
static func dir_exists(dir_path: String) -> bool:
	if DirAccess.open(dir_path) != null:
		return true
	return not ResourceLoader.list_directory(dir_path).is_empty()
