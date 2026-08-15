@tool
class_name YazzedBoss extends CharacterBody2D
## Yazzed. He charges at Sami; what happens when he MISSES is what changes
## between stages.
##
##   STAGE 1  readable wind-up, and he's dumb — he overshoots into the TV.
##   STAGE 2  same charging, but the TV is gone. Objects chip his HP.
##   STAGE 3  fast, aggressive, and BOUNCY. First charge (and the bounce
##            right after) aim at Sami; sometimes he charges a WALL on
##            purpose to come back at Sami from a strange angle. Later
##            bounces are random — but NEVER at the TV. The player has to
##            dodge late so he overshoots into it.
##
## The BossFight node drives the stages; this script only does the moving.

signal charge_started(target: Vector2)
signal charge_ended
signal wall_hit(normal: Vector2)
signal tv_hit
signal player_hit
signal stunned_started(seconds: float)
signal damaged(amount: float, hp_left: float)
signal died

## NOTE: named BossState, not State — the player's state.gd already
## declares a global class called State and the two would collide.
enum BossState { IDLE, TELEGRAPH, CHARGING, STUNNED, HURT, DEAD }

@export_group("Health")
@export var max_hp: float = 100.0
## Stage 2 ends when his HP drops to this (the TV comes back down).
@export var stage3_hp_threshold: float = 50.0

@export_group("Timing — stage 1 & 2 (readable)")
## How long he winds up before launching.
@export var telegraph_seconds: float = 1.0
## How long he waits between attacks.
@export var rest_seconds: float = 1.4
@export var charge_speed: float = 420.0
## How long he's stunned after hitting a wall (his opening).
@export var stun_seconds: float = 1.6

@export_group("Timing — stage 3 (fast & aggressive)")
@export var telegraph_seconds_s3: float = 0.5
@export var rest_seconds_s3: float = 0.8
@export var charge_speed_s3: float = 620.0
## Max wall bounces before the charge gives up.
@export var max_bounces: int = 3
## Chance he aims at a WALL instead of Sami, to bounce in from an angle.
@export_range(0.0, 1.0) var wall_feint_chance: float = 0.35
## Speed kept after each bounce (1.0 = no loss).
@export_range(0.1, 1.0) var bounce_speed_keep: float = 0.95

@export_group("Contact")
## Damage dealt to Sami on contact.
@export var contact_damage: float = 1.0
@export var contact_cuts: bool = true
@export var contact_cause: String = "bleeding"
## Seconds before he can hurt Sami again.
@export var contact_cooldown: float = 0.9

@export_group("Look")
@export var sprite: AnimatedSprite2D
@export var anim_idle: String = "idle"
@export var anim_telegraph: String = "telegraph"
@export var anim_charge: String = "charge"
@export var anim_stunned: String = "stunned"
@export var anim_hurt: String = "hurt"
@export var anim_dead: String = "dead"
## Squash while winding up, stretch while charging (pure juice, no art needed).
@export var use_squash_stretch: bool = true
@export var telegraph_squash := Vector2(1.25, 0.78)
@export var charge_stretch := Vector2(1.18, 0.86)
@export var shake_pixels: float = 3.0

var hp: float
var stage: int = 1
@warning_ignore("shadowed_global_identifier") # "state" is also a global class in state.gd
var state: BossState = BossState.IDLE
var active: bool = false          ## the BossFight node turns this on

var _timer: float = 0.0
var _dir := Vector2.RIGHT
var _speed: float = 0.0
var _bounces: int = 0
var _contact_cd: float = 0.0
var _player: Node2D
var _base_scale := Vector2.ONE
var _base_sprite_pos := Vector2.ZERO
var _aiming_at_wall := false


func _ready() -> void:
	hp = max_hp
	if sprite:
		_base_scale = sprite.scale
		_base_sprite_pos = sprite.position
	if Engine.is_editor_hint():
		return
	_player = get_tree().get_first_node_in_group("Player")


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or not active or state == BossState.DEAD:
		return
	if _contact_cd > 0.0:
		_contact_cd -= delta

	match state:
		BossState.IDLE:
			_tick_idle(delta)
		BossState.TELEGRAPH:
			_tick_telegraph(delta)
		BossState.CHARGING:
			_tick_charging(delta)
		BossState.STUNNED, BossState.HURT:
			_tick_stunned(delta)


# --- states ----------------------------------------------------------------

func _tick_idle(delta: float) -> void:
	velocity = Vector2.ZERO
	move_and_slide()
	_timer -= delta
	if _timer <= 0.0:
		_begin_telegraph()


func _begin_telegraph() -> void:
	state = BossState.TELEGRAPH
	_timer = telegraph_seconds_s3 if stage >= 3 else telegraph_seconds
	_aiming_at_wall = false
	_dir = _pick_direction()
	_play(anim_telegraph)
	if use_squash_stretch and sprite:
		sprite.scale = _base_scale * telegraph_squash


func _tick_telegraph(delta: float) -> void:
	velocity = Vector2.ZERO
	move_and_slide()
	# rattle in place so the wind-up reads even without art
	if sprite and shake_pixels > 0.0:
		sprite.position = _base_sprite_pos + Vector2(
			randf_range(-shake_pixels, shake_pixels),
			randf_range(-shake_pixels, shake_pixels))
	_timer -= delta
	if _timer <= 0.0:
		_launch()


