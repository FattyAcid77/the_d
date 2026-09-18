class_name ToxicArea extends Area2D
## Air that kills unless you hold your breath. Add a CollisionShape2D and
## place it over the bad room.

signal player_entered
signal player_exited
signal warning(time_left: float)  # fires each frame while the timer runs

## Which DeathCause is used when the air gets them.
@export var death_cause: String = "unknown"

## How long they survive in here without holding their breath.
@export var grace_seconds: float = 2.0

## Does the timer reset when they leave, or stay where it was?
@export var reset_on_exit: bool = true

## Optional: only dangerous once this flag is set (a gas leak that starts later in the story).
@export var active_flag: String = ""

## Optional: harmless once this flag is set (the vents got fixed).
@export var disabled_flag: String = ""

@export_group("Sound")
## Loops the whole time Sami is inside - the gas hiss, the hum.
@export var inside_sound_id: String = ""
## Seconds to fade the loop in / out.
@export var inside_sound_fade: float = 0.5

var _player: Node2D = null
var _timer: float = 0.0


func _ready() -> void:
	SoundLink.attach(self)  # every signal here becomes a SoundMap moment
	body_entered.connect(_on_entered)
	body_exited.connect(_on_exited)
	_timer = grace_seconds


func _process(delta: float) -> void:
	if _player == null or not is_active() or Deaths.is_dead:
		return
	if _is_protected():
		return  # holding their breath: safe
	_timer -= delta
	warning.emit(maxf(0.0, _timer))
	if _timer <= 0.0:
		_timer = grace_seconds
		Deaths.kill(death_cause)


func is_active() -> bool:
	if disabled_flag != "" and Flags.is_set(disabled_flag):
		return false
	if active_flag != "" and not Flags.is_set(active_flag):
		return false
	return true


func time_left() -> float:
	return maxf(0.0, _timer)


func _is_protected() -> bool:
	if _player == null:
		return false
	var b := _player.get_node_or_null("Breath")
	return b != null and b.has_method("is_protected") and b.is_protected()


func _on_entered(body: Node2D) -> void:
	if body.is_in_group("Player") or body is Player:
		_player = body
		player_entered.emit()
		if inside_sound_id != "":
			var snd := get_node_or_null("/root/Sound")
			if snd and snd.has_method("start_loop"):
				snd.start_loop("toxic:" + str(get_instance_id()), inside_sound_id, inside_sound_fade)


func _on_exited(body: Node2D) -> void:
	if body == _player:
		_player = null
		if reset_on_exit:
			_timer = grace_seconds
		player_exited.emit()
		_stop_hum()


func _stop_hum() -> void:
	var snd := get_node_or_null("/root/Sound")
	if snd and snd.has_method("stop_loop"):
		snd.stop_loop("toxic:" + str(get_instance_id()), inside_sound_fade)


func _exit_tree() -> void:
	_stop_hum()
