extends Node
## PlayerIdentity. Quietly finds out who is sitting at the keyboard - the
## Discord avatar first, then the Windows account picture - and hands the
## image to whatever UI asks for it later in the game.
## Nothing leaves the machine: the only request made is the image download
## from Discord's CDN, and the result is cached in user://.

signal identity_ready(info: Dictionary)
signal avatar_ready(texture: Texture2D)

const CACHE_DIR := "user://identity"
const CACHE_IMAGE := "user://identity/avatar.png"
const CACHE_INFO := "user://identity/identity.cfg"

## The application id from discord.com/developers. Without it the Discord
## probes are skipped and we go straight to the local fallbacks.
@export var client_id: String = "1550869788111147099"
## Leave empty: no Origin header is how Discord recognises a local game.
## Only fill this in if Discord ever whitelists an origin for the app.
@export var rpc_origin: String = ""
## Discord CDN root. Only changed by the test harness.
@export var cdn_base: String = "https://cdn.discordapp.com"
## Square size asked of the CDN: 16..4096, powers of two.
@export var avatar_size: int = 256
## Look the player up as soon as the game starts, so the reveal has no wait.
@export var auto_start: bool = true
## Use the Windows account picture when Discord is not there.
@export var allow_os_picture: bool = true
## Print every step and every raw Discord reply.
@export var verbose: bool = false

## source, id, username, global_name, avatar_hash. Empty until a probe answers.
var info: Dictionary = {}
var avatar: Texture2D = null

var _busy := false
var _http: HTTPRequest = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_http = HTTPRequest.new()
	add_child(_http)
	_load_cache()
	if auto_start:
		fetch()


func has_avatar() -> bool:
	return avatar != null


func get_avatar() -> Texture2D:
	return avatar


func get_display_name() -> String:
	for key in ["global_name", "username", "os_name"]:
		var v := str(info.get(key, ""))
		if v != "" and v != "<null>":
			return v
	return ""


## Runs the whole chain again. Safe to call from anywhere; ignored while busy.
func fetch() -> void:
	if _busy:
		return
	_busy = true
	_run()


## Wipes the cached picture, for a settings toggle or a fresh playthrough.
func forget() -> void:
	DirAccess.remove_absolute(CACHE_IMAGE)
	DirAccess.remove_absolute(CACHE_INFO)
	info = {}
	avatar = null


func _run() -> void:
	# Always give the caller a frame to connect to the signals: some paths
	# finish with no await at all and would emit before anyone is listening.
	await get_tree().process_frame
	var user := await _ask_discord()
	if not user.is_empty():
		var tex := await _download_avatar(user)
		if tex:
			_adopt(tex, {
				"source": "discord",
				"id": str(user.get("id", "")),
				"username": str(user.get("username", "")),
				"global_name": str(user.get("global_name", "")),
				"avatar_hash": str(user.get("avatar", "")),
			})
			return
	if allow_os_picture:
		var tex := _load_os_picture()
		if tex:
			_adopt(tex, {"source": "os", "os_name": OS.get_environment("USERNAME")})
			return
	if avatar:
		# Nothing new, but a cached picture from an earlier session is still good.
		_finish()
		return
	info = {"source": "none", "os_name": OS.get_environment("USERNAME")}
	_finish()


func _ask_discord() -> Dictionary:
	if client_id == "":
		return {}
	var pipe := DiscordPipeProbe.new()
	pipe.client_id = client_id
	pipe.verbose = verbose
	add_child(pipe)
	pipe.start()
	var user: Dictionary = await pipe.finished
	pipe.queue_free()
	if not user.is_empty():
		return user

	var ws := DiscordWSProbe.new()
	ws.client_id = client_id
	ws.origin = rpc_origin
	ws.verbose = verbose
	add_child(ws)
	ws.start()
	user = await ws.finished
	ws.queue_free()
	return user


func _download_avatar(user: Dictionary) -> Texture2D:
	var url := _avatar_url(user)
	if verbose:
		print("PlayerIdentity: GET ", url)
	var err := _http.request(url)
	if err != OK:
		return null
	var res: Array = await _http.request_completed
	if int(res[1]) != 200:
		push_warning("PlayerIdentity: avatar download returned %s" % res[1])
		return null
	var img := Image.new()
	if img.load_png_from_buffer(res[3]) != OK:
		return null
	img.save_png(CACHE_IMAGE)
	return ImageTexture.create_from_image(img)


