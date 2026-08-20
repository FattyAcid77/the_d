extends CanvasLayer
## Board — the pause menu. Add as an Autoload named "Board".
##
## The clipboard with four tabs down its left edge: INVENTORY, LOGBOOK, MAP,
## SETTINGS. Opens over the game, pauses it, and closes back to where he was.
##
## ART, AND WHY THERE ARE NO COORDINATES IN HERE
## Every PNG is authored on the same 640x360 canvas with everything already
## in the right place. So each layer is drawn at (0,0) and it lines up. Even
## the tabs' CLICKABLE AREAS are read out of their own art — the opaque part
## of Inventory_Button.png IS the button. Move a tab in the art, and the
## clicking moves with it. Nothing to re-enter here.
##
## KEYS
##   ESC  open / close (comes back to the tab you were last on)
##   I    inventory      M  map
##   L    logbook        O  settings
##
## FROM CODE
##   Board.open()      Board.close()      Board.toggle()
##   Board.show_tab(Board.Tab.MAP)

signal opened(tab: int)
signal closed
signal tab_changed(tab: int)

enum Tab { INVENTORY, LOGBOOK, MAP, SETTINGS }

## WHERE THE ART LIVES. An autoload has NO INSPECTOR — it's built from a
## script with no scene — so there is nowhere to drag textures in. The art
## therefore loads ITSELF from this folder, by filename. Drop a replacement
## PNG in with the same name and it's picked up. Nothing to wire.
## The size everything is authored at. Scaled up to the screen at runtime.
const CANVAS := Vector2(640, 360)

const ART_DIR := "res://FD_Testing/GameSystems/Board/Art/"
const ART_BOARD := "BOARD_UI_OPTIONS.png"
const ART_TABS := {
	Tab.INVENTORY: "Inventory_Button.png",
	Tab.LOGBOOK: "LogBook.png",
	Tab.MAP: "Map_Button.png",
	Tab.SETTINGS: "Settings.png",
}

## Loaded from ART_DIR at startup. Set them from code before the first open
## if you want to override, but you shouldn't need to.
var board_art: Texture2D
var tab_inventory: Texture2D
var tab_logbook: Texture2D
var tab_map: Texture2D
var tab_settings: Texture2D

@export_group("Tab feel")
## The selected tab is drawn again on top at this brightness, so it lifts
## off the others. 1.0 = no change, 1.35 is a clear but gentle lift.
@export var selected_brightness: float = 1.35
## And nudged sideways by this much, like a real tab being pulled out.
@export var selected_nudge: float = 2.0
## Hover brightness, for the tab the mouse is over.
@export var hover_brightness: float = 1.15
@export var tab_click_sound: AudioStream

@export_group("Size on screen")
## The art is drawn on a 640x360 canvas, then scaled up to fit the screen and
## CENTRED — exactly the way the LogBook does it.
##
## KEEP THIS THE SAME AS LogBook's `board_scale` (0.94) or the clipboard and
## the tabs will not sit on top of the LogBook's clipboard.
@export var board_scale: float = 0.94

@export_group("Behaviour")
## Pause the game while the board is open.
@export var pause_game: bool = true
## The tab shown the very first time it's opened.
@export var default_tab: Tab = Tab.INVENTORY
## Come back to the tab he was last on, instead of the default every time.
@export var remember_tab: bool = true
## Dim the game behind the board.
@export var dim_color: Color = Color(0, 0, 0, 0.55)
## Seconds for the board to glide up from the bottom. This is the SAME
## number and the same easing the LogBook uses, so every tab and the LogBook
## move as one thing instead of three different animations.
@export var slide_seconds: float = 0.42

@export_group("Keys")
##   TAB          open / close
##   SHIFT + I    inventory      SHIFT + M   map
##   SHIFT + L    logbook        SHIFT + O   settings
## The letters need SHIFT so they never collide with normal gameplay keys.
## They work from inside the game too, jumping straight to that tab.
##
## Optional Input Map action that also opens/closes. Leave it — TAB works
## whether or not you've set the action up.
@export var open_action: String = "pause"
@export var use_letter_shortcuts: bool = true
## The letters need Shift held. Turn off if you'd rather press them bare.
@export var letters_need_shift: bool = true

