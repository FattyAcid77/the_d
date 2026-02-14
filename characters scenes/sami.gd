class_name Sami extends CharacterBody2D


#up to change
@export var speed = 5000.0
@export var accel: float = 1200.0
@export var input_enabled:bool = true
@export var camera_adj: bgrd_node


@onready var ray_cast_2d: RayCast2D = $RayCast2D

@onready var amount: Label = $HUD/Coins/Amount
@onready var quest_tracker: ColorRect = $HUD/QuestTracker
@onready var title: Label = $HUD/QuestTracker/Details/Title
@onready var objectives: VBoxContainer = $HUD/QuestTracker/Details/Objectives
@onready var quest_manger: Node2D = $QuestManger
@onready var ani: AnimatedSprite2D = $Sprite2D
@onready var area_ind: area_indicator = $AreaIndicator

@onready var camera =  $Camera2D
@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D

var can_move = true
var input_direction: Vector2 = Vector2.ZERO
var desired_vel: Vector2 = Vector2.ZERO

func _ready() -> void:
	#Need To Be Ref to the Global to use in other Scenes
	Dialog_Global.player = self
	quest_tracker.visible = false
	scale = Vector2.ONE
	set_camera_limits()


#Keep in mind that Delta Time should be used consistently so that gameplay remains the same across different PCs, regardless of their hardware specifications
func _physics_process(delta: float) -> void:
	
	if can_move and input_enabled :
		
		if Input.is_action_pressed("right"):
			#velocity.x += 1
			ani.play("Right")
			ani.flip_h = false
		elif Input.is_action_pressed("left"):
			#velocity.x -= 1
			ani.play("Left")
			ani.flip_h = true
		elif Input.is_action_pressed("down"):
			#velocity.y += 1
			ani.play("down")
		elif Input.is_action_pressed("up"):
			#velocity.y -= 1
			ani.play("Up")
		else:
			ani.stop()
		
		input_direction = Input.get_vector("left", "right", "up", "down")
		velocity = input_direction.normalized() * speed
		#if velocity.length() > 0:
			#velocity = velocity.normalized() * speed
			#velocity = input_direction.normalized() * speed
			#position += velocity * delta
		#velocity = input_direction.normalized() * speed
		
		raycast()
		move_and_slide()
		
		
		

func _process(delta: float) -> void:
	#if input_enabled:
		#input_direction = Input.get_vector("left", "right", "up", "down")
		#desired_vel = input_direction.normalized() * speed
		if SceneManager.player_in_area:
			area_ind.show_E()
		else:
			area_ind.hide_E()


	

func raycast():
	var Raycast_length: int = 150
	if velocity != Vector2.ZERO:
		ray_cast_2d.target_position = velocity.normalized() * Raycast_length


func _input(event) -> void:
	#interact with a NPC/Quest
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

func orient(dir:Vector2) -> void:
	#if dir.x:
		#anim_sprite.flip_h
	pass

func disable():
	input_enabled = false
	
func enable():
	input_enabled = true
	visible = true
	
func set_camera_limits():
	camera.limit_right = camera_adj.right_limits
	print(camera.limit_right)
	camera.limit_top = camera_adj.top_limits
	print(camera.limit_top)
	camera.limit_left = camera_adj.left_limits
	print(camera.limit_left)
	camera.limit_bottom = camera_adj.bottom_limits
	print(camera.limit_bottom)
	
