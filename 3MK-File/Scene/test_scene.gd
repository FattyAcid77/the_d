class_name odai_Sami extends Node2D

@onready var options: Control = $Options


@onready var rig: RigidBody2D = $RigidBody2D





@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var icon: Sprite2D = $RigidBody2D/Icon

# === RADIO SCENE HOLDER ===
@onready var radio_holder: Panel = $CharacterBody2D/RadioHolder


var scene_to_instantiate: PackedScene = preload("res://3MK-File/myshit/radio_2_0.tscn")
var radio_instance: Node = null


# === MAIN LOGIC ===
func _ready() -> void:
	print("radio_holder =", radio_holder)  # should NOT be Null
	remove_child(rig)
	

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("E"):
		if radio_instance == null:
			_open_radio()
		else:
			_close_radio()
	if Input.is_action_just_pressed("Option"):
		add_child(options)
		if Input.is_action_just_pressed("Option"):
			remove_child(options)
	# Keep icons updated to reflect RadioGlobal state
	vis()


# === RADIO OPEN / CLOSE ===
func _open_radio() -> void:
	var new_scene = scene_to_instantiate.instantiate()
	new_scene.scale = Vector2(0.4, 0.4)
	new_scene.position = Vector2(50, 50)  # relative to RadioHolder
	radio_holder.add_child(new_scene)
	radio_instance = new_scene
	print("📻 Radio opened inside panel.")


func _close_radio() -> void:
	if radio_instance and is_instance_valid(radio_instance):
		radio_instance.queue_free()
		radio_instance = null
		print("❌ Radio closed.")


# === ICON VISIBILITY HANDLER ===


func vis() -> void:
	pass
