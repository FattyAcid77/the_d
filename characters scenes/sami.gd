class_name Sami extends CharacterBody2D



#up to change
@export var speed = 5000.0
@export var accel: float = 1200.0
@export var input_enabled:bool = true
@onready var ray_cast_2d: RayCast2D = $RayCast2D

@onready var amount: Label = $HUD/Coins/Amount
@onready var quest_tracker: ColorRect = $HUD/QuestTracker
@onready var title: Label = $HUD/QuestTracker/Details/Title
@onready var objectives: VBoxContainer = $HUD/QuestTracker/Details/Objectives
@onready var quest_manger: Node2D = $QuestManger

@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D

var can_move = true
var input_direction: Vector2 = Vector2.ZERO
var desired_vel: Vector2 = Vector2.ZERO

func _ready() -> void:
	#Need To Be Ref to the Global to use in other Scenes
	Dialog_Global.player = self
	quest_tracker.visible = false
	scale = Vector2.ONE



#Keep in mind that Delta Time should be used consistently so that gameplay remains the same across different PCs, regardless of their hardware specifications
func _physics_process(delta: float) -> void:
	
	if can_move:
		velocity = input_direction.normalized() * speed
		raycast()
		move_and_slide()
		

func _process(delta: float) -> void:
	if input_enabled:
		input_direction = Input.get_vector("left", "right", "up", "down")
		desired_vel = input_direction.normalized() * speed


	

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
