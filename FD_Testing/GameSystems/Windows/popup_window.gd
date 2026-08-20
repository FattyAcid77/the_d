class_name PopupWindow extends Window
## One live popup window, built from a PopupWindowDef.
## You don't make these yourself — PopupWindows.open() does.

signal closed(def: PopupWindowDef)
## Fires once a PORTAL window's separate scene is alive inside it, handing
## you the scene's root node so you can talk to it from the main game.
signal portal_ready(scene_root: Node)

var def: PopupWindowDef
## For PORTAL windows showing a separate scene: that scene's root node.
var portal_root: Node = null
## The camera looking into a PORTAL window. Move it yourself if you like.
var portal_camera: Camera2D = null
var _portal_anchor := Vector2i.ZERO      ## window pos when the portal opened
var _portal_base := Vector2.ZERO         ## camera pos when the portal opened
var _portal_target := Vector2.ZERO

var _root: Control
var _bg: ColorRect
var _frame: NinePatchRect          ## the skin's nine-slice art
var _titlebar: Control             ## the skin's title bar strip
var _icon_rect: TextureRect        ## the logo in that bar
var _title_label: Label
var _close_btn: Control
var _content: Control              ## everything the window SHOWS goes in here
var _grip: Control
var _resizing := false
var _resize_from := Vector2i.ZERO
var _resize_size := Vector2i.ZERO
var _label: Label
var _audio: AudioStreamPlayer
var _life: float = 0.0
var _scroll_x: float = 0.0
var _typed: float = 0.0
var _dragging := false
var _drag_from := Vector2i.ZERO
var _base_position := Vector2i.ZERO
var _closing := false
var _change_left: float = -1.0
var _steps: int = 0
var _last_free_position := Vector2i.ZERO
var _blockers_touching: Array = []

## NOTE: this script extends Window, and Window has a BUILT-IN enum called
## `Flags` (FLAG_BORDERLESS and friends). That native enum shadows our Flags
## autoload inside this file, so we fetch the autoload by path instead.
@onready var _flags: Node = get_node_or_null("/root/Flags")


func setup(d: PopupWindowDef) -> void:
	def = d
	# --- the window itself ---
	title = tr(d.title)
	size = d.size
	# A skin draws its own frame, so the OS chrome has to go — otherwise you
	# get your title bar underneath the operating system's one.
	borderless = d.borderless or d.skin != null
	unresizable = not d.user_can_resize
	always_on_top = d.always_on_top and d.depth != PopupWindowDef.Depth.BELOW_GAME
	transparent = d.transparent
	transparent_bg = d.transparent
	# A REAL window: focusable + listed in the taskbar. Making it
	# unfocusable is what made popups feel "weak" — the OS treats them as
	# floating decorations rather than programs.
	unfocusable = d.unfocusable
	set_flag(Window.FLAG_NO_FOCUS, d.unfocusable)
	set_flag(Window.FLAG_POPUP, false)          # a popup would auto-close
	if not d.show_in_taskbar:
		set_flag(Window.FLAG_NO_FOCUS, true)

	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	_bg = ColorRect.new()
	_bg.color = d.background_color
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_bg)

	_build_chrome()

	if d.show_title_inside and d.skin == null and d.title != "":
		var tl := Label.new()
		tl.text = tr(d.title)
		tl.add_theme_font_size_override("font_size", 14)
		tl.modulate = Color(1, 1, 1, 0.55)
		tl.position = Vector2(8, 4)
		tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_root.add_child(tl)

	_build_contents()

	# 1) the one-shot as it appears
	if d.open_sound:
		var op := AudioStreamPlayer.new()
		op.stream = d.open_sound
		op.volume_db = d.open_sound_volume_db
		add_child(op)
		op.play()

	# 2) the ambient that runs the whole time it's open
	if d.sound:
		_audio = AudioStreamPlayer.new()
		_audio.stream = d.sound
		_audio.volume_db = d.sound_volume_db - (40.0 if d.sound_fade > 0.0 else 0.0)
		add_child(_audio)
		_audio.play()
		if d.sound_loops:
			_audio.finished.connect(func() -> void:
				if is_instance_valid(_audio) and not _closing:
					_audio.play())
		if d.sound_fade > 0.0:
			var tw := create_tween()
			tw.tween_property(_audio, "volume_db", d.sound_volume_db, d.sound_fade)

	_life = d.lifetime
	_change_left = d.change_after if d.change_to != "" else -1.0
	close_requested.connect(_on_close_requested)
	if d.user_can_drag:
		_root.gui_input.connect(_on_drag_input)

	if d.grow_in:
		var target := size
		size = Vector2i(8, 8)
		var tw2 := create_tween()
		tw2.tween_property(self, "size", target, maxf(0.05, d.fade_seconds)) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)



