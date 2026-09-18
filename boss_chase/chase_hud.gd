class_name ChaseHud extends CanvasLayer

# Three readouts: your hearts, the boss's, and how much corridor is left.
# The corridor bar matters more than it looks — it's the actual clock, and
# without it the dead end arrives as a surprise.

@export var runner: Node2D
@export var boss: Node2D
@export var finish_y: float = 2032.0

@onready var runner_label: Label = $Root/Rows/RunnerHp
@onready var boss_label: Label = $Root/Rows/BossHp
@onready var corridor_bar: ProgressBar = $Root/Rows/Corridor

var _start_y: float = 0.0


func _ready() -> void:
	if runner != null:
		_start_y = runner.global_position.y
		runner.health_changed.connect(_on_runner_health)
		_on_runner_health(runner.stats.current_health if runner.stats else 0)
	if boss != null:
		boss.health_changed.connect(_on_boss_health)
		_on_boss_health(boss.stats.current_health if boss.stats else 0)


func _process(_delta: float) -> void:
	if runner == null:
		return
	var total: float = maxf(finish_y - _start_y, 1.0)
	var travelled: float = clampf(runner.global_position.y - _start_y, 0.0, total)
	corridor_bar.value = (travelled / total) * 100.0


func _on_runner_health(current: int) -> void:
	runner_label.text = "YOU   " + "@".repeat(maxi(current, 0))


func _on_boss_health(current: int) -> void:
	boss_label.text = "BOSS  " + "X".repeat(maxi(current, 0))
