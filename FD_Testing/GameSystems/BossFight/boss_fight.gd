class_name BossFight extends Node
## The Yazzed fight, start to finish.
##
##   STAGE 1  the TV is DOWN. He charges dumbly and slams into it.
##            One TV hit -> stage 2.
##   STAGE 2  the TV LIFTS AWAY. Chip his HP with traps and throwables
##            until it reaches `stage3_hp`. Then the TV comes back down.
##   STAGE 3  he's fast, aggressive and BOUNCY, and never aims at the TV.
##            Dodge late so he overshoots into it -> he dies.
##
## Sami dying resets the whole fight (Yazzed back to full).

signal fight_started
signal stage_changed(stage: int)
signal boss_damaged(hp: float, max_hp: float)
signal fight_won
signal fight_reset

@export_group("Pieces")
@export var boss: YazzedBoss
@export var tv: BossTV
## Traps/throwables in the room — they're reset with the fight.
@export var objects: Array[Node] = []
## Optional juice node (screen shake, hit stop, flashes).
@export var juice: Node

@export_group("Start")
## Start when the player walks into this Area2D. Leave empty to call
## start_fight() yourself (from a cutscene or a dialog action).
@export var trigger_area: Area2D
## Dialog played before the fight begins (optional).
@export var intro_dialog: Dialog
@export var boss_name: String = "Yazzed"

@export_group("Stages")
## TESTING: which stage the fight begins at (1, 2 or 3). Set it to 3 to jump
## straight to the bouncy phase instead of playing through. Leave at 1 for
## the real game. Starting at 2 or 3 also sets Yazzed's HP to match.
@export_range(1, 3) var start_stage: int = 1
## HP Yazzed has when you start at stage 2 (defaults to his max).
@export var start_stage2_hp: float = -1.0
## HP at which stage 2 ends and the TV comes back down.
@export var stage3_hp: float = 50.0
## Pause between stages, so transitions breathe.
@export var stage_pause: float = 1.2
## Time the TV stays down in stage 1 before... nothing. It just waits.
@export var tv_lift_delay: float = 1.0

@export_group("Ending")
## The comic that plays when he dies (Nada's panels).
@export var victory_comic: Comic
## Or a single video, if you'd rather.
@export var victory_video: VideoStream
@export var won_flag: String = "yazzed_defeated"

@export_group("UI")
@export var show_health_bar: bool = true
@export var health_bar_name: String = "YAZZED"

var stage: int = 0
var running: bool = false
var won: bool = false

var _layer: CanvasLayer
var _bar: ProgressBar
var _name_label: Label
var _stage_label: Label


func _ready() -> void:
	if boss:
		boss.tv_hit.connect(_on_tv_hit)
		boss.damaged.connect(_on_boss_damaged)
	if tv:
		tv.hit.connect(_on_tv_struck)
	if trigger_area:
		trigger_area.body_entered.connect(_on_trigger)
	_build_ui()
	if Flags.is_set(won_flag):
		won = true
		if boss:
			boss.queue_free()


func _on_trigger(body: Node2D) -> void:
	if body.is_in_group("Player") or body is Player:
		start_fight()


# --- the fight -------------------------------------------------------------

func start_fight() -> void:
	if running or won or boss == null:
		return
	running = true
	if intro_dialog:
		DialogManager.start_dialog(intro_dialog, boss_name, null)
		await DialogManager.dialog_finished
	_set_bar_visible(show_health_bar)
	fight_started.emit()
	# testing shortcut: jump straight into a later stage
	if boss:
		if start_stage == 2:
			boss.hp = start_stage2_hp if start_stage2_hp > 0.0 else boss.max_hp
		elif start_stage == 3:
			boss.hp = minf(boss.hp, stage3_hp)
		_update_bar()
	if start_stage > 1:
		print("BossFight: TESTING — starting at stage %d." % start_stage)
	await _enter_stage(clampi(start_stage, 1, 3))


func _enter_stage(n: int) -> void:
	stage = n
	if boss:
		boss.stage = n
	stage_changed.emit(n)
	_update_stage_label()
	print("BossFight: stage %d" % n)

	match n:
		1:
			if tv:
				await tv.drop()
			await _breathe()
			if boss:
				boss.active = true
		2:
			if boss:
				boss.active = false
			if tv:
				await tv.lift()
			await _breathe()
			if boss:
				boss.active = true
		3:
			if boss:
				boss.active = false
			if juice and juice.has_method("flash"):
				juice.flash()
			if tv:
				await tv.drop()
			await _breathe()
			if boss:
				boss.active = true


func _breathe() -> void:
	await get_tree().create_timer(stage_pause, true, false, false).timeout


func _on_boss_damaged(_amount: float, hp_left: float) -> void:
	boss_damaged.emit(hp_left, boss.max_hp)
	_update_bar()
	if juice and juice.has_method("hit_stop"):
		juice.hit_stop()
	if stage == 2 and hp_left <= stage3_hp:
		await _enter_stage(3)


## Yazzed reports slamming into the TV.
func _on_tv_hit() -> void:
	if tv:
		tv.take_hit()


## The TV reports being struck — this is what moves the fight along.
func _on_tv_struck() -> void:
	if juice and juice.has_method("shake"):
		juice.shake(12.0)
	if stage == 1:
		await _enter_stage(2)
	elif stage == 3:
		_win()


func _win() -> void:
	won = true
	running = false
	if boss:
		boss.kill()
	_set_bar_visible(false)
	Flags.set_flag(won_flag)
	fight_won.emit()
	print("BOSS FIGHT WON — flag '%s' raised." % won_flag)
	await get_tree().create_timer(1.0, true, false, false).timeout
	if victory_comic:
		await Cutscene.play_comic(victory_comic)
	elif victory_video:
		await Cutscene.play_stream(victory_video)


## Sami died — put everything back and start over.
func reset_fight() -> void:
	running = false
	stage = 0
	if boss:
		boss.active = false
		boss.reset()
	if tv:
		tv.reset()
	for o in objects:
		if o and o.has_method("reset"):
			o.reset()
	_update_bar()
	fight_reset.emit()
	print("BossFight: reset.")


# --- UI --------------------------------------------------------------------

func _build_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 50
	add_child(_layer)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	box.position = Vector2(-200, 16)
	box.custom_minimum_size = Vector2(400, 0)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(box)

	_name_label = Label.new()
	_name_label.text = tr(health_bar_name)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", 20)
	box.add_child(_name_label)

	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(400, 14)
	_bar.show_percentage = false
	_bar.max_value = 1.0
	_bar.value = 1.0
	box.add_child(_bar)

	_stage_label = Label.new()
	_stage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stage_label.modulate = Color(1, 1, 1, 0.6)
	box.add_child(_stage_label)

	_set_bar_visible(false)


func _update_bar() -> void:
	if _bar and boss:
		_bar.value = clampf(boss.hp / maxf(1.0, boss.max_hp), 0.0, 1.0)


func _update_stage_label() -> void:
	if _stage_label:
		_stage_label.text = "STAGE %d" % stage


func _set_bar_visible(v: bool) -> void:
	if _layer:
		_layer.visible = v
