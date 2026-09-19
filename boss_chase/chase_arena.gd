class_name ChaseArena extends Node2D

# The referee. Owns win/lose, freezes the fight, shows the overlay, restarts.
#
# Extends Node2D and NOT `Level` on purpose: Main Scenes/Level_trans_script.gd
# hands itself to SceneManager and expects a Player, doors and a
# LevelDataHandoff. We want none of that plumbing.

const CORRIDOR_WIDTH: float = 176.0
const ART_SCALE: float = 0.458333       # corridor art pixels -> game pixels

#region /// reading MAP.png as a tile grid
## MAP.png is one printed section of corridor on a 16px grid: a beam across the
## top with its two corners, then a stretch of side wall carrying the joint
## marks. Laying it as tiles instead of a repeating sprite is what keeps the
## beams on an exact interval and lets the dead end be capped.
const TILE_WORLD: float = 16.0 * ART_SCALE   # one tile, in game pixels
const MAP_COL_LEFT: int = 7                  # the left wall's column in MAP.png
const MAP_ROW_BEAM: int = 1                  # the beam's row in MAP.png
const SECTION_ROWS: int = 34                 # beam + wall = one printed section
const CORRIDOR_TILES: int = 24               # CORRIDOR_WIDTH / TILE_WORLD
#endregion
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

#region /// tuning — the whole chase, from one inspector
# Every number the fight runs on lives here and is pushed onto the runner, the
# boss and each bin as they are built. Nothing below reads its own defaults at
# runtime, so this node is the only place worth editing.

@export_group("Health")
## Hits the rat can take. The bar art has four segments, so four lines up
## exactly — any other number still works, it just scales onto those four.
@export var runner_health: int = 4
## Parried bins needed to finish the cat. Keep `rolling_cans` at least double
## this or the fight cannot be won.
@export var boss_health: int = 6

@export_group("Runner")
## Forward speed. Also sets the corridor's length, since `chase_seconds` is
## measured in seconds of running.
@export var run_speed: float = 90.0
@export var dodge_speed: float = 120.0
## Press the parry this early and it still lands.
@export var parry_window: float = 0.12
## Swinging at empty air costs you this long before you can swing again.
@export var parry_lockout: float = 0.40
## How close a bin has to be to swat it. Smaller = more timing, less area.
@export var parry_reach: float = 32.0

@export_group("Bins")
## How fast a shoved bin rolls up at you. You are running into it, so you close
## at this PLUS your own run speed.
@export var bin_speed: float = 140.0
## How far a shoved bin travels before it runs out of steam.
@export var bin_travel: float = 260.0
## How far ahead of you a bin must sit before the cat will send it — this is
## your reaction time, in distance.
@export var bin_lead: float = 150.0
## How long a parried bin takes to reach the cat. Higher = slower, more readable.
@export var parried_bin_time: float = 0.85
@export var parried_bin_travel: float = 320.0

@export_group("Boss")
## Match it to `run_speed` and the gap only moves when something slows you.
@export var boss_speed: float = 90.0
## How slowly it limps while staggered by a parry.
@export var boss_stagger_speed: float = 40.0
## How long a parry staggers it.
@export var boss_stagger_time: float = 0.9
## Let it close to this and it has you — the run ends.
@export var catch_lead: float = 24.0
## Minimum rest between any two moves. Keep it above the 1.2s attack animation
## or one slam will cut the next short.
@export var move_gap: float = 1.5
@export var shove_cooldown: float = 2.2
@export var wave_cooldown: float = 4.0
## How far the cat can reach to grab a bin.
@export var shove_range: float = 380.0
## How far out it will still fire the lane strike.
@export var wave_range: float = 420.0

@export_group("Slam")
## Seconds into the attack animation when the paw lands — frame 3 of 8 at
## 6.667 fps. The lane aims for exactly this long, so the strike goes off ON the
## slam. Change it and the two drift apart.
@export var slam_impact: float = 0.45
## How long the lane stays lethal after it fires.
@export var wave_fire_time: float = 0.25
## Width of the lane. Narrower is easier to step out of.
@export var wave_lane_width: float = 56.0
@export var wave_damage: int = 1
#endregion

