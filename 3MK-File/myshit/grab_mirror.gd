class_name GrabMirror extends CharacterBody2D

# A mirror you can push/pull (hold F) and rotate (hold E).
# Stays in the "beam_mirror" group so the beam still bounces off it.
#
# unlock_frequency > 0 puts it behind the radio:
#   LOCKED - signal never caught, mirror simply isn't there (no beam, no collision)
#   HIDDEN - caught but dial is elsewhere: invisible + walk-through, beam still bounces
#   ACTIVE - dial sits on its frequency: this is the mirror you're handling
# the dial is how the player switches between proc'd mirrors.

enum MirrorState { LOCKED, HIDDEN, ACTIVE }

# preload instead of the class_name — same class-cache reason as radio_signal_manager
const QSig := preload("res://3MK-File/script/quest_signal.gd")

@export var bar_color: Color = Color(0.75, 0.9, 1.0, 0.9)
@export var grabbed_color: Color = Color(1.0, 0.95, 0.55, 0.95)
## Radio frequency that procs this mirror into existence. 0 = always there.
@export_range(0, 1700) var unlock_frequency: int = 0

var _focused_player: Player = null
var _is_grabbed: bool = false
var _state: MirrorState = MirrorState.ACTIVE
var _beacon: Node2D = null


func _ready() -> void:
	add_to_group("beam_mirror")
	add_to_group("grabbable")
	$InteractZone.body_entered.connect(_on_zone_entered)
	$InteractZone.body_exited.connect(_on_zone_exited)
	queue_redraw()
	if unlock_frequency > 0:
		visible = false   # no first-frame flash, real state lands below
		_apply_state.call_deferred(_pick_state())


func _process(_delta: float) -> void:
	if unlock_frequency <= 0 or _state == MirrorState.LOCKED:
		return
	var next := _pick_state()
	if next != _state:
		_apply_state(next)


func _pick_state() -> MirrorState:
	if not RadioSignals.is_caught(unlock_frequency):
		return MirrorState.LOCKED
	if absf(RadioGlobal.radio - unlock_frequency) <= RadioSignals.BAND_FULL:
		return MirrorState.ACTIVE
	return MirrorState.HIDDEN


func _apply_state(next: MirrorState) -> void:
	_state = next
	var player := get_tree().get_first_node_in_group("Player")
	match next:
		MirrorState.LOCKED:
			visible = false
			$CollisionShape2D.set_deferred("disabled", true)
			_set_zone(false)
			_spawn_beacon()
		MirrorState.HIDDEN:
			visible = false
			$CollisionShape2D.set_deferred("disabled", false)
			_set_zone(false)
			_drop_player()
			_let_player_through(player, true)
		MirrorState.ACTIVE:
			visible = true
			$CollisionShape2D.set_deferred("disabled", false)
			_set_zone(true)
			if not _is_grabbed:
				_let_player_through(player, false)


func _set_zone(on: bool) -> void:
	$InteractZone.set_deferred("monitoring", on)
	$InteractZone.set_deferred("monitorable", on)


func _let_player_through(player: Node, on: bool) -> void:
	if not player is PhysicsBody2D:
		return
	if on:
		add_collision_exception_with(player)
		player.add_collision_exception_with(self)
	else:
		remove_collision_exception_with(player)
		player.remove_collision_exception_with(self)


# going invisible mid-grab: put the mirror down so the player
# isn't dragging something they can't see
func _drop_player() -> void:
	if _focused_player == null:
		return
	if _focused_player.grabbed == self:
		_focused_player.end_grab()
	if _focused_player.focus_grabbable == self:
		_focused_player.focus_grabbable = null
	_focused_player = null


func _spawn_beacon() -> void:
	if _beacon != null:
		return
	_beacon = QSig.new()
	_beacon.quest_type = QSig.Type.SIDE
	_beacon.frequency = unlock_frequency
	add_child(_beacon)
	if not RadioSignals.side_signal_caught.is_connected(_on_signal_caught):
		RadioSignals.side_signal_caught.connect(_on_signal_caught)


func _on_signal_caught(freq: int) -> void:
	if freq != unlock_frequency:
		return
	RadioSignals.side_signal_caught.disconnect(_on_signal_caught)
	if _beacon != null:
		_beacon.queue_free()
		_beacon = null
	# catching means the dial is already sitting on us, so we come in ACTIVE
	_apply_state(MirrorState.ACTIVE)
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.4)


func rotate_by(amount: float) -> void:
	rotation += amount


func on_grabbed(player: Node) -> void:
	_is_grabbed = true
	add_collision_exception_with(player)   # so we don't block each other
	queue_redraw()


func on_released(player: Node) -> void:
	_is_grabbed = false
	velocity = Vector2.ZERO
	if _state == MirrorState.ACTIVE:
		remove_collision_exception_with(player)
	queue_redraw()


# Only the test Player has focus_grabbable. The real Sami is also in the "Player"
# group, so check the type or it errors when Sami walks near.
func _on_zone_entered(body: Node) -> void:
	if body is Player:
		_focused_player = body
		body.focus_grabbable = self


func _on_zone_exited(body: Node) -> void:
	if body == _focused_player:
		if _focused_player.focus_grabbable == self:
			_focused_player.focus_grabbable = null
		_focused_player = null


# just a bar with a dot on one end so you can see which way it points
func _draw() -> void:
	var col: Color = grabbed_color if _is_grabbed else bar_color
	draw_rect(Rect2(-6, -32, 12, 64), col)
	draw_rect(Rect2(-6, -32, 12, 64), Color(1, 1, 1, 0.8), false, 2.0)
	draw_circle(Vector2(0, -32), 4.0, Color(1, 1, 1, 0.9))
