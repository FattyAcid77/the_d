class_name HealthWatcher extends Node
## Connects HEALTH to DEATH. Add this as a child of Sami.
##
## It watches his `stats` resource (HealthData) and calls Deaths.kill()
## the moment health reaches 0. Because I don't know your HealthData's exact
## property names, it AUTO-DETECTS the common ones — check the Output panel
## on first run: it prints which property it locked onto.
##
## If it can't find it, set `health_property` yourself in the inspector.

## Property on the player holding the health resource.
@export var stats_property: String = "stats"

## Name of the health value inside that resource. Leave EMPTY to auto-detect
## (tries current_health, health, hp, current_hp, health_current...).
@export var health_property: String = ""

## Which DeathCause is used when health runs out.
@export var death_cause: String = "bleeding"

## Ignore damage deaths while the player is holding their breath?
## (The breath mechanic already blocks toxic death; this covers the rest.)
@export var immune_while_holding_breath: bool = false

const CANDIDATES := ["current_health", "health", "hp", "current_hp",
		"health_current", "value", "amount"]

var _stats: Resource
var _prop: String = ""
var _player: Node


func _ready() -> void:
	_player = get_parent()
	await get_tree().process_frame          # let the player set itself up
	_find_stats()


func _find_stats() -> void:
	if _player == null or not (stats_property in _player):
		push_warning("HealthWatcher: '%s' not found on %s." % [stats_property, _player])
		return
	_stats = _player.get(stats_property)
	if _stats == null:
		return
	if health_property != "":
		_prop = health_property
	else:
		for c in CANDIDATES:
			if c in _stats:
				_prop = c
				break
	if _prop == "":
		push_warning("HealthWatcher: couldn't find a health value on %s. " % _stats
				+ "Set `health_property` manually.")
	else:
		print("HealthWatcher: watching '%s' on the player's health resource." % _prop)


func _process(_delta: float) -> void:
	if _stats == null or _prop == "":
		return
	if Deaths.is_dead:
		return
	if immune_while_holding_breath and _is_holding_breath():
		return
	var hp: float = float(_stats.get(_prop))
	if hp <= 0.0:
		Deaths.kill(death_cause)


func _is_holding_breath() -> bool:
	var b := _player.get_node_or_null("Breath")
	return b != null and b.get("is_holding") == true
