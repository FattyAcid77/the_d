class_name DialogUI extends CanvasLayer
## The dialog box. DialogManager creates one and calls start(); runs while paused.
##
## CUSTOM LOOK: build the box however you like in dialog_ui.tscn, then drag your
## nodes into the exported slots on the DialogUI root. text_label must be a
## RichTextLabel with BBCode enabled.

signal finished

## Reading direction. AUTO detects per line: Arabic flows right-to-left and
## right-aligns, English flows left-to-right. Force LTR or RTL to override.
enum TextDir { AUTO, LTR, RTL }

@export var typewriter_speed: float = 40.0      ## characters per second
@export var type_sound: AudioStream              ## short blip per character
@export var pitch_min: float = 0.9
@export var pitch_max: float = 1.1
@export var keyword_color: String = "#ffd24a"    ## colour of clickable words
@export var text_direction_mode: TextDir = TextDir.AUTO
## Text of the "end conversation" button in the topic hub (Arabic works).
@export var leave_label: String = "Leave"

@export var box: Control                  ## the whole visual container to show/hide
@export var portrait_rect: TextureRect    ## optional
@export var name_label: Label
@export var text_label: RichTextLabel
@export var choices_box: Container         ## where choice buttons are added
@export var topics_box: Container          ## where topic buttons are added
@export var leave_button: Button           ## the X — closes the dialog from anywhere
@export var audio: AudioStreamPlayer       ## optional (typewriter blip)
@export var layout_margin: MarginContainer ## the container that holds the text rows

## --- Art-locked layout ---------------------------------------------------
## The box art is used at its TRUE aspect ratio (no 9-slice, no distortion),
## and everything is placed as FRACTIONS of the art, so it looks identical
## at any window size. If you ever swap the art, update these to match it.
const ART_W: float = 954.0
const ART_H: float = 258.0
## interior writing area of the big frame (fractions of the art)
const BODY_LEFT := 0.065
const BODY_TOP := 0.40
const BODY_RIGHT := 0.035
const BODY_BOTTOM := 0.10
## reference font heights in ART pixels (scaled with the box)
const NAME_FONT_ART := 22.0
const BODY_FONT_ART := 20.0

const FALLBACK_SOUND := "res://GameSystems/DialogV2/dialogue_noise.mp3"

var _dialog: Dialog
var _speaker_default := ""
var _clicked_topic := ""
var _picked_topic := ""
var _chosen_choice: DialogChoice
var _leave_pressed := false
var _end_all := false
var _input_lock_until := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if type_sound == null and ResourceLoader.exists(FALLBACK_SOUND):
		type_sound = load(FALLBACK_SOUND)
	if text_label:
		text_label.meta_clicked.connect(_on_meta_clicked)
		text_label.fit_content = false      # keep a fixed text region (issue 3/4)
		text_label.scroll_active = false
	if name_label:
		# the name lives in the top-left plate and never moves with the line's language
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		name_label.text_direction = Control.TEXT_DIRECTION_AUTO
	if leave_button:
		leave_button.pressed.connect(_request_close)
	get_viewport().size_changed.connect(_fit_box)
	_fit_box.call_deferred()
	hide_ui()


## Size the box to the art's aspect ratio and place the content by fractions.
func _fit_box() -> void:
	if box == null:
		return
	var vw: float = box.get_parent_area_size().x if box.get_parent_control() else get_viewport().get_visible_rect().size.x
	var width: float = vw - 16.0                 # 8px breathing room each side
	var height: float = width * (ART_H / ART_W)  # true aspect, no distortion
	box.offset_left = 8.0
	box.offset_right = -8.0
	box.offset_top = -height - 8.0
	box.offset_bottom = -8.0
	var s: float = height / ART_H                # art pixel -> screen pixel scale
	if layout_margin:
		layout_margin.add_theme_constant_override("margin_left", int(width * BODY_LEFT))
		layout_margin.add_theme_constant_override("margin_top", int(height * BODY_TOP))
		layout_margin.add_theme_constant_override("margin_right", int(width * BODY_RIGHT))
		layout_margin.add_theme_constant_override("margin_bottom", int(height * BODY_BOTTOM))
	if name_label:
		name_label.add_theme_font_size_override("font_size", maxi(10, int(NAME_FONT_ART * s)))
	if text_label:
		text_label.add_theme_font_size_override("normal_font_size", maxi(10, int(BODY_FONT_ART * s)))
	if leave_button:
		leave_button.add_theme_font_size_override("font_size", maxi(10, int(NAME_FONT_ART * s)))


func hide_ui() -> void:
	if box:
		box.visible = false


func start(dialog: Dialog, speaker_name: String, portrait: Texture2D) -> void:
	if not _validate():
		finished.emit()
		return
	_dialog = dialog
	_speaker_default = speaker_name
	if portrait_rect:
		portrait_rect.texture = portrait
		portrait_rect.visible = portrait != null
	_reset_runtime()
	if box:
		box.visible = true
	get_tree().paused = true
	_lock_input(0.2)
	await _run()
	get_tree().paused = false
	hide_ui()
	finished.emit()


