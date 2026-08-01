class_name BossObject extends Area2D
## The little things around Yazzed's room. Three flavours, set by `kind`:
##
##   TRAP       sits there. If YAZZED charges through it, he takes damage.
##   THROWABLE  Sami can pick it up and throw it at Yazzed.
##   HAZARD     hurts SAMI. Yazzed can shove it at him.
##
## An object can also DEBUFF Sami (slow him, blur him — whatever you hook
## onto the `debuffed_player` signal).

signal hit_boss(damage: float)
signal hit_player
signal debuffed_player(seconds: float)
signal picked_up
signal thrown(direction: Vector2)
signal used_up

enum Kind { TRAP, THROWABLE, HAZARD }

@export var kind: Kind = Kind.TRAP

@export_group("Damage")
## Damage dealt to YAZZED (traps and throwables).
@export var boss_damage: float = 10.0
## Damage dealt to SAMI (hazards, or a thrown object that misses).
@export var player_damage: float = 0.0
@export var player_cuts: bool = false
@export var damage_cause: String = "bleeding"

@export_group("Debuff on Sami")
## How long the debuff lasts. 0 = no debuff.
@export var debuff_seconds: float = 0.0
## Free text so you can tell debuffs apart in one handler ("slow", "blind").
@export var debuff_name: String = "slow"

@export_group("Throwing")
@export var throw_speed: float = 520.0
## How far it flies before dropping.
@export var throw_range: float = 420.0
## Can Yazzed shove this one at Sami?
@export var boss_can_push: bool = true
@export var push_speed: float = 380.0

@export_group("Life")
## Gone after it lands a hit?
@export var one_use: bool = true
## Comes back after this many seconds (0 = stays gone).
@export var respawn_seconds: float = 0.0

@export_group("Look")
@export var sprite: Node2D
@export var spin_while_flying: float = 12.0
## Little hop when it spawns/respawns.
@export var spawn_hop_pixels: float = 14.0

var flying: bool = false
var held: bool = false

var _vel := Vector2.ZERO
var _travelled: float = 0.0
var _home := Vector2.ZERO
var _player_in := false
var _player: Node2D


func _ready() -> void:
	add_to_group("boss_object")
	_home = global_position
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	area_entered.connect(_on_area_entered)
	_hop()


func _physics_process(delta: float) -> void:
	if held and _player:
		global_position = _player.global_position + Vector2(0, -24)
		return
	if not flying:
		return
	global_position += _vel * delta
	_travelled += _vel.length() * delta
	if sprite and spin_while_flying != 0.0:
		sprite.rotation += spin_while_flying * delta
	if _travelled >= throw_range:
		_land()


# --- Sami picking it up / throwing -----------------------------------------

func _process(_delta: float) -> void:
	if kind != Kind.THROWABLE or flying:
		return
	if held:
		if Input.is_action_just_pressed("interact"):
			_throw()
	elif _player_in and Input.is_action_just_pressed("interact"):
		_pick_up()


func _pick_up() -> void:
	held = true
	picked_up.emit()


func _throw() -> void:
	held = false
	flying = true
	_travelled = 0.0
	var dir := Vector2.RIGHT
	if _player and "cardinal_direction" in _player:
		dir = _player.cardinal_direction
	elif _player:
		dir = (get_global_mouse_position() - _player.global_position).normalized()
	_vel = dir.normalized() * throw_speed
	thrown.emit(dir)


## Yazzed shoves it (call from his charge, or connect his charge_started).
func push_from(from: Vector2) -> void:
	if not boss_can_push or flying or held:
		return
	flying = true
	_travelled = 0.0
	_vel = (global_position - from).normalized() * push_speed


func _land() -> void:
	flying = false
	_vel = Vector2.ZERO
	if sprite:
		sprite.rotation = 0.0


# --- contact ---------------------------------------------------------------

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player") or body is Player:
		_player = body
		_player_in = true
		if kind == Kind.HAZARD or (flying and player_damage > 0.0):
			_hurt_player(body)
		return
	if body is YazzedBoss:
		_hit_boss(body)


func _on_area_entered(area: Area2D) -> void:
	if area.get_parent() is YazzedBoss:
		_hit_boss(area.get_parent())


func _on_body_exited(body: Node2D) -> void:
	if body == _player:
		_player_in = false


func _hit_boss(boss) -> void:
	if kind == Kind.HAZARD or boss_damage <= 0.0:
		return
	boss.take_damage(boss_damage)
	hit_boss.emit(boss_damage)
	_consume()


func _hurt_player(body: Node2D) -> void:
	hit_player.emit()
	if player_damage > 0.0:
		var w := body.get_node_or_null("Wounds")
		if w and w.has_method("take_damage"):
			w.take_damage(player_damage, damage_cause, player_cuts)
	if debuff_seconds > 0.0:
		debuffed_player.emit(debuff_seconds)
	_consume()


func _consume() -> void:
	if not one_use:
		return
	used_up.emit()
	visible = false
	set_deferred("monitoring", false)
	flying = false
	held = false
	if respawn_seconds > 0.0:
		await get_tree().create_timer(respawn_seconds).timeout
		respawn()
	

func respawn() -> void:
	global_position = _home
	visible = true
	set_deferred("monitoring", true)
	flying = false
	held = false
	_travelled = 0.0
	if sprite:
		sprite.rotation = 0.0
	_hop()


func reset() -> void:
	respawn()


func _hop() -> void:
	if sprite == null or spawn_hop_pixels <= 0.0:
		return
	var base := sprite.position
	sprite.position = base - Vector2(0, spawn_hop_pixels)
	var tw := create_tween()
	tw.tween_property(sprite, "position", base, 0.25).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