# --- the skin: your own frame, title bar, logo and close button ------------

## Builds everything the SKIN draws, and creates the content area that the
## window's actual contents live inside. With no skin, the content area is
## simply the whole window and nothing else is drawn.
func _build_chrome() -> void:
	var sk: WindowSkin = def.skin

	if sk == null:
		_content = Control.new()
		_content.set_anchors_preset(Control.PRESET_FULL_RECT)
		_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_root.add_child(_content)
		return

	# 1. the nine-slice frame
	if sk.frame:
		_frame = NinePatchRect.new()
		_frame.texture = sk.frame
		_frame.patch_margin_left = sk.patch_left
		_frame.patch_margin_top = sk.patch_top
		_frame.patch_margin_right = sk.patch_right
		_frame.patch_margin_bottom = sk.patch_bottom
		_frame.draw_center = sk.draw_center
		_frame.modulate = sk.frame_modulate
		_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
		_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if sk.pixel_perfect \
				else CanvasItem.TEXTURE_FILTER_LINEAR
		_root.add_child(_frame)
		# the skin's frame is the background now
		if _bg:
			_bg.visible = not sk.draw_center

	# 2. the title bar strip
	if sk.title_bar_height > 0:
		_titlebar = Control.new()
		_titlebar.set_anchors_preset(Control.PRESET_TOP_WIDE)
		# Anchored left-to-right, so set the BOTTOM OFFSET rather than .size —
		# assigning size on non-equal opposite anchors is overridden after
		# _ready() and Godot warns about it.
		_titlebar.offset_top = 0
		_titlebar.offset_bottom = sk.title_bar_height
		_titlebar.custom_minimum_size.y = sk.title_bar_height
		# STOP so it can catch drags; the frame art still shows through
		_titlebar.mouse_filter = Control.MOUSE_FILTER_STOP
		_root.add_child(_titlebar)

		if sk.title_bar_texture:
			var bar := NinePatchRect.new()
			bar.texture = sk.title_bar_texture
			bar.set_anchors_preset(Control.PRESET_FULL_RECT)
			bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_titlebar.add_child(bar)

		# the logo
		var logo: Texture2D = def.icon if def.icon else sk.default_icon
		_icon_rect = TextureRect.new()
		_icon_rect.texture = logo
		_icon_rect.visible = logo != null
		_icon_rect.offset_left = sk.icon_offset.x
		_icon_rect.offset_top = sk.icon_offset.y
		_icon_rect.offset_right = sk.icon_offset.x + sk.icon_size.x
		_icon_rect.offset_bottom = sk.icon_offset.y + sk.icon_size.y
		_icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if sk.pixel_perfect \
				else CanvasItem.TEXTURE_FILTER_LINEAR
		_titlebar.add_child(_icon_rect)

		# the words
		if sk.show_title_text:
			_title_label = Label.new()
			_title_label.text = tr(def.title)
			_title_label.add_theme_font_size_override("font_size", sk.title_font_size)
			_title_label.add_theme_color_override("font_color", sk.title_color)
			if sk.title_font:
				_title_label.add_theme_font_override("font", sk.title_font)
			_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_title_label.set_anchors_preset(Control.PRESET_FULL_RECT)
			var indent: float = sk.title_indent_when_icon if logo != null else 0.0
			_title_label.offset_left = sk.title_offset.x + indent
			_title_label.offset_top = sk.title_offset.y
			_title_label.offset_right = -(sk.close_size.x + sk.close_offset.x + 4.0)
			match sk.title_align:
				1: _title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				2: _title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
				_: _title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			_titlebar.add_child(_title_label)

		if sk.drag_from_title_bar:
			_titlebar.gui_input.connect(_on_drag_input)

	# 3. the close button
	if sk.show_close_button:
		_close_btn = _make_close_button(sk)
		_root.add_child(_close_btn)

	# 4. the content area, pushed below the title bar and inside the frame
	_content = Control.new()
	_content.set_anchors_preset(Control.PRESET_FULL_RECT)
	_content.offset_left = sk.content_margin_left
	_content.offset_right = -sk.content_margin_right
	_content.offset_top = sk.top_inset() + sk.content_margin_top
	_content.offset_bottom = -sk.content_margin_bottom
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_content)

	# 5. the resize grip
	if sk.show_resize_grip:
		_grip = _make_grip(sk)
		_root.add_child(_grip)

	if sk.drag_from_anywhere:
		_root.mouse_filter = Control.MOUSE_FILTER_STOP
		_root.gui_input.connect(_on_drag_input)


