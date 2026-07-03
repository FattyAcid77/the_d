extends Area2D
class_name TaskPuzzleArea

@export var puzzle_id: String = ""
@export var puzzle_name: String = ""
@export var mirror_entries: Array[MirrorFrequencyEntry] = []

var _player_inside: bool = false
var _last_radio: int = -9999

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_update_mirrors(RadioGlobal.radio)

func _process(_delta: float) -> void:
	if not _player_inside:
		return
	var current: int = RadioGlobal.radio
	if current == _last_radio:
		return
	_last_radio = current
	_update_mirrors(current)

func _update_mirrors(freq: int) -> void:
	var player := get_tree().get_first_node_in_group("Player")
	for entry in mirror_entries:
		if entry == null:
			continue
		var mirror := get_node_or_null(entry.mirror_path)
		if mirror == null:
			push_warning("TaskPuzzleArea: mirror_path not found → " + str(entry.mirror_path))
			continue
		var matched: bool = (entry.frequency == freq)
		mirror.visible = matched
		# Beam still reflects (raycast ignores collision-exceptions).
		# Player passes through when invisible.
		if mirror is RigidBody2D and player != null:
			if matched:
				mirror.remove_collision_exception_with(player)
			else:
				mirror.add_collision_exception_with(player)
		# Disable E / snap-zone interaction while invisible.
		var iz: Node = mirror.get_node_or_null("InteractZone")
		if iz != null and iz is Area2D:
			iz.set_deferred("monitoring", matched)
			iz.set_deferred("monitorable", matched)

func _on_body_entered(body: Node2D) -> void:
	# Group-based so it works for BOTH the real Sami and the test player.
	if body.is_in_group("Player"):
		_player_inside = true
		_last_radio = -9999
		_update_mirrors(RadioGlobal.radio)
		if puzzle_id != "":
			GameState.enter_puzzle(puzzle_id, puzzle_name)

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("Player"):
		_player_inside = false
