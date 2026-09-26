extends Node
## PlayerIdentity. Quietly finds out who is sitting at the keyboard - the
## Discord avatar first, then the Windows account picture - and hands the
## image to whatever UI asks for it later in the game.
## Nothing leaves the machine: the only request made is the image download
## from Discord's CDN, and the result is cached in user://.
## Also finds the desktop wallpaper, Wallpaper Engine's moving one first.

signal identity_ready(info: Dictionary)
signal avatar_ready(texture: Texture2D)
## The wallpaper lookup finished. texture is the first frame, or null.
signal wallpaper_ready(texture: Texture2D)

const CACHE_DIR := "user://identity"
const CACHE_IMAGE := "user://identity/avatar.png"
const CACHE_INFO := "user://identity/identity.cfg"
const WINDOWS_HELPER := "res://FD_Testing/GameSystems/Identity/WindowsUserPicture.cs"
const DESKTOP_HELPER := "res://FD_Testing/GameSystems/Identity/WindowsDesktop.cs"
const WALL_CACHE := "user://identity/wallpaper"
const WALL_MAX_WIDTH := 640
const WALL_MAX_PIXELS := 30000000

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
## Look for a Wallpaper Engine wallpaper before the Windows one.
@export var use_wallpaper_engine: bool = true
## Highest Wallpaper Engine age rating shown; anything above falls back to the Windows wallpaper.
@export_enum("Everyone", "Questionable", "Mature") var wallpaper_max_rating: int = 0
## Frames kept from a moving wallpaper. More = a longer loop and more memory.
@export var wallpaper_max_frames: int = 150
## Wallpaper Engine's folder. Empty = find it. Only set by the test harness.
@export var wallpaper_engine_dir: String = ""
## The monitors plugged in, when wallpaper_engine_dir is set. Only set by the test harness.
@export var wallpaper_test_monitors: PackedStringArray = []

## source, id, username, global_name, avatar_hash. Empty until a probe answers.
var info: Dictionary = {}
var avatar: Texture2D = null

var _busy := false
var _http: HTTPRequest = null
var _os_picture: Texture2D = null
var _wallpaper: Texture2D = null
var _wall_images: Array[Image] = []
var _wall_delays := PackedFloat32Array()
var _wall_frames: SpriteFrames = null
var _wall_info: Dictionary = {}
var _wall_state := 0  # 0 never asked, 1 looking, 2 settled
var _wall_gen := 0
var _wall_stop: Array = [false]
var _wall_thread: Thread = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_http = HTTPRequest.new()
	add_child(_http)
	_load_cache()
	if auto_start:
		fetch()
		refresh_wallpaper()


func _exit_tree() -> void:
	_stop_wallpaper_job()


func has_avatar() -> bool:
	return avatar != null


func get_avatar() -> Texture2D:
	return avatar


## The best name we have: Discord nickname, then Discord username, then the
## Windows user. Empty only if everything failed.
func get_display_name() -> String:
	for key in ["global_name", "username", "os_name"]:
		var v := _field(key)
		if v != "":
			return v
	return get_os_name()


func get_discord_id() -> String:
	return _field("id")


## The @name, lowercase and unique.
func get_username() -> String:
	return _field("username")


## The display name shown in Discord, which the player picked themselves.
func get_nickname() -> String:
	return _field("global_name")


## The Windows account name, e.g. Fahad-Alhawas. Same as get_os_name().
func get_pc_user() -> String:
	return get_os_name()


## The machine name, e.g. FAHAD-PC.
func get_pc_name() -> String:
	var v := OS.get_environment("COMPUTERNAME")
	return v if v != "" else OS.get_environment("HOSTNAME")


## The Discord picture only, null if Discord never answered.
func get_discord_avatar() -> Texture2D:
	return avatar if _field("source") == "discord" else null


## The Windows account picture, even when the Discord one is on show.
## Same as get_os_picture().
func get_pc_avatar() -> Texture2D:
	return get_os_picture()


