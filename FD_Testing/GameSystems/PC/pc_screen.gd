class_name PcScreen extends CanvasLayer
## The in-game computer. Powers on, logs in as the real player (Windows name,
## picture and wallpaper), then runs a small desktop: character files, the
## tutorial and the social links. The X on the taskbar or Esc shuts it down.

signal powered_on
signal logged_in
signal shut_down
signal closed
signal data_toggled(open: bool)
signal app_opened(app: String)
signal app_closed(app: String)
signal character_selected(character: PcCharacter)
signal scrolled
signal link_opened(url: String)

enum Phase { BOOTING, DESKTOP, CLOSING }

const CANVAS := Vector2(640, 360)

@export_group("Content")
## The character files, in list order. Keep it A-Z when you add one.
@export var characters: Array[PcCharacter] = []
## What the tutorial window says. English here, Arabic in translations.csv. BBCode works.
@export_multiline var tutorial_text: String = ""
## Opened by the Instagram button.
@export var instagram_url: String = ""
## Opened by the X button.
@export var x_url: String = ""
## 24-hour clock instead of 12-hour.
@export var use_24_hour: bool = false

@export_group("Player")
## Put the player's own desktop wallpaper on the screen behind the windows.
@export var use_player_wallpaper: bool = true
## How bright the wallpaper sits behind the glass. 1 = as is.
@export_range(0.0, 1.0) var wallpaper_brightness: float = 0.55
## Play a Wallpaper Engine wallpaper moving, not just its first frame.
@export var animate_wallpaper: bool = true
## How fast a moving wallpaper plays. 0 freezes it, negative plays it backwards.
@export var wallpaper_speed: float = 1.0
## Redraw the player's picture and wallpaper on the art's pixel grid.
@export var pixelate_player_images: bool = true
## Name on the login bar when Windows gives none.
@export var fallback_name: String = "User"
## Use the Discord picture when Windows won't give one.
@export var discord_fallback: bool = true

@export_group("Wallpaper effects")
## Slow drift and zoom on a still wallpaper (a still preview or the Windows one).
@export var still_drift: bool = true
## Screen flicker on a still wallpaper.
@export var still_flicker: bool = true
## Slow drift and zoom on a moving wallpaper.
@export var moving_drift: bool = false
## Screen flicker on a moving wallpaper.
@export var moving_flicker: bool = true
## How close the drift zooms in at its nearest. 1 = no zoom.
@export_range(1.0, 2.0, 0.01) var drift_zoom: float = 1.15
## Seconds for one slow zoom in and back out. wallpaper_speed scales it.
@export var drift_seconds: float = 30.0
## How dark the flicker gets. 0 = none, 1 = the dips go black.
@export_range(0.0, 1.0, 0.01) var flicker_strength: float = 0.2
## Average seconds between flicker dips.
@export var flicker_every: float = 4.0

@export_group("Timing")
## Monitor still dark before it powers on.
@export var off_seconds: float = 0.5
## Screen lit but empty, before the login.
@export var power_seconds: float = 0.35
## How long the login spinner turns.
@export var login_seconds: float = 2.0
## Login spinner frames per second.
@export var login_fps: float = 6.0
## Screen on, then off, when shutting down.
@export var shutdown_seconds: float = 0.6
## Fade from the game and back.
@export var fade_seconds: float = 0.25

@export_group("Art")
@export var boot_off: Texture2D
@export var boot_on: Texture2D
## The login frames side by side, each 640x360.
@export var login_sheet: Texture2D
## The desktop with the Arabic taskbar label.
@export var desktop_arabic: Texture2D
## The page under the list when a character has no page art of its own.
@export var default_page: Texture2D
## The mouse while the PC is up. Scaled up with the art.
@export var cursor: Texture2D
## The pixel of the cursor that clicks.
@export var cursor_hotspot: Vector2i = Vector2i(2, 2)

@export_group("Behaviour")
## Freeze the world while the PC is up.
@export var pause_game: bool = true
@export var debug_log: bool = false

var phase: Phase = Phase.BOOTING
var app: String = ""
var scroll: int = 0
var selected: int = -1

var _was_paused := false
var _mouse_mode := Input.MOUSE_MODE_VISIBLE
var _restored := false
var _cursor_scale := 0
var _desktop_english: Texture2D
var _wall_frames: Array[Texture2D] = []
var _wall_delays := PackedFloat32Array()
var _wall_index := 0
var _wall_time := 0.0
var _wall_mat: ShaderMaterial
var _drift_time := 0.0
var _drift_mix := 0.0
var _flicker_mix := 0.0
var _push := 1.0
var _push_tween: Tween
var _dip_wait := 0.0
var _dip_left := 0.0
var _dip_dim := 0.0
var _rng := RandomNumberGenerator.new()
var _icons := {}
var _apps := {}

