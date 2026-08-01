class_name WoundComponent extends Node
## Sami's damage + bleeding. Add as a child of the player NAMED "Wounds".
##
## THIS IS THE "DAMAGE CODE" the breath system was waiting for:
## when Sami gets cut, this opens a WOUND, and a wound is what makes him
## bleed — which is what feeds blood into the breath stages and the floor
## puzzle.
##
## HURT HIM from anywhere:
##     $Wounds.take_damage(1)                       # a plain hit
##     $Wounds.take_damage(1, "bleeding", true)     # a hit that CUTS
##     $Wounds.cut("bleeding")                      # a cut with no damage
## Patch him up:
##     $Wounds.bandage()          # stops the bleeding
##     $Wounds.heal(1)            # gives health back
##
## Bleeding can also drain health over time — set `bleed_damage` above 0
## if you want wounds to be a clock the player has to answer.

signal damaged(amount: float, cause_id: String)
signal wound_opened(cause_id: String)
signal wound_closed
signal health_changed(current: float, maximum: float)
signal died(cause_id: String)

@export_group("Health source")
## Property on the player holding the HealthData resource.
@export var stats_property: String = "stats"
## Leave EMPTY to auto-detect (current_health / health / hp / ...).
@export var health_property: String = ""
@export var max_health_property: String = ""
## Used only if the resource has no max property.
@export var fallback_max: float = 3.0

@export_group("Damage")
## Seconds of immunity after being hit, so one hazard can't chain-kill.
@export var invulnerable_seconds: float = 0.8
## Cause id used when damage kills him and no cause was given.
@export var default_death_cause: String = "bleeding"
## Kill him here when health hits 0. Turn OFF if HealthWatcher does it.
@export var handle_death: bool = true

@export_group("Bleeding")
## Where drips land, from Sami's origin — same idea as the Breath node's
## feet_offset. Keep the two the same so all blood lands together.
@export var feet_offset := Vector2(0, 30)
## Health lost per second while bleeding. 0 = bleeding costs no health
## (it only produces blood for the breath/puzzle systems).
@export var bleed_damage: float = 0.0
## He stops bleeding by himself after this long. 0 = bleeds until bandaged.
@export var bleed_seconds: float = 0.0
## Drip blood onto the floor while bleeding. This is the "every second"
## splatting — set drip_interval to whatever rhythm you want.
@export var drip_while_bleeding: bool = true
## Seconds between splats. Change freely (1.0 = one splat per second).
@export var drip_interval: float = 1.0
## Blood type for the drips. LEAVE EMPTY to use the blood of whichever
## breath stage he's currently in — so the trail matches his strain.
@export var drip_blood: BloodType

var is_bleeding: bool = false
var invuln: float = 0.0

var _player: Node2D
var _stats: Resource
var _prop: String = ""
var _max_prop: String = ""
var _bleed_left: float = 0.0
var _drip_timer: float = 0.0


func _ready() -> void:
	_player = get_parent() as Node2D
	await get_tree().process_frame
	_bind_stats()


func _bind_stats() -> void:
	if _player == null or not (stats_property in _player):
		push_warning("WoundComponent: '%s' not found on the player." % stats_property)
		return
	_stats = _player.get(stats_property)
	_prop = health_property if health_property != "" else HealthAccess.find_health(_stats)
	_max_prop = max_health_property if max_health_property != "" else HealthAccess.find_max(_stats)
	if _prop == "":
		push_warning("WoundComponent: couldn't find a health property. Set it manually.")
	else:
		print("WoundComponent: health = '%s', max = '%s'." % [_prop, _max_prop])


func _process(delta: float) -> void:
	if invuln > 0.0:
		invuln = maxf(0.0, invuln - delta)
	if not is_bleeding or Deaths.is_dead:
		return

	if bleed_damage > 0.0:
		_change_health(-bleed_damage * delta, default_death_cause)

	if bleed_seconds > 0.0:
		_bleed_left -= delta
		if _bleed_left <= 0.0:
			stop_bleeding()

	if drip_while_bleeding and _player:
		_drip_timer -= delta
		if _drip_timer <= 0.0:
			_drip_timer = drip_interval
			var t := _drip_type()
			if t:
				BloodWorld.spill(t, _player.global_position + feet_offset)


# --- getting hurt ----------------------------------------------------------

## The main entry point. `opens_wound` makes him start bleeding.
func take_damage(amount: float, cause_id: String = "", opens_wound: bool = false) -> void:
	if Deaths.is_dead or invuln > 0.0:
		return
	invuln = invulnerable_seconds
	var cause: String = cause_id if cause_id != "" else default_death_cause
	if amount > 0.0:
		_change_health(-amount, cause)
		damaged.emit(amount, cause)
	if opens_wound:
		cut(cause)


## Open a wound without dealing damage (a shallow cut that just bleeds).
func cut(cause_id: String = "") -> void:
	if is_bleeding:
		_bleed_left = bleed_seconds       # a fresh cut restarts the clock
		return
	is_bleeding = true
	_bleed_left = bleed_seconds
	_drip_timer = drip_interval
	_set_breath_bleeding(true)
	wound_opened.emit(cause_id if cause_id != "" else default_death_cause)


## Stop the bleeding (bandage, med kit, a nurse...).
func bandage() -> void:
	stop_bleeding()


func stop_bleeding() -> void:
	if not is_bleeding:
		return
	is_bleeding = false
	_bleed_left = 0.0
	_set_breath_bleeding(false)
	wound_closed.emit()


func heal(amount: float) -> void:
	_change_health(amount, "")


func full_heal() -> void:
	stop_bleeding()
	_change_health(HealthAccess.get_max(_stats, _max_prop, fallback_max), "")


## Which blood to drip: the explicit one, or the current breath stage's.
func _drip_type() -> BloodType:
	if drip_blood:
		return drip_blood
	var b := _player.get_node_or_null("Breath") if _player else null
	if b and "stage_blood" in b:
		var arr: Array = b.stage_blood
		var idx: int = int(b.stage)
		if idx < 0:
			idx = 0                      # not holding: use the first stage
		if idx < arr.size():
			return arr[idx]
	return null


# --- internals -------------------------------------------------------------

func _change_health(delta_hp: float, cause_id: String) -> void:
	if _stats == null or _prop == "":
		return
	var maximum := HealthAccess.get_max(_stats, _max_prop, fallback_max)
	var hp := HealthAccess.get_health(_stats, _prop)
	hp = clampf(hp + delta_hp, 0.0, maximum)
	HealthAccess.set_health(_stats, _prop, hp)
	health_changed.emit(hp, maximum)
	if hp <= 0.0 and handle_death and not Deaths.is_dead:
		died.emit(cause_id)
		Deaths.kill(cause_id if cause_id != "" else default_death_cause)


## Keeps the breath component's bleeding flag in sync, so the 4 stages
## know whether to spill blood.
func _set_breath_bleeding(value: bool) -> void:
	var b := _player.get_node_or_null("Breath") if _player else null
	if b and "is_bleeding" in b:
		b.is_bleeding = value
