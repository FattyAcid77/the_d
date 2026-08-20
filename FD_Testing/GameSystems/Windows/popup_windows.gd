extends Node
## PopupWindows — add as an Autoload named "PopupWindows".
## Spawns real OS windows that talk to the player, emit sound, or look into
## another world.
##
##     PopupWindows.open_id("whisper_1")        # by id, from Windows/Defs/
##     PopupWindows.open(my_def)                # by resource
##     PopupWindows.close_id("whisper_1")
##     PopupWindows.close_all()
## From a dialog line: action_name = "window", action_args = ["whisper_1"]
##
## ===================== PROJECT SETTINGS REQUIRED =====================
## Project > Project Settings > Display > Window:
##   Subwindows > Embed Subwindows      = OFF   (or they open INSIDE the game)
##   Per Pixel Transparency > Allowed   = ON    (for transparent windows)
##   Size > Mode                        = Windowed  (NOT fullscreen)
##   Size > Borderless                  = ON
## Then let this script size the game to the monitor (borderless_fullscreen
## below) — it looks fullscreen but real windows can still appear over it.
## =====================================================================

signal window_opened(id: String)
signal window_closed(id: String)

const DEFS_DIR := "res://FD_Testing/GameSystems/Windows/Defs"

## Make the main game window fill the monitor with no border at startup.
## This is the "looks fullscreen but windows still work" mode.
##
## DEFAULT IS OFF ON PURPOSE. When this was on, the autoload seized the game
## window the moment the project started — borderless, resized to the whole
## monitor, moved to 0,0 — before any menu had drawn. That reads exactly like
## "the game doesn't run". Only switch it on when you actually want real
## desktop windows floating over the game.
@export var borderless_fullscreen: bool = false

## How far a BELOW_GAME window is pushed behind (see the note on _send_back).
@export var raise_game_for_below: bool = true

## Prints what's happening while you set windows up.
@export var debug_log: bool = true

var defs: Array[PopupWindowDef] = []
var open_windows := {}          ## id -> PopupWindow


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_defs()
	if borderless_fullscreen:
		_go_borderless_fullscreen.call_deferred()
	var dm := get_node_or_null("/root/DialogManager")
	if dm and dm.has_signal("action_requested"):
		dm.action_requested.connect(_on_dialog_action)


func _go_borderless_fullscreen() -> void:
	if not borderless_fullscreen:
		return
	var screen := DisplayServer.screen_get_size()
	if screen.x <= 0 or screen.y <= 0:
		return                      # headless / no display — leave the window alone
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
	DisplayServer.window_set_size(screen)
	DisplayServer.window_set_position(Vector2i.ZERO)
	if debug_log:
		print("PopupWindows: game set to borderless %dx%d." % [screen.x, screen.y])


func _load_defs() -> void:
	defs.clear()
	var dir := DirAccess.open(DEFS_DIR)
	if dir == null:
		push_warning("PopupWindows: no Defs folder at %s" % DEFS_DIR)
		return
	for file in dir.get_files():
		if file.get_extension() == "tres" or file.get_extension() == "res":
			var r := load(DEFS_DIR + "/" + file)
			if r is PopupWindowDef:
				defs.append(r)
	if debug_log:
		print("PopupWindows: loaded %d window definitions." % defs.size())


func get_def(id: String) -> PopupWindowDef:
	for d in defs:
		if d.id == id:
			return d
	return null


# --- opening ---------------------------------------------------------------

func open_id(id: String) -> PopupWindow:
	var d := get_def(id)
	if d == null:
		push_warning("PopupWindows: no window called '%s'." % id)
		return null
	return open(d)


func open(d: PopupWindowDef) -> PopupWindow:
	if d == null:
		return null
	if open_windows.has(d.id):
		return open_windows[d.id]                 # already up
	if d.once_only and Flags.is_set("window_seen:" + d.id):
		return null

	var w := PopupWindow.new()
	w.setup(d)
	w.closed.connect(_on_window_closed)
	open_windows[d.id] = w

	# The root can be mid-"setting up children" when a dialog line or a signal
	# asks for a window, and a plain add_child() then fails outright:
	#   "Parent node is busy setting up children, add_child() failed."
	# Deferring is the only safe way in. Position is applied in the same
	# deferred step, AFTER the window is actually in the tree.
	_attach.call_deferred(w, d)

	if d.depth == PopupWindowDef.Depth.BELOW_GAME:
		_send_back.call_deferred(w)

	Flags.set_flag("window_seen:" + d.id)
	if d.open_flag != "":
		Flags.set_flag(d.open_flag)
	window_opened.emit(d.id)
	return w


## Adds the window to the tree and places it, one frame later, once the
## scene tree is no longer busy.
func _attach(w: PopupWindow, d: PopupWindowDef) -> void:
	if not is_instance_valid(w):
		return
	get_tree().root.add_child(w)
	w.position = _place(d, w)
	w.remember_position()
	# The portal's follow was armed while the window was still at 0,0, so
	# re-anchor now that it's in its real spot — otherwise the view starts
	# offset by however far the window was placed.
	w.reset_portal_anchor()
	if debug_log:
		print("PopupWindows: opened '%s' at %s" % [d.id, w.position])