## Fills {id} {username} {nickname} {name} {pc_user} {pc_name} {wallpaper}
## in any string: PlayerIdentity.format("Patient file: {name}")
func format(text: String) -> String:
	return text \
		.replace("{id}", get_discord_id()) \
		.replace("{username}", get_username()) \
		.replace("{nickname}", get_nickname()) \
		.replace("{name}", get_display_name()) \
		.replace("{pc_user}", get_pc_user()) \
		.replace("{pc_name}", get_pc_name()) \
		.replace("{wallpaper}", str(_wall_info.get("title", "")))


func _field(key: String) -> String:
	var v := str(info.get(key, ""))
	return "" if v == "<null>" or v == "null" else v


## The Windows account name, whatever Discord says. Empty off Windows.
func get_os_name() -> String:
	return OS.get_environment("USERNAME")


## The Windows account picture read straight from disk, skipping Discord and
## the cache. Null when the account has none.
func get_os_picture() -> Texture2D:
	if _os_picture == null:
		var img := _find_os_image()
		if img:
			_os_picture = ImageTexture.create_from_image(img)
	return _os_picture


## The player's desktop wallpaper: the first frame of a Wallpaper Engine one,
## else the Windows one. Null for a solid colour or off Windows. Asked before
## the lookup has finished, it reads the Windows one on the spot.
func get_wallpaper() -> Texture2D:
	if _wallpaper == null:
		if not _wall_images.is_empty():
			_wallpaper = ImageTexture.create_from_image(_wall_images[0])
		elif _wall_state != 2:
			var img := _find_wallpaper_image()
			if img:
				_wallpaper = ImageTexture.create_from_image(img)
	return _wallpaper


## The moving wallpaper for an AnimatedSprite2D, animation "default", exact
## gif timing. Null unless the wallpaper moves.
func get_wallpaper_frames() -> SpriteFrames:
	if _wall_frames == null and _wall_images.size() > 1:
		_wall_frames = SpriteFrames.new()
		_wall_frames.set_animation_speed("default", 100.0)
		for i in _wall_images.size():
			_wall_frames.add_frame("default", ImageTexture.create_from_image(_wall_images[i]), _wall_delays[i] * 100.0)
	return _wall_frames


## Every frame as an Image, for code that reshapes them (the PC). One image
## for a still wallpaper, empty until the lookup has finished.
func get_wallpaper_images() -> Array[Image]:
	return _wall_images


## Seconds each frame of get_wallpaper_images() stays up.
func get_wallpaper_delays() -> PackedFloat32Array:
	return _wall_delays


## source (wallpaper_engine, windows, none), animated, and for Wallpaper
## Engine: title, type, rating, workshop_id, preview. skipped says why a
## Wallpaper Engine wallpaper wasn't used.
func get_wallpaper_info() -> Dictionary:
	return _wall_info


## False while the wallpaper is still being looked up. Asking starts the
## lookup if nothing has yet.
func is_wallpaper_ready() -> bool:
	if _wall_state == 0:
		refresh_wallpaper()
	return _wall_state == 2


## Looks the wallpaper up again in the background, e.g. after a settings
## toggle. wallpaper_ready fires when it's done.
func refresh_wallpaper() -> void:
	_stop_wallpaper_job()
	_wall_gen += 1
	_wall_stop = [false]
	_wall_state = 1
	var settings := {
		"use_we": use_wallpaper_engine,
		"dir": wallpaper_engine_dir,
		"monitors": wallpaper_test_monitors,
		"max_rating": wallpaper_max_rating,
		"max_frames": maxi(wallpaper_max_frames, 1),
	}
	if use_wallpaper_engine and wallpaper_engine_dir == "":
		settings.merge(desktop_facts(), true)
	_wall_thread = Thread.new()
	_wall_thread.start(_wallpaper_job.bind(settings, _wall_stop, _wall_gen), Thread.PRIORITY_LOW)


## Runs the whole chain again. Safe to call from anywhere; ignored while busy.
func fetch() -> void:
	if _busy:
		return
	_busy = true
	_run()


## Wipes the cached picture and wallpaper, for a settings toggle or a fresh
## playthrough.
func forget() -> void:
	DirAccess.remove_absolute(CACHE_IMAGE)
	DirAccess.remove_absolute(CACHE_INFO)
	_clear_wallpaper_cache()
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
	var img := _find_os_image()
	if img == null:
		return null
	img.save_png(CACHE_IMAGE)
	return ImageTexture.create_from_image(img)


