class_name Sami20 extends CharacterBody2D

## Player controller — a clean, state-machine driven rewrite of Sami.
##
## All the per-mode behaviour (idle / walk / drag / frozen) lives in the
## StateMachine child and its State nodes. This script owns only:
##   - shared DATA (tuning, the direction we're facing, the dragged object)
##   - reusable HELPERS the states call into (input, grabbing, animation)
##
## The old `can_move` / `input_enabled` / enable() / disable() contract is
## kept intact, so dialog, elevators, the beam puzzle and level transitions
## keep working unchanged — flipping those flags simply sends us to Interact.

# --- Movement tuning ---
@export var speed: float = 100.0
@export var drag_speed: float = 60.0   # User-tuned. Don't change without asking.

# --- External control flags (other systems toggle these to freeze us) ---
@export var input_enabled: bool = true
var can_move: bool = true

# --- Stats (kept for the health UI / rest of the game) ---
@export var stats: HealthData

# --- Shared runtime state ---
var look_direction: Vector2 = Vector2.DOWN   # last direction we faced
var dragged_object: RigidBody2D = null

const RAY_LENGTH: float = 50.0

# --- Node references ---
@onready var sprite: AnimatedSprite2D = $Sprite2D
@onready var ray_cast: RayCast2D = $RayCast2D
@onready var push_pull_area: Area2D = $"Push-pull-Logic"
@onready var pin_joint: PinJoint2D = $PinJoint2D
# Typed as Node (not StateMachine) on purpose: it breaks a circular class
# reference (player -> StateMachine -> State -> player) that GDScript can't
# resolve. The player never calls into the machine anyway.
@onready var state_machine: Node = $StateMachine

# --- Animation tables ---
# Same animation names as the original Sami. Kept on the player because
# several states share them. PULL faces the object, so its up/down are
# swapped vs. the look vector (see _direction_string).
enum AnimState { NORMAL, PUSH, PULL }

const NORMAL_ANIMS := { "UP": "Up",     "DOWN": "down",    "LEFT": "Left",    "RIGHT": "Right" }
const PUSH_ANIMS   := { "UP": "PS_UP",  "DOWN": "PS_DOWN", "LEFT": "PS_LEFT", "RIGHT": "PS_RIGHT" }
const PULL_ANIMS   := { "UP": "PL_UP",  "DOWN": "PL_DOWN", "LEFT": "PL_LEFT", "RIGHT": "PL_RIGHT" }
const FLIPPED_ANIMS := { "Left": true }


func _ready() -> void:
	Dialog_Global.player = self
	scale = Vector2.ONE


# === Input helpers ========================================================

## Raw input snapped to the 4 cardinal directions (no diagonals).
func get_input_direction() -> Vector2:
	var raw := Input.get_vector("left", "right", "up", "down")
	if raw == Vector2.ZERO:
		return Vector2.ZERO
	if absf(raw.x) > absf(raw.y):
		return Vector2(signf(raw.x), 0.0)
	return Vector2(0.0, signf(raw.y))


## True while the player is allowed to control Sami (nothing froze us).
func can_control() -> bool:
	return input_enabled and can_move


## Aim the interaction raycast where we're currently facing.
func aim_raycast() -> void:
	ray_cast.target_position = look_direction * RAY_LENGTH
	ray_cast.force_raycast_update()


# === Drag helpers =========================================================

## Try to grab the closest RigidBody2D in front of us.
## Returns true if something was grabbed.
func try_grab() -> bool:
	var best_body: RigidBody2D = null
	var best_distance: float = INF

	for body in push_pull_area.get_overlapping_bodies():
		if not body is RigidBody2D:
			continue
		var to_body := body.global_position - global_position
		if to_body.dot(look_direction) <= 0.0:
			continue  # only grab things in front of us
		var distance := to_body.length()
		if distance < best_distance:
			best_distance = distance
			best_body = body

	if best_body == null:
		return false

	pin_joint.node_b = best_body.get_path()
	dragged_object = best_body
	return true


func release_grab() -> void:
	pin_joint.node_b = NodePath("")
	dragged_object = null


# === Interaction ==========================================================

## Interact with whatever the raycast is hitting.
## Returns true if it started an interaction (so the FSM should freeze us).
func try_interact() -> bool:
	var target := ray_cast.get_collider()
	if target == null:
		return false
	if target.is_in_group("NPC"):
		can_move = false  # the dialog system flips this back when it ends
		target.start_dialog()
		return true
	if target.is_in_group("Quest_Item"):
		target.start_interact()
		return true
	return false


# === Animation ============================================================

func play_idle() -> void:
	sprite.play("Idle")


## Play the directional animation for a mode (NORMAL / PUSH / PULL).
## `vec` decides the facing direction.
func play_directional_anim(anim_state: AnimState, vec: Vector2) -> void:
	var dir := _direction_string(anim_state, vec)
	var anim_name: String
	match anim_state:
		AnimState.PUSH: anim_name = PUSH_ANIMS[dir]
		AnimState.PULL: anim_name = PULL_ANIMS[dir]
		_:              anim_name = NORMAL_ANIMS[dir]

	sprite.play(anim_name)
	sprite.flip_h = FLIPPED_ANIMS.get(anim_name, false)


## Convert a vector to "UP" / "DOWN" / "LEFT" / "RIGHT".
## PULL is special: the pull art faces the object, so up/down are swapped
## relative to the look vector (kept exactly as the original Sami).
func _direction_string(anim_state: AnimState, v: Vector2) -> String:
	if absf(v.y) >= absf(v.x):
		if anim_state == AnimState.PULL:
			return "UP" if v.y > 0.0 else "DOWN"
		return "DOWN" if v.y > 0.0 else "UP"
	return "RIGHT" if v.x > 0.0 else "LEFT"


# === Public API kept for the rest of the game =============================

func disable() -> void:
	input_enabled = false


func enable() -> void:
	input_enabled = true
	visible = true