func _make_close_button(sk: WindowSkin) -> Control:
	var holder := Control.new()
	holder.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	holder.offset_right = -sk.close_offset.x
	holder.offset_left = -sk.close_offset.x - sk.close_size.x
	holder.offset_top = sk.close_offset.y
	holder.offset_bottom = sk.close_offset.y + sk.close_size.y
	holder.mouse_filter = Control.MOUSE_FILTER_STOP

	if sk.close_normal:
		var b := TextureButton.new()
		b.texture_normal = sk.close_normal
		b.texture_hover = sk.close_hover if sk.close_hover else sk.close_normal
		b.texture_pressed = sk.close_pressed if sk.close_pressed else sk.close_normal
		b.ignore_texture_size = true
		b.stretch_mode = TextureButton.STRETCH_SCALE
		b.set_anchors_preset(Control.PRESET_FULL_RECT)
		b.pressed.connect(_on_skin_close)
		holder.add_child(b)
	else:
		# no art supplied yet — a plain X so the window is still closable
		var b2 := Button.new()
		b2.text = "X"
		b2.flat = true
		b2.add_theme_color_override("font_color", sk.close_fallback_color)
		b2.add_theme_font_size_override("font_size", int(sk.close_size.y * 0.8))
		b2.set_anchors_preset(Control.PRESET_FULL_RECT)
		b2.pressed.connect(_on_skin_close)
		holder.add_child(b2)
	return holder


func _make_grip(sk: WindowSkin) -> Control:
	var g := Control.new()
	g.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	g.offset_left = -sk.resize_grip_size.x
	g.offset_top = -sk.resize_grip_size.y
	g.offset_right = 0
	g.offset_bottom = 0
	g.mouse_filter = Control.MOUSE_FILTER_STOP
	g.mouse_default_cursor_shape = Control.CURSOR_FDIAGSIZE
	if sk.resize_grip_texture:
		var t := TextureRect.new()
		t.texture = sk.resize_grip_texture
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.set_anchors_preset(Control.PRESET_FULL_RECT)
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		g.add_child(t)
	g.gui_input.connect(_on_grip_input)
	return g


func _on_skin_close() -> void:
	if def.skin and def.skin.close_click_sound:
		var p := AudioStreamPlayer.new()
		p.stream = def.skin.close_click_sound
		get_tree().root.add_child(p)
		p.play()
		p.finished.connect(p.queue_free)
	close_window()


func _on_grip_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_resizing = event.pressed
		if _resizing:
			_resize_from = Vector2i(DisplayServer.mouse_get_position())
			_resize_size = size
	elif event is InputEventMouseMotion and _resizing:
		var delta := Vector2i(DisplayServer.mouse_get_position()) - _resize_from
		var mn: Vector2i = def.skin.min_size if def.skin else Vector2i(80, 60)
		size = Vector2i(maxi(mn.x, _resize_size.x + delta.x),
				maxi(mn.y, _resize_size.y + delta.y))


# --- the logo --------------------------------------------------------------

