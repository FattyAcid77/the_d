class_name BossTV extends StaticBody2D
## The TV Yazzed slams into. It's the bookend of the fight: hit 1 ends
## stage 1, hit 2 (in stage 3) kills him.
##
## It DROPS from the ceiling when a stage needs it, and lifts away when it
## doesn't. Put it in the group "boss_tv" (done in _ready) so Yazzed's
## stage-3 aiming knows never to bounce toward it.

signal dropped
signal hit
signal destroyed

@export_group("Drop animation")
## How far above its resting place it starts.
@export var drop_height: float = 420.0
@export var drop_seconds: float = 0.9
## A little bounce when it lands.
@export var land_bounce_pixels: float = 18.0
@export var lift_seconds: float = 0.7
## Shake the screen when it lands? (needs a BossJuice node in the scene)
@export var shake_on_land: float = 8.0

@export_group("Hits")
## How many hits it can take before it's wrecked (2 = the whole fight).
@export var max_hits: int = 2

@export_group("Look")
@export var sprite: AnimatedSprite2D
@export var anim_idle: String = "idle"
@export var anim_hit: String = "hit"
@export var anim_broken: String = "broken"
## Sparks/pieces spawned on a hit (optional).
@export var hit_particles: PackedScene

var hits_taken: int = 0
var is_down: bool = false          ## in position and hittable

var _rest_position := Vector2.ZERO
var _busy := false
@onready var collision: CollisionShape2D = get_node_or_null("CollisionShape2D")


func _ready() -> void:
	add_to_group("boss_tv")
	_rest_position = position
	# start hidden above the room
	position = _rest_position - Vector2(0, drop_height)
	visible = false
	_set_solid(false)
	_play(anim_idle)


## Bring it down. Await this if you want to wait for the landing.
func drop() -> void:
	if is_down or _busy:
		return
	_busy = true
	visible = true
	position = _rest_position - Vector2(0, drop_height)
	var tw := create_tween()
	tw.tween_property(self, "position", _rest_position, drop_seconds) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	# a small settle bounce
	tw.tween_property(self, "position", _rest_position - Vector2(0, land_bounce_pixels), 0.12) \
		.set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "position", _rest_position, 0.14) \
		.set_ease(Tween.EASE_IN)
	await tw.finished
	is_down = true
	_busy = false
	_set_solid(true)
	dropped.emit()
	_shake()


## Take it away (between stages).
func lift() -> void:
	if _busy:
		return
	_busy = true
	is_down = false
	_set_solid(false)
	var tw := create_tween()
	tw.tween_property(self, "position", _rest_position - Vector2(0, drop_height), lift_seconds) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	await tw.finished
	visible = false
	_busy = false


## Yazzed slammed into it.
func take_hit() -> void:
	if not is_down:
		return
	hits_taken += 1
	hit.emit()
	_play(anim_hit)
	_shake()
	if hit_particles:
		var p := hit_particles.instantiate()
		get_parent().add_child(p)
		if p is Node2D:
			p.global_position = global_position
	# a hard recoil
	var tw := create_tween()
	tw.tween_property(self, "position", _rest_position + Vector2(0, -10), 0.06)
	tw.tween_property(self, "position", _rest_position, 0.12)
	if hits_taken >= max_hits:
		_play(anim_broken)
		destroyed.emit()


func reset() -> void:
	hits_taken = 0
	is_down = false
	_busy = false
	position = _rest_position - Vector2(0, drop_height)
	visible = false
	_set_solid(false)
	_play(anim_idle)


func _set_solid(v: bool) -> void:
	if collision:
		collision.set_deferred("disabled", not v)


func _shake() -> void:
	if shake_on_land <= 0.0:
		return
	for j in get_tree().get_nodes_in_group("boss_juice"):
		if j.has_method("shake"):
			j.shake(shake_on_land)


func _play(anim_name: String) -> void:
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation(anim_name):
		if sprite.animation != anim_name:
			sprite.play(anim_name)
