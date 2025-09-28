extends Node

var _transition_screen: TransitionScreen
var transition_screen_scene = preload("res://control scene/transition_screen.tscn")
var _transition:String
var _content_path:String
var _load_progress_timer: Timer
var _scene_to_unload: Node

signal load_start(transition_screen)
signal scene_added(loaded_scene:Node, loading_screen)
signal load_complete(loaded_scene:Node)

signal _content_finished_loading(content)
signal _content_invalid(content_path:String)
signal _content_failed_to_load(content_path:String)

func _ready() -> void:
	#_content_invalid.connect(_on_content_invalid)
	pass

func _load_content(content_path: String) -> void:
	if _transition_screen != null:
		await _transition_screen.transition_in_complete
	
	_content_path = content_path
	var loader = ResourceLoader.load_threaded_request(content_path)
	if not ResourceLoader.exists(content_path) or loader == null:
		_content_invalid.emit(content_path)
		return
	_load_progress_timer = Timer.new()
	_load_progress_timer.wait_time = 0.1
	_load_progress_timer.timeout.connect(_monitor_load_status)
	get_tree().root.add_child(_load_progress_timer)
	_load_progress_timer.start()

func _monitor_load_status() -> void:
	var load_progress = []
	var load_status = ResourceLoader.load_threaded_get_status(_content_path, load_progress)

	match load_status:
		ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			_content_invalid.emit(_content_path)
			_load_progress_timer.stop()
			return
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			if _transition_screen != null:
				_transition_screen.update_bar(load_progress[0] * 100) # 0.1
		ResourceLoader.THREAD_LOAD_FAILED:
			_content_failed_to_load.emit(_content_path)
			_load_progress_timer.stop()
			return
		ResourceLoader.THREAD_LOAD_LOADED:
			_load_progress_timer.stop()
			_load_progress_timer.queue_free()
			_content_finished_loading.emit(ResourceLoader.load_threaded_get(_content_path).instantiate())
			return # this last return isn't necessary but I like how the 3 dead ends stand out as similar


func load_new_scene(contenet_path:String, transition_type:String="fade_to_black") -> void:
	_transition = transition_type
	_transition_screen = transition_screen_scene.instantiate() as TransitionScreen
	get_tree().root.add_child(_transition_screen)
	_transition_screen.start_transition()
	_load_content(contenet_path)
	
func on_content_finished_loading(contenet) -> void:
	var outgoing_scene = _scene_to_unload
	
	var incoming_data:LevelDataHandoff
	if get_tree().current_scene is Node2D:
		incoming_data = get_tree().current_scene.dataas as LevelDataHandoff
		
		
	outgoing_scene.queue_free()
	
	
	