static var _sharp_font: Font = null

@onready var _root: Control = %Root
@onready var _stage: Control = %Stage
@onready var _boot: TextureRect = %Boot
@onready var _avatar: TextureRect = %Avatar
@onready var _user_name: Label = %UserName
@onready var _desktop: TextureRect = %Desktop
@onready var _wallpaper: TextureRect = %Wallpaper
@onready var _glare: TextureRect = %Glare
@onready var _clock: PcClock = %Clock
@onready var _data_bar: Control = %DataBar
@onready var _slots_box: Control = %Slots
@onready var _arrow_left: TextureButton = %ArrowLeft
@onready var _arrow_right: TextureButton = %ArrowRight
@onready var _pointer: TextureRect = %Pointer
@onready var _page: TextureRect = %Page
@onready var _page_text: RichTextLabel = %PageText
@onready var _tutorial_text: RichTextLabel = %TutorialText


func _ready() -> void:
	SoundLink.attach(self)  # every signal here becomes a SoundMap moment
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("pc_screen")
	_apps = {"characters": %CharactersApp, "tutorial": %TutorialApp, "media": %MediaApp}
	_desktop_english = _desktop.texture
	_clock.use_24_hour = use_24_hour
	_sharpen_font()
	_wire()
	var loc := get_node_or_null("/root/Loc")
	if loc and loc.has_signal("language_changed"):
		loc.language_changed.connect(_on_language_changed)
	_apply_language()
	_layout()
	get_viewport().size_changed.connect(_layout)

	if pause_game:
		_was_paused = get_tree().paused
		get_tree().paused = true
	_mouse_mode = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_boot_up()


func _exit_tree() -> void:
	_restore()


func _process(delta: float) -> void:
	_step_effects(delta)
	if _wall_frames.size() < 2 or wallpaper_speed == 0.0:
		return
	_wall_time += delta * absf(wallpaper_speed)
	var step := 1 if wallpaper_speed > 0.0 else -1
	var start := _wall_index
	var hops := 0
	while _wall_time >= _wall_delays[_wall_index] and hops < _wall_frames.size():
		_wall_time -= _wall_delays[_wall_index]
		_wall_index = posmod(_wall_index + step, _wall_frames.size())
		hops += 1
	if _wall_index != start:
		_wallpaper.texture = _wall_frames[_wall_index]


# --- boot and shutdown -----------------------------------------------------

func _boot_up() -> void:
	phase = Phase.BOOTING
	_desktop.visible = false
	_boot.visible = true
	_boot.texture = boot_off
	_avatar.visible = false
	_user_name.visible = false
	_root.modulate.a = 0.0
	await _fade(1.0)
	# the monitor is still dark, so a slow wallpaper read goes unseen
	_load_player()
	if not await _wait(off_seconds):
		return
	_boot.texture = boot_on
	powered_on.emit()
	if not await _wait(power_seconds):
		return

	_avatar.visible = _avatar.texture != null
	_user_name.visible = true
	var frames := _login_frames()
	var step := 1.0 / maxf(login_fps, 1.0)
	var t := 0.0
	var i := 0
	while t < login_seconds or i == 0:
		if not frames.is_empty():
			_boot.texture = frames[i % frames.size()]
		i += 1
		if not await _wait(step):
			return
		t += step

	phase = Phase.DESKTOP
	_boot.visible = false
	_desktop.visible = true
	if debug_log:
		print("PcScreen: logged in as ", _user_name.text)
	logged_in.emit()


## Screen on, screen off, fade back to the game.
func shut_down_pc() -> void:
	if phase == Phase.CLOSING:
		return
	phase = Phase.CLOSING
	set_data(false)
	shut_down.emit()
	_desktop.visible = false
	_avatar.visible = false
	_user_name.visible = false
	_boot.visible = true
	_boot.texture = boot_on
	await get_tree().create_timer(shutdown_seconds * 0.5).timeout
	_boot.texture = boot_off
	await get_tree().create_timer(shutdown_seconds * 0.5).timeout
	await _fade(0.0)
	_restore()
	if debug_log:
		print("PcScreen: shut down")
	closed.emit()
	queue_free()