func _reset_runtime() -> void:
	_clicked_topic = ""
	_picked_topic = ""
	_chosen_choice = null
	_leave_pressed = false
	_end_all = false


func _request_close() -> void:
	# the X button: end the whole conversation no matter where we are
	_end_all = true
	_leave_pressed = true


# --- main loop -------------------------------------------------------------

func _run() -> void:
	var start := _pick_branch()
	if start == "":
		push_warning("DialogUI: no playable branch in this dialog.")
		return
	await _play_branch(start)
	if _end_all:
		return
	while true:
		if _picked_topic != "":
			var t := _picked_topic
			_picked_topic = ""
			await _play_branch(t)
			if _end_all:
				return
			continue
		var topics := _collect_topics()
		if topics.is_empty():
			return
		await _topic_mode(topics)
		if _leave_pressed or _end_all:
			_leave_pressed = false
			return


## Chooses what the NPC says when the player talks. Branches are checked
## IN ORDER — the first one whose flag conditions pass is played.
## So put the MOST SPECIFIC branch FIRST and the default greeting LAST.
func _pick_branch() -> String:
	for b in _dialog.branches:
		if b == null or b.is_topic:
			continue
		if not b.can_play():
			continue
		return b.id
	return "entry" if _dialog.get_branch("entry") else ""


func _play_branch(branch_id: String) -> void:
	var b := _dialog.get_branch(branch_id)
	if b == null:
		push_warning("DialogUI: no branch named '%s'" % branch_id)
		return
	for line in b.lines:
		if line == null:
			continue
		if line.show_if_flag != "" and not Flags.is_set(line.show_if_flag):
			continue
		if line.hide_if_flag != "" and Flags.is_set(line.hide_if_flag):
			continue
		for f in line.set_flags:
			Flags.set_flag(f)

		var has_text := line.text.strip_edges() != ""
		if box:
			box.visible = has_text or box.visible
		if choices_box:
			choices_box.visible = false
		if topics_box:
			topics_box.visible = false

		if line.move_camera:
			if has_text:
				_move_camera(line.camera_target, line.camera_time)
			else:
				await _move_camera(line.camera_target, line.camera_time)

		if line.action_name != "":
			DialogManager.emit_action(line.action_name, line.action_args, line.wait_for_action)
			if line.wait_for_action:
				while DialogManager.is_waiting_action() and not _end_all:
					await get_tree().process_frame
		if _end_all:
			return
		if not has_text:
			continue

		_apply_line_direction(line.text)
		name_label.text = line.speaker_name if line.speaker_name != "" else _speaker_default
		await _typewrite(line)
		if _end_all:
			return

		if not line.choices.is_empty():
			var c := await _ask_choices(line.choices)
			if _end_all:
				return
			if c != null:
				if c.set_flag != "":
					Flags.set_flag(c.set_flag)
				if c.ends_dialog:
					_end_all = true
					return
				if c.goto_branch != "":
					await _play_branch(c.goto_branch)
					return
			continue

		var res := await _wait_advance_or_meta()
		if _end_all:
			return
		if res != "":
			_picked_topic = res
			return

	Flags.set_flag("topic_seen:" + branch_id)


# --- direction / presentation ----------------------------------------------

func _line_is_rtl(s: String) -> bool:
	match text_direction_mode:
		TextDir.LTR:
			return false
		TextDir.RTL:
			return true
		_:
			for ch in s:
				var o := ch.unicode_at(0)
				if (o >= 0x0600 and o <= 0x06FF) or (o >= 0x0750 and o <= 0x077F) \
						or (o >= 0x08A0 and o <= 0x08FF) or (o >= 0xFB50 and o <= 0xFDFF) \
						or (o >= 0xFE70 and o <= 0xFEFF):
					return true
			return false


func _apply_line_direction(s: String) -> void:
	var rtl := _line_is_rtl(s)
	if text_label:
		text_label.text_direction = Control.TEXT_DIRECTION_RTL if rtl else Control.TEXT_DIRECTION_LTR


func _move_camera(target: Vector2, time: float) -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	if time <= 0.0:
		cam.global_position = target
		return
	var start := cam.global_position
	var elapsed := 0.0
	while elapsed < time and not _end_all:
		elapsed += get_process_delta_time()
		cam.global_position = start.lerp(target, clampf(elapsed / time, 0.0, 1.0))
		await get_tree().process_frame
	cam.global_position = target


func _typewrite(line: DialogLine) -> void:
	text_label.text = _build_bbcode(line)
	text_label.visible_characters = 0
	_lock_input(0.12)   # the press that advanced into this line must not also skip it
	var total := text_label.get_total_character_count()
	var shown := 0.0
	while text_label.visible_characters < total:
		if _end_all or _interact_pressed():
			break
		shown += get_process_delta_time() * typewriter_speed
		var v := int(shown)
		if v != text_label.visible_characters:
			text_label.visible_characters = v
			_blip()
		await get_tree().process_frame
	text_label.visible_characters = -1
	_lock_input(0.12)