## Change this window's logo while it's open. Works mid-sentence, mid-chain,
## whenever you like:
##     var w = PopupWindows.open_id("whisper_1")
##     w.set_icon_texture(load("res://art/logo_bad.png"))
##
## Only works on a SKINNED window — the operating system won't let a single
## program give each of its windows a different taskbar icon.
func set_icon_texture(tex: Texture2D) -> void:
	if _icon_rect == null:
		if def and def.skin == null:
			push_warning("PopupWindow: set_icon_texture needs a skin — "
					+ "the OS can't give individual windows their own icon.")
		return
	_icon_rect.texture = tex
	_icon_rect.visible = tex != null


## Change the words in the skin's title bar (and the OS title too).
func set_window_title(t: String) -> void:
	title = tr(t)
	if _title_label:
		_title_label.text = tr(t)

# --- contents --------------------------------------------------------------

## Where the window's actual contents go: inside the skin's content area if
## there is one, otherwise straight onto the root.
func _content_parent() -> Control:
	return _content if _content != null else _root


## The usable area for contents, in pixels — the window minus the skin's
## frame and title bar. Text motion uses this so words never sit under
## your title bar or outside your frame.
func _content_size() -> Vector2:
	if def.skin:
		var sk: WindowSkin = def.skin
		return Vector2(
			maxf(8.0, def.size.x - sk.content_margin_left - sk.content_margin_right),
			maxf(8.0, def.size.y - sk.top_inset() - sk.content_margin_top - sk.content_margin_bottom))
	return Vector2(def.size)


## Builds whatever this window shows, from `def`. Called on setup and again
## every time the window morphs into a different def.
func _build_contents() -> void:
	match def.kind:
		PopupWindowDef.Kind.TEXT:
			_build_text()
		PopupWindowDef.Kind.PORTAL:
			_build_portal()
		PopupWindowDef.Kind.IMAGE:
			_build_image()
		PopupWindowDef.Kind.SOUND:
			pass                      # nothing to show


## THE MORPH. Same OS window, different contents — it doesn't blink, doesn't
## move, keeps its taskbar entry. It just becomes something else.
func morph_to(d: PopupWindowDef) -> void:
	if _closing or d == null:
		return

	var old_def := def
	_steps += 1

	# fade the old contents out
	if old_def.change_fade > 0.0 and _root:
		var tw := create_tween()
		tw.tween_property(_root, "modulate:a", 0.0, old_def.change_fade)
		await tw.finished
		if _closing or not is_instance_valid(self):
			return

	# clear everything the old def put on screen, but keep _root itself
	_label = null
	_scroll_x = 0.0
	_typed = 0.0
	_frame = null
	_titlebar = null
	_icon_rect = null
	_title_label = null
	_close_btn = null
	_content = null
	_grip = null
	portal_camera = null
	portal_root = null
	for c in _root.get_children():
		c.queue_free()
	# they're freed at the end of the frame, so detach them now or the new
	# chrome is built alongside the old one for a frame
	for c2 in _root.get_children():
		_root.remove_child(c2)
	if _audio and is_instance_valid(_audio):
		_audio.queue_free()
		_audio = null

	# The manager tracks live windows by id, so tell it this one is now a
	# different def — otherwise close_id() and "already open" checks break.
	var pw := get_node_or_null("/root/PopupWindows")
	if pw and pw.has_method("rekey_window"):
		pw.rekey_window(old_def.id, d.id, self)

	def = d
	title = tr(d.title)
	if not old_def.change_keep_size:
		size = d.size
	background_color_apply(d)

	# the new def may have a different skin, a different logo, or none
	borderless = d.borderless or d.skin != null
	_build_chrome()

	# the title-inside label belongs to the new def now
	if d.show_title_inside and d.skin == null and d.title != "":
		var tl := Label.new()
		tl.text = tr(d.title)
		tl.add_theme_font_size_override("font_size", 14)
		tl.modulate = Color(1, 1, 1, 0.55)
		tl.position = Vector2(8, 4)
		tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_root.add_child(tl)

	_build_contents()

	# the new def's own sounds
	if d.open_sound:
		var op := AudioStreamPlayer.new()
		op.stream = d.open_sound
		op.volume_db = d.open_sound_volume_db
		add_child(op)
		op.play()
	if d.sound:
		_audio = AudioStreamPlayer.new()
		_audio.stream = d.sound
		_audio.volume_db = d.sound_volume_db
		add_child(_audio)
		_audio.play()
		if d.sound_loops:
			_audio.finished.connect(func() -> void:
				if is_instance_valid(_audio) and not _closing:
					_audio.play())

	# fresh timers for the new def
	_life = d.lifetime
	_change_left = d.change_after if d.change_to != "" else -1.0
	if d.change_max_steps > 0 and _steps >= d.change_max_steps:
		_change_left = -1.0

	if not d.change_keep_position:
		remember_position()

	# fade the new contents in
	if _root:
		if old_def.change_fade > 0.0:
			_root.modulate.a = 0.0
			var tw2 := create_tween()
			tw2.tween_property(_root, "modulate:a", 1.0, old_def.change_fade)
		else:
			_root.modulate.a = 1.0