## False once the PC started shutting down, so the boot stops where it is.
func _wait(seconds: float) -> bool:
	if seconds > 0.0:
		await get_tree().create_timer(seconds).timeout
	return phase == Phase.BOOTING and is_inside_tree()


func _fade(to: float) -> void:
	var tw := create_tween()
	tw.tween_property(_root, "modulate:a", to, maxf(fade_seconds, 0.01))
	await tw.finished


func _login_frames() -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	if login_sheet == null:
		return out
	var count := maxi(1, roundi(login_sheet.get_width() / CANVAS.x))
	var w := login_sheet.get_width() / float(count)
	for i in count:
		var frame := AtlasTexture.new()
		frame.atlas = login_sheet
		frame.region = Rect2(i * w, 0, w, login_sheet.get_height())
		out.append(frame)
	return out


func _restore() -> void:
	if _restored:
		return
	_restored = true
	Input.set_custom_mouse_cursor(null)
	Input.mouse_mode = _mouse_mode
	if pause_game and is_inside_tree():
		get_tree().paused = _was_paused


# --- the player --------------------------------------------------------------

func _load_player() -> void:
	var who := ""
	var face: Texture2D = null
	var pi := get_node_or_null("/root/PlayerIdentity")
	if pi == null:
		push_warning("PcScreen: PlayerIdentity autoload is missing, using the fallback name.")
	else:
		who = pi.get_os_name()
		face = pi.get_os_picture()
		if face == null and discord_fallback:
			if pi.has_avatar():
				face = pi.get_avatar()
			else:
				pi.avatar_ready.connect(_on_late_avatar, CONNECT_ONE_SHOT)
		if use_player_wallpaper and not pi.is_wallpaper_ready():
			# still decoding: show what there is, swap in the real one when it lands
			pi.wallpaper_ready.connect(_on_late_wallpaper, CONNECT_ONE_SHOT)
	_user_name.text = who if who != "" else fallback_name
	_avatar.texture = _fit(face, _avatar.size)
	_show_wallpaper()
	if not pixelate_player_images:
		_avatar.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		_wallpaper.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if debug_log:
		print("PcScreen: name '%s', picture %s, wallpaper %s, %d frame(s)" % [_user_name.text,
				face != null, _wallpaper.texture != null, maxi(_wall_frames.size(), int(_wallpaper.texture != null))])


## The player's wallpaper on the screen, every frame fitted once so playing it
## is only a texture swap.
func _show_wallpaper() -> void:
	_wall_frames.clear()
	_wall_delays.clear()
	_wall_index = 0
	_wall_time = 0.0
	var tex: Texture2D = null
	var pi := get_node_or_null("/root/PlayerIdentity")
	if pi and use_player_wallpaper:
		var images: Array[Image] = pi.get_wallpaper_images()
		if animate_wallpaper and images.size() > 1:
			var delays: PackedFloat32Array = pi.get_wallpaper_delays()
			for i in images.size():
				var frame := _fit_image(images[i], _wallpaper.size, 1 if pixelate_player_images else 0)
				if frame:
					_wall_frames.append(frame)
					_wall_delays.append(maxf(delays[i] if i < delays.size() else 0.1, 0.02))
			if not _wall_frames.is_empty():
				tex = _wall_frames[0]
		if tex == null:
			# twice the art grid: room for the drift to zoom in without going soft
			tex = _fit(pi.get_wallpaper(), _wallpaper.size, 2 if pixelate_player_images else 4)
	_wallpaper.texture = tex
	_wallpaper.self_modulate = Color(wallpaper_brightness, wallpaper_brightness, wallpaper_brightness)
	_wallpaper.visible = tex != null
	_glare.visible = _wallpaper.visible
	var mat := _wallpaper_material()
	mat.set_shader_parameter("cells", _wallpaper.size)
	mat.set_shader_parameter("pixelate", pixelate_player_images)


func _on_late_wallpaper(_first: Texture2D) -> void:
	if phase != Phase.CLOSING and is_inside_tree():
		_show_wallpaper()


## Discord answered after the PC opened. Still worth it while the login is up.
func _on_late_avatar(tex: Texture2D) -> void:
	if phase != Phase.BOOTING or _avatar.texture != null:
		return
	_avatar.texture = _fit(tex, _avatar.size)
	_avatar.visible = _user_name.visible


# --- wallpaper effects ---------------------------------------------------------