func _build_bbcode(line: DialogLine) -> String:
	var t := line.text
	for kw in line.keywords:
		if kw == null or kw.word == "":
			continue
		var unlocked := kw.unlock_flag == "" or Flags.is_set(kw.unlock_flag)
		if unlocked:
			var link := "[url=%s][color=%s][u]%s[/u][/color][/url]" % [kw.topic_branch, keyword_color, kw.word]
			t = t.replace(kw.word, link)
	if _line_is_rtl(line.text):
		t = "[p align=right]" + t + "[/p]"   # push Arabic to the right side (issue 2)
	return t


func _ask_choices(choices: Array[DialogChoice]) -> DialogChoice:
	_clear(choices_box)
	var any := false
	_chosen_choice = null
	for c in choices:
		if c == null:
			continue
		if c.show_if_flag != "" and not Flags.is_set(c.show_if_flag):
			continue
		var btn := Button.new()
		btn.text = c.text
		btn.pressed.connect(func() -> void: _chosen_choice = c)
		choices_box.add_child(btn)
		any = true
	if not any:
		return null
	choices_box.visible = true
	choices_box.get_child(0).grab_focus()
	while _chosen_choice == null and not _end_all:
		await get_tree().process_frame
	choices_box.visible = false
	_clear(choices_box)
	return _chosen_choice


func _topic_mode(topics: Array) -> void:
	if box:
		box.visible = true
	_clear(topics_box)
	_picked_topic = ""
	_leave_pressed = false
	for t in topics:
		var btn := Button.new()
		btn.text = t["label"]
		var branch_id: String = t["branch"]
		btn.pressed.connect(func() -> void: _picked_topic = branch_id)
		topics_box.add_child(btn)
	topics_box.visible = true
	var leave_btn := Button.new()
	leave_btn.text = leave_label
	leave_btn.pressed.connect(func() -> void: _leave_pressed = true)
	topics_box.add_child(leave_btn)
	if topics_box.get_child_count() > 0:
		topics_box.get_child(0).grab_focus()
	_lock_input(0.2)
	# NOTE: interact does NOT close the hub — the player picks a topic or
	# presses Leave / the X. (Pressing E by habit shouldn't end the talk.)
	while _picked_topic == "" and not _leave_pressed and not _end_all and _clicked_topic == "":
		await get_tree().process_frame
	if _clicked_topic != "":
		_picked_topic = _clicked_topic
		_clicked_topic = ""
	topics_box.visible = false
	_clear(topics_box)


func _collect_topics() -> Array:
	var seen := {}
	var out := []
	# 1) branches that declare themselves as topics
	for b in _dialog.branches:
		if b == null or not b.is_topic or b.id == "entry":
			continue
		if b.unlock_flag != "" and not Flags.is_set(b.unlock_flag):
			continue
		if b.ask_once and Flags.is_set("topic_seen:" + b.id):
			continue
		if seen.has(b.id):
			continue
		seen[b.id] = true
		out.append({
			"branch": b.id,
			"label": b.topic_label if b.topic_label != "" else b.id,
		})
	# 2) topics unlocked by clickable keywords inside lines
	for b in _dialog.branches:
		for line in b.lines:
			if line == null:
				continue
			for kw in line.keywords:
				if kw == null or kw.topic_branch == "":
					continue
				var unlocked := kw.unlock_flag == "" or Flags.is_set(kw.unlock_flag)
				if not unlocked:
					continue
				if kw.ask_once and Flags.is_set("topic_seen:" + kw.topic_branch):
					continue
				if seen.has(kw.topic_branch) or _dialog.get_branch(kw.topic_branch) == null:
					continue
				seen[kw.topic_branch] = true
				out.append({
					"branch": kw.topic_branch,
					"label": kw.topic_label if kw.topic_label != "" else kw.word,
				})
	return out


# --- input / helpers -------------------------------------------------------

func _wait_advance_or_meta() -> String:
	while true:
		await get_tree().process_frame
		if _end_all:
			return ""
		if _clicked_topic != "":
			var t := _clicked_topic
			_clicked_topic = ""
			return t
		if _interact_pressed():
			return ""
	return ""


func _interact_pressed() -> bool:
	if Time.get_ticks_msec() < _input_lock_until:
		return false
	return Input.is_action_just_pressed("interact")


func _lock_input(seconds: float) -> void:
	_input_lock_until = Time.get_ticks_msec() + int(seconds * 1000.0)


func _on_meta_clicked(meta: Variant) -> void:
	_clicked_topic = str(meta)


func _blip() -> void:
	if type_sound == null or audio == null:
		return
	audio.stream = type_sound
	audio.pitch_scale = randf_range(pitch_min, pitch_max)
	audio.play()


func _clear(node: Node) -> void:
	if node == null:
		return
	for c in node.get_children():
		c.queue_free()


func _validate() -> bool:
	var missing: Array[String] = []
	if box == null: missing.append("box")
	if name_label == null: missing.append("name_label")
	if text_label == null: missing.append("text_label")
	if choices_box == null: missing.append("choices_box")
	if topics_box == null: missing.append("topics_box")
	if missing.size() > 0:
		push_error("DialogUI: these node slots are empty on the DialogUI root — " \
			+ "assign them in the inspector: " + ", ".join(missing))
		return false
	return true