## Widest picture wins across every place Windows keeps one.
func _find_os_image() -> Image:
	var best: Image = null
	for file in os_picture_files():
		var img := _image_from_file(file)
		if img and (best == null or img.get_width() > best.get_width()):
			best = img
	return best


## Every file that may hold the Windows account picture. The newest copies sit
## in a folder only admin can open, so the readable copies are tried too: the
## tile Windows drops in %TEMP% as <user>.bmp, and the old .dat in ProgramData.
func os_picture_files() -> PackedStringArray:
	var out := PackedStringArray()
	for root in _picture_roots():
		var file := _best_picture_in(root, 2)
		if file != "":
			out.append(file)
	var asked := _windows_tile_path()
	if asked != "" and FileAccess.file_exists(asked):
		out.append(asked)
	var user := OS.get_environment("USERNAME")
	if user == "":
		return out
	var temp := _env_path("TEMP")
	var domain := OS.get_environment("USERDOMAIN")
	var data := _env_path("PROGRAMDATA")
	var guesses := PackedStringArray()
	if temp != "":
		guesses.append(temp + "/" + user + ".bmp")
		if domain != "":
			guesses.append(temp + "/" + domain + "+" + user + ".bmp")
	if data != "":
		guesses.append(data + "/Microsoft/User Account Pictures/" + user + ".dat")
	for path in guesses:
		if FileAccess.file_exists(path) and not out.has(path):
			out.append(path)
	return out


## Windows writes its own readable copy when asked through the C# helper.
## Only on Windows and in the .NET build; anywhere else this is "".
func _windows_tile_path() -> String:
	if OS.get_name() != "Windows":
		return ""
	var helper := windows_helper()
	if helper == null:
		return ""
	return str(helper.call("TilePath")).replace("\\", "/")


## The C# WindowsUserPicture object, or null when C# isn't available.
func windows_helper() -> Object:
	return _csharp(WINDOWS_HELPER, "TilePath")


## The C# WindowsDesktop object, or null when C# isn't available.
func desktop_helper() -> Object:
	return _csharp(DESKTOP_HELPER, "ActiveMonitors")


## What the wallpaper lookup needs from Windows, asked in-process through the
## C# helper so no command line is started: monitors (main first), we_exe
## (path or name of the running Wallpaper Engine, "" if closed) and steam.
## Empty without C#; the lookup then falls back to tasklist and reg.
func desktop_facts() -> Dictionary:
	if OS.get_name() != "Windows":
		return {}
	var helper := desktop_helper()
	if helper == null:
		return {}
	return {
		"monitors": PackedStringArray(helper.call("ActiveMonitors")),
		"we_exe": str(helper.call("WallpaperEngine")),
		"steam": str(helper.call("SteamPath")).replace("\\", "/"),
	}


func _csharp(path: String, method: String) -> Object:
	if not ClassDB.class_exists("CSharpScript") or not ResourceLoader.exists(path):
		return null
	var script := load(path) as Script
	if script == null or not script.can_instantiate():
		return null
	var helper: Object = script.new()
	return helper if helper and helper.has_method(method) else null


func _env_path(name: String) -> String:
	return OS.get_environment(name).replace("\\", "/")


## Windows keeps a copy of the current wallpaper as TranscodedWallpaper (no
## extension, usually a jpg) and a screen-sized copy under CachedFiles.
func _find_wallpaper_image() -> Image:
	var appdata := OS.get_environment("APPDATA").replace("\\", "/")
	if appdata == "":
		return null
	var themes := appdata + "/Microsoft/Windows/Themes"
	var f := FileAccess.open(themes + "/TranscodedWallpaper", FileAccess.READ)
	if f:
		var img := image_from_buffer(f.get_buffer(f.get_length()))
		f.close()
		if img:
			return img
	var cached := _best_picture_in(themes + "/CachedFiles", 0)
	if cached != "":
		return Image.load_from_file(cached)
	return null


# --- wallpaper lookup, on a background thread ---------------------------------

