class_name Sami extends CharacterBody2D

# --- Movement ---
@export var speed: float = 5000.0
@export var drag_speed: float = 60.0   # User-tuned. Don't change without asking.
@export var accel: float = 1200.0

# --- State ---
@export var input_enabled: bool = true
@export var stats: HealthData

var dragged_object: RigidBody2D = null
var can_move: bool = true
var input_direction: Vector2 = Vector2.ZERO
var desired_vel: Vector2 = Vector2.ZERO
var look_direction: Vector2 = Vector2.DOWN

var push_force: int = 80
var ray_length: float = 50.0

# --- Node references ---
@onready var ray_cast_2d: RayCast2D = $RayCast2D
@onready var inventory_ui: CanvasLayer = $"Inventory UI"
@onready var amount: Label = $HUD/Coins/Amount
@onready var quest_tracker: ColorRect = $HUD/QuestTracker
@onready var title: Label = $HUD/QuestTracker/Details/Title
@onready var objectives: VBoxContainer = $HUD/QuestTracker/Details/Objectives
@onready var quest_manger: Node2D = $QuestManger
@onready var ani: AnimatedSprite2D = $Sprite2D
@onready var pp_logic: Area2D = $"Push-pull-Logic"
@onready var camera = $Camera2D
@export var camera_adj

# --- Animation system ---

enum AnimState { NORMAL, PUSH, PULL }

# Per-state lookup tables. Each is independent and uses string keys
# so it lines up directly with the per-state direction functions below.
const NORMAL_ANIMS := {
	"UP":    "Up",
	"DOWN":  "down",
	"LEFT":  "Left",
	"RIGHT": "Right",
}

const PUSH_ANIMS := {
	"UP":    "PS_UP",
	"DOWN":  "PS_DOWN",
	"LEFT":  "PS_LEFT",
	"RIGHT": "PS_RIGHT",
}

const PULL_ANIMS := {
	"UP":    "PL_UP",
	"DOWN":  "PL_DOWN",
	"LEFT":  "PL_LEFT",
	"RIGHT": "PL_RIGHT",
}

const FLIPPED_ANIMS := { "Left": true }

# --- Lifecycle ---

func _ready() -> void:
	print("Game Started! Sami's Health is: ", stats.current_health)
	Dialog_Global.player = self
	quest_tracker.visible = false
	scale = Vector2.ONE
	inventory.player_ref(self)
	camera_limit_adj()


func _physics_process(delta: float) -> void:
	if can_move and input_enabled:
		_handle_movement_and_animation()

	_handle_drag_input()


func _handle_movement_and_animation() -> void:
	# Get raw input and snap to 4 cardinal directions only.
	var raw_input := Input.get_vector("left", "right", "up", "down")
	input_direction = _snap_to_cardinal(raw_input)

	if dragged_object != null:
		# FIRST CHECK: Are we actually pressing a movement key?
		if input_direction == Vector2.ZERO:
			velocity = Vector2.ZERO
			ani.play("Idle") # Wait for player input!
		else:
			# Axis-locked dragging: only input along look_direction does anything.
			var alignment := input_direction.dot(look_direction)

			if alignment > 0:
				# Pressing toward the object → push.
				velocity = look_direction * drag_speed
				_play_anim(AnimState.PUSH, look_direction)
			elif alignment < 0:
				# Pressing away from the object → pull.
				velocity = -look_direction * drag_speed
				_play_anim(AnimState.PULL, look_direction)
			else:
				# Perpendicular input (e.g., pressing Left while looking Up): stand still.
				velocity = Vector2.ZERO
				ani.play("Idle")
	else:
		# Free 4-direction movement when not dragging.
		velocity = input_direction * speed

		if input_direction != Vector2.ZERO:
			look_direction = input_direction
			_play_anim(AnimState.NORMAL, input_direction)
		else:
			ani.play("Idle")

	# Aim raycast where we're looking (used for NPC / quest interaction).
	ray_cast_2d.target_position = look_direction * ray_length
	ray_cast_2d.force_raycast_update()

	move_and_slide()

