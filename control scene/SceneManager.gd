extends Node

var transition_screen: TransitionScreen
var transition_screen_scene = preload("res://control scene/transition_screen.tscn")
var loading_screen: LoadingScreen
var loading_screen_scene = preload("res://loading_screen.tscn")
var _transition:String
var _content_path:String
var _load_progress_timer: Timer
var player_in_area: bool

# true from the moment a transition starts until the new scene is revealed.
# other systems check this so they don't fight the transition (see pause_menu.gd)
var is_transitioning: bool = false

# keep the loading art up at least this long so fast levels don't just flash it
var min_display_time: float = 0.6

# how much longer than the fade to wait before deciding a load is "slow" and
# showing the loading art. The fade itself (~0.93s) is the main grace window -
# the load runs during it, so by the time the screen is black we already know
# whether this scene was quick. Showing the art costs ~1.4s, so it should only
# commit when the load is clearly still running.
var loading_screen_grace: float = 0.25

var _loaded_content: Node = null
var _load_done: bool = false
var _loading_shown_at: int = 0
# last real progress reported by the loader. Tracked even while the loading
# screen isn't up yet, because on a fast drive the load can finish during the
# fade - the bar then has to open already full instead of stuck at zero.
var _last_progress: float = 0.0


signal content_finished_loading(content)
signal content_invalid(content_path:String)
signal content_failed_to_load(content_path:String)
signal _load_settled

func _ready() -> void:
	pass


# >>> DEBUG SLOW LOAD - delete along with control scene/debug_slow_load.gd
# live knob, so the delay can be changed without restarting the game.
# F9 off | F10 400ms | F11 2000ms | F12 reload this scene with that setting
func _input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_F9:
			DebugSlowLoad.set_hold_ms(0)
		KEY_F10:
			DebugSlowLoad.set_hold_ms(400)
		KEY_F11:
			DebugSlowLoad.set_hold_ms(2000)
		KEY_F12:
			reload_current_scene()
# <<< DEBUG SLOW LOAD


# ---------------------------------------------------------------- entry points

# force_loading_screen makes the art show even if the scene loads instantly.
# defaulted, so existing callers are unaffected
# these await _run_transition so callers can "await SceneManager.load_new_scene(...)"
# and have it actually mean something. Calling without await still works - it just
# runs up to the first internal await and returns, as before
func load_new_scene(contenet_path:String, force_loading_screen: bool = false) -> void:
	await _run_transition(contenet_path, null, force_loading_screen)


func reload_current_scene(force_loading_screen: bool = false) -> void:
	var current = get_tree().current_scene
	if current == null or current.scene_file_path.is_empty():
		return
	await _run_transition(current.scene_file_path, null, force_loading_screen)


# for callers holding a PackedScene instead of a path (Prescription checkpoints)
func load_new_packed(packed: PackedScene, force_loading_screen: bool = false) -> void:
	if packed == null:
		return
	if not packed.resource_path.is_empty():
		await _run_transition(packed.resource_path, null, force_loading_screen)
	else:
		# built at runtime, nothing to stream from disk
		await _run_transition("", packed.instantiate(), force_loading_screen)


# ------------------------------------------------------------- the transition

func _run_transition(content_path: String, preloaded: Node, force_loading_screen: bool = false) -> void:
	if is_transitioning:
		return
	is_transitioning = true
	_transition = "fade_to_black"
	_loaded_content = null
	_load_done = false
	_last_progress = 0.0
	player_in_area = false

	# start reading from disk BEFORE the fade, so the two overlap.
	# waiting for the fade first wasted ~1s of disk time on every transition.
	if preloaded != null:
		_loaded_content = preloaded
		_load_done = true
		_last_progress = 1.0
	elif not _start_load(content_path):
		_abort_transition()
		return

	# the curtain
	transition_screen = transition_screen_scene.instantiate() as TransitionScreen
	# set here rather than in the .tscn: without it the fade animation stops
	# dead if anything paused the tree, and the transition never completes
	transition_screen.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child(transition_screen)
	transition_screen.start_transition()
	await transition_screen.transition_in_complete

	# the load has had the whole fade as a head start. Give it a little longer
	# before committing to the loading art, so a load that only just overruns
	# doesn't cost the full screen
	if not _load_done and loading_screen_grace > 0.0:
		await _await_load_or_timeout(loading_screen_grace)

	# still going? then this really is a slow scene - show the art
	if force_loading_screen or not _load_done:
		loading_screen = loading_screen_scene.instantiate() as LoadingScreen
		get_tree().root.add_child(loading_screen)
		await loading_screen.loading_screen_ready
		loading_screen.set_progress(_last_progress)
		_loading_shown_at = Time.get_ticks_msec()

		if not _load_done:
			await _load_settled

		var elapsed := float(Time.get_ticks_msec() - _loading_shown_at) / 1000.0
		if elapsed < min_display_time:
			await get_tree().create_timer(min_display_time - elapsed, true).timeout

	if _loaded_content == null:
		_abort_transition()
		return

	on_content_finished_loading(_loaded_content)

	# the loading art has to be gone before the curtain opens, or it would
	# still be covering the scene the fade is revealing
	if loading_screen != null:
		await loading_screen.hide_screen()
		loading_screen = null

	var curtain_anim := transition_screen.animation_player
	transition_screen.finish_transition()
	await curtain_anim.animation_finished
	transition_screen = null

	_loaded_content = null
	is_transitioning = false