func _avatar_url(user: Dictionary) -> String:
	var id := str(user.get("id", ""))
	var hash_str := str(user.get("avatar", ""))
	if hash_str != "" and hash_str != "<null>":
		return "%s/avatars/%s/%s.png?size=%d" % [cdn_base, id, hash_str, avatar_size]
	# No picture set: Discord serves one of its default shapes instead.
	var index := 0
	var disc := str(user.get("discriminator", "0"))
	if disc != "0" and disc.is_valid_int():
		index = int(disc) % 5
	elif id.is_valid_int():
		index = (int(id) >> 22) % 6
	return "%s/embed/avatars/%d.png" % [cdn_base, index]


## Windows keeps the account picture in a few places and a few shapes: plain
## jpg/png, and .accountpicture-ms containers with the real image inside.
func _load_os_picture() -> Texture2D:
	for root in _picture_roots():
		var file := _best_picture_in(root, 2)
		if file == "":
			continue
		var img := _image_from_file(file)
		if img == null:
			continue
		img.save_png(CACHE_IMAGE)
		return ImageTexture.create_from_image(img)
	return null


func _picture_roots() -> PackedStringArray:
	var roots := PackedStringArray()
	var appdata := OS.get_environment("APPDATA").replace("\\", "/")
	if appdata != "":
		roots.append(appdata + "/Microsoft/Windows/AccountPictures")
	var public_dir := OS.get_environment("PUBLIC").replace("\\", "/")
	if public_dir != "":
		roots.append(public_dir + "/AccountPictures")
	return roots


## Biggest file wins: Windows stores several sizes of the same face.
func _best_picture_in(dir_path: String, depth: int) -> String:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return ""
	var best := ""
	var best_size := 0
	for file in dir.get_files():
		var ext := file.get_extension().to_lower()
		if not ext in ["jpg", "jpeg", "png", "accountpicture-ms"]:
			continue
		var f := FileAccess.open(dir_path + "/" + file, FileAccess.READ)
		if f == null:
			continue
		var size := f.get_length()
		f.close()
		if size > best_size:
			best_size = size
			best = dir_path + "/" + file
	if best != "" or depth <= 0:
		return best
	for sub in dir.get_directories():
		best = _best_picture_in(dir_path + "/" + sub, depth - 1)
		if best != "":
			return best
	return ""


func _image_from_file(path: String) -> Image:
	if path.get_extension().to_lower() != "accountpicture-ms":
		return Image.load_from_file(path)
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var bytes := f.get_buffer(f.get_length())
	f.close()
	return carve_image(bytes)


## An .accountpicture-ms is a wrapper holding the face at several sizes. Pull
## out every image that starts inside it and keep the widest one.
static func carve_image(bytes: PackedByteArray) -> Image:
	var png_sig := PackedByteArray([0x89, 0x50, 0x4E, 0x47])
	var jpg_sig := PackedByteArray([0xFF, 0xD8, 0xFF])
	var best: Image = null
	for entry in [[png_sig, "png"], [jpg_sig, "jpg"]]:
		var sig: PackedByteArray = entry[0]
		var from := 0
		while true:
			var at := _find_seq(bytes, sig, from)
			if at < 0:
				break
			from = at + 1
			var img := Image.new()
			var slice := bytes.slice(at)
			var err := img.load_png_from_buffer(slice) if entry[1] == "png" else img.load_jpg_from_buffer(slice)
			if err == OK and (best == null or img.get_width() > best.get_width()):
				best = img
	return best


static func _find_seq(bytes: PackedByteArray, seq: PackedByteArray, from: int) -> int:
	var limit := bytes.size() - seq.size()
	var i := from
	while i <= limit:
		var hit := true
		for j in seq.size():
			if bytes[i + j] != seq[j]:
				hit = false
				break
		if hit:
			return i
		i += 1
	return -1


func _adopt(tex: Texture2D, new_info: Dictionary) -> void:
	avatar = tex
	info = new_info
	_save_info()
	_finish()


func _finish() -> void:
	_busy = false
	if verbose:
		print("PlayerIdentity: ", info)
	identity_ready.emit(info)
	if avatar:
		avatar_ready.emit(avatar)


func _load_cache() -> void:
	DirAccess.make_dir_recursive_absolute(CACHE_DIR)
	var cfg := ConfigFile.new()
	if cfg.load(CACHE_INFO) == OK:
		for key in cfg.get_section_keys("identity"):
			info[key] = cfg.get_value("identity", key)
	if FileAccess.file_exists(CACHE_IMAGE):
		var img := Image.load_from_file(CACHE_IMAGE)
		if img:
			avatar = ImageTexture.create_from_image(img)


func _save_info() -> void:
	var cfg := ConfigFile.new()
	for key in info:
		cfg.set_value("identity", key, info[key])
	cfg.save(CACHE_INFO)