## True while the wallpaper on screen is a moving one (Wallpaper Engine gif).
func is_wallpaper_moving() -> bool:
	return _wall_frames.size() > 1


## Pushes the wallpaper in (or back out) over some seconds, on top of any
## drift. 1 = normal, 1.5 = half again closer. For dialog and cutscene beats.
func zoom_wallpaper(to: float, seconds: float = 2.0) -> void:
	if _push_tween:
		_push_tween.kill()
	_push_tween = create_tween()
	_push_tween.tween_property(self, "_push", maxf(to, 1.0), maxf(seconds, 0.01)) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## One flicker dip right now, even with flicker turned off. For scares.
func flicker_wallpaper(seconds: float = 0.25, depth: float = 0.8) -> void:
	_dip_left = seconds
	_dip_dim = clampf(depth, 0.0, 1.0)
	_dip_wait = maxf(_dip_wait, seconds + 0.5)


func _wallpaper_material() -> ShaderMaterial:
	if _wall_mat == null:
		_wall_mat = ShaderMaterial.new()
		_wall_mat.shader = preload("res://FD_Testing/GameSystems/PC/pc_wallpaper.gdshader")
		_wallpaper.material = _wall_mat
		# the shader picks one sample per art pixel itself, so it reads the texture smoothly
		_wallpaper.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	return _wall_mat


## Drift and flicker, faded in and out over a moment when switched live.
func _step_effects(delta: float) -> void:
	if _wall_mat == null or not _wallpaper.visible:
		return
	var moving := is_wallpaper_moving()
	var drift_on := moving_drift if moving else still_drift
	var flicker_on := moving_flicker if moving else still_flicker

	_drift_mix = move_toward(_drift_mix, 1.0 if drift_on else 0.0, delta)
	if drift_on:
		_drift_time += delta * wallpaper_speed
	var cycle := TAU * _drift_time / maxf(drift_seconds, 1.0)
	var zoom := (1.0 + (drift_zoom - 1.0) * (0.5 - 0.5 * cos(cycle)) * _drift_mix) * _push
	# the centre wanders only as far as the zoom leaves room, so no edge ever shows
	var room := 0.5 - 0.5 / zoom
	var wander := Vector2(sin(cycle * 0.73), sin(cycle * 0.51 + 1.3)) * _drift_mix
	_wall_mat.set_shader_parameter("zoom", zoom)
	_wall_mat.set_shader_parameter("center", Vector2(0.5, 0.5) + wander * room)

	_flicker_mix = move_toward(_flicker_mix, 1.0 if flicker_on else 0.0, delta * 4.0)
	var dim := 0.0
	if _flicker_mix > 0.0:
		dim += flicker_strength * 0.25 * _rng.randf() * _flicker_mix
		_dip_wait -= delta
		if _dip_wait <= 0.0:
			_dip_left = _rng.randf_range(0.05, 0.22)
			_dip_dim = flicker_strength * _rng.randf_range(0.5, 1.0)
			_dip_wait = _rng.randf_range(0.4, 1.6) * maxf(flicker_every, 0.1)
	if _dip_left > 0.0:
		_dip_left -= delta
		dim += _dip_dim
	_wall_mat.set_shader_parameter("brightness", clampf(1.0 - dim, 0.0, 1.0))


## Crops to the box's shape and shrinks to its size, on the art grid or finer.
func _fit(tex: Texture2D, box: Vector2, scale := -1) -> Texture2D:
	if tex == null:
		return null
	return _fit_image(tex.get_image(), box, scale)


