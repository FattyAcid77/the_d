extends Node
## Temporary debug tool. Attach to a Node in an empty scene, press F6, and read
## the Output panel: it says which step of the identity chain is failing.
## Delete the scene once the picture shows up.


func _ready() -> void:
	print("--- identity debug ---")
	print("os: ", OS.get_name())

	var pi := get_node_or_null("/root/PlayerIdentity")
	if pi == null:
		print("FAIL: /root/PlayerIdentity does not exist. The autoload is missing or")
		print("      the Name box is not exactly PlayerIdentity.")
		return
	print("autoload: ok")
	print("client_id: ", "EMPTY - fill it in player_identity.gd" if pi.client_id == "" else pi.client_id)
	print("rpc_origin: ", "(empty, correct)" if pi.rpc_origin == "" else pi.rpc_origin)

	_scan_pipes(pi.client_id)
	_scan_os_picture()
	_scan_wallpaper_engine()

	pi.verbose = true
	pi.forget()
	pi.fetch()
	var info: Dictionary = await pi.identity_ready
	print("result: ", info)
	var tex: Texture2D = pi.get_avatar()
	if tex:
		print("avatar: %dx%d - the picture is there, the problem is in your UI node" % [tex.get_width(), tex.get_height()])
	else:
		print("avatar: none")
	pi.refresh_wallpaper()
	await pi.wallpaper_ready
	print("wallpaper: ", pi.get_wallpaper_info(), ", %d frame(s)" % pi.get_wallpaper_images().size())
	print("--- end ---")


func _scan_pipes(client_id: String) -> void:
	if OS.get_name() != "Windows":
		print("pipes: skipped, not Windows")
		return
	var opened := ""
	for i in 10:
		for path in DiscordPipeProbe.pipe_paths(i):
			var f := FileAccess.open(path, FileAccess.READ_WRITE)
			if f == null:
				print("pipe %d [%s]: not open (err %d)" % [i, path, FileAccess.get_open_error()])
				continue
			opened = path
			print("pipe %d [%s]: OPEN" % [i, path])
			if client_id != "":
				_handshake(f, client_id)
			f.close()
			break
		if opened != "":
			break
	if opened == "":
		print("pipes: none open. Discord desktop closed, or it runs as another")
		print("       Windows user than the editor (admin vs normal).")


func _handshake(f: FileAccess, client_id: String) -> void:
	var body := JSON.stringify({"v": 1, "client_id": client_id}).to_utf8_buffer()
	var head := PackedByteArray()
	head.resize(8)
	head.encode_u32(0, 0)
	head.encode_u32(4, body.size())
	f.store_buffer(head)
	f.store_buffer(body)
	f.flush()
	var reply := PackedByteArray()
	var deadline := Time.get_ticks_msec() + 2000
	while reply.size() < 8 and Time.get_ticks_msec() < deadline:
		var chunk := f.get_buffer(8 - reply.size())
		if chunk.is_empty():
			OS.delay_msec(20)
		else:
			reply.append_array(chunk)
	if reply.size() < 8:
		print("  no answer from Discord on this pipe")
		return
	var size := reply.decode_u32(4)
	print("  raw: ", f.get_buffer(size).get_string_from_utf8())


func _scan_os_picture() -> void:
	var pi := get_node("/root/PlayerIdentity")
	for root in pi._picture_roots():
		_list(root, 2)
	_list(pi._env_path("PROGRAMDATA") + "/Microsoft/User Account Pictures", 0)
	var helper: Object = pi.windows_helper()
	print("C# helper: ", "not available (not the .NET build, or not built yet)" if helper == null else "asked Windows -> '%s'" % helper.call("TilePath"))
	var user := OS.get_environment("USERNAME")
	var bmp: String = pi._env_path("TEMP") + "/" + user + ".bmp"
	print("os picture: ", bmp, " -> ", "there" if FileAccess.file_exists(bmp) else "not there")
	for file in pi.os_picture_files():
		var img: Image = pi._image_from_file(file)
		if img:
			print("  candidate: ", file, " -> %dx%d" % [img.get_width(), img.get_height()])
			continue
		var f := FileAccess.open(file, FileAccess.READ)
		if f == null:
			print("  candidate: ", file, " -> can't open (", error_string(FileAccess.get_open_error()), ")")
		else:
			print("  candidate: ", file, " -> %d bytes, starts %s" % [f.get_length(), f.get_buffer(24).hex_encode()])
	var pic: Texture2D = pi.get_os_picture()
	print("os picture used by the PC: ", "%dx%d" % [pic.get_width(), pic.get_height()] if pic else "none")


func _list(path: String, depth: int) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		print("os picture: ", path, " -> can't open (", error_string(DirAccess.get_open_error()), ")")
		return
	dir.include_hidden = true
	print("os picture: ", path, " -> files ", dir.get_files())
	if depth > 0:
		for sub in dir.get_directories():
			_list(path + "/" + sub, depth - 1)


func _scan_wallpaper_engine() -> void:
	var pi := get_node("/root/PlayerIdentity")
	var facts: Dictionary = pi.desktop_facts()
	if facts.is_empty():
		print("wallpaper C# helper: not available (not the .NET build, or not built yet) - using tasklist")
		facts = {"we_exe": WallpaperEngineLink.running_exe(), "monitors": PackedStringArray(), "steam": ""}
	else:
		print("wallpaper C# helper: ok")
		for m in facts["monitors"]:
			print("  monitor plugged in: ", m)
	var exe: String = facts["we_exe"]
	print("wallpaper engine: ", exe + " running" if exe != "" else "not running (the Windows wallpaper is used)")
	var dir := WallpaperEngineLink.find_install_dir(facts["steam"])
	print("wallpaper engine folder: ", dir if dir != "" else "not found in any Steam library")
	if dir == "":
		return
	var config: Variant = JSON.parse_string(WallpaperEngineLink._text(dir + "/config.json"))
	if config is Dictionary:
		var screens := WallpaperEngineLink.selected_screens(config, OS.get_environment("USERNAME"))
		var pick := WallpaperEngineLink.pick_screen(screens, facts["monitors"])
		for pair in screens:
			var mark := "  <- " + str(pick[2]) if not pick.is_empty() and pair[0] == pick[0] else ""
			print("  config.json screen %s -> %s%s" % [pair[0], pair[1], mark])
	print("  current: ", WallpaperEngineLink.current_wallpaper(dir, OS.get_environment("USERNAME"), facts["monitors"]))
