extends Node

var _transition_screen:TransitionScreen
var transition_screen_scene = preload("res://control scene/transition_screen.tscn")
var _transition:String
var _content_path:String

func _ready() -> void:
	pass

func load_content(content_path: String) -> void:
	if transition_screen  != null:
		await loading_screen.trasnsition_in_complete
	_content_path = content_path
	var loader = ResourceLoader.load_threaded_request(content_path)
	if not ResourceLoader.exists(content_path) or loader == null:
		content_invalid.emit(content_path)
		return
	

func load_new_scene(contenet_path:String, transition_type:String="fade_to_black") -> void:
	_transition = transition_type
	transition_screen = transition_screen_scene.instantiate() as TransitionScreen
	get_tree().root.add_child(transition_screen)
	transition_screen.start_transition()
	
func on_content_finished_loading(contenet) -> void:
	var outgoing_scene = get_tree().current_scene
	
	var incoming_data:LevelDataHandoff
	if get_tree().current_scene is Level:
		incoming_data = get_tree().current_scene.dataas LevelDataHandoff
		
	if content is Level:
		content.data = incoming_data
		
	outgoing_scene.queue_free()
	
	
	
