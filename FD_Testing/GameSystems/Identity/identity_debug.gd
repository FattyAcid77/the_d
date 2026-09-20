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
	var roots: PackedStringArray = pi._picture_roots()
	if roots.is_empty():
		print("os picture: no APPDATA or PUBLIC")
		return
	for root in roots:
		var dir := DirAccess.open(root)
		if dir == null:
			print("os picture: ", root, " -> folder not there")
			continue
		print("os picture: ", root, " -> files ", dir.get_files(), " folders ", dir.get_directories())
		print("  best: ", pi._best_picture_in(root, 2))
