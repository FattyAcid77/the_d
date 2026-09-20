class_name ResList
## Folder scanning that survives export.
##
## In the editor, DirAccess lists "thing.tres". In an exported game the same
## folder lists "thing.tres.remap" and every extension check comes back
## empty, so a system that loads its content by scanning a folder finds
## nothing and the game looks broken for no reason. Use these instead.


## Full paths of the .tres/.res files directly in a folder, sorted.
static func tres_files(dir_path: String) -> Array[String]:
	return files_with_extensions(dir_path, ["tres", "res"])


## Same idea for any extensions (lowercase, no dot).
static func files_with_extensions(dir_path: String, exts: Array) -> Array[String]:
	var out: Array[String] = []
	for file in _list(dir_path):
		if exts.has(file.get_extension().to_lower()):
			out.append(dir_path.path_join(file))
	out.sort()
	return out


# File names in the folder with any ".remap" already stripped off.
static func _list(dir_path: String) -> Array[String]:
	var seen := {}
	var names: Array[String] = []

	# ResourceLoader knows the real names inside a pck
	for f in ResourceLoader.list_directory(dir_path):
		if f.ends_with("/"):
			continue
		if not seen.has(f):
			seen[f] = true
			names.append(f)

	# DirAccess covers the editor, and anything the loader didn't list
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
					clean = ""
				if clean != "" and not seen.has(clean):
					seen[clean] = true
					names.append(clean)
			f2 = dir.get_next()
		dir.list_dir_end()

	return names


## tres_files, but into every subfolder too.
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


## True if the folder exists, in the editor or in a build.
static func dir_exists(dir_path: String) -> bool:
	if DirAccess.open(dir_path) != null:
		return true
	return not ResourceLoader.list_directory(dir_path).is_empty()
