extends Node2D

@onready var options: Control = $"../Options"





# === ICON REFERENCES ===
@onready var ic2: Sprite2D = $Icon2
@onready var ic3: Sprite2D = $Icon3
@onready var ic4: Sprite2D = $Icon4
@onready var ic5: Sprite2D = $Icon5
@onready var ic6: Sprite2D = $Icon6
@onready var ic7: Sprite2D = $Icon7
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

# === RADIO SCENE HOLDER ===
@onready var radio_holder: Node = $"CanvasLayer/RadioHolder"
var scene_to_instantiate: PackedScene = preload("res://3MK-File/myshit/radio_2_0.tscn")
var radio_instance: Node = null


# === MAIN LOGIC ===
func _ready() -> void:
	print("radio_holder =", radio_holder)  # should NOT be Null
	hide_all_icons()  # start hidden
	remove_child(options)

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
func hide_all_icons() -> void:
	ic2.visible = false
	ic3.visible = false
	ic4.visible = false
	ic5.visible = false
	ic6.visible = false
	ic7.visible = false


func vis() -> void:
	# Hide all first
	hide_all_icons()

	# Then show only one icon depending on RadioGlobal state
	if RadioGlobal.state1:
		ic2.visible = true
	elif RadioGlobal.state2:
		ic3.visible = true
	elif RadioGlobal.state3:
		ic4.visible = true
	elif RadioGlobal.state4:
		ic5.visible = true
	elif RadioGlobal.state5:
		ic6.visible = true
	elif RadioGlobal.state6:
		ic7.visible = true





func _on_task_radio_task_completed() -> void:
	anim.play("default")
