extends Panel
# NOTE: this flag reads backwards — true means the radio is CLOSED. Do not
# rename it: FD_Testing/GameSystems/StatuePuzzle/radio_link.gd looks it up by
# this exact name to tell whether the radio is on screen.
var sami_radio: bool = true
@export var Radio_Sami: PackedScene = preload("res://3MK-File/Scene/radio_ui.tscn")
var instance


func _ready() -> void:
	add_to_group("radio_panel")   # RadioSignals finds us here to auto open/close


func is_on() -> bool:
	return not sami_radio


func set_radio_on(on: bool) -> void:
	if on == is_on():
		return
	if on:
		instance = Radio_Sami.instantiate()
		add_child(instance)
		instance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		instance.scale = Vector2(0.4, 0.4)
		sami_radio = false
	else:
		instance.queue_free()   # remove_child alone leaked the old one
		instance = null
		sami_radio = true


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("Radio_button"):
		set_radio_on(not is_on())
