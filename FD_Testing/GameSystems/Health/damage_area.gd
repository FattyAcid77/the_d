class_name DamageArea extends Area2D
## A hurty thing: broken glass, a blade, a hot pipe, a trap.
## Add a CollisionShape2D and drop it in the level.
##
## `opens_wound` is the important one for your bleeding mechanic — it's what
## turns a hazard into a CUT, which makes Sami bleed, which feeds the breath
## stages and the blood puzzle.

## How much health it takes. 0 = it only cuts, no damage.
@export var damage: float = 1.0

## Does it CUT him (start bleeding)?
@export var opens_wound: bool = true

## Which DeathCause is blamed if this kills him.
@export var cause_id: String = "bleeding"

@export_group("Behaviour")
## ON = hurts once on entry. OFF = keeps hurting while he stands in it.
@export var once_per_entry: bool = true
## For continuous hazards: seconds between hits.
@export var repeat_seconds: float = 1.0
## Only dangerous once this flag is set. Empty = always.
@export var active_flag: String = ""
## Harmless once this flag is set (the glass was swept up).
@export var disabled_flag: String = ""
## Disappear after hurting him once (a single shard).
@export var one_shot: bool = false

signal hurt_player

var _player: Node2D = null
var _timer: float = 0.0


func _ready() -> void:
	body_entered.connect(_on_entered)
	body_exited.connect(_on_exited)


func is_active() -> bool:
	if disabled_flag != "" and Flags.is_set(disabled_flag):
		return false
	if active_flag != "" and not Flags.is_set(active_flag):
		return false
	return true


func _process(delta: float) -> void:
	if once_per_entry or _player == null or not is_active():
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer = repeat_seconds
		_hit()


func _hit() -> void:
	if _player == null or Deaths.is_dead:
		return
	var w := _player.get_node_or_null("Wounds")
	if w == null or not w.has_method("take_damage"):
		push_warning("DamageArea: the player has no 'Wounds' child (WoundComponent).")
		return
	w.take_damage(damage, cause_id, opens_wound)
	hurt_player.emit()
	if one_shot:
		queue_free()


func _on_entered(body: Node2D) -> void:
	if not (body.is_in_group("Player") or body is Player):
		return
	_player = body
	_timer = repeat_seconds
	if is_active():
		_hit()


func _on_exited(body: Node2D) -> void:
	if body == _player:
		_player = null
