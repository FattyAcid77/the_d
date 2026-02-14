extends Panel
var sami_radio: bool = true
@export var Radio_Sami: PackedScene
var instance 



# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if Input.is_action_just_pressed("E"):
		if sami_radio:
			instance = Radio_Sami.instantiate()
			add_child(instance)
			instance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

			instance.scale = Vector2(0.4, 0.4)
			sami_radio = false
		else:
			remove_child(instance)
			sami_radio = true
