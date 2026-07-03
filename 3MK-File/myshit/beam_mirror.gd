extends RigidBody2D
class_name BeamMirror

enum RotationSystem { SNAP, HOLD_AND_ROTATE }

# ── Inspector ──────────────────────────────────────────────────────────────
@export_group("Rotation Control")
@export var rotation_system: RotationSystem = RotationSystem.SNAP

@export_subgroup("Snap Settings")
## Degrees rotated per 'action' press.
@export var snap_degrees: float = 45.0

@export_subgroup("Hold & Rotate Settings")
## Lerp speed toward input direction (higher = snappier).
@export var rotate_speed: float = 0.4

@export_group("Physics Feel")
## Higher = harder to get moving and harder to stop.
@export var mirror_mass: float = 10.0
## Higher = decelerates faster after a push.
@export var push_damping: float = 15.0
## Higher = stops spinning faster after a bump.
@export var spin_damping: float = 40.0
## Force applied while holding F.
@export var push_force: float = 6000.0

# Local offsets of the 4 snap squares relative to BeamMirror center
# (InteractZone pos (1,0) + each shape's local pos)
const _SNAP_ZONE_LOCAL_POS: Dictionary = {
	1: Vector2(20,  23),   # bottom-right
	2: Vector2(20, -20),   # top-right
	3: Vector2(-23, -22),  # top-left
	4: Vector2(-23,  25),  # bottom-left
}

# ── State ──────────────────────────────────────────────────────────────────
var _player_nearby: bool = false
var _player_body: Sami = null
var _grabbed: bool = false
var _snap_angle: float = 0.0
var _target_angle: float = 0.0

var _active_snap_zones: Dictionary = {}   # shape_index → true (player is physically inside)
var _player_locked: bool = false           # player is snapped & frozen at a zone
var _lock_world_pos: Vector2 = Vector2.ZERO
var _locked_zone_idx: int = -1

# ── Lifecycle ──────────────────────────────────────────────────────────────
func _ready() -> void:
	add_to_group("beam_mirror")
	mass          = mirror_mass
	linear_damp   = push_damping
	angular_damp  = spin_damping
	gravity_scale = 0.0
	can_sleep     = false
	_snap_angle   = rotation
	_target_angle = rotation
	$InteractZone.body_entered.connect(_on_interact_zone_body_entered)
	$InteractZone.body_exited.connect(_on_interact_zone_body_exited)
	$InteractZone.body_shape_entered.connect(_on_interact_zone_body_shape_entered)
	$InteractZone.body_shape_exited.connect(_on_interact_zone_body_shape_exited)
	var saved := GameState.get_mirror_state(get_tree().current_scene.scene_file_path, name)
	if not saved.is_empty():
		global_position = saved["position"]
		rotation        = saved["rotation"]
		_snap_angle     = rotation
		_target_angle   = rotation
	queue_redraw()

# ── Rotation input (E) ─────────────────────────────────────────────────────
func _input(event: InputEvent) -> void:
	if not _player_nearby:
		return

	match rotation_system:
		RotationSystem.SNAP:
			if event.is_action_pressed("action"):
				_snap_angle += deg_to_rad(snap_degrees)
				rotation = _snap_angle
				angular_velocity = 0.0

		RotationSystem.HOLD_AND_ROTATE:
			if event.is_action_pressed("action"):
				_grabbed = true
				_target_angle = rotation
				# If player is already standing in a snap zone, lock them immediately
				if not _active_snap_zones.is_empty():
					_lock_player(_active_snap_zones.keys()[0])
			elif event.is_action_released("action"):
				_grabbed = false
				_unlock_player()

# ── Lock / Unlock helpers ─────────────────────────────────────────────────
func _lock_player(zone_idx: int) -> void:
	if _player_body == null or _player_locked:
		return
	_locked_zone_idx  = zone_idx
	_lock_world_pos   = to_global(_SNAP_ZONE_LOCAL_POS[zone_idx])
	_player_body.global_position = _lock_world_pos
	_player_body.velocity        = Vector2.ZERO
	_player_body.can_move        = false
	_player_locked               = true

func _unlock_player() -> void:
	if not _player_locked:
		return
	_player_locked    = false
	_locked_zone_idx  = -1
	if _player_body != null:
		_player_body.can_move = true
		_player_body.ani.play("Idle")

# ── Physics process ────────────────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	if _player_nearby and Input.is_physical_key_pressed(KEY_F):
		if _player_body != null:
			_player_body.dragged_object = self
			var alignment := _get_input_vec().dot(_player_body.look_direction)
			if alignment > 0.1:
				apply_central_force(_player_body.look_direction * push_force)
			elif alignment < -0.1:
				apply_central_force(-_player_body.look_direction * push_force)
		return

	if _player_body != null and _player_body.dragged_object == self:
		_player_body.dragged_object = null

	if not _grabbed or rotation_system != RotationSystem.HOLD_AND_ROTATE:
		return

	var input_vec := _get_input_vec()

	if _player_locked:
		# Pin player to the snap point every frame so they can't drift
		_player_body.global_position = _lock_world_pos
		_player_body.velocity        = Vector2.ZERO
		# Show push animation matching WASD direction (looks like cranking the mirror)
		if input_vec.length_squared() > 0.01:
			_player_body.look_direction = -input_vec
			_player_body._play_anim(Sami.AnimState.PULL, -input_vec)
		else:
			_player_body.ani.play("Idle")

	if input_vec.length_squared() > 0.01:
		_target_angle = (-input_vec).angle()

	rotation         = lerp_angle(rotation, _target_angle, rotate_speed * delta)
	angular_velocity = 0.0
	linear_velocity  = Vector2.ZERO

func _get_input_vec() -> Vector2:
	return Vector2(
		Input.get_action_strength("right") - Input.get_action_strength("left"),
		Input.get_action_strength("down")  - Input.get_action_strength("up")
	)

# ── Visual ─────────────────────────────────────────────────────────────────
func _draw() -> void:
	draw_rect(Rect2(-6, -32, 12, 64), Color(0.75, 0.9, 1.0, 0.9))
	draw_rect(Rect2(-6, -32, 12, 64), Color(1.0, 1.0, 1.0, 0.8), false, 2.0)
	draw_line(Vector2(-5, -30), Vector2(-5, 30), Color(1, 1, 1, 0.5), 1.5)

# ── Snap zone shape tracking ───────────────────────────────────────────────
func _on_interact_zone_body_shape_entered(_body_rid: RID, body: Node2D, _body_shape: int, local_shape: int) -> void:
	if not body is Sami or local_shape not in _SNAP_ZONE_LOCAL_POS:
		return
	_active_snap_zones[local_shape] = true
	# Player walked into a zone while already holding E → snap them now
	if _grabbed and not _player_locked:
		_lock_player(local_shape)

func _on_interact_zone_body_shape_exited(_body_rid: RID, body: Node2D, _body_shape: int, local_shape: int) -> void:
	if body is Sami:
		_active_snap_zones.erase(local_shape)

# ── Proximity detection ────────────────────────────────────────────────────
func _on_interact_zone_body_entered(body: Node) -> void:
	if body is Sami:
		_player_nearby = true
		_player_body = body as Sami

func _on_interact_zone_body_exited(body: Node) -> void:
	if body is Sami:
		if _player_body != null and _player_body.dragged_object == self:
			_player_body.dragged_object = null
		_unlock_player()
		_player_nearby = false
		_player_body   = null
		_grabbed       = false
		_active_snap_zones.clear()