## scale is texels per art pixel: -1 = the art grid (1, or 4 when not
## pixelating), 0 = crop only and let the screen scale it. A moving wallpaper
## redrawn 4x finer would cost seconds and hundreds of MB.
func _fit_image(source: Image, box: Vector2, scale := -1) -> Texture2D:
	if source == null or source.is_empty():
		return null
	var img := source.duplicate() as Image
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	var cw := w
	var ch := h
	if float(w) / h > box.aspect():
		cw = int(h * box.aspect())
	else:
		ch = int(w / box.aspect())
	img = img.get_region(Rect2i(int((w - cw) / 2.0), int((h - ch) / 2.0), cw, ch))
	if scale < 0:
		scale = 1 if pixelate_player_images else 4
	if scale > 0:
		img.resize(int(box.x) * scale, int(box.y) * scale, Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(img)


# --- desktop -----------------------------------------------------------------

func _wire() -> void:
	(%PowerButton as BaseButton).pressed.connect(shut_down_pc)
	(%DataButton as BaseButton).pressed.connect(toggle_data)
	(%CloseData as BaseButton).pressed.connect(set_data.bind(false))
	(%CharactersIcon as BaseButton).pressed.connect(toggle_app.bind("characters"))
	(%TutorialIcon as BaseButton).pressed.connect(toggle_app.bind("tutorial"))
	(%MediaIcon as BaseButton).pressed.connect(toggle_app.bind("media"))
	(%CloseCharacters as BaseButton).pressed.connect(close_app)
	(%CloseTutorial as BaseButton).pressed.connect(close_app)
	(%CloseMedia as BaseButton).pressed.connect(close_app)
	(%ClosePage as BaseButton).pressed.connect(deselect)
	(%Instagram as BaseButton).pressed.connect(func() -> void: open_link(instagram_url))
	(%XLink as BaseButton).pressed.connect(func() -> void: open_link(x_url))
	_arrow_left.pressed.connect(scroll_by.bind(-1))
	_arrow_right.pressed.connect(scroll_by.bind(1))
	var slots := _slots_box.get_children()
	for i in slots.size():
		var slot := slots[i] as TextureButton
		slot.pressed.connect(func() -> void: select(scroll + i))
		slot.mouse_entered.connect(func() -> void: slot.self_modulate = Color(1.25, 1.25, 1.25))
		slot.mouse_exited.connect(func() -> void: slot.self_modulate = Color.WHITE)


func toggle_data() -> void:
	set_data(not _data_bar.visible)


## The bar the DATA button opens. Closing it closes whatever app is open too.
func set_data(open: bool) -> void:
	if not open:
		close_app()
	if _data_bar.visible == open:
		return
	_data_bar.visible = open
	data_toggled.emit(open)


func toggle_app(which: String) -> void:
	if app == which:
		close_app()
	else:
		open_app(which)


## "characters", "tutorial" or "media". Only one is open at a time.
func open_app(which: String) -> void:
	if phase != Phase.DESKTOP or not _apps.has(which) or app == which:
		return
	close_app()
	set_data(true)
	app = which
	(_apps[which] as Control).visible = true
	if which == "characters":
		scroll = 0
		_refresh_characters()
	elif which == "tutorial":
		_tutorial_text.text = tr(tutorial_text)
		_tutorial_text.scroll_to_line(0)
	app_opened.emit(which)


func close_app() -> void:
	if app == "":
		return
	var was := app
	(_apps[was] as Control).visible = false
	app = ""
	if was == "characters":
		deselect()
	app_closed.emit(was)


func open_link(url: String) -> void:
	if url.strip_edges() == "":
		push_warning("PcScreen: that link is empty. Fill instagram_url / x_url on the PC scene.")
		return
	OS.shell_open(url)
	link_opened.emit(url)


# --- characters ----------------------------------------------------------------

func scroll_by(step: int) -> void:
	var before := scroll
	scroll += step
	_refresh_characters()
	if scroll != before:
		scrolled.emit()


func select(index: int) -> void:
	if index < 0 or index >= characters.size() or characters[index] == null:
		return
	if app != "characters":
		open_app("characters")
	var slot_count := _slots_box.get_child_count()
	if index < scroll:
		scroll = index
	elif index >= scroll + slot_count:
		scroll = index - slot_count + 1
	selected = index
	var c := characters[index]
	_page.texture = c.page_art if c.page_art else default_page
	_page_text.text = tr(c.text)
	_page_text.scroll_to_line(0)
	_page.visible = true
	_refresh_characters()
	character_selected.emit(c)


func deselect() -> void:
	selected = -1
	_page.visible = false
	_update_pointer()


func _refresh_characters() -> void:
	var slots := _slots_box.get_children()
	var max_scroll := maxi(0, characters.size() - slots.size())
	scroll = clampi(scroll, 0, max_scroll)
	for i in slots.size():
		var slot := slots[i] as TextureButton
		var idx := scroll + i
		slot.visible = idx < characters.size() and characters[idx] != null
		if slot.visible:
			slot.texture_normal = _icon_of(characters[idx])
	_arrow_left.disabled = scroll <= 0
	_arrow_right.disabled = scroll >= max_scroll
	_arrow_left.modulate.a = 0.3 if _arrow_left.disabled else 1.0
	_arrow_right.modulate.a = 0.3 if _arrow_right.disabled else 1.0
	_update_pointer()


## The little arrow above the page, under whichever icon is picked.
func _update_pointer() -> void:
	var slots := _slots_box.get_children()
	var at := selected - scroll
	var show := _page.visible and selected >= 0 and at >= 0 and at < slots.size()
	_pointer.visible = show
	if show:
		var slot := slots[at] as Control
		_pointer.position.x = _slots_box.position.x + slot.position.x \
				+ floorf((slot.size.x - _pointer.size.x) * 0.5)


## Icons come as full 640x360 layers; keep just the drawn part.
func _icon_of(c: PcCharacter) -> Texture2D:
	if _icons.has(c):
		return _icons[c]
	var tex: Texture2D = c.icon
	if tex:
		var img := tex.get_image()
		if img and not img.is_empty():
			if img.is_compressed():
				img.decompress()
			var used := img.get_used_rect()
			if used.has_area() and used.size != img.get_size():
				var cut := AtlasTexture.new()
				cut.atlas = tex
				cut.region = Rect2(used)
				tex = cut
	_icons[c] = tex
	return tex


# --- input, layout, look -------------------------------------------------------

## Every key stops here while the PC is up, so TAB can't open the Board under it.
func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.is_action_pressed("ui_cancel") and not event.is_echo():
			shut_down_pc()
		get_viewport().set_input_as_handled()
		return
	var mb := event as InputEventMouseButton
	if mb and mb.pressed and app == "characters":
		var local := _slots_box.get_global_transform_with_canvas().affine_inverse() * mb.position
		if Rect2(Vector2.ZERO, _slots_box.size).has_point(local):
			if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
				scroll_by(-1)
			elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				scroll_by(1)


## Fits the 640x360 art to the screen, centred, and resizes the cursor to match.
func _layout() -> void:
	var screen := get_viewport().get_visible_rect().size
	var s := minf(screen.x / CANVAS.x, screen.y / CANVAS.y)
	_stage.scale = Vector2(s, s)
	_stage.position = ((screen - CANVAS * s) * 0.5).floor()
	_set_cursor(s)


func _set_cursor(stage_scale: float) -> void:
	if cursor == null or _restored:
		return
	var win := Vector2(get_window().size)
	var view := get_viewport().get_visible_rect().size
	var stretch := minf(win.x / view.x, win.y / view.y) if view.x > 0 and view.y > 0 else 1.0
	var biggest := maxi(cursor.get_width(), cursor.get_height())
	var k := clampi(roundi(stage_scale * stretch), 1, maxi(1, int(256.0 / biggest)))
	if k == _cursor_scale:
		return
	var img := cursor.get_image()
	if img == null:
		return
	if img.is_compressed():
		img.decompress()
	img.resize(img.get_width() * k, img.get_height() * k, Image.INTERPOLATE_NEAREST)
	Input.set_custom_mouse_cursor(ImageTexture.create_from_image(img), Input.CURSOR_ARROW,
			Vector2(cursor_hotspot * k))
	_cursor_scale = k


func _on_language_changed(_code: String) -> void:
	_apply_language()


func _apply_language() -> void:
	var loc := get_node_or_null("/root/Loc")
	var rtl: bool = loc != null and loc.is_rtl()
	_desktop.texture = desktop_arabic if rtl and desktop_arabic else _desktop_english
	# in right-to-left text "left" alignment means the start of the line, the right edge
	for label: RichTextLabel in [_page_text, _tutorial_text]:
		label.text_direction = Control.TEXT_DIRECTION_RTL if rtl else Control.TEXT_DIRECTION_AUTO
	_tutorial_text.text = tr(tutorial_text)
	if selected >= 0 and selected < characters.size():
		_page_text.text = tr(characters[selected].text)


## Text is drawn at art size and scaled up with the stage, which blurs a normal
## font. With no font set in pc_theme.tres, the default one is switched to
## signed-distance mode, which stays sharp at any scale.
func _sharpen_font() -> void:
	var th := _root.theme
	if th == null or th.default_font != null:
		return
	th = th.duplicate()
	th.default_font = _sharp_default_font(_root.get_theme_default_font())
	var bold := FontVariation.new()
	bold.base_font = th.default_font
	bold.variation_embolden = 0.9
	th.set_font("bold_font", "RichTextLabel", bold)
	_root.theme = th


static func _sharp_default_font(base: Font) -> Font:
	if _sharp_font == null:
		_sharp_font = base
		if base is FontFile:
			var copy := (base as FontFile).duplicate() as FontFile
			copy.multichannel_signed_distance_field = true
			_sharp_font = copy
	return _sharp_font
