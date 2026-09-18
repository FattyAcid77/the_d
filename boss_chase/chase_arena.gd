class_name ChaseArena extends Node2D

# The referee. Owns win/lose, freezes the fight, shows the overlay, restarts.
#
# Extends Node2D and NOT `Level` on purpose: Main Scenes/Level_trans_script.gd
# hands itself to SceneManager and expects a Player, doors and a
# LevelDataHandoff. We want none of that plumbing.

@export var world: Node2D
@export var runner: Node2D
@export var boss: Node2D
@export var dead_end: Area2D
@export var overlay: CanvasLayer

var _finished: bool = false


func _ready() -> void:
	if dead_end != null:
		dead_end.body_entered.connect(_on_dead_end_entered)
	if runner != null:
		runner.died.connect(func(): lose("The boss got you."))
	if boss != null:
		boss.defeated.connect(win)
	if overlay != null:
		overlay.restart_pressed.connect(restart)
		overlay.hide_result()


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
	get_tree().reload_current_scene()
