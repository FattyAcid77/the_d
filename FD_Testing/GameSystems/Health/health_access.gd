class_name HealthAccess
## Small helper so every system reads Sami's health the same way, without
## me knowing your HealthData's exact property names.
##
## It looks for the first property that exists out of a list of common
## names. If your resource uses something unusual, pass the name explicitly.

const HEALTH_NAMES := ["current_health", "health", "hp", "current_hp",
		"health_current", "value", "amount"]
const MAX_NAMES := ["max_health", "health_max", "max_hp", "total_health", "max"]


## Find the property holding the CURRENT health. "" if not found.
static func find_health(stats: Object) -> String:
	if stats == null:
		return ""
	for n in HEALTH_NAMES:
		if n in stats:
			return n
	return ""


## Find the property holding MAX health. "" if not found.
static func find_max(stats: Object) -> String:
	if stats == null:
		return ""
	for n in MAX_NAMES:
		if n in stats:
			return n
	return ""


static func get_health(stats: Object, prop: String) -> float:
	if stats == null or prop == "" or not (prop in stats):
		return 0.0
	return float(stats.get(prop))


static func set_health(stats: Object, prop: String, value: float) -> void:
	if stats == null or prop == "" or not (prop in stats):
		return
	# keep ints as ints if that's what the resource uses
	var current = stats.get(prop)
	if typeof(current) == TYPE_INT:
		stats.set(prop, int(round(value)))
	else:
		stats.set(prop, value)


static func get_max(stats: Object, prop: String, fallback: float = 3.0) -> float:
	if stats == null or prop == "" or not (prop in stats):
		return fallback
	return float(stats.get(prop))
