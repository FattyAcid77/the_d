class_name Player extends CharacterBody2D
# 3-point health, shared live with Health_UI through this same resource.
@export var stats: HealthData

@onready var anim: AnimatedSprite2D = $Sprite2D
@onready var state_machine: Sami_statemachine = $Statemachine
# inventory panel, toggled with I. lives under UI.
@onready var inventory: CanvasLayer = get_node_or_null("UI/Inventory UI")

@export var input_enabled: bool = true

#-------camera settings----------
@export var camera_adj: bgrd_node
@onready var sami_camera = $Camera2D

var cardinal_direction : Vector2 = Vector2.DOWN
var direction : Vector2 = Vector2.ZERO
var move_speed : float = 100.0

# push / pull
const PUSH_HOLD_DISTANCE: float = 46    # matches the arm reach in the PS_ sprites (77px frames)
const PULL_HOLD_DISTANCE: float = 34.0    # PL_ sprites reach less far (54px frames), tune to taste
var focus_grabbable: Node = null          # object whose zone we're standing in
var grabbed: Node = null                  # object we're holding
var grab_offset: Vector2 = Vector2.ZERO   # player->object; side locked at grab, distance follows the pose

# Called when the node enters the scene tree for the first time.
func _ready():
	camera_limit_set()
	# Hand ourselves to the state machine so every state can control us.
	state_machine.Initialize(self)
	if inventory != null:
		_set_inventory(false)   # start hidden


# Every frame we ONLY read the input into 'direction'.
# The states decide what to do with it (move, animate, switch).
func _process( delta ):
	direction.x = Input.get_action_strength("right") - Input.get_action_strength("left")
	direction.y = Input.get_action_strength("down") - Input.get_action_strength("up")

	# I toggles the inventory panel. Doesn't pause, so you can test movement with it open.
	if inventory != null and Input.is_action_just_pressed("I"):
		_set_inventory(not inventory.visible)


func _physics_process( delta ):
	move_and_slide()

	# holding something above us draws in front of it; holding something below
	# draws behind it, so it doesn't look like our feet are stomping through it.
	# Only ever nudge the winner UP to 1, never push either one negative — the
	# floor sits at the default z_index 0, and dropping below that makes
	# whichever one we push down vanish behind it.
	if grabbed != null:
		if grabbed.global_position.y >= global_position.y:
			z_index = 0
			grabbed.z_index = 1   # it's below us, draw it in front
		else:
			z_index = 1           # it's above us, draw us in front
			grabbed.z_index = 0


# Turns the raw input into a facing (down/up/left/right) and flips the sprite.
# Returns true only when the facing actually changed.
func SetDirection() -> bool:
	var new_dir: Vector2 = cardinal_direction
	if direction == Vector2.ZERO:
		return false

	if direction.y == 0:
		new_dir = Vector2.LEFT if direction.x < 0 else Vector2.RIGHT
	elif direction.x == 0:
		new_dir = Vector2.UP if direction.y < 0 else Vector2.DOWN

	if new_dir == cardinal_direction:
		return false

	cardinal_direction = new_dir
	anim.scale.x = -1 if cardinal_direction == Vector2.LEFT else 1
	return true


func UpdateAnimation( anim_state : String ) -> void:
	var anim_name: String = anim_state + "_" + AnimDirection()
	# Don't restart an animation that's already playing — calling play() every
	# frame snaps it back to frame 0 and makes it look frozen / slow.
	if anim.animation == anim_name:
		return
	if anim.sprite_frames.has_animation(anim_name):
		anim.play(anim_name)


func AnimDirection() -> String:
	if cardinal_direction == Vector2.DOWN:
		return "down"
	elif cardinal_direction == Vector2.UP:
		return "up"
	else:
		return "Side"


# face the side an object is on (no movement input needed, so it holds while
# we push or pull)
func face_toward(vec: Vector2) -> void:
	if vec == Vector2.ZERO:
		return
	if abs(vec.x) >= abs(vec.y):
		cardinal_direction = Vector2.RIGHT if vec.x >= 0 else Vector2.LEFT
	else:
		cardinal_direction = Vector2.DOWN if vec.y >= 0 else Vector2.UP
	anim.scale.x = 1   # push/pull have their own left/right frames, never flipped


# play a PS_ or PL_ frame for a direction
func update_drag_animation(prefix: String, dir: Vector2) -> void:
	anim.scale.x = 1
	var anim_name: String = prefix + "_" + _dir4(dir)
	if anim.animation == anim_name:
		return
	if anim.sprite_frames.has_animation(anim_name):
		anim.play(anim_name)


func _dir4(vec: Vector2) -> String:
	if abs(vec.x) >= abs(vec.y):
		return "RIGHT" if vec.x >= 0 else "LEFT"
	return "DOWN" if vec.y >= 0 else "UP"


# Drag and Rotate both call this so the pose always matches.
# The pull art is named weirdly: up/down by where you move, left/right by where
# you face, so we just flip the y.
func play_push_pull_anim(pushing: bool) -> void:
	# push and pull are drawn with different reach, so the held distance follows the pose
	if grabbed != null:
		grab_offset = grab_offset.normalized() * (PUSH_HOLD_DISTANCE if pushing else PULL_HOLD_DISTANCE)
	if pushing:
		update_drag_animation("PS", cardinal_direction)
	else:
		update_drag_animation("PL", Vector2(cardinal_direction.x, -cardinal_direction.y))


# grab the object we're next to. true if we got one.
func try_start_grab() -> bool:
	if focus_grabbable == null:
		return false
	grabbed = focus_grabbable
	# lock which side the object is on; play_push_pull_anim sets the actual distance
	var to_object: Vector2 = grabbed.global_position - global_position
	var side: Vector2
	if abs(to_object.x) >= abs(to_object.y):
		side = Vector2.RIGHT if to_object.x >= 0 else Vector2.LEFT
	else:
		side = Vector2.DOWN if to_object.y >= 0 else Vector2.UP
	grab_offset = side * PUSH_HOLD_DISTANCE
	if grabbed.has_method("on_grabbed"):
		grabbed.on_grabbed(self)
	return true


func end_grab() -> void:
	if grabbed != null:
		if grabbed.has_method("on_released"):
			grabbed.on_released(self)
		grabbed.z_index = 0
	grabbed = null
	z_index = 0


# keep the held object pinned at the locked offset so it can't slip past us
func drag_follow() -> void:
	if grabbed == null:
		return
	grabbed.global_position = global_position + grab_offset
	if grabbed is CharacterBody2D:
		grabbed.velocity = Vector2.ZERO


# show/hide the inventory panel and stop it processing while hidden
func _set_inventory(on: bool) -> void:
	inventory.visible = on
	inventory.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED

func camera_limit_set() -> void:
	sami_camera.limit_top = camera_adj.top_limits
	sami_camera.limit_right = camera_adj.right_limits
	sami_camera.limit_bottom = camera_adj.bottom_limits
	sami_camera.limit_left = camera_adj.left_limits

func enable() -> void:
	input_enabled = true
	visible = true

func disable() -> void:
	input_enabled = false

func orient(dir: Vector2) -> void:
	pass
