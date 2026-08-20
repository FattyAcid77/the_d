class_name RadioReactor extends Node
## Put this INSIDE the scene that a PORTAL window shows, and the radio dial
## in the main game starts changing that room, live, while the player watches
## through the window.
##
## THE IDEA
## Sami can't go in there. He can't reach it, and he never will. But the
## PLAYER can — by turning a dial. The only thing crossing between the two
## worlds is a radio frequency.
##
## HOW TO SET IT UP
##   1. Build the other room as its own scene, e.g. OtherRoom.tscn.
##   2. Add a Node to it, attach this script.
##   3. Fill its `bands` array with RadioBand .tres files —
##      "at 1120, show the door", "at 640, play the flicker animation".
##   4. Make a PopupWindowDef with kind = PORTAL, portal_same_world = OFF,
##      and portal_scene = OtherRoom.tscn.
##   5. Open that window. Turn the dial. Watch the room change.
##
## It reads the radio through RadioLink, so the other developer's radio code
## is never touched.

signal band_entered(id: String)
signal band_exited(id: String)

## The frequencies this room listens to, and what each one does.
@export var bands: Array[RadioBand] = []

## How often to check the dial, in seconds. 0 = every frame.
## A small value like 0.1 is plenty and costs nothing.
@export var poll_interval: float = 0.05

## Print what it's doing. Very useful while tuning the numbers.
@export var debug_log: bool = false

var _radio: Node
var _active: Dictionary = {}        ## band -> true
var _latched: Dictionary = {}       ## band -> true, never undone
var _holding: Dictionary = {}       ## band -> seconds held so far
var _sounds: Dictionary = {}        ## band -> AudioStreamPlayer
var _clock: float = 0.0


func _ready() -> void:
	# The portal scene runs inside a SubViewport, so it can't reach the main
	# tree by relative path — always go through /root.
	_radio = get_node_or_null("/root/RadioLink")
	if _radio == null:
		push_warning("RadioReactor: no RadioLink autoload — this room won't react.")


func _process(delta: float) -> void:
	if _radio == null or bands.is_empty():
		return
	_clock -= delta
	if _clock > 0.0:
		return
	_clock = poll_interval

	var hz: int = _radio.frequency()
	var open: bool = _radio.is_open() if _radio.has_method("is_open") else true
	var flags := get_node_or_null("/root/Flags")

	for band in bands:
		if band == null:
			continue
		if _latched.has(band):
			continue
		if band.require_flag != "" and flags and not flags.is_set(band.require_flag):
			continue

		var tuned := band.matches(hz) and (open or not band.require_radio_open)

		# hold-to-trigger
		if tuned and band.hold_seconds > 0.0 and not _active.has(band):
			var held: float = _holding.get(band, 0.0) + poll_interval
			_holding[band] = held
			if held < band.hold_seconds:
				continue
		elif not tuned:
			_holding.erase(band)

		if tuned and not _active.has(band):
			_enter(band, flags)
		elif not tuned and _active.has(band):
			_exit(band, flags)


# --- entering / leaving a band ---------------------------------------------

func _enter(band: RadioBand, flags: Node) -> void:
	_active[band] = true
	if band.latch:
		_latched[band] = true

	if debug_log:
		print("RadioReactor: tuned in to '%s' (%d Hz)" % [band.id, band.frequency])

	if flags and band.set_flag_on_enter != "":
		flags.set_flag(band.set_flag_on_enter)

	_do(band, true)
	_start_sound(band)
	band_entered.emit(band.id)


func _exit(band: RadioBand, flags: Node) -> void:
	_active.erase(band)
	_holding.erase(band)

	if debug_log:
		print("RadioReactor: tuned away from '%s'" % band.id)

	if flags and band.set_flag_on_leave != "":
		flags.set_flag(band.set_flag_on_leave)

	if not band.latch:
		_do(band, false)
	_stop_sound(band)
	band_exited.emit(band.id)


# --- doing the thing -------------------------------------------------------

func _do(band: RadioBand, entering: bool) -> void:
	var node: Node = null
	if not band.target.is_empty():
		node = get_node_or_null(band.target)
		if node == null:
			push_warning("RadioReactor: band '%s' target not found: %s"
					% [band.id, band.target])
			return

	match band.action:
		RadioBand.Do.SHOW:
			if node and "visible" in node:
				node.visible = entering
		RadioBand.Do.HIDE:
			if node and "visible" in node:
				node.visible = not entering
		RadioBand.Do.PLAY_ANIM:
			if node and entering and node.has_method("play"):
				if band.value_name != "":
					node.play(band.value_name)
				else:
					node.play()
			elif node and not entering and node.has_method("stop"):
				node.stop()
		RadioBand.Do.MODULATE:
			if node and "modulate" in node:
				node.modulate = band.value_color if entering else Color(1, 1, 1, 1)
		RadioBand.Do.MOVE_TO:
			if node and node is Node2D:
				var dest: Vector2 = band.value_position if entering else Vector2.ZERO
				if band.move_time > 0.0:
					var tw := create_tween()
					tw.tween_property(node, "position", dest, band.move_time)
				else:
					node.position = dest
		RadioBand.Do.CALL_METHOD:
			if node and entering and band.value_name != "" \
					and node.has_method(band.value_name):
				node.callv(band.value_name, band.value_args)
		RadioBand.Do.SET_FLAG, RadioBand.Do.NOTHING:
			pass                   # the flag work already happened above


# --- sound -----------------------------------------------------------------

func _start_sound(band: RadioBand) -> void:
	if band.sound == null:
		return
	var p := AudioStreamPlayer.new()
	p.stream = band.sound
	p.volume_db = band.sound_volume_db
	add_child(p)
	p.play()
	_sounds[band] = p


func _stop_sound(band: RadioBand) -> void:
	var p = _sounds.get(band)
	if p and is_instance_valid(p):
		p.queue_free()
	_sounds.erase(band)


# --- for your own code -----------------------------------------------------

## Is this band id currently tuned in?
func is_tuned(band_id: String) -> bool:
	for b in _active.keys():
		if b.id == band_id:
			return true
	return false


## Undo a latched band so it can fire again.
func unlatch(band_id: String) -> void:
	for b in _latched.keys():
		if b.id == band_id:
			_latched.erase(b)
			return
