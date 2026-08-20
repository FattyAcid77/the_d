extends Node
## Prescription — add as an Autoload named "Prescription".
## The old-school password save system, themed as medicine prescriptions.
##
## HOW IT WORKS
## - You define checkpoints (PrescriptionCheckpoint .tres in Checkpoints/).
## - When the player REACHES one, a popup shows their new prescription,
##   e.g.  "Nazomel 250mg"  — they write it down.
## - Later (fresh game), they open the pharmacy window, dial in the
##   medicine, and the game restores that checkpoint. A wrong/made-up
##   medicine fails the checksum: "This medication does not exist."
##
## REACHING a checkpoint (pick any):
##     Prescription.reach(3)                       # from code
##     dialog line action:  action_name = "checkpoint", args = [3]
##
## SHOWING the current code again:
##     Prescription.show_current()                 # from code
##     dialog action:  "prescription_show"         # e.g. a nurse NPC
##
## ENTERING a code (hook this to a main-menu button, or a pharmacist):
##     Prescription.open_entry()
##     dialog action:  "prescription_entry"

signal checkpoint_reached(number: int)
signal checkpoint_applied(number: int)

const CHECKPOINTS_DIR := "res://FD_Testing/GameSystems/Prescription/Checkpoints"
const CURRENT_FLAG := "prescription_current"

## The four syllable/dose tables. 16 entries each — together they encode
## 16 bits (8-bit checkpoint number + 8-bit checksum).
## !! NEVER reorder or change these once codes are in players' hands.
const PREFIX := ["Na","Zo","Ka","Ri","Mo","Fa","Du","Le","Sa","Ti","Bu","He","Pa","Vi","Xo","Ga"]
const MIDDLE := ["zo","ra","mi","lo","ne","da","fu","ke","si","to","va","ce","li","ru","be","no"]
const SUFFIX := ["mel","dex","rin","zol","pam","tan","vir","lam","ide","ine","ate","oxin","adol","ium","ex","al"]
const DOSE := [50,100,150,200,250,300,350,400,450,500,600,700,750,800,900,1000]

## Popup texts — change to Arabic if you like.
@export var new_prescription_text: String = "NEW PRESCRIPTION:"
@export var invalid_text: String = "This medication does not exist."
@export var filled_text: String = "Prescription filled."
## Shown under a held popup, telling the player how to dismiss it.
@export var dismiss_text: String = "(write it down — press to continue)"

## Seconds a short message stays up. The PRESCRIPTION popup ignores this:
## it waits for a keypress so the player always has time to write it down.
@export var message_seconds: float = 3.0

@export_group("Anti brute-force")
## After this many wrong medicines in a row, the pharmacy makes them wait.
@export var wrong_tries_before_lock: int = 3
## How long that wait is (seconds).
@export var lock_seconds: float = 10.0

var checkpoints: Array[PrescriptionCheckpoint] = []

var _layer: CanvasLayer
var _popup: PanelContainer
var _popup_label: Label
var _popup_hint: Label
var _holding := false
var _wrong_tries := 0
var _locked_until := 0
var _entry: PanelContainer
var _dial_values := [0, 0, 0, 0]
var _dial_labels: Array = []
var _entry_msg: Label
var _entry_was_paused := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_checkpoints()
	_build_ui()
	var dm := get_node_or_null("/root/DialogManager")
	if dm and dm.has_signal("action_requested"):
		dm.action_requested.connect(_on_dialog_action)


func _load_checkpoints() -> void:
	checkpoints.clear()
	var dir := DirAccess.open(CHECKPOINTS_DIR)
	if dir == null:
		push_warning("Prescription: no checkpoints folder at %s" % CHECKPOINTS_DIR)
		return
	for file in dir.get_files():
		if file.get_extension() == "tres" or file.get_extension() == "res":
			var r := load(CHECKPOINTS_DIR + "/" + file)
			if r is PrescriptionCheckpoint:
				checkpoints.append(r)


func get_checkpoint(number: int) -> PrescriptionCheckpoint:
	for c in checkpoints:
		if c.number == number:
			return c
	return null


