class_name ToxicArea extends Area2D
## Air that kills unless you hold your breath. Add a CollisionShape2D and
## place it over the bad room.
##
## While the player is inside WITHOUT holding their breath, a countdown runs
## (`grace_seconds`) and then they die. Holding their breath pauses it —
## and because breath only lasts 16 seconds, big toxic rooms become a real
## crossing problem.

signal player_entered
signal player_exited
signal warning(time_left: float)     ## fires each frame while the timer runs

## Which DeathCause is used when the air gets them.
@export var death_cause: String = "unknown"

## How long they survive in here without holding their breath.
@export var grace_seconds: float = 2.0

## Does the timer reset when they leave, or stay where it was?
@export var reset_on_exit: bool = true

## Optional: only dangerous once this flag is set (a gas leak that starts
## later in the story). Empty = always dangerous.
@export var active_flag: String = ""

## Optional: harmless once this flag is set (the vents got fixed).
@export var disabled_flag: String = ""

var _player: Node2D = null
var _timer: float = 0.0


func _ready() -> void:
	body_entered.connect(_on_entered)
	body_exited.connect(_on_exited)
	_timer = grace_seconds


func _process(delta: float) -> void:
	if _player == null or not is_active() or Deaths.is_dead:
		return
	if _is_protected():
		return                       # holding their breath: safe
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


func _on_exited(body: Node2D) -> void:
	if body == _player:
		_player = null
		if reset_on_exit:
			_timer = grace_seconds
		player_exited.emit()