func _wallpaper_job(settings: Dictionary, stop: Array, gen: int) -> void:
	var info := {"source": "none"}
	var images: Array[Image] = []
	var delays := PackedFloat32Array()
	var we := _wallpaper_engine_pick(settings)
	if not we.is_empty():
		if WallpaperEngineLink.rating_level(we["rating"]) > int(settings["max_rating"]):
			info["skipped"] = "Wallpaper Engine wallpaper is rated %s" % we["rating"]
		else:
			var bytes := FileAccess.get_file_as_bytes(we["preview"])
			if GifDecoder.is_gif(bytes):
				var anim := _wallpaper_animation(we["preview"], bytes, int(settings["max_frames"]), stop)
				images.assign(anim.get("images", []))
				delays = anim.get("delays", PackedFloat32Array())
			else:
				var img := image_from_buffer(bytes)
				if img:
					images.append(img)
					delays.append(0.0)
			if images.is_empty():
				info["skipped"] = "Wallpaper Engine preview unreadable: " + str(we["preview"])
			else:
				info = we.duplicate()
				info["source"] = "wallpaper_engine"
	if stop[0]:
		return
	if images.is_empty():
		var img := _find_wallpaper_image()
		if img:
			images.append(img)
			delays.append(0.0)
			info["source"] = "windows"
	info["animated"] = images.size() > 1
	_wallpaper_done.call_deferred({"images": images, "delays": delays, "info": info}, gen)


## The running Wallpaper Engine's current wallpaper, or {}.
func _wallpaper_engine_pick(settings: Dictionary) -> Dictionary:
	if not settings["use_we"]:
		return {}
	var dir: String = settings["dir"]
	if dir == "":
		var exe: String = settings["we_exe"] if settings.has("we_exe") else WallpaperEngineLink.running_exe()
		if exe == "":
			return {}
		exe = exe.replace("\\", "/")
		if exe.contains("/") and FileAccess.file_exists(exe.get_base_dir() + "/config.json"):
			dir = exe.get_base_dir()
		else:
			dir = WallpaperEngineLink.find_install_dir(settings.get("steam", ""))
		if dir == "":
			return {}
	return WallpaperEngineLink.current_wallpaper(dir, OS.get_environment("USERNAME"), settings["monitors"])


## Decoding a gif takes a few seconds, so the frames are kept in user:// and
## reused until the preview file changes.
func _wallpaper_animation(path: String, bytes: PackedByteArray, max_frames: int, stop: Array) -> Dictionary:
	var key := ("%s|%d|%d|%d|%d" % [path, FileAccess.get_modified_time(path), bytes.size(),
			max_frames, WALL_MAX_WIDTH]).md5_text()
	var cfg := ConfigFile.new()
	if cfg.load(WALL_CACHE + "/wallpaper.cfg") == OK and cfg.get_value("cache", "key", "") == key:
		var delays: PackedFloat32Array = cfg.get_value("cache", "delays", PackedFloat32Array())
		var images: Array[Image] = []
		for i in delays.size():
			var img := Image.load_from_file(WALL_CACHE + "/%03d.png" % i)
			if img == null:
				images.clear()
				break
			images.append(img)
		if not images.is_empty():
			return {"images": images, "delays": delays}

	var res := GifDecoder.decode(bytes, max_frames, WALL_MAX_WIDTH, WALL_MAX_PIXELS, stop)
	if res.is_empty():
		return {}
	_clear_wallpaper_cache()
	DirAccess.make_dir_recursive_absolute(WALL_CACHE)
	var frames: Array = res["frames"]
	for i in frames.size():
		(frames[i] as Image).save_png(WALL_CACHE + "/%03d.png" % i)
	# the key goes in last, so a cache cut short by quitting is never trusted
	cfg = ConfigFile.new()
	cfg.set_value("cache", "key", key)
	cfg.set_value("cache", "delays", res["delays"])
	cfg.save(WALL_CACHE + "/wallpaper.cfg")
	return {"images": frames, "delays": res["delays"]}