func _launch() -> void:
	state = BossState.CHARGING
	_bounces = 0
	_speed = charge_speed_s3 if stage >= 3 else charge_speed
	if sprite:
		sprite.position = _base_sprite_pos
		if use_squash_stretch:
			sprite.scale = _base_scale * charge_stretch
	_play(anim_charge)
	charge_started.emit(global_position + _dir * 400.0)


func _tick_charging(delta: float) -> void:
	velocity = _dir * _speed
	var col := move_and_collide(velocity * delta)
	if col:
		_on_collision(col)
		return
	_touch_player()


func _tick_stunned(delta: float) -> void:
	velocity = Vector2.ZERO
	move_and_slide()
	_timer -= delta
	if _timer <= 0.0:
		_end_charge()


# --- collisions ------------------------------------------------------------

func _on_collision(col: KinematicCollision2D) -> void:
	var other := col.get_collider()

	# the TV: always ends the charge, always counts
	if other and other.is_in_group("boss_tv"):
		tv_hit.emit()
		_stun(stun_seconds)
		return

	# Sami
	if other and (other.is_in_group("Player") or other is Player):
		_hurt_player()
		if stage < 3:
			_stun(stun_seconds * 0.5)
		else:
			_bounce(col.get_normal())
		return

	# a wall or an object
	wall_hit.emit(col.get_normal())
	if stage >= 3 and _bounces < max_bounces:
		_bounce(col.get_normal())
	else:
		_stun(stun_seconds)


func _bounce(normal: Vector2) -> void:
	_bounces += 1
	var new_dir := _dir.bounce(normal).normalized()
	# the FIRST bounce hunts Sami; after that it's random, never the TV
	if _bounces == 1 and _player:
		new_dir = (_player.global_position - global_position).normalized()
	else:
		new_dir = _random_safe_direction(new_dir)
	_dir = new_dir
	_speed *= bounce_speed_keep
	if _bounces > max_bounces:
		_stun(stun_seconds)


func _stun(seconds: float) -> void:
	state = BossState.STUNNED
	_timer = seconds
	velocity = Vector2.ZERO
	if sprite:
		sprite.scale = _base_scale
		sprite.position = _base_sprite_pos
	_play(anim_stunned)
	stunned_started.emit(seconds)


func _end_charge() -> void:
	state = BossState.IDLE
	_timer = rest_seconds_s3 if stage >= 3 else rest_seconds
	if sprite:
		sprite.scale = _base_scale
	_play(anim_idle)
	charge_ended.emit()


# --- aiming ----------------------------------------------------------------

func _pick_direction() -> Vector2:
	if _player == null:
		_player = get_tree().get_first_node_in_group("Player")
	var to_player := Vector2.RIGHT
	if _player:
		to_player = (_player.global_position - global_position).normalized()
	# stage 3: sometimes he charges a wall on purpose, to come back at Sami
	# from an angle they aren't watching
	if stage >= 3 and randf() < wall_feint_chance:
		_aiming_at_wall = true
		return to_player.rotated(randf_range(PI * 0.35, PI * 0.75)).normalized()
	return to_player


## A random direction that does NOT point at the TV (stage 3 rule).
func _random_safe_direction(fallback: Vector2) -> Vector2:
	var tvs := get_tree().get_nodes_in_group("boss_tv")
	for i in 12:
		var d := Vector2.from_angle(randf() * TAU)
		var ok := true
		for tv in tvs:
			if tv is Node2D:
				var to_tv: Vector2 = (tv.global_position - global_position).normalized()
				if d.dot(to_tv) > 0.65:     # roughly pointing at the TV
					ok = false
					break
		if ok:
			return d
	return fallback


# --- damage ----------------------------------------------------------------

func take_damage(amount: float) -> void:
	if state == BossState.DEAD or not active:
		return
	hp = maxf(0.0, hp - amount)
	damaged.emit(amount, hp)
	if hp <= 0.0:
		return                      # the BossFight node decides how he dies
	_play(anim_hurt)


func kill() -> void:
	state = BossState.DEAD
	active = false
	velocity = Vector2.ZERO
	if sprite:
		sprite.scale = _base_scale
	_play(anim_dead)
	died.emit()


func reset() -> void:
	hp = max_hp
	stage = 1
	state = BossState.IDLE
	_timer = rest_seconds
	_bounces = 0
	if sprite:
		sprite.scale = _base_scale
		sprite.position = _base_sprite_pos
	_play(anim_idle)


func _touch_player() -> void:
	if _player == null or _contact_cd > 0.0:
		return
	if global_position.distance_to(_player.global_position) < 34.0:
		_hurt_player()


func _hurt_player() -> void:
	if _contact_cd > 0.0:
		return
	_contact_cd = contact_cooldown
	player_hit.emit()
	if _player:
		var w := _player.get_node_or_null("Wounds")
		if w and w.has_method("take_damage"):
			w.take_damage(contact_damage, contact_cause, contact_cuts)


func _play(anim_name: String) -> void:
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation(anim_name):
		if sprite.animation != anim_name:
			sprite.play(anim_name)
