extends Area2D

@export var configurations: Array[IndicatorConfig] = []
@onready var indicator_sprite: Sprite2D = $Sprite2D2

var _current_targets: Array[Node2D] = []

func _ready() -> void:
	indicator_sprite.hide()
	# Connect BOTH bodies and areas
	body_entered.connect(_on_node_entered)
	body_exited.connect(_on_node_exited)
	area_entered.connect(_on_node_entered)
	area_exited.connect(_on_node_exited)

# One function to handle both Areas and Bodies
func _on_node_entered(node: Node2D) -> void:
	for config in configurations:
		if node.is_in_group(config.target_group):
			_current_targets.append(node)
			_update_indicator()
			return

func _on_node_exited(node: Node2D) -> void:
	if node in _current_targets:
		_current_targets.erase(node)
		_update_indicator()

func _update_indicator() -> void:
	if _current_targets.is_empty():
		indicator_sprite.hide()
		return
		
	var active_target: Node2D = _current_targets.back()
	for config in configurations:
		if active_target.is_in_group(config.target_group):
			indicator_sprite.texture = config.icon
			indicator_sprite.show()
			return