## The background rect belongs to _root's children, so it is rebuilt here.
func background_color_apply(d: PopupWindowDef) -> void:
	_bg = ColorRect.new()
	_bg.color = d.background_color
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_bg)


func _build_text() -> void:
	_label = Label.new()
	_label.text = tr(def.text)
	_label.add_theme_font_size_override("font_size", def.font_size)
	_label.add_theme_color_override("font_color", def.text_color)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if def.text_motion == PopupWindowDef.TextMotion.SCROLL:
		_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		var cs := _content_size()
		_label.position = Vector2(cs.x, cs.y * 0.5 - def.font_size)
		_scroll_x = cs.x
	else:
		_label.set_anchors_preset(Control.PRESET_FULL_RECT)
		if def.text_align_center:
			_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if def.text_motion == PopupWindowDef.TextMotion.TYPEWRITER:
		_label.visible_characters = 0
	_content_parent().add_child(_label)


func _build_portal() -> void:
	var svc := SubViewportContainer.new()
	svc.stretch = true
	svc.set_anchors_preset(Control.PRESET_FULL_RECT)
	svc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content_parent().add_child(svc)

	var sv := SubViewport.new()
	sv.size = def.size
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	svc.add_child(sv)

	if def.portal_same_world and def.portal_scene == null:
		# NOT SUPPORTED, AND IT CRASHES GODOT — see README 37.
		# Sharing the level's World2D with a SubViewport that lives inside a
		# separate OS window makes the renderer recurse and Godot dies with a
		# hard segfault (signal 11), not a catchable error. Verified on 4.4.1.
		# It never actually worked: before, an unrelated null-tree bug made
		# the assignment silently fail, which is the only reason it looked OK.
		#
		# To show THIS level from another angle, put a copy of the level in
		# `portal_scene`. It runs as its own world, which is safe.
		push_warning("PopupWindow '%s': portal_same_world isn't supported "
				% def.id
				+ "(it crashes Godot). Put a copy of the level in portal_scene "
				+ "instead — see README 37.")
		var msg := Label.new()
		msg.text = "no portal scene"
		msg.set_anchors_preset(Control.PRESET_FULL_RECT)
		msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		msg.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		msg.modulate = Color(1, 1, 1, 0.4)
		_content_parent().add_child(msg)
	if def.portal_scene:
		# ITS OWN LITTLE WORLD — a completely separate scene running inside
		# this window. Sami is not in there and cannot go in there.
		#
		# It gets its own World2D, so its physics and lighting are entirely
		# separate from the main level. Put a RadioReactor inside that scene
		# and the player can change it with the radio dial while watching.
		sv.own_world_3d = false
		sv.world_2d = World2D.new()
		sv.handle_input_locally = false
		sv.disable_3d = true
		var inst := def.portal_scene.instantiate()
		sv.add_child(inst)
		portal_root = inst

		# THE MISSING PIECE: a separate-world portal had no camera at all,
		# so the view sat at the scene's origin and nothing could ever move
		# it. Use the scene's own camera if it has one, otherwise make one.
		var cam2 := _find_camera(inst)
		if cam2 == null and def.portal_make_camera:
			cam2 = Camera2D.new()
			cam2.global_position = def.portal_camera_position
			cam2.zoom = def.portal_zoom
			sv.add_child(cam2)
		if cam2:
			cam2.enabled = true
			portal_camera = cam2
			cam2.tree_entered.connect(cam2.make_current, CONNECT_ONE_SHOT)
			_arm_follow(cam2)

		portal_ready.emit(inst)


