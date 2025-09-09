extends Area2D

const DialgueSystemPreload = preload("res://FD_Testing/Diloage_System/dialogueSystem.tscn")


@export var activate_instant: bool
@export var only_active_once: bool
@export var overrude_dialogue_position: bool
@export var override_position: Vector2
@export var dialogue: Array[DE]



var dialogue_top_pos: Vector2 = Vector2(160, 48)
var dialogue_bottom_pos: Vector2 = Vector2(160, 192)

var player_body_in: bool = false
var has_activated_already: bool = false
var desired_dualogue_pos: Vector2

var player_node: CharacterBody2D = null


func _ready() -> void:
	for i in get_tree().get_nodes_in_group("player"):
		player_node = i


func _process(_delta: float) -> void:
	if !player_node:
		for i in get_tree().get_nodes_in_group("player"):
			player_node = i
		return
	
	if !activate_instant and player_body_in:
		if only_active_once and has_activated_already:
			set_process(false)
			return
		
		if Input.is_action_just_pressed("ui_accept"):
			_activate_dialogue()
			player_body_in = false


func _activate_dialogue() -> void:
	player_node.can_move = false
	
	var new_dialogue = DialgueSystemPreload.instantiate()
	if overrude_dialogue_position:
		desired_dualogue_pos = override_position
	else:
		if player_node.global_position.y > get_viewport().get_camera_2d().get_screen_center_position().y:
			desired_dualogue_pos  = dialogue_top_pos
		else:
			desired_dualogue_pos  = dialogue_bottom_pos

	new_dialogue.global_position = desired_dualogue_pos 
	new_dialogue.dialogue = dialogue
	get_parent().add_child(new_dialogue)


func _on_body_entered(body: Node2D) -> void:
	if only_active_once and has_activated_already:
		return
	if body.is_in_group("player"):
		player_body_in = true
		if activate_instant:
			_activate_dialogue()


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_body_in = false
