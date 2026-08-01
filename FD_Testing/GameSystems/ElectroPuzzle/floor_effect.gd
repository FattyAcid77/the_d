class_name FloorEffect extends Area2D
## Icy and watery floors for the generator run.
##
## HOW IT WORKS WITHOUT TOUCHING SAMI'S CODE
## His states set `velocity` and he calls move_and_slide() himself. So this
## area doesn't try to change his speed — it runs AFTER him (higher physics
## priority) and pushes him a little extra with move_and_collide():
##   ICE   — keeps a drift that builds up in the direction he's moving and
##           only fades slowly, so he slides past corners.
##   WATER — pushes back against his movement, so he wades.
##   PUSH  — a constant shove (a draught, a current, a vent).
##
## Add a CollisionShape2D and lay it over the floor tiles.

enum Kind { ICE, WATER, PUSH }

@export var kind: Kind = Kind.ICE

@export_group("Ice")
## How fast the slide builds up toward his current movement (lower = more
## slippery, because it takes longer to change direction).
@export var ice_grip: float = 1.6
## How fast the slide dies away when he stops (lower = longer slide).
@export var ice_friction: float = 0.9
## Maximum slide speed.
@export var ice_max: float = 140.0

@export_group("Water")
## How hard the water pulls back (fraction of his own speed).
@export var water_drag: float = 0.45

@export_group("Push")
@export var push_direction := Vector2(1, 0)
@export var push_strength: float = 90.0

@export_group("Extra")
## Damage per second while standing in it (0 = harmless). Uses the Wounds
## component, so it can also CUT.
@export var damage_per_second: float = 0.0
@export var damage_cause: String = "unknown"
@export var damage_opens_wound: bool = false
## Only active once this flag is set. Empty = always.
@export var active_flag: String = ""
## Harmless once this flag is set.
@export var disabled_flag: String = ""

var _player: CharacterBody2D = null
var _drift := Vector2.ZERO
var _damage_acc: float = 0.0


func _ready() -> void:
	# run after the player has already moved this frame
	process_physics_priority = 100
	body_entered.connect(_on_entered)
	body_exited.connect(_on_exited)


func is_active() -> bool:
	if disabled_flag != "" and Flags.is_set(disabled_flag):
		return false
	if active_flag != "" and not Flags.is_set(active_flag):
		return false
	return true


func _physics_process(delta: float) -> void:
	if _player == null or not is_active():
		_drift = _drift.lerp(Vector2.ZERO, delta * 4.0)
		return

	match kind:
		Kind.ICE:
			# build the slide toward where he's actually going
			var target: Vector2 = _player.velocity
			if target.length() > 1.0:
				_drift = _drift.lerp(target.limit_length(ice_max), delta * ice_grip)
			else:
				_drift = _drift.lerp(Vector2.ZERO, delta * ice_friction)
			if _drift.length() > 1.0:
				_player.move_and_collide(_drift * delta)
		Kind.WATER:
			if _player.velocity.length() > 1.0:
				_player.move_and_collide(-_player.velocity * water_drag * delta)
		Kind.PUSH:
			_player.move_and_collide(push_direction.normalized() * push_strength * delta)

	if damage_per_second > 0.0:
		_damage_acc += damage_per_second * delta
		if _damage_acc >= 1.0:
			var whole := floori(_damage_acc)
			_damage_acc -= whole
			var w := _player.get_node_or_null("Wounds")
			if w and w.has_method("take_damage"):
				w.take_damage(float(whole), damage_cause, damage_opens_wound)


func _on_entered(body: Node2D) -> void:
	if (body.is_in_group("Player") or body is Player) and body is CharacterBody2D:
		_player = body
		_drift = Vector2.ZERO
		_damage_acc = 0.0


func _on_exited(body: Node2D) -> void:
	if body == _player:
		_player = null