@export_group("Debug")
@export var debug_log: bool = false
## Outline each tab's clickable area, so you can see what's being read
## out of the art.
@export var show_hit_areas: bool = false

var is_open := false
var tab: int = Tab.INVENTORY

var _root: Control
var _canvas: Control        ## the 640x360 art space, scaled and centred
var _dim: ColorRect
var _board: TextureRect
var _tab_layer: Control
var _pages: Control
var _page_nodes := {}
var _hit := {}            ## Tab -> Rect2 read from the art
var _hover: int = -1
var _was_paused := false
var _tween: Tween


func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	tab = default_tab
	_load_art()
	_build()


## Pulls every PNG out of ART_DIR. Missing files are reported loudly rather
## than silently leaving a blank screen, which is exactly what used to happen.
func _load_art() -> void:
	board_art = _tex(ART_BOARD)
	tab_inventory = _tex(ART_TABS[Tab.INVENTORY])
	tab_logbook = _tex(ART_TABS[Tab.LOGBOOK])
	tab_map = _tex(ART_TABS[Tab.MAP])
	tab_settings = _tex(ART_TABS[Tab.SETTINGS])


func _tex(file: String) -> Texture2D:
	var path := ART_DIR + file
	if not ResourceLoader.exists(path):
		push_error("Board: missing art '%s'. It should be in %s" % [file, ART_DIR])
		return null
	return load(path) as Texture2D


# --- building --------------------------------------------------------------

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	# IGNORE, not STOP. A full-screen STOP control eats every click before
	# anything else sees it — which is why the tabs did nothing and why the
	# LogBook's cards underneath could not be dragged.
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_dim = ColorRect.new()
	_dim.color = dim_color
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_dim)

	# EVERYTHING ART-RELATED LIVES IN HERE, at plain 640x360 coordinates.
	# The canvas itself is scaled and centred to the screen, so the art lands
	# in the same place as the LogBook's clipboard at ANY resolution — and,
	# just as important, mouse clicks convert back into these coordinates so
	# the inventory slots can actually be hit.
	_canvas = Control.new()
	_canvas.size = CANVAS
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_canvas)

	_board = TextureRect.new()
	_board.texture = board_art
	_board.position = Vector2.ZERO
	_board.size = CANVAS
	_board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_board.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_board.stretch_mode = TextureRect.STRETCH_KEEP
	_canvas.add_child(_board)

	# The pages go ON TOP of the clipboard art. They used to be underneath,
	# and since the clipboard's paper is fully opaque it simply covered them
	# — the board appeared blank no matter what was on the page.
	_pages = Control.new()
	_pages.position = Vector2.ZERO
	_pages.size = CANVAS
	_pages.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(_pages)

	_tab_layer = Control.new()
	_tab_layer.position = Vector2.ZERO
	_tab_layer.size = CANVAS
	_tab_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(_tab_layer)
	# Connect right here. Doing it from _notification(NOTIFICATION_READY) was
	# a race: that notification is what TRIGGERS _ready, so _tab_layer could
	# still be null when it ran and the tabs would never draw.
	_tab_layer.draw.connect(_draw_tabs)

	_read_hit_areas()
	_build_pages()
	_layout()
	get_viewport().size_changed.connect(_layout)


## Scales the 640x360 canvas up to fit the screen and centres it, using the
## SAME formula as LogBook._layout(). This is what makes the two clipboards
## line up, whatever resolution the game is running at.
func _layout() -> void:
	if _canvas == null:
		return
	var screen := get_viewport().get_visible_rect().size
	var s: float = minf(screen.y * board_scale / CANVAS.y,
			screen.x * board_scale / CANVAS.x)
	_canvas.scale = Vector2(s, s)
	_canvas.position = (screen - CANVAS * s) * 0.5


## Screen pixels -> the 640x360 art coordinates everything is authored in.
func to_canvas(screen_pos: Vector2) -> Vector2:
	var s: float = _canvas.scale.x if _canvas and _canvas.scale.x > 0.0 else 1.0
	return (screen_pos - _root.position - _canvas.position) / s


