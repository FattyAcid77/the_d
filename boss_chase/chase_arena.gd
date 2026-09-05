class_name ChaseArena extends Node2D

# The referee. Owns win/lose, freezes the fight, shows the overlay, restarts.
#
# Extends Node2D and NOT `Level` on purpose: Main Scenes/Level_trans_script.gd
# hands itself to SceneManager and expects a Player, doors and a
# LevelDataHandoff. We want none of that plumbing.

const RunnerScript := preload("res://boss_chase/chase_runner.gd")

const CORRIDOR_WIDTH: float = 176.0
const ART_SCALE: float = 0.458333       # corridor art pixels -> game pixels
const FIRST_CAN: float = 260.0          # nothing to dodge until you have settled in
const LAST_CAN_MARGIN: float = 220.0    # a clear run into the dead end
## Fixed lane pattern. Nothing here is random - the same numbers always build
## the same corridor.
const LANES: Array[float] = [88.0, 40.0, 136.0, 64.0, 112.0, 30.0, 146.0, 100.0, 55.0, 125.0]

## How many seconds of running the corridor is worth, at full speed. This is the
## whole length of the level - change it and everything below rebuilds.
@export var chase_seconds: float = 143.0

## Bins the boss can grab and roll at you. Every one you parry costs it a heart,
## so keep this at least double its health or the fight cannot be won.
@export var rolling_cans: int = 36

## Bins that only sit there and hurt on contact.
@export var still_cans: int = 20

@export var can_scene: PackedScene

@export var world: Node2D
@export var runner: Node2D
@export var boss: Node2D
@export var dead_end: Area2D
@export var overlay: CanvasLayer

var _finished: bool = false
var _length: float = 0.0


func _ready() -> void:
	_build_corridor()
	_fill_corridor()
	if dead_end != null:
		dead_end.body_entered.connect(_on_dead_end_entered)
	if runner != null:
		runner.died.connect(func(): lose("The boss got you."))
	if boss != null:
		boss.defeated.connect(win)
	if overlay != null:
		overlay.restart_pressed.connect(restart)
		overlay.hide_result()

	_intro()


# Notice, then run. The cat gets up while the rat is still looking back, then
# waits on the spot until the rat actually goes.
func _intro() -> void:
	if runner == null or boss == null:
		return
	runner.hold()
	boss.hold()
	boss.notice()
	await runner.notice()
	if _finished:
		return
	runner.go()
	boss.go()


#region /// building the corridor

# Everything with a length takes it from `chase_seconds`: the floor, the side
# walls, the far wall, the dead end, the wall art and the HUD's bar.
func _build_corridor() -> void:
	if world == null:
		return
	_length = maxf(chase_seconds, 5.0) * RunnerScript.RUN_SPEED

	var floor_art: Polygon2D = world.get_node_or_null("Floor")
	if floor_art != null:
		floor_art.polygon = PackedVector2Array([
			Vector2(0.0, 0.0), Vector2(CORRIDOR_WIDTH, 0.0),
			Vector2(CORRIDOR_WIDTH, _length), Vector2(0.0, _length)])

	for side in ["Bounds/WallLeft", "Bounds/WallRight"]:
		var wall: Node2D = world.get_node_or_null(side)
		if wall == null:
			continue
		wall.position.y = _length * 0.5
		var box: CollisionShape2D = wall.get_node_or_null("CollisionShape2D")
		if box != null and box.shape is RectangleShape2D:
			# duplicated because both walls share the one shape resource
			var shape: RectangleShape2D = box.shape.duplicate()
			shape.size = Vector2(16.0, _length + 128.0)
			box.shape = shape

	var far_wall: Node2D = world.get_node_or_null("Bounds/WallBottom")
	if far_wall != null:
		far_wall.position.y = _length + 8.0
	if dead_end != null:
		dead_end.position.y = _length - 16.0

	var walls_art: Sprite2D = world.get_node_or_null("Walls")
	if walls_art != null:
		walls_art.region_rect = Rect2(96.0, 16.0, 448.0, (_length + 32.0) / ART_SCALE)

	var hud: Node = get_node_or_null("Hud")
	if hud != null and "finish_y" in hud:
		hud.finish_y = _length - 16.0

	# The camera clamps itself to a fixed rect at startup, which used to stop
	# dead at the old corridor's end and let the runner walk out of frame.
	var cam: Camera2D = runner.get_node_or_null("Camera2D") if runner != null else null
	if cam != null:
		cam.limit_top = -16
		cam.limit_bottom = int(_length + 16.0)
		cam.reset_smoothing()


# One line of bins down the corridor, evenly spaced, with the rolling ones
# spread evenly through it - so the parry chances arrive at a steady rate
# instead of clumping.
func _fill_corridor() -> void:
	if world == null or can_scene == null:
		return
	var parent: Node = world.get_node_or_null("Obstacles")
	if parent == null:
		return
	var rollers: int = maxi(rolling_cans, 0)
	var total: int = rollers + maxi(still_cans, 0)
	if total <= 0:
		return
	var span: float = maxf(_length - FIRST_CAN - LAST_CAN_MARGIN, 0.0)
	var made: int = 0
	for i in total:
		var can: Node2D = can_scene.instantiate()
		var want: int = int(round(float(i + 1) * rollers / float(total)))
		can.rolls = want > made
		if can.rolls:
			made += 1
		can.position = Vector2(LANES[i % LANES.size()],
			FIRST_CAN + span * float(i) / float(total))
		parent.add_child(can)

#endregion


func _on_dead_end_entered(body: Node2D) -> void:
	if body.is_in_group("chase_runner"):
		lose("You hit the dead end.")


func lose(reason: String) -> void:
	_finish("GAME OVER", reason)


func win() -> void:
	_finish("YOU WIN", "The boss is down.")


func _finish(title: String, subtitle: String) -> void:
	if _finished:
		return          # both lose conditions can land on the same frame
	_finished = true

	if runner != null:
		runner.stop()
	if boss != null:
		boss.stop()

	# Freeze only OUR gameplay. Don't touch get_tree().paused — the PauseMenu
	# autoload owns that flag in every scene, and if we set it too then Escape
	# would silently un-freeze a game that's already over.
	#
	# Deferred because we get here from inside a physics callback — either the
	# DeadEnd's body_entered or the boss's overlap poll — and disabling a
	# CollisionObject mid-callback is not allowed.
	if world != null:
		world.set_deferred("process_mode", Node.PROCESS_MODE_DISABLED)

	if overlay != null:
		overlay.show_result(title, subtitle)


func restart() -> void:
	# If the player hit Escape on the game-over screen the tree is paused, and
	# reload_current_scene() on a paused tree leaves you stuck staring at it.
	get_tree().paused = false
	SceneManager.reload_current_scene()