## The first Camera2D anywhere inside the portal scene, if it has one.
func _find_camera(node: Node) -> Camera2D:
	for c in node.get_children():
		if c is Camera2D:
			return c
		var deep := _find_camera(c)
		if deep:
			return deep
	return null


## Remembers where the window and the camera started, so dragging can be
## measured against it.
func _arm_follow(cam: Camera2D) -> void:
	_portal_anchor = position
	_portal_base = cam.global_position
	_portal_target = cam.global_position


## Moves the portal camera to match how far the window has been dragged.
## Called every frame, so it works whether the player dragged the window by
## the title bar, by a skin's custom drag, or code moved it.
func _update_portal_follow(delta: float) -> void:
	if portal_camera == null or not is_instance_valid(portal_camera):
		return
	if def.portal_follow == 0:                       # Fixed
		return

	if def.portal_follow == 1:                       # Desktop
		# how far this window has been dragged since it opened
		var moved := Vector2(position - _portal_anchor)
		var dir := -1.0 if def.portal_follow_invert else 1.0
		_portal_target = _portal_base + moved * def.portal_follow_scale * dir
	else:                                            # World
		# where the window physically sits over THIS level right now
		var tree := get_tree()
		if tree == null:
			return
		var r := WindowSpace.window_rect_in_world(tree, self)
		_portal_target = r.position + r.size * 0.5

	if def.portal_follow_smooth > 0.0:
		portal_camera.global_position = portal_camera.global_position.lerp(
				_portal_target, clampf(delta / def.portal_follow_smooth, 0.0, 1.0))
	else:
		portal_camera.global_position = _portal_target


## Re-anchors the follow to wherever the window is NOW, so the current view
## becomes the new starting point. Call it if you move the window in code
## and don't want the view to jump.
func reset_portal_anchor() -> void:
	if portal_camera:
		_arm_follow(portal_camera)


func _build_image() -> void:
	var tr := TextureRect.new()
	tr.texture = def.image
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if def.image_fills_window:
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_SCALE
	else:
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_content_parent().add_child(tr)


# --- running ---------------------------------------------------------------

func _process(delta: float) -> void:
	if def == null or _closing:
		return

	# text motion
	if _label:
		match def.text_motion:
			PopupWindowDef.TextMotion.TYPEWRITER:
				var total := _label.get_total_character_count()
				if _label.visible_characters < total:
					_typed += delta * def.text_speed
					_label.visible_characters = int(_typed)
				elif def.text_loop and _life <= 0.0:
					_typed = 0.0
					_label.visible_characters = 0
			PopupWindowDef.TextMotion.SCROLL:
				_scroll_x -= def.text_speed * delta
				_label.position.x = _scroll_x
				if _scroll_x < -_label.size.x:
					if def.text_loop:
						_scroll_x = _content_size().x
					elif def.close_mode == PopupWindowDef.CloseMode.TIMER:
						close_window()

	# the jitter
	if def.shake_pixels > 0.0 and not _dragging:
		position = _base_position + Vector2i(
			int(randf_range(-def.shake_pixels, def.shake_pixels)),
			int(randf_range(-def.shake_pixels, def.shake_pixels)))

	# has this window been dragged onto something in the level?
	_check_blockers()

	# a portal view slides as the window is dragged
	_update_portal_follow(delta)

	# the change timer — turn into another window
	if _change_left >= 0.0:
		_change_left -= delta
		if _change_left <= 0.0:
			_change_left = -1.0
			_do_change()
			return

	# closing
	match def.close_mode:
		PopupWindowDef.CloseMode.TIMER:
			_life -= delta
			if _life <= 0.0:
				close_window()
		PopupWindowDef.CloseMode.FLAG:
			if def.close_flag != "" and _flags and _flags.is_set(def.close_flag):
				close_window()