## Reads each tab's clickable rectangle out of its own PNG's opaque pixels.
## This is why there are no hard-coded button positions anywhere.
func _read_hit_areas() -> void:
	var arts := {
		Tab.INVENTORY: tab_inventory,
		Tab.LOGBOOK: tab_logbook,
		Tab.MAP: tab_map,
		Tab.SETTINGS: tab_settings,
	}
	for t in arts:
		var tex: Texture2D = arts[t]
		if tex == null:
			continue
		var img := tex.get_image()
		if img == null:
			continue
		var used := img.get_used_rect()
		_hit[t] = Rect2(used.position, used.size)
		if debug_log:
			print("Board: tab %d clickable at %s" % [t, _hit[t]])


func _build_pages() -> void:
	for t in [Tab.INVENTORY, Tab.LOGBOOK, Tab.MAP, Tab.SETTINGS]:
		var page := Control.new()
		page.position = Vector2.ZERO
		page.size = CANVAS
		page.mouse_filter = Control.MOUSE_FILTER_IGNORE
		page.visible = false
		_pages.add_child(page)
		_page_nodes[t] = page

	var inv := BoardInventory.new()
	_page_nodes[Tab.INVENTORY].add_child(inv)

	var map := BoardMap.new()
	_page_nodes[Tab.MAP].add_child(map)

	var setts := BoardSettings.new()
	_page_nodes[Tab.SETTINGS].add_child(setts)
	# LOGBOOK has no page of its own — it hands over to the existing
	# LogBook system, which draws its own full-screen clipboard.


# --- opening and closing ---------------------------------------------------

func toggle() -> void:
	if is_open:
		close()
	else:
		open()


func open(which: int = -1) -> void:
	if is_open:
		return
	is_open = true
	visible = true

	if which >= 0:
		tab = which
	elif not remember_tab:
		tab = default_tab

	if pause_game:
		_was_paused = get_tree().paused
		get_tree().paused = true

	_layout()
	_show_page(true)
	_slide_in()

	if debug_log:
		print("Board: opened on tab %d" % tab)
	opened.emit(tab)


func close() -> void:
	if not is_open:
		return
	is_open = false

	# the logbook draws itself, so it slides down with us, in step
	var lb := get_node_or_null("/root/LogBook")
	if lb and tab == Tab.LOGBOOK and lb.has_method("close"):
		lb.close(true)

	_slide_out()

	if debug_log:
		print("Board: closed")
	closed.emit()


## Glides up from the bottom, exactly like the LogBook does.
func _slide_in() -> void:
	var h := get_viewport().get_visible_rect().size.y
	_root.position.y = h
	if _tween and _tween.is_running():
		_tween.kill()
	_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_property(_root, "position:y", 0.0, slide_seconds)


## And slides back down instead of blinking out.
func _slide_out() -> void:
	var h := get_viewport().get_visible_rect().size.y
	if _tween and _tween.is_running():
		_tween.kill()
	_tween = create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_property(_root, "position:y", h, slide_seconds * 0.8)
	_tween.tween_callback(func() -> void:
		visible = false
		if pause_game:
			get_tree().paused = _was_paused)


func show_tab(which: int) -> void:
	if not is_open:
		open(which)
		return
	if which == tab:
		return

	# leaving the logbook puts its own screen away — instantly, since the
	# board stays up and only the page underneath is changing.
	if tab == Tab.LOGBOOK:
		var lb := get_node_or_null("/root/LogBook")
		if lb and lb.has_method("close"):
			lb.close(false)

	tab = which
	_show_page(false)
	_play_click()
	tab_changed.emit(which)