## Works out where on the desktop the window goes.
func _place(d: PopupWindowDef, w: Window) -> Vector2i:
	var screen := DisplayServer.screen_get_size()
	var s := d.size
	var pos := Vector2i.ZERO
	match d.placement:
		PopupWindowDef.Placement.FIXED:
			pos = d.fixed_position
		PopupWindowDef.Placement.CENTER:
			pos = (screen - s) / 2
		PopupWindowDef.Placement.RANDOM:
			var m := d.random_margin
			pos = Vector2i(
				randi_range(m, maxi(m + 1, screen.x - s.x - m)),
				randi_range(m, maxi(m + 1, screen.y - s.y - m)))
		PopupWindowDef.Placement.NEAR_PLAYER:
			pos = _player_screen_position() - s / 2
		PopupWindowDef.Placement.EDGE:
			var side := randi() % 4
			match side:
				0: pos = Vector2i(randi_range(0, maxi(1, screen.x - s.x)), 0)
				1: pos = Vector2i(randi_range(0, maxi(1, screen.x - s.x)), screen.y - s.y)
				2: pos = Vector2i(0, randi_range(0, maxi(1, screen.y - s.y)))
				_: pos = Vector2i(screen.x - s.x, randi_range(0, maxi(1, screen.y - s.y)))
	pos += d.offset
	# keep it on the monitor
	pos.x = clampi(pos.x, 0, maxi(0, screen.x - s.x))
	pos.y = clampi(pos.y, 0, maxi(0, screen.y - s.y))
	return pos


## Sami's position translated to desktop coordinates.
func _player_screen_position() -> Vector2i:
	# get_first_node_in_group() returns a plain Node, which has no
	# global_position — so type it as Node2D explicitly.
	var p := get_tree().get_first_node_in_group("Player") as Node2D
	if p == null:
		return DisplayServer.screen_get_size() / 2
	var cam := get_viewport().get_camera_2d()
	var screen_pos: Vector2 = p.global_position
	if cam:
		screen_pos = (p.global_position - cam.get_screen_center_position()) * cam.zoom \
				+ get_viewport().get_visible_rect().size * 0.5
	return DisplayServer.window_get_position() + Vector2i(screen_pos)


## "Behind the game" — Godot has always_on_top but no always_on_bottom, so
## we raise the GAME window instead, which pushes the popup behind it.
## Caveat: if the player alt-tabs, the OS may reorder them again.
func _send_back(w: Window) -> void:
	if not raise_game_for_below:
		return
	w.always_on_top = false
	await get_tree().process_frame
	DisplayServer.window_move_to_foreground()      # the game jumps in front


# --- closing ---------------------------------------------------------------

## Opens a def at an exact desktop position, ignoring its placement setting.
## Used by the window chain when a window closes and its replacement should
## appear in the same spot. Pass Vector2i(-99999, -99999) for "wherever".
func open_at(d: PopupWindowDef, at: Vector2i) -> PopupWindow:
	var w := open(d)
	if w and at.x != -99999:
		_place_at.call_deferred(w, at)
	return w


func _place_at(w: PopupWindow, at: Vector2i) -> void:
	if is_instance_valid(w):
		w.position = at
		w.remember_position()


## Called by a window that has morphed into a different def, so the live
## window is filed under its NEW id. You don't call this yourself.
func rekey_window(old_id: String, new_id: String, w: PopupWindow) -> void:
	if old_id != "" and open_windows.has(old_id):
		open_windows.erase(old_id)
	if new_id != "":
		open_windows[new_id] = w


## The ONE icon the operating system shows for this program — taskbar,
## alt-tab, every OS window at once. Godot's DisplayServer.set_icon() takes
## no window argument, so this genuinely cannot be done per window; that's
## what WindowSkin is for.
##
## Still useful as a story beat: change the whole program's icon partway
## through and every window the player has open changes with it.
##     PopupWindows.set_app_icon(load("res://art/icon_wrong.png"))
func set_app_icon(tex: Texture2D) -> void:
	if tex == null:
		return
	var img := tex.get_image()
	if img == null:
		push_warning("PopupWindows: couldn't read an Image from that texture.")
		return
	DisplayServer.set_icon(img)
	if debug_log:
		print("PopupWindows: application icon changed.")


func close_id(id: String) -> void:
	if open_windows.has(id):
		open_windows[id].close_window()


func close_all() -> void:
	for id in open_windows.keys():
		if is_instance_valid(open_windows[id]):
			open_windows[id].close_window()


func is_open(id: String) -> bool:
	return open_windows.has(id)


func _on_window_closed(d: PopupWindowDef) -> void:
	open_windows.erase(d.id)
	window_closed.emit(d.id)
	if debug_log:
		print("PopupWindows: closed '%s'." % d.id)


## DIALOG ACTIONS — on any DialogLine, Action group:
##   action_name = "window"          args = ["whisper_1"]   open it
##   action_name = "window_close"    args = ["whisper_1"]   close it
##   action_name = "window_close_all"                       close everything
## Tick wait_for_action if the conversation should pause meanwhile.
func _on_dialog_action(action_name: String, args: Array) -> void:
	match action_name:
		"window":
			if args.size() > 0:
				open_id(str(args[0]))
		"window_close":
			if args.size() > 0:
				close_id(str(args[0]))
		"window_close_all":
			close_all()
		_:
			return
	var dm := get_node_or_null("/root/DialogManager")
	if dm and dm.has_method("is_waiting_action") and dm.is_waiting_action():
		dm.finish_action()
