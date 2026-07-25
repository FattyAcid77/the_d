class_name PuzzleStatue extends Node2D
## The statue's brain. Wire the four speakers and their target numbers in the
## inspector. It reacts in three stages, exactly your design:
##
##   0 sides correct  ->  plays anim_sad
##   1 side correct   ->  plays anim_half     (the statue "moves")
##   2 sides correct  ->  plays anim_solved, sets `solved_flag`,
##                        and the statue SPEAKS (starts `dialog`)
##
## Right side = speakers 1 & 4, left side = speakers 2 & 3 (like your sketch),
## but really: whatever you plug into the right_/left_ slots.
##
## Persistence: if `solved_flag` is already set (loaded save), the statue
## starts solved and the speakers lock.

signal side_solved(side: String)          ## "right" or "left", first time only
signal puzzle_solved

@export_group("Speakers")
@export var right_speaker_a: PuzzleSpeaker    ## e.g. speaker 1
@export var right_speaker_b: PuzzleSpeaker    ## e.g. speaker 4
@export var left_speaker_a: PuzzleSpeaker     ## e.g. speaker 2
@export var left_speaker_b: PuzzleSpeaker     ## e.g. speaker 3

@export_group("Answers")
@export var right_target_a: int = 1
@export var right_target_b: int = 4
@export var left_target_a: int = 2
@export var left_target_b: int = 3

@export_group("Feedback")
## The statue's AnimatedSprite2D with the three animations below.
@export var sprite: AnimatedSprite2D
@export var anim_sad: String = "sad"
@export var anim_half: String = "half"
@export var anim_solved: String = "solved"
## Your chosen per-speaker tell (hum + number tint on a correct speaker).
@export var per_speaker_tell: bool = true

@export_group("On Solve")
## What the statue says when it wakes up. Plays automatically once.
@export var dialog: Dialog
@export var statue_name: String = "Statue"
@export var portrait: Texture2D
@export var solved_flag: String = "statue_solved"
## Optional cutscene played BEFORE the statue speaks (.ogv path). Empty = none.
@export_file("*.ogv") var solve_cutscene: String = ""

var _right_was_solved := false
var _left_was_solved := false
var _solved := false


func _ready() -> void:
	for s in _speakers():
		if s:
			s.value_changed.connect(_on_speaker_changed)
	if Flags.is_set(solved_flag):
		_apply_solved(false)   # already solved in a previous session: no speech
	else:
		_evaluate(false)


func _speakers() -> Array:
	return [right_speaker_a, right_speaker_b, left_speaker_a, left_speaker_b]


func _on_speaker_changed(_speaker: PuzzleSpeaker) -> void:
	_evaluate(true)


func _evaluate(animate: bool) -> void:
	if _solved:
		return
	var r_a := right_speaker_a != null and right_speaker_a.value == right_target_a
	var r_b := right_speaker_b != null and right_speaker_b.value == right_target_b
	var l_a := left_speaker_a != null and left_speaker_a.value == left_target_a
	var l_b := left_speaker_b != null and left_speaker_b.value == left_target_b

	if right_speaker_a: right_speaker_a.set_correct(r_a, per_speaker_tell)
	if right_speaker_b: right_speaker_b.set_correct(r_b, per_speaker_tell)
	if left_speaker_a: left_speaker_a.set_correct(l_a, per_speaker_tell)
	if left_speaker_b: left_speaker_b.set_correct(l_b, per_speaker_tell)

	var right_ok := r_a and r_b
	var left_ok := l_a and l_b

	if right_ok and not _right_was_solved:
		_right_was_solved = true
		side_solved.emit("right")
	if left_ok and not _left_was_solved:
		_left_was_solved = true
		side_solved.emit("left")

	var sides := int(right_ok) + int(left_ok)
	match sides:
		0:
			_play(anim_sad)
		1:
			_play(anim_half)
		2:
			_solve(animate)


func _solve(speak: bool) -> void:
	Flags.set_flag(solved_flag)
	_apply_solved(speak)
	puzzle_solved.emit()


func _apply_solved(speak: bool) -> void:
	_solved = true
	_play(anim_solved)
	for s in _speakers():
		if s:
			s.set_correct(true, per_speaker_tell)
			s.lock()
	if speak:
		_speak.call_deferred()


func _speak() -> void:
	if solve_cutscene != "":
		await Cutscene.play(solve_cutscene)
	if dialog:
		DialogManager.start_dialog(dialog, statue_name, portrait)


func _play(anim_name: String) -> void:
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation(anim_name):
		if sprite.animation != anim_name:
			sprite.play(anim_name)