func _wallpaper_done(result: Dictionary, gen: int) -> void:
	if gen != _wall_gen:
		return
	if _wall_thread:
		_wall_thread.wait_to_finish()
		_wall_thread = null
	_wall_images.assign(result["images"])
	_wall_delays = result["delays"]
	_wall_info = result["info"]
	_wallpaper = null
	_wall_frames = null
	_wall_state = 2
	if verbose:
		print("PlayerIdentity: wallpaper ", _wall_info, ", %d frame(s)" % _wall_images.size())
	wallpaper_ready.emit(get_wallpaper())


func _stop_wallpaper_job() -> void:
	if _wall_thread:
		_wall_stop[0] = true
		_wall_thread.wait_to_finish()
		_wall_thread = null


func _clear_wallpaper_cache() -> void:
	var dir := DirAccess.open(WALL_CACHE)
	if dir == null:
		return
	for file in dir.get_files():
		dir.remove(file)


## Decodes by the file's first bytes, not its name.
static func image_from_buffer(bytes: PackedByteArray) -> Image:
	if bytes.size() < 12:
		return null
	var img := Image.new()
	var err := ERR_FILE_UNRECOGNIZED
	if bytes[0] == 0x89 and bytes[1] == 0x50:
		err = img.load_png_from_buffer(bytes)
	elif bytes[0] == 0xFF and bytes[1] == 0xD8:
		err = img.load_jpg_from_buffer(bytes)
	elif bytes[0] == 0x42 and bytes[1] == 0x4D:
		return bmp_image(bytes)
	elif bytes.slice(8, 12).get_string_from_ascii() == "WEBP":
		err = img.load_webp_from_buffer(bytes)
	return img if err == OK else null


## Godot only reads bottom-up .bmp files. Windows also writes top-down ones
## (negative height), so those get their height flipped, then the image.
static func bmp_image(bytes: PackedByteArray) -> Image:
	if bytes.size() < 26 or bytes[0] != 0x42 or bytes[1] != 0x4D:
		return null
	var img := Image.new()
	var height := bytes.decode_s32(22)
	if height >= 0:
		return img if img.load_bmp_from_buffer(bytes) == OK else null
	var fixed := bytes.duplicate()
	fixed.encode_s32(22, -height)
	if img.load_bmp_from_buffer(fixed) != OK:
		return null
	img.flip_y()
	return img


## The <user>.dat Windows keeps in ProgramData is a user tile: version, a count,
## then elements of type/length/data, where type 1 is a whole .bmp file.
## If the header isn't that, any .bmp found inside is tried instead.
static func tile_image(bytes: PackedByteArray) -> Image:
	var best: Image = null
	if bytes.size() >= 8 and bytes.decode_u32(0) == 1:
		var at := 8
		for i in bytes.decode_u32(4):
			if at + 8 > bytes.size():
				break
			var kind := bytes.decode_u32(at)
			var length := bytes.decode_u32(at + 4)
			at += 8
			if length > bytes.size() - at:
				break
			if kind == 1:
				best = _wider(best, bmp_image(bytes.slice(at, at + length)))
			at += length
	if best:
		return best
	var bm := PackedByteArray([0x42, 0x4D])
	var from := 0
	for tries in 64:
		var start := _find_seq(bytes, bm, from)
		if start < 0 or start + 26 > bytes.size():
			break
		from = start + 1
		var size := bytes.decode_u32(start + 2)
		if size > 26 and size <= bytes.size() - start:
			best = _wider(best, bmp_image(bytes.slice(start, start + size)))
	return best


static func _wider(a: Image, b: Image) -> Image:
	if b == null:
		return a
	if a == null or b.get_width() > a.get_width():
		return b
	return a


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
	# the account picture folders are hidden, and DirAccess skips hidden by default
	dir.include_hidden = true
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
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.is_empty():
		return null
	match path.get_extension().to_lower():
		"accountpicture-ms":
			return carve_image(bytes)
		"dat":
			var tile := tile_image(bytes)
			return tile if tile else carve_image(bytes)
	return image_from_buffer(bytes)


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
	var i := bytes.find(seq[0], from)
	while i >= 0 and i <= limit:
		var hit := true
		for j in range(1, seq.size()):
			if bytes[i + j] != seq[j]:
				hit = false
				break
		if hit:
			return i
		i = bytes.find(seq[0], i + 1)
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
