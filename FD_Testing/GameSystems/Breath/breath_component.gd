class_name BreathComponent extends Node2D
## Sami's hold-breath mechanic. Add as a child of the player NAMED "Breath".
##
## HOW IT WORKS
##   - Hold the `hold_action` key to hold your breath.
##   - It lasts `stage_seconds` x `stage_count` (4s x 4 = 16s by default),
##     split into 4 STAGES. Each stage can play its own animation and, if
##     Sami is cut, spills a different BLOOD TYPE.
##   - While holding, he CANNOT die (toxic air can't reach him).
##   - When the 16 seconds run out he gasps: breath_failed fires and the
##     toxic area (or whatever) is free to kill him.
##
## SIGNALS let the rest of the game react without touching this script.

signal breath_started
signal stage_changed(stage: int)          ## 0,1,2,3
signal breath_released(total_held: float)
signal breath_failed                      ## ran out of air
signal blood_spilled(type: BloodType, world_pos: Vector2)

@export var hold_action: String = "hold_breath"

@export_group("Breath")
@export var stage_seconds: float = 4.0
@export var stage_count: int = 4
## Air is a BUDGET, not a reset button: letting go does NOT give the 16
## seconds back instantly. This is how fast air comes back while breathing
## normally (1.0 = one second of air per second of breathing).
@export var recover_rate: float = 1.0
## He can't start holding again until at least this many seconds of air
## are available (stops "tap the key" from dodging the limit).
@export var min_air_to_start: float = 1.0

@export_group("Running out")
## Running out of air KILLS him (that's the whole tension).
@export var die_on_fail: bool = true
## Which DeathCause is blamed. Make one with this id in Death/Causes/.
@export var fail_cause: String = "unknown"

@export_group("Bleeding")
## Where blood lands, measured from Sami's ORIGIN. His sprite is centred on
## his body, so blood needs pushing DOWN to his feet. Raise Y until it sits
## under his shoes (his collision box is ~75 tall, so ~30 is a good start).
@export var feet_offset := Vector2(0, 30)
## Is Sami cut right now? Set from your damage code: $Breath.is_bleeding = true
@export var is_bleeding: bool = false
## One BloodType per stage, in order. Stage 0 bleeds types[0], etc.
@export var stage_blood: Array[BloodType] = []
## Also spill the moment a stage BEGINS (otherwise only at stage end).
@export var spill_on_stage_start: bool = true

@export_group("Look")
## Animation played per stage, e.g. ["Hold_1","Hold_2","Hold_3","Hold_4"].
## Missing animations are skipped safely — a tint is used instead.
@export var stage_animations: Array[String] = []
## Fallback tint per stage when there's no animation yet.
@export var stage_tints: Array[Color] = [
	Color(1, 1, 1), Color(0.92, 0.95, 1.0), Color(0.82, 0.9, 1.0), Color(0.7, 0.85, 1.0)]

var is_holding: bool = false
## Seconds of air spent. 0 = lungs full, stage_seconds*stage_count = empty.
var air_used: float = 0.0
var stage: int = -1

var _player: Node2D
var _anim: AnimatedSprite2D
var _base_modulate := Color.WHITE
var _spilled_stages := {}
var _warned_empty := false


func _ready() -> void:
	_player = get_parent() as Node2D
	# Children are _ready() BEFORE their parent, so the player's @onready
	# vars (like `anim`) don't exist yet — wait one frame before binding.
	await get_tree().process_frame
	_bind_anim()


func _bind_anim() -> bool:
	if _anim != null and is_instance_valid(_anim):
		return true
	if _player and "anim" in _player:
		var a = _player.anim
		if a is AnimatedSprite2D:
			_anim = a
			_base_modulate = _anim.modulate
			return true
	return false


func _process(delta: float) -> void:
	if Deaths.is_dead or DialogManager.is_active:
		if is_holding:
			_release()
		return

	var total: float = stage_seconds * stage_count
	var wants: bool = InputMap.has_action(hold_action) and Input.is_action_pressed(hold_action)

	if wants and not is_holding:
		if air_left() >= min_air_to_start:
			_start()
	elif is_holding and not wants:
		_release()

	if is_holding:
		air_used += delta
		_update_stage(true)
		if air_used >= total:
			_fail()
	else:
		# breathing: air comes back gradually, it is NOT free — and he walks
		# BACK DOWN through the stages as his lungs refill (4 -> 3 -> 2 -> 1).
		if air_used > 0.0:
			air_used = maxf(0.0, air_used - recover_rate * delta)
			_update_stage(false)