## Compares this window's rectangle against every WindowBlocker in the level.
## Runs whether the window was dragged by the player, by the OS title bar, or
## moved by code — so nothing can sneak past.
func _check_blockers() -> void:
	var tree := get_tree()
	if tree == null:
		return

	var blockers := tree.get_nodes_in_group("window_blockers")
	if blockers.is_empty():
		_last_free_position = position
		return

	var my_rect := WindowSpace.window_rect_in_world(tree, self)
	var hit: Array = []
	var must_stop := false

	for b in blockers:
		if not (b is WindowBlocker) or not b.affects(self):
			continue
		if my_rect.intersects(b.world_rect()):
			hit.append(b)
			if b.blocks:
				must_stop = true

	# newly touched
	for b in hit:
		if not _blockers_touching.has(b):
			b.on_window_touch(self)

	# no longer touched
	for b in _blockers_touching:
		if is_instance_valid(b) and not hit.has(b):
			b.on_window_leave(self)

	_blockers_touching = hit

	if must_stop:
		# shove it back where it was still free — this is the "wall"
		position = _last_free_position
		_base_position = _last_free_position
	else:
		_last_free_position = position


func _do_change() -> void:
	var pw := get_node_or_null("/root/PopupWindows")
	if pw == null or def.change_to == "":
		return
	var next_def = pw.get_def(def.change_to)
	if next_def == null:
		push_warning("PopupWindow: change_to '%s' — no window def with that id." % def.change_to)
		return

	if def.change_morph:
		morph_to(next_def)
	else:
		var keep := position if def.change_keep_position else Vector2i(-99999, -99999)
		close_window()
		pw.open_at(next_def, keep)


func remember_position() -> void:
	_base_position = position
	_last_free_position = position


# --- reading / writing the body text ---------------------------------------
# WindowBlocker uses these to change what a window says when it bumps
# into something in the level.

## The words currently shown in the window ("" for non-TEXT windows).
func get_body_text() -> String:
	return _label.text if _label else ""


## Change the words shown, mid-life. Restarts the typewriter.
func set_body_text(t: String) -> void:
	if _label == null:
		return
	_label.text = t
	if def and def.text_motion == PopupWindowDef.TextMotion.TYPEWRITER:
		_typed = 0.0
		_label.visible_characters = 0


## A quick shove, for when the window hits something.
func nudge(pixels: float) -> void:
	var tw := create_tween()
	var from := position
	tw.tween_property(self, "position",
			from + Vector2i(int(randf_range(-pixels, pixels)), int(randf_range(-pixels, pixels))),
			0.05)
	tw.tween_property(self, "position", from, 0.08)


func _on_close_requested() -> void:
	if def.close_mode == PopupWindowDef.CloseMode.USER \
			or def.close_mode == PopupWindowDef.CloseMode.TIMER:
		close_window()


## Close it (fading sound and visuals out first).
func close_window() -> void:
	if _closing:
		return
	_closing = true
	if def.close_sound:
		var cp := AudioStreamPlayer.new()
		cp.stream = def.close_sound
		cp.volume_db = def.close_sound_volume_db
		get_tree().root.add_child(cp)       # outlives this window
		cp.play()
		cp.finished.connect(cp.queue_free)
	if _audio and def.sound_fade > 0.0:
		var tw := create_tween()
		tw.tween_property(_audio, "volume_db", def.sound_volume_db - 40.0, def.sound_fade)
	if def.fade_seconds > 0.0 and _root:
		var tw2 := create_tween()
		tw2.tween_property(_root, "modulate:a", 0.0, def.fade_seconds)
		await tw2.finished
	if def.closed_flag != "" and _flags:
		_flags.set_flag(def.closed_flag)
	closed.emit(def)
	queue_free()


# --- dragging --------------------------------------------------------------

func _on_drag_input(event: InputEvent) -> void:
	if not def.user_can_drag:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		if _dragging:
			_drag_from = Vector2i(event.position)
	elif event is InputEventMouseMotion and _dragging:
		position += Vector2i(event.position) - _drag_from
		_base_position = position