# ==========================================================================
# the code itself
# ==========================================================================

func _checksum(number: int) -> int:
	return (((number ^ 0xA7) * 13) + 41) & 0xFF


## 16 bits -> the four dial indices [prefix, middle, suffix, dose]
func _encode(number: int) -> Array:
	var bits: int = ((number & 0xFF) << 8) | _checksum(number)
	return [(bits >> 12) & 0xF, (bits >> 8) & 0xF, (bits >> 4) & 0xF, bits & 0xF]


## dial indices -> checkpoint number, or -1 if the checksum fails
func _decode(dials: Array) -> int:
	var bits: int = (dials[0] << 12) | (dials[1] << 8) | (dials[2] << 4) | dials[3]
	var number: int = (bits >> 8) & 0xFF
	var check: int = bits & 0xFF
	if check != _checksum(number):
		return -1
	return number


## The human-readable medicine, e.g. "Nazomel 250mg".
func code_text(number: int) -> String:
	var d := _encode(number)
	return PREFIX[d[0]] + MIDDLE[d[1]] + SUFFIX[d[2]] + " " + str(DOSE[d[3]]) + "mg"


# ==========================================================================
# reaching / applying
# ==========================================================================

## Call when the player passes a save point. Shows the prescription popup.
func reach(number: int) -> void:
	if get_checkpoint(number) == null:
		push_error("Prescription: no checkpoint numbered %d." % number)
		return
	Flags.set_flag(CURRENT_FLAG, number)
	checkpoint_reached.emit(number)
	await _show_popup_held(new_prescription_text + "\n" + code_text(number))


## Show the player's current prescription again (nurse NPC, pause menu...).
func show_current() -> void:
	var n: int = int(Flags.get_flag(CURRENT_FLAG, -1))
	if n < 0:
		_show_popup(invalid_text)
		return
	await _show_popup_held(new_prescription_text + "\n" + code_text(n))


## Restore the game to a checkpoint (what a valid entered code does).
func apply(number: int) -> void:
	var c := get_checkpoint(number)
	if c == null:
		return
	Flags.clear_all()
	for f in c.set_flags:
		Flags.set_flag(f)
	Flags.set_flag(CURRENT_FLAG, number)
	GameProgress.goto_state(c.state_name)
	checkpoint_applied.emit(number)
	if c.scene:
		get_tree().paused = false
		SceneManager.load_new_packed(c.scene)


# ==========================================================================
# UI
# ==========================================================================

func _build_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 85
	_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_layer)

	# --- the small popup (new prescription / messages) ---
	_popup = PanelContainer.new()
	_popup.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_popup.position = Vector2(-180, 40)
	_popup.custom_minimum_size = Vector2(360, 0)
	_popup.visible = false
	_layer.add_child(_popup)
	var pvb := VBoxContainer.new()
	_popup.add_child(pvb)
	_popup_label = Label.new()
	_popup_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_popup_label.add_theme_font_size_override("font_size", 22)
	pvb.add_child(_popup_label)
	_popup_hint = Label.new()
	_popup_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_popup_hint.modulate = Color(1, 1, 1, 0.6)
	pvb.add_child(_popup_hint)

	# --- the pharmacy entry window (four dials) ---
	_entry = PanelContainer.new()
	_entry.set_anchors_preset(Control.PRESET_CENTER)
	_entry.position = Vector2(-260, -140)
	_entry.custom_minimum_size = Vector2(520, 0)
	_entry.visible = false
	_layer.add_child(_entry)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	_entry.add_child(vb)
	var title := Label.new()
	title.text = tr("PHARMACY — enter your prescription")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	vb.add_child(title)
	var dials := HBoxContainer.new()
	dials.add_theme_constant_override("separation", 10)
	dials.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(dials)
	for i in 4:
		dials.add_child(_make_dial(i))
	_entry_msg = Label.new()
	_entry_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_entry_msg.modulate = Color(1, 0.6, 0.6)
	vb.add_child(_entry_msg)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 20)
	vb.add_child(buttons)
	var ok := Button.new()
	ok.text = tr("Fill prescription")
	ok.pressed.connect(_on_entry_confirm)
	buttons.add_child(ok)
	var cancel := Button.new()
	cancel.text = tr("Cancel")
	cancel.pressed.connect(close_entry)
	buttons.add_child(cancel)