## Works out which stage the current air level means, and applies the look.
## `spilling` is only true while actually holding — recovering never bleeds.
func _update_stage(spilling: bool) -> void:
	var new_stage: int = -1
	if air_used > 0.0:
		new_stage = mini(int(air_used / stage_seconds), stage_count - 1)
	if new_stage == stage:
		return
	var going_up: bool = new_stage > stage
	stage = new_stage
	if stage < 0:
		_restore_look()          # lungs full again: back to normal
		_spilled_stages.clear()  # a fresh hold can bleed all stages again
	else:
		_apply_stage_look(stage)
	stage_changed.emit(stage)
	if spilling and going_up and spill_on_stage_start:
		_try_spill(stage)


## True while he's safe from bad air.
func is_protected() -> bool:
	return is_holding


## TESTING: drops one stage's blood right now, ignoring everything else.
## Call from the Remote tab or a button: $Breath.test_spill(0)
func test_spill(s: int = 0) -> void:
	if s < 0 or s >= stage_blood.size() or stage_blood[s] == null:
		push_warning("Breath.test_spill: no BloodType in slot %d." % s)
		return
	var pos: Vector2 = (_player.global_position if _player else global_position) + feet_offset
	BloodWorld.spill(stage_blood[s], pos)


## Seconds of air still available.
func air_left() -> float:
	return maxf(0.0, stage_seconds * stage_count - air_used)


## 0.0 (empty) .. 1.0 (full) — handy for a lungs meter in the UI.
func air_fraction() -> float:
	var total: float = stage_seconds * stage_count
	return 0.0 if total <= 0.0 else air_left() / total


func _start() -> void:
	is_holding = true
	breath_started.emit()
	# picks up from however much air is left (no free reset)
	var s: int = mini(int(air_used / stage_seconds), stage_count - 1)
	if s != stage:
		stage = s
		_apply_stage_look(stage)
		stage_changed.emit(stage)
	if spill_on_stage_start:
		_try_spill(stage)


func _release() -> void:
	if not is_holding:
		return
	if not spill_on_stage_start:
		_try_spill(stage)          # spill at the end of the stage instead
	is_holding = false
	breath_released.emit(air_used)
	# NOTE: the stage is NOT cleared here — recovery walks it back down
	# one stage at a time, and _update_stage() restores the look at 0.


## Out of air. This is the end of the line — he suffocates.
func _fail() -> void:
	var was := stage
	_release()
	air_used = stage_seconds * stage_count      # empty until he breathes
	breath_failed.emit()
	if was >= 0:
		_try_spill(was)
	if die_on_fail and not Deaths.is_dead:
		Deaths.kill(fail_cause)


func _try_spill(s: int) -> void:
	if not is_bleeding:
		return                       # he isn't cut — nothing to spill
	if _spilled_stages.has(s):
		return                       # this stage already bled once
	if s < 0:
		return
	if s >= stage_blood.size():
		if not _warned_empty:
			_warned_empty = true
			push_warning("Breath: no BloodType for stage %d. Set `Stage Blood` "
					% (s + 1) + "to size %d and drop Breath/Types/blood_stage1..4.tres in."
					% stage_count)
		return
	var t: BloodType = stage_blood[s]
	if t == null:
		push_warning("Breath: `Stage Blood` slot %d is empty." % s)
		return
	_spilled_stages[s] = true
	var pos: Vector2 = (_player.global_position if _player else global_position) + feet_offset
	if t.first_spill_flag != "":
		Flags.set_flag(t.first_spill_flag)
	blood_spilled.emit(t, pos)
	BloodWorld.spill(t, pos)          # stains the floor / feeds the puzzle grid


func _apply_stage_look(s: int) -> void:
	if not _bind_anim():
		return
	if s < stage_animations.size():
		var anim_name: String = stage_animations[s]
		if anim_name != "" and _anim.sprite_frames and _anim.sprite_frames.has_animation(anim_name):
			_anim.play(anim_name)
			return
	if s < stage_tints.size():
		_anim.modulate = stage_tints[s]


func _restore_look() -> void:
	if _bind_anim():
		_anim.modulate = _base_modulate
