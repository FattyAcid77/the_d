class_name RadioStatue extends Node2D
## The statue. It listens to the speakers and answers with a MOOD and a
## NUMBER in a speech bubble.
##
##   HAPPY = wrong. The number is a decoy — ignore it.
##   SAD   = right. That number is real, and goes on the board.
##
## FOUR STAGES, in order. Each stage unlocks when the one before it is
## answered correctly:
##   Stage 1: one speaker            (top left)
##   Stage 2: the two on the left
##   Stage 3: the two on the right
##   Stage 4: all four at once
##
## Single-speaker stages answer the moment the speaker is tuned. Multi-
## speaker stages need the PLAY button (it appears once every speaker in
## that stage holds a frequency).

signal answered(response: StatueResponse)
signal answer_found(numbers: PackedStringArray)   ## a SAD (real) answer
signal stage_advanced(stage: int)
signal all_stages_done

@export_group("Setup")
## The speakers, in index order (0..3).
@export var speakers: Array[RadioSpeaker] = []
## Everything the statue can answer to (all stages).
@export var responses: Array[StatueResponse] = []
## The board that collects the real numbers.
@export var board: Node

@export_group("Stages")
## Which speakers each stage needs, in order. Defaults to your layout:
##   1) top-left only   2) both left   3) both right   4) all four
@export var stage_1_speakers: Array[int] = [0]
@export var stage_2_speakers: Array[int] = [0, 2]
@export var stage_3_speakers: Array[int] = [1, 3]
@export var stage_4_speakers: Array[int] = [0, 1, 2, 3]
## Start at stage 1. Raised as each stage is answered.
@export var current_stage: int = 1

@export_group("Look")
@export var sprite: AnimatedSprite2D
@export var anim_idle: String = "idle"
@export var anim_happy: String = "happy"
@export var anim_sad: String = "sad"
@export var bubble_offset := Vector2(0, -110)
## How long an answer stays up. 0 = until the tuning changes.
@export var bubble_seconds: float = 0.0

@export_group("Play button")
@export var play_button_text: String = "PLAY"
@export var play_button_offset := Vector2(90, -40)

@export_group("Progress")
@export var stage_flag_prefix: String = "statue_stage_"
@export var all_done_flag: String = "statue_answers_found"

var current_response: StatueResponse = null

var _tuning := {}                      ## speaker_index -> hz
var _bubble: Node2D
var _bubble_label: Label
var _play_btn: Button
var _bubble_timer: float = 0.0


func _ready() -> void:
	for s in speakers:
		if s:
			s.tuned.connect(_on_speaker_tuned)
			if s.current_hz >= 0:
				_tuning[s.speaker_index] = s.current_hz
	_build_ui()
	_play(anim_idle)
	_refresh_play_button()
	_validate_responses()


## Catches puzzle frequencies the player could never dial in.
func _validate_responses() -> void:
	if not RadioLink.available():
		push_warning("RadioStatue: RadioGlobal isn't in the project — the "
				+ "speakers will sit at their starting values.")
		return
	for r in responses:
		if r == null:
			continue
		if r.speakers.size() != r.frequencies.size():
			push_warning("RadioStatue: '%s' has %d speakers but %d frequencies."
					% [r.resource_path.get_file(), r.speakers.size(), r.frequencies.size()])
			continue
		for hz in r.frequencies:
			if not RadioLink.is_reachable(int(hz)):
				push_warning("RadioStatue: '%s' wants %d Hz — NOT reachable. "
						% [r.resource_path.get_file(), hz]
						+ "Must be a multiple of 10 between %d and %d."
						% [RadioLink.min_hz(), RadioLink.max_hz()])


func _process(delta: float) -> void:
	if bubble_seconds > 0.0 and _bubble.visible:
		_bubble_timer -= delta
		if _bubble_timer <= 0.0:
			_bubble.visible = false


## Which speakers the current stage uses.
func stage_speakers(stage: int = -1) -> Array[int]:
	var s: int = stage if stage > 0 else current_stage
	match s:
		1: return stage_1_speakers
		2: return stage_2_speakers
		3: return stage_3_speakers
		4: return stage_4_speakers
	return []


# --- listening -------------------------------------------------------------

func _on_speaker_tuned(index: int, hz: int) -> void:
	_tuning[index] = hz
	_refresh_play_button()
	# a one-speaker stage answers straight away; bigger stages wait for PLAY
	if stage_speakers().size() <= 1:
		_evaluate()


## The PLAY button: sound every speaker of this stage together.
func play_stage() -> void:
	_evaluate()


func _evaluate() -> void:
	var needed := stage_speakers()
	var hit: StatueResponse = null
	for r in responses:
		if r == null or r.stage != current_stage:
			continue
		if r.matches(_tuning):
			hit = r
			break
	if hit == null:
		if needed.size() > 1:
			_say("...", false)     # played them together, nothing recognised
		return
	_answer(hit)


func _answer(r: StatueResponse) -> void:
	current_response = r
	_play(anim_sad if r.is_answer() else anim_happy)
	_say(r.spoken, r.is_answer())
	if r.heard_flag != "":
		Flags.set_flag(r.heard_flag)
	answered.emit(r)
	if not r.is_answer():
		return                      # happy = decoy, stage stays put

	answer_found.emit(r.numbers())
	if board and board.has_method("offer_numbers"):
		board.offer_numbers(r.numbers())
	Flags.set_flag(stage_flag_prefix + str(current_stage))
	print("Statue: stage %d answered with '%s'." % [current_stage, r.spoken])

	if current_stage >= 4:
		Flags.set_flag(all_done_flag)
		all_stages_done.emit()
		print("STATUE: all stages complete.")
	else:
		current_stage += 1
		stage_advanced.emit(current_stage)
		print("Statue: stage %d unlocked (speakers %s)."
				% [current_stage, str(stage_speakers())])
	_refresh_play_button()


# --- bubble + button -------------------------------------------------------

func _build_ui() -> void:
	_bubble = Node2D.new()
	_bubble.position = bubble_offset
	add_child(_bubble)
	var bg := Panel.new()
	bg.size = Vector2(160, 46)
	bg.position = -bg.size * 0.5
	_bubble.add_child(bg)
	_bubble_label = Label.new()
	_bubble_label.size = bg.size
	_bubble_label.position = bg.position
	_bubble_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bubble_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_bubble_label.add_theme_font_size_override("font_size", 22)
	_bubble.add_child(_bubble_label)
	_bubble.visible = false

	_play_btn = Button.new()
	_play_btn.text = play_button_text
	_play_btn.position = play_button_offset
	_play_btn.pressed.connect(play_stage)
	_play_btn.visible = false
	add_child(_play_btn)


func _say(text: String, is_answer: bool) -> void:
	_bubble_label.text = text
	_bubble_label.add_theme_color_override("font_color",
			Color(0.4, 0.85, 1.0) if is_answer else Color(1, 1, 1))
	_bubble.visible = true
	_bubble_timer = bubble_seconds


## The button appears only when EVERY speaker of this stage holds a value.
func _refresh_play_button() -> void:
	if _play_btn == null:
		return
	var needed := stage_speakers()
	if needed.size() <= 1:
		_play_btn.visible = false
		return
	for idx in needed:
		if not _tuning.has(idx) or int(_tuning[idx]) < 0:
			_play_btn.visible = false
			return
	_play_btn.visible = true


func _play(anim_name: String) -> void:
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation(anim_name):
		if sprite.animation != anim_name:
			sprite.play(anim_name)
