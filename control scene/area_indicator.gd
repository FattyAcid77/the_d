extends Area2D
## Universal "press this button" indicator.
##
## Drop it under the player. Anything that walks into range and belongs to one
## of the groups in `configurations` makes the matching button appear above it.
## Add a group to the list and it works — no code per interactable.
##
## Each config can carry two images, one for keyboard and one for a controller,
## and the indicator swaps them the moment the player changes input device.

@export var configurations: Array[IndicatorConfig] = []

## Turn on to print what enters and leaves, when something is not showing up.
@export var debug: bool = false

@onready var indicator_sprite: Sprite2D = $Sprite2D2

var _current_targets: Array[Node2D] = []
var _using_gamepad: bool = false


func _ready() -> void:
	indicator_sprite.hide()
	# Connected here, in code, ON PURPOSE. The scene used to also wire these
	# in the .tscn to methods that did not exist, which threw an error every
	# single time anything touched the area.
	body_entered.connect(_on_node_entered)
	body_exited.connect(_on_node_exited)
	area_entered.connect(_on_node_entered)
	area_exited.connect(_on_node_exited)


## Watches which device the player last used, so the prompt matches the pad in
## their hands. Stick drift would flip this constantly, hence the deadzone.
func _input(event: InputEvent) -> void:
	var pad: bool = event is InputEventJoypadButton
	if event is InputEventJoypadMotion and absf(event.axis_value) > 0.5:
		pad = true
	var keys: bool = event is InputEventKey or event is InputEventMouseButton

	if pad and not _using_gamepad:
		_using_gamepad = true
		_update_indicator()
	elif keys and _using_gamepad:
		_using_gamepad = false
		_update_indicator()


func _on_node_entered(node: Node2D) -> void:
	if _config_for(node) == null:
		return
	if node in _current_targets:
		return   # a node can arrive through both body_ and area_entered
	_current_targets.append(node)
	if debug:
		print("[indicator] entered: %s" % node.name)
	_update_indicator()


func _on_node_exited(node: Node2D) -> void:
	if node in _current_targets:
		_current_targets.erase(node)
		if debug:
			print("[indicator] exited: %s" % node.name)
		_update_indicator()


## The most recently arrived target wins, so walking up to a second thing
## swaps the prompt to it rather than keeping the first one.
func _update_indicator() -> void:
	# Written as a loop, not .filter(): filter returns an untyped Array, which
	# will not assign back into Array[Node2D].
	var alive: Array[Node2D] = []
	for node in _current_targets:
		if is_instance_valid(node):
			alive.append(node)
	_current_targets = alive
	if _current_targets.is_empty():
		indicator_sprite.hide()
		return

	var config: IndicatorConfig = _config_for(_current_targets.back())
	if config == null:
		indicator_sprite.hide()
		return

	var tex: Texture2D = _icon_for(config)
	if tex == null:
		indicator_sprite.hide()
		return
	indicator_sprite.texture = tex
	indicator_sprite.show()


## First config whose group this node belongs to, or null.
func _config_for(node: Node) -> IndicatorConfig:
	for config in configurations:
		if config == null or config.target_group == &"":
			continue
		if node.is_in_group(config.target_group):
			return config
	return null


## Falls back to the keyboard image when a config has no controller one, so a
## half-filled config still shows something instead of vanishing.
func _icon_for(config: IndicatorConfig) -> Texture2D:
	if _using_gamepad and config.icon_gamepad != null:
		return config.icon_gamepad
	return config.icon
