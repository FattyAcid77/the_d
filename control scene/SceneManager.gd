extends Node

var transition_screen: TransitionScreen
var transition_screen_scene = preload("res://control scene/transition_screen.tscn")
var _transition:String
var _content_path:String
var _load_progress_timer: Timer



signal content_finished_loading(content)
signal content_invalid(content_path:String)
signal content_failed_to_load(content_path:String)

func _ready() -> void:
	content_finished_loading.connect(on_content_finished_loading)
	pass

func _load_content(content_path: String) -> void:
	if transition_screen != null:
		await transition_screen.transition_in_complete
	
	_content_path = content_path
	var loader = ResourceLoader.load_threaded_request(content_path)
	if not ResourceLoader.exists(content_path) or loader == null:
		content_invalid.emit(content_path)
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
			content_invalid.emit(_content_path)
			_load_progress_timer.stop()
			return
		#ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			#if transition_screen != null:
				#transition_screen.update_bar(load_progress[0] * 100) # 0.1
		ResourceLoader.THREAD_LOAD_FAILED:
			content_failed_to_load.emit(_content_path)
			_load_progress_timer.stop()
			return
		ResourceLoader.THREAD_LOAD_LOADED:
			_load_progress_timer.stop()
			_load_progress_timer.queue_free()
			content_finished_loading.emit(ResourceLoader.load_threaded_get(_content_path).instantiate())
			return # this last return isn't necessary but I like how the 3 dead ends stand out as similar


func load_new_scene(contenet_path:String) -> void:
	var transition_type = "fade_to_black"
	_transition = transition_type
	transition_screen = transition_screen_scene.instantiate() as TransitionScreen
	get_tree().root.add_child(transition_screen)
	transition_screen.start_transition()
	_load_content(contenet_path)
	
func on_content_finished_loading(contenet: Node2D) -> void:
	var outgoing_scene = get_tree().current_scene
	
	var incoming_data:LevelDataHandoff
	if get_tree().current_scene is Level:
		incoming_data = get_tree().current_scene.data as LevelDataHandoff
	
	if contenet is Level:
		contenet.data = incoming_data
		
	outgoing_scene.queue_free()
	
	get_tree().root.call_deferred("add_child", contenet)
	get_tree().set_deferred("current_scene", contenet)
	
	if transition_screen != null:
		transition_screen.finish_transition()
		
		if contenet is Level:
			contenet.init_player_location()
		
		await transition_screen.animation_player.animation_finished
		transition_screen = null
		
		if contenet is Level:
			contenet.enter_level()
	
	
