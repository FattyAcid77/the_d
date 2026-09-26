class_name WallpaperEngineLink extends RefCounted
## Finds the wallpaper Wallpaper Engine is showing: the entry in its
## config.json for the monitor plugged in right now, then that wallpaper's
## project.json and preview. Thread safe.

const RATINGS := ["everyone", "questionable", "mature"]
const PREVIEW_NAMES := ["preview.gif", "preview.jpg", "preview.png", "preview.webp", "preview.jpeg"]
const EXES := ["wallpaper64.exe", "wallpaper32.exe"]


## True while Wallpaper Engine is running. Installed but closed means the
## player is looking at the plain Windows wallpaper.
static func is_running() -> bool:
	return running_exe() != ""


## "wallpaper64.exe" or "wallpaper32.exe", whichever is running, else "".
## Only used without the C# helper (WindowsDesktop.cs), which asks in-process.
static func running_exe() -> String:
	if OS.get_name() != "Windows":
		return ""
	var out := []
	if OS.execute("tasklist", ["/NH", "/FO", "CSV"], out) != 0:
		return ""
	var text := "".join(out).to_lower()
	for exe in EXES:
		if text.contains("\"%s\"" % exe):
			return exe
	return ""


## Wallpaper Engine's install folder, or "" if it isn't in any Steam library.
## steam_root comes from the C# helper; without it the registry is asked
## through reg, and only when the usual places come up empty.
static func find_install_dir(steam_root: String = "") -> String:
	var libraries := PackedStringArray()
	# a Steam copy of the game already sits in a library, often the same one
	var exe := OS.get_executable_path().replace("\\", "/")
	var at := exe.to_lower().find("/steamapps/")
	if at > 0:
		_add_library(exe.substr(0, at), libraries)
	for env in ["ProgramFiles(x86)", "ProgramFiles"]:
		var root := OS.get_environment(env).replace("\\", "/")
		if root != "":
			_add_library(root + "/Steam", libraries)
	_add_library(steam_root, libraries)
	var dir := _install_in(libraries)
	if dir == "" and steam_root == "":
		_add_library(_steam_path_from_registry(), libraries)
		dir = _install_in(libraries)
	return dir


## What Wallpaper Engine shows on the main screen: {title, type, rating,
## preview, folder, workshop_id, screen}, or {} if it can't be shown.
## monitors are the device paths plugged in now, main one first (C# helper).
static func current_wallpaper(install_dir: String, user: String = "",
		monitors: PackedStringArray = PackedStringArray()) -> Dictionary:
	var config: Variant = JSON.parse_string(_text(install_dir + "/config.json"))
	if not config is Dictionary:
		return {}
	var pick := pick_screen(selected_screens(config, user), monitors)
	if pick.is_empty():
		return {}
	var info := read_project(_resolve(pick[1], install_dir).get_base_dir())
	if not info.is_empty():
		info["screen"] = pick[2]
	return info


## config.json keeps the last wallpaper of every monitor it has ever seen,
## keyed by the monitor's device path, and never drops the old ones. The live
## one is the key that matches a monitor plugged in now. Returns
## [screen id, file, how it was matched], or [].
static func pick_screen(screens: Array, monitors: PackedStringArray) -> Array:
	for i in monitors.size():
		var id := _screen_id(monitors[i])
		for pair in screens:
			if _screen_id(pair[0]) == id:
				return [pair[0], pair[1], "main monitor" if i == 0 else "second monitor"]
	# Wallpaper Engine's "layout" mode names screens by position; the main one sits at 0,0
	for pair in screens:
		if _screen_id(pair[0]) == "monitorpositionl0t0":
			return [pair[0], pair[1], "layout mode, main monitor"]
	if screens.is_empty():
		return []
	return [screens[0][0], screens[0][1], "no monitor matched, first entry (may be old)"]


static func _screen_id(id: String) -> String:
	return id.replace("\\", "/").to_lower()


## The live selection per screen from config.json, for this Windows user
## (every user's if none matches). Includes monitors that are long gone;
## pick_screen sorts that out.
static func selected_files(config: Dictionary, user: String = "") -> PackedStringArray:
	var out := PackedStringArray()
	for pair in selected_screens(config, user):
		if not out.has(pair[1]):
			out.append(pair[1])
	return out