## `animate` is TRUE only when the board itself is opening (TAB). Switching
## between tabs is instant — the board is already up, so nothing should slide.
func _show_page(animate: bool = false) -> void:
	# THE LOGBOOK IS ITS OWN FULL SCREEN. It draws its own clipboard, blur
	# and cards on CanvasLayer 80 — underneath us. So on that tab we hide
	# our own clipboard and dimmer and let the real one show through, and
	# only keep the tabs on top. Before this, our opaque clipboard was drawn
	# straight over it, which is why the LogBook looked empty.
	var on_logbook := (tab == Tab.LOGBOOK)
	if _board:
		_board.visible = not on_logbook
	if _dim:
		_dim.visible = not on_logbook

	for t in _page_nodes:
		_page_nodes[t].visible = (t == tab)
		if _page_nodes[t].visible:
			for c in _page_nodes[t].get_children():
				if c.has_method("refresh"):
					c.refresh()

	# The LOGBOOK tab is the existing LogBook system, opened in place. When
	# the board is opening it slides at the same 0.42s with the same easing,
	# so the clipboard and the logbook come up as ONE movement. When you're
	# just switching tabs it appears instantly, like every other tab.
	if tab == Tab.LOGBOOK:
		var lb := get_node_or_null("/root/LogBook")
		if lb and lb.has_method("open"):
			lb.open(animate)

	_tab_layer.queue_redraw()


# --- input -----------------------------------------------------------------

## Tabs are handled in _input, not _unhandled_input, so a click on a tab is
## caught BEFORE the page under it (or the LogBook's cards) can take it.
func _input(event: InputEvent) -> void:
	if not is_open:
		return
	if event is InputEventMouseMotion:
		var was_h: int = _hover
		_hover = _tab_at(event.position)
		if was_h != _hover:
			_tab_layer.queue_redraw()
		return
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		var t: int = _tab_at(event.position)
		if t >= 0:
			show_tab(t)
			get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var handled := false
		if _is_open_key(event):
			toggle()
			handled = true
		elif use_letter_shortcuts and (event.shift_pressed or not letters_need_shift):
			var want := -1
			match event.keycode:
				KEY_I: want = Tab.INVENTORY
				KEY_L: want = Tab.LOGBOOK
				KEY_M: want = Tab.MAP
				KEY_O: want = Tab.SETTINGS
			if want >= 0:
				# show_tab opens the board first if it's shut, so one call
				# covers both "switch tab" and "jump straight there".
				show_tab(want)
				handled = true
		if handled:
			get_viewport().set_input_as_handled()
		return



func _is_open_key(event: InputEventKey) -> bool:
	if event.keycode == KEY_TAB and not event.shift_pressed:
		return true
	return InputMap.has_action(open_action) and event.is_action_pressed(open_action)


## Tabs move with the slide AND with the canvas scaling, so convert the
## mouse back into art coordinates before testing.
func _tab_at(pos: Vector2) -> int:
	var local := to_canvas(pos)
	for t in _hit:
		if (_hit[t] as Rect2).has_point(local):
			return t
	return -1


func _play_click() -> void:
	if tab_click_sound == null:
		return
	var p := AudioStreamPlayer.new()
	p.stream = tab_click_sound
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)


# --- drawing the tab states ------------------------------------------------

func _draw_tabs() -> void:
	var arts := {
		Tab.INVENTORY: tab_inventory,
		Tab.LOGBOOK: tab_logbook,
		Tab.MAP: tab_map,
		Tab.SETTINGS: tab_settings,
	}
	# On the LOGBOOK tab our clipboard is hidden so the real LogBook shows
	# through — and the clipboard is what normally draws the four tabs. So
	# when it's hidden we draw all of them ourselves, otherwise the other
	# three disappear and there's no way to click back out.
	var must_draw_all: bool = _board != null and not _board.visible

	for t in arts:
		var tex: Texture2D = arts[t]
		if tex == null:
			continue
		var selected: bool = (t == tab)
		var hovered: bool = (t == _hover)
		if not selected and not hovered and not must_draw_all:
			continue                      # the board art already shows it
		var b: float = 1.0
		if selected:
			b = selected_brightness
		elif hovered:
			b = hover_brightness
		var nudge := Vector2(selected_nudge if selected else 0.0, 0.0)
		_tab_layer.draw_texture(tex, nudge, Color(b, b, b, 1.0))

	if show_hit_areas:
		for t in _hit:
			_tab_layer.draw_rect(_hit[t], Color(0, 1, 0, 0.9), false, 1.0)
