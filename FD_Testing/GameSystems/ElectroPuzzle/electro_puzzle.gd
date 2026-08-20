class_name ElectroPuzzle extends Node
## The whole generator puzzle.
##
## PHASE 1 — SEQUENCE: flip the three switches in the right order. Wrong
##           order = buzz and everything resets.
## PHASE 2 — THE RUN: a countdown starts, the lights start flickering, the
##           chase music kicks in, and Sami has to reach the MAIN generator
##           while Haji shouts at him.
## PHASE 3 — THE MAIN GEN: flip it (optionally with the radio tuned to the
##           right frequency) before the timer runs out.
##
## Fail = the timer runs out. What that costs is up to you (`on_fail`).

signal switch_accepted(index: int, remaining: int)
signal sequence_wrong
signal run_started(seconds: float)
signal run_tick(time_left: float)
signal callout(text: String)          ## Haji shouting during the run
signal run_failed
signal puzzle_solved

enum FailAction { RESET_ONLY, KILL_PLAYER, RELOAD_CHECKPOINT }

@export_group("Setup")
## The three sequence switches, in ANY order — their `order_index` decides
## the correct sequence, not their position in this list.
@export var gens: Array[ElectroGen] = []
## The final generator at the end of the run.
@export var main_gen: ElectroGen
## Optional: the flicker/darkness controller for the run.
@export var lights: Node

@export_group("The run")
## How long Sami has to reach the main generator.
@export var run_seconds: float = 45.0
## Music for the run (swapped in when it starts).
@export var chase_music: AudioStream
@export var music_volume_db: float = -6.0

@export_group("Haji's callouts")
## Lines shouted during the run. They do NOT pause the game.
@export var callout_lines: Array[String] = [
	"Haji: MOVE! The whole floor is going!",
	"Haji: don't stop, don't stop —",
	"Haji: I can hear it building up!",
]
## Seconds between callouts.
@export var callout_every: float = 9.0
## How long each line stays on screen.
@export var callout_seconds: float = 3.0

@export_group("Story hooks")
## Dialog played ONCE when the three switches are done ("We need to go to
## the main Gen"). This runs BEFORE the timer starts.
@export var after_switches_dialog: Dialog
@export var sami_name: String = "Sami"
## Flags
@export var switches_done_flag: String = "electro_switches_done"
@export var solved_flag: String = "electro_puzzle_solved"

@export_group("Failing")
@export var on_fail: FailAction = FailAction.RESET_ONLY
@export var fail_death_cause: String = "unknown"

var running: bool = false
var solved: bool = false
var time_left: float = 0.0
var next_index: int = 0                ## which order_index we expect next

var _music: AudioStreamPlayer
var _callout_timer: float = 0.0
var _callout_i: int = 0


func _ready() -> void:
	for g in gens:
		if g:
			g.flipped.connect(_on_gen_flipped)
	if main_gen:
		main_gen.flipped.connect(_on_main_flipped)
	_music = AudioStreamPlayer.new()
	_music.volume_db = music_volume_db
	add_child(_music)
	if Flags.is_set(solved_flag):
		solved = true


func _process(delta: float) -> void:
	if not running:
		return
	time_left -= delta
	run_tick.emit(time_left)

	_callout_timer -= delta
	if _callout_timer <= 0.0 and callout_lines.size() > 0:
		_callout_timer = callout_every
		var line: String = tr(callout_lines[_callout_i % callout_lines.size()])
		_callout_i += 1
		callout.emit(line)
		if lights and lights.has_method("show_callout"):
			lights.show_callout(line, callout_seconds)

	if time_left <= 0.0:
		_fail()


# --- phase 1: the sequence -------------------------------------------------

func _on_gen_flipped(gen: ElectroGen) -> void:
	if solved or running:
		return
	if gen.is_main:
		return
	if gen.order_index == next_index:
		next_index += 1
		var remaining: int = _sequence_length() - next_index
		switch_accepted.emit(gen.order_index, remaining)
		print("ElectroPuzzle: switch %d accepted (%d left)" % [gen.order_index, remaining])
		if remaining <= 0:
			_sequence_complete()
	else:
		sequence_wrong.emit()
		print("ElectroPuzzle: wrong order — resetting.")
		_reset_switches()


func _sequence_length() -> int:
	var n := 0
	for g in gens:
		if g and not g.is_main:
			n += 1
	return n


func _reset_switches() -> void:
	next_index = 0
	for g in gens:
		if g:
			g.reset_switch()


func _sequence_complete() -> void:
	Flags.set_flag(switches_done_flag)
	for g in gens:
		if g:
			g.blow()                       # the three pop as the sequence lands
	# Sami's line first (this pauses), THEN the timer starts
	if after_switches_dialog and not Flags.is_set("electro_line_said"):
		Flags.set_flag("electro_line_said")
		DialogManager.start_dialog(after_switches_dialog, sami_name, null)
		await DialogManager.dialog_finished
	start_run()


# --- phase 2: the run ------------------------------------------------------

func start_run() -> void:
	if running or solved:
		return
	running = true
	time_left = run_seconds
	_callout_timer = callout_every
	_callout_i = 0
	if chase_music:
		_music.stream = chase_music
		_music.play()
	if lights and lights.has_method("start_flicker"):
		lights.start_flicker()
	run_started.emit(run_seconds)
	print("ElectroPuzzle: RUN STARTED — %.0f seconds to the main gen." % run_seconds)


func _stop_run() -> void:
	running = false
	_music.stop()
	if lights and lights.has_method("stop_flicker"):
		lights.stop_flicker()


# --- phase 3: the main generator ------------------------------------------

func _on_main_flipped(gen: ElectroGen) -> void:
	if solved:
		return
	if not running:
		print("ElectroPuzzle: the main gen does nothing yet — flip the three switches first.")
		gen.reset_switch()
		return
	if not gen.radio_ok():
		print("ElectroPuzzle: main gen needs the radio tuned to %d Hz." % gen.required_hz)
		gen.reset_switch()
		return
	_win(gen)


func _win(gen: ElectroGen) -> void:
	solved = true
	_stop_run()
	gen.blow()
	Flags.set_flag(solved_flag)
	puzzle_solved.emit()
	print("ELECTRO PUZZLE SOLVED — flag '%s' raised." % solved_flag)


func _fail() -> void:
	_stop_run()
	run_failed.emit()
	print("ElectroPuzzle: TIME UP.")
	match on_fail:
		FailAction.KILL_PLAYER:
			Deaths.kill(fail_death_cause)
		FailAction.RELOAD_CHECKPOINT:
			var n: int = int(Flags.get_flag("prescription_current", -1))
			if n >= 0 and Prescription.get_checkpoint(n) != null:
				Prescription.apply(n)
			else:
				SceneManager.reload_current_scene()
		_:
			_reset_all()


## Put everything back so the player can try again.
func _reset_all() -> void:
	next_index = 0
	Flags.clear_flag(switches_done_flag)
	for g in gens:
		if g:
			g.is_blown = false
			g.reset_switch()
	if main_gen:
		main_gen.is_blown = false
		main_gen.reset_switch()