## Same as selected_files, as [screen id, file] pairs.
static func selected_screens(config: Dictionary, user: String = "") -> Array:
	var users: Array = []
	for key in config:
		if user != "" and str(key).to_lower() == user.to_lower():
			users = [config[key]]
			break
		users.append(config[key])
	var out: Array = []
	for u in users:
		var live: Variant = _dig(u, ["general", "wallpaperconfig", "selectedwallpapers"])
		if live is Dictionary:
			_take_screens(live, out)
	return out


## Reads one wallpaper folder. {} if it has no project.json or no preview.
static func read_project(folder: String) -> Dictionary:
	var project: Variant = JSON.parse_string(_text(folder + "/project.json"))
	if not project is Dictionary:
		return {}
	var preview := str(project.get("preview", ""))
	preview = folder + "/" + preview if preview != "" else ""
	if preview == "" or not FileAccess.file_exists(preview):
		preview = ""
		for name in PREVIEW_NAMES:
			if FileAccess.file_exists(folder + "/" + name):
				preview = folder + "/" + name
				break
	if preview == "":
		return {}
	var id: Variant = project.get("workshopid", "")
	if id is float:
		id = int(id)
	if str(id) == "" and folder.get_file().is_valid_int():
		id = folder.get_file()
	return {
		"title": str(project.get("title", "")),
		"type": str(project.get("type", "")).to_lower(),
		"rating": str(project.get("contentrating", "")),
		"preview": preview,
		"folder": folder,
		"workshop_id": str(id),
	}


## 0 Everyone, 1 Questionable, 2 Mature. Local wallpapers carry no rating and
## count as Everyone, the way Wallpaper Engine itself lists them.
static func rating_level(rating: String) -> int:
	return maxi(RATINGS.find(rating.strip_edges().to_lower()), 0)


static func _take_screens(screens: Dictionary, out: Array) -> void:
	for screen in screens:
		var entry: Variant = screens[screen]
		if not entry is Dictionary:
			continue
		var file := str(entry.get("file", ""))
		var playlist: Variant = entry.get("playlist")
		if file == "" and playlist is Dictionary and playlist.get("items") is Array:
			# a playlist with no single file set still names its wallpapers
			var items: Array = playlist["items"]
			if not items.is_empty():
				file = str(items[0])
		if file != "":
			out.append([str(screen), file])


static func _dig(node: Variant, keys: Array) -> Variant:
	for key in keys:
		if not node is Dictionary:
			return null
		node = node.get(key)
	return node


static func _resolve(file: String, install_dir: String) -> String:
	file = file.replace("\\", "/")
	if file.is_absolute_path():
		return file
	return install_dir + "/" + file


static func _install_in(libraries: PackedStringArray) -> String:
	for lib in libraries:
		var dir := lib + "/steamapps/common/wallpaper_engine"
		if FileAccess.file_exists(dir + "/config.json"):
			return dir
	return ""


## A Steam root plus every other library its libraryfolders.vdf lists.
static func _add_library(root: String, into: PackedStringArray) -> void:
	root = root.replace("\\", "/").trim_suffix("/")
	if root == "" or into.has(root):
		return
	into.append(root)
	var vdf := _text(root + "/steamapps/libraryfolders.vdf")
	if vdf == "":
		return
	var re := RegEx.create_from_string("\"path\"\\s+\"([^\"]+)\"")
	for m in re.search_all(vdf):
		var path := m.get_string(1).replace("\\\\", "/").replace("\\", "/").trim_suffix("/")
		if path != "" and not into.has(path):
			into.append(path)


## Only asked when the usual places come up empty.
static func _steam_path_from_registry() -> String:
	if OS.get_name() != "Windows":
		return ""
	var out := []
	if OS.execute("reg", ["query", "HKCU\\Software\\Valve\\Steam", "/v", "SteamPath"], out) != 0:
		return ""
	for line in "".join(out).split("\n"):
		var at := line.find("REG_SZ")
		if at >= 0:
			return line.substr(at + 6).strip_edges()
	return ""


static func _text(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	return FileAccess.get_file_as_string(path).trim_prefix(char(0xFEFF))
