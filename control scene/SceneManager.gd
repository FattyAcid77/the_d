extends Node

var _transition_screen:TransitionScreen
var transition_screen_scene = preload("res://control scene/transition_screen.tscn")
var _transition:String
var _content_path:String

func _ready() -> void:
	pass

func load_new_scene(contenet_path:String, transition_type:String="fade_to_black") -> void:
	_transition = transition_type
	transition_screen = transition_screen_scene.instantiate() as TransitionScreen
	get_tree().root.add_child(transition_screen)
	transition_screen.start_transition()
	