var _finished: bool = false
var _length: float = 0.0


func _ready() -> void:
	_apply_tuning()
	_build_corridor()
	_fill_corridor()
	if dead_end != null:
		dead_end.body_entered.connect(_on_dead_end_entered)
	if runner != null:
		runner.died.connect(func(): lose("You ran out of health."))
	if boss != null:
		boss.defeated.connect(win)
		boss.caught.connect(func(): lose("The boss caught you."))
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


# Push the inspector's numbers onto whoever actually uses them. Bins get theirs
# in _fill_corridor as they are made, since they do not exist yet.
func _apply_tuning() -> void:
	if runner != null:
		_set_health(runner.stats, runner_health)
		runner.run_speed = run_speed
		runner.dodge_speed = dodge_speed
		runner.parry_buffer = parry_window
		runner.parry_lockout = parry_lockout
	if boss != null:
		_set_health(boss.stats, boss_health)
		boss.run_speed = boss_speed
		boss.recover_speed = boss_stagger_speed
		boss.recover_time = boss_stagger_time
		boss.catch_lead = catch_lead
		boss.move_gap = move_gap
		boss.shove_cooldown = shove_cooldown
		boss.wave_cooldown = wave_cooldown
		boss.telekinesis_range = shove_range
		boss.wave_range = wave_range
		boss.roll_lead_min = bin_lead
		boss.slam_impact = slam_impact
		boss.wave_fire_time = wave_fire_time
		boss.wave_lane_width = wave_lane_width
		boss.wave_damage = wave_damage

	# Children are ready before we are, so the HUD already drew itself off the
	# old health values. Tell it to look again now that ours have landed.
	var hud: Node = get_node_or_null("Hud")
	if hud != null and hud.has_method("refresh"):
		hud.refresh()


# max first, then current: HealthData clamps current down to max as you set it.
func _set_health(stats: HealthData, amount: int) -> void:
	if stats == null:
		return
	stats.max_health = maxi(amount, 1)
	stats.current_health = stats.max_health


#region /// building the corridor

# Everything with a length takes it from `chase_seconds`: the floor, the side
# walls, the far wall, the dead end, the wall art and the HUD's bar.
func _build_corridor() -> void:
	if world == null:
		return
	_length = maxf(chase_seconds, 5.0) * maxf(run_speed, 1.0)

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

	var walls_art: TileMapLayer = world.get_node_or_null("Walls")
	if walls_art != null:
		_paint_walls(walls_art)

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


# Print the corridor one section at a time, straight from the sheet: row k of
# every section is row k of MAP.png, so the beams land on an exact interval and
# the joint marks keep the spacing the artist drew. The dead end gets the beam
# again, flipped, which is the only way to cap it without inventing new art.
func _paint_walls(walls: TileMapLayer) -> void:
	walls.clear()
	var right_col: int = CORRIDOR_TILES + 1
	# Stop the side walls level with the dead end, not with the nominal corridor
	# length — the camera clamps before that and the cap would never be seen.
	var rows: int = int(floor((_length - 16.0) / TILE_WORLD))
	for r in rows:
		var atlas_row: int = MAP_ROW_BEAM + r % SECTION_ROWS
		walls.set_cell(Vector2i(0, r), 0, Vector2i(MAP_COL_LEFT, atlas_row))
		walls.set_cell(Vector2i(right_col, r), 0, Vector2i(MAP_COL_LEFT + right_col, atlas_row))
		if r % SECTION_ROWS == 0:
			for c in range(1, right_col):
				walls.set_cell(Vector2i(c, r), 0, Vector2i(MAP_COL_LEFT + c, MAP_ROW_BEAM))

	for c in right_col + 1:
		walls.set_cell(Vector2i(c, rows), 0, Vector2i(MAP_COL_LEFT + c, MAP_ROW_BEAM),
			TileSetAtlasSource.TRANSFORM_FLIP_V)


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
		can.roll_speed = bin_speed
		can.roll_distance = bin_travel
		can.parry_reach = parry_reach
		can.reverse_distance = parried_bin_travel
		can.reverse_time = parried_bin_time
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
