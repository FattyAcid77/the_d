class_name CutsceneTrigger extends Area2D
## Plays a cutscene when the player is inside this area. Add an Area2D with
## this script + a CollisionShape2D, place it in the level.

@export_group("What to play")
## A single video - drag your .ogv here.
@export var video: VideoStream
## Or a comic (multi-panel) - drag a Comic .tres here.
@export var comic: Comic

@export_group("When")
## The area does NOTHING until this flag is set.
@export var require_flag: String = ""
## Only ever play once.
@export var play_once: bool = true
## Flag used to remember it played (auto-generated if left empty).
@export var seen_flag: String = ""
## Optional: set this flag after the cutscene ends (e.g.
@export var set_flag_after: String = ""

var _player_in: bool = false
@onready var visual: Node2D = get_node_or_null("Visual")


func _ready() -> void:
	if seen_flag == "":
		seen_flag = "cutscene_seen:" + str(get_path())
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _process(_delta: float) -> void:
	if visual:
		visual.visible = _is_active()
	# checking every frame (not just on entry) means it also fires if the flag turns
	if _player_in and _is_active() and not Cutscene.is_playing:
		_fire()


func _is_active() -> bool:
	if video == null and comic == null:
		return false
	if require_flag != "" and not Flags.is_set(require_flag):
		return false
	if play_once and Flags.is_set(seen_flag):
		return false
	return true


func _fire() -> void:
	Flags.set_flag(seen_flag)
	if comic:
		await Cutscene.play_comic(comic)
	else:
		await Cutscene.play_stream(video)
	if set_flag_after != "":
		Flags.set_flag(set_flag_after)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player") or body is Player:
		_player_in = true


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("Player") or body is Player:
		_player_in = false