func _make_dial(index: int) -> Control:
	var box := VBoxContainer.new()
	var up := Button.new()
	up.text = "▲"
	box.add_child(up)
	var value := Label.new()
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.add_theme_font_size_override("font_size", 22)
	value.custom_minimum_size = Vector2(100, 34)
	box.add_child(value)
	var down := Button.new()
	down.text = "▼"
	box.add_child(down)
	_dial_labels.append(value)
	up.pressed.connect(func() -> void: _spin(index, 1))
	down.pressed.connect(func() -> void: _spin(index, -1))
	return box


func _spin(index: int, dir: int) -> void:
	_dial_values[index] = wrapi(_dial_values[index] + dir, 0, 16)
	_entry_msg.text = ""
	_update_dials()


func _update_dials() -> void:
	_dial_labels[0].text = PREFIX[_dial_values[0]]
	_dial_labels[1].text = MIDDLE[_dial_values[1]]
	_dial_labels[2].text = SUFFIX[_dial_values[2]]
	_dial_labels[3].text = str(DOSE[_dial_values[3]]) + "mg"


func open_entry() -> void:
	_entry_was_paused = get_tree().paused
	get_tree().paused = true
	_dial_values = [0, 0, 0, 0]
	_entry_msg.text = ""
	_update_dials()
	_entry.visible = true


func close_entry() -> void:
	_entry.visible = false
	get_tree().paused = _entry_was_paused


func _on_entry_confirm() -> void:
	var now := Time.get_ticks_msec()
	if now < _locked_until:
		_entry_msg.text = "Please wait %d s." % int((_locked_until - now) / 1000.0 + 1)
		return
	var number := _decode(_dial_values)
	if number < 0 or get_checkpoint(number) == null:
		_wrong_tries += 1
		if _wrong_tries >= wrong_tries_before_lock:
			_wrong_tries = 0
			_locked_until = now + int(lock_seconds * 1000.0)
			_entry_msg.text = tr(invalid_text) + "\nThe pharmacist checks the records..."
		else:
			_entry_msg.text = invalid_text
		return
	_wrong_tries = 0
	_entry.visible = false
	get_tree().paused = false
	_show_popup(filled_text)
	apply(number)


func _show_popup(text: String) -> void:
	_popup_label.text = text
	_popup_hint.text = ""
	_popup.visible = true
	var t := get_tree().create_timer(message_seconds, true, false, true)
	t.timeout.connect(func() -> void: _popup.visible = false)


## The important one: stays on screen, pauses the game, and waits for a
## keypress — so the player can never miss writing their prescription down.
func _show_popup_held(text: String) -> void:
	_popup_label.text = text
	_popup_hint.text = tr(dismiss_text)
	_popup.visible = true
	_holding = true
	# Only take the pause if nobody else already has it (a dialog or cutscene
	# may have paused first — then it owns the unpause, not us).
	var i_paused := false
	if not get_tree().paused:
		get_tree().paused = true
		i_paused = true
	await get_tree().create_timer(0.35, true, false, true).timeout   # ignore the press that got here
	while _holding:
		await get_tree().process_frame
		if InputAccess.just_pressed() or InputAccess.just_pressed("ui_accept"):
			_holding = false
	_popup.visible = false
	if i_paused:
		get_tree().paused = false


func _on_dialog_action(action_name: String, args: Array) -> void:
	match action_name:
		"checkpoint":
			if args.size() > 0:
				await reach(int(args[0]))
				_finish_dialog_action()
		"prescription_show":
			await show_current()
			_finish_dialog_action()
		"prescription_entry":
			open_entry()
			_finish_dialog_action()


func _finish_dialog_action() -> void:
	var dm := get_node_or_null("/root/DialogManager")
	if dm and dm.has_method("is_waiting_action") and dm.is_waiting_action():
		dm.finish_action()