# waits until the load finishes or the window runs out, whichever comes first.
# process_frame still fires while the tree is paused, so this can't wedge
func _await_load_or_timeout(seconds: float) -> void:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while not _load_done and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame


func _abort_transition() -> void:
	_clear_load_timer()
	if loading_screen != null:
		loading_screen.queue_free()
		loading_screen = null
	if transition_screen != null:
		transition_screen.queue_free()
		transition_screen = null
	_loaded_content = null
	is_transitioning = false


# ------------------------------------------------------------------ threading

func _start_load(content_path: String) -> bool:
	if not ResourceLoader.exists(content_path):
		content_invalid.emit(content_path)
		return false

	_content_path = content_path
	if ResourceLoader.load_threaded_request(content_path, "", true) != OK:
		content_invalid.emit(content_path)
		return false

	_load_progress_timer = Timer.new()
	_load_progress_timer.wait_time = 0.1
	# must keep ticking even if something paused the tree mid-transition
	_load_progress_timer.process_mode = Node.PROCESS_MODE_ALWAYS
	_load_progress_timer.timeout.connect(_monitor_load_status)
	get_tree().root.add_child(_load_progress_timer)
	_load_progress_timer.start()
	# >>> DEBUG SLOW LOAD - delete along with control scene/debug_slow_load.gd
	DebugSlowLoad.begin()
	# <<< DEBUG SLOW LOAD
	return true


func _monitor_load_status() -> void:
	# >>> DEBUG SLOW LOAD - delete along with control scene/debug_slow_load.gd
	# sit on the real result for a while, so the load looks slow to everything
	# downstream: grace window, loading art, progress bar, min_display_time
	if DebugSlowLoad.is_holding():
		_last_progress = DebugSlowLoad.fake_progress()
		if loading_screen != null:
			loading_screen.set_progress(_last_progress)
		return
	# <<< DEBUG SLOW LOAD

	var load_progress = []
	var load_status = ResourceLoader.load_threaded_get_status(_content_path, load_progress)

	match load_status:
		ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			_finish_load(null)
			content_invalid.emit(_content_path)
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			_last_progress = load_progress[0]
			if loading_screen != null:
				loading_screen.set_progress(_last_progress)
		ResourceLoader.THREAD_LOAD_FAILED:
			_finish_load(null)
			content_failed_to_load.emit(_content_path)
		ResourceLoader.THREAD_LOAD_LOADED:
			_last_progress = 1.0
			if loading_screen != null:
				loading_screen.set_progress(1.0)
			_finish_load(ResourceLoader.load_threaded_get(_content_path).instantiate())
			content_finished_loading.emit(_loaded_content)


func _finish_load(content: Node) -> void:
	_clear_load_timer()
	_loaded_content = content
	_load_done = true
	_load_settled.emit()


func _clear_load_timer() -> void:
	if _load_progress_timer != null:
		_load_progress_timer.stop()
		_load_progress_timer.queue_free()
		_load_progress_timer = null


# --------------------------------------------------------------- the swap

# hands the outgoing level's LevelDataHandoff to the incoming one, so the player
# spawns at the matching door. Level._ready() -> enter_level() does the placing.
func on_content_finished_loading(contenet: Node2D) -> void:
	var outgoing_scene = get_tree().current_scene

	var incoming_data:LevelDataHandoff
	if outgoing_scene is Level:
		incoming_data = outgoing_scene.data as LevelDataHandoff

	if contenet is Level:
		contenet.data = incoming_data

	outgoing_scene.queue_free()

	get_tree().root.call_deferred("add_child", contenet)
	get_tree().set_deferred("current_scene", contenet)