func _handle_drag_input() -> void:
	if Input.is_action_just_pressed("drag"):
		print("Pushing")
		# Find the closest grabbable body that is in front of us.
		var best_body: RigidBody2D = null
		var best_distance: float = INF

		for body in pp_logic.get_overlapping_bodies():
			if not body is RigidBody2D:
				continue

			var to_body := body.global_position - global_position
			# Only consider bodies in front of us.
			if to_body.dot(look_direction) <= 0:
				continue

			var distance := to_body.length()
			if distance < best_distance:
				best_distance = distance
				best_body = body

		if best_body != null:
			$PinJoint2D.node_b = best_body.get_path()
			dragged_object = best_body

	if Input.is_action_just_released("drag"):
		$PinJoint2D.node_b = NodePath("")
		dragged_object = null

# --- Math helpers ---

func _snap_to_cardinal(v: Vector2) -> Vector2:
	if v == Vector2.ZERO:
		return Vector2.ZERO
	if abs(v.x) > abs(v.y):
		return Vector2(sign(v.x), 0)
	return Vector2(0, sign(v.y))

# --- Per-state direction functions ---
# These are intentionally kept SEPARATE — do NOT merge them.
# Each state owns its own vector-to-direction math so we can tweak
# or print-debug one without affecting the others.
#
# Reminder: in Godot 2D, +Y is DOWN, -Y is UP.

# NORMAL state: walking around with no dragged object.
# Vector passed in is usually input_direction.
func _vector_NORMAL_to_direction_string(v: Vector2) -> String:
	if abs(v.y) >= abs(v.x):
		return "DOWN" if v.y > 0 else "UP"
	return "RIGHT" if v.x > 0 else "LEFT"


# PUSH state: moving toward a held object.
# Vector passed in is look_direction (points at the object).
func _vector_PUSH_to_direction_string(v: Vector2) -> String:
	if abs(v.y) >= abs(v.x):
		return "DOWN" if v.y > 0 else "UP"
	return "RIGHT" if v.x > 0 else "LEFT"


# PULL state: moving away from a held object.
# Vector passed in is look_direction (points at the object — NOT the
# direction of movement). The pull animation faces the object, so we
# convert look_direction directly without flipping it.
func _vector_PULL_to_direction_string(v: Vector2) -> String:
	if abs(v.y) >= abs(v.x):
		return "UP" if v.y > 0 else "DOWN"
	return "RIGHT" if v.x > 0 else "LEFT"


# --- Play function (router) ---
# Routes the vector through the correct per-state direction function,
# then looks up the animation name in the matching per-state table.
func _play_anim(state: int, vec: Vector2) -> void:
	var dir_str: String
	var anim_name: String

	match state:
		AnimState.NORMAL:
			dir_str = _vector_NORMAL_to_direction_string(vec)
			anim_name = NORMAL_ANIMS[dir_str]
		AnimState.PUSH:
			dir_str = _vector_PUSH_to_direction_string(vec)
			anim_name = PUSH_ANIMS[dir_str]
		AnimState.PULL:
			dir_str = _vector_PULL_to_direction_string(vec)
			anim_name = PULL_ANIMS[dir_str]
		_:
			# Should never happen, but fail loud if it does.
			push_warning("Unknown AnimState: %s" % state)
			return

	ani.play(anim_name)
	ani.flip_h = FLIPPED_ANIMS.get(anim_name, false)

# --- Other ---

func _process(delta: float) -> void:
	if SceneManager.player_in_area:
		pass
	else:
		pass


func _input(event) -> void:
	if Input.is_action_just_pressed("I"):
		inventory_ui.visible = !inventory_ui.visible
		get_tree().paused = !get_tree().paused

	if event.is_action_pressed("ui_accept"):
		var target = ray_cast_2d.get_collider()
		if target != null:
			if target.is_in_group("NPC"):
				print("This is talking to a NPC")
				can_move = false
				target.start_dialog()
			elif target.is_in_group("Quest_Item"):
				print("This is in item")
				target.start_interact()


func orient(dir: Vector2) -> void:
	pass


func disable() -> void:
	input_enabled = false


func enable() -> void:
	input_enabled = true
	visible = true


func apply_item() -> void:
	pass

func camera_limit_adj() -> void:
	var top_limit = null
	var right_limit = null
	var bot_limit = null
	var left_limit = null
