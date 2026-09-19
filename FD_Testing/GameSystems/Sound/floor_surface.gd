class_name FloorSurface extends Area2D
## Area that names the floor ("wet", "metal"). Sounds played from a body
## inside it use that surface's variant from SoundDef.surface_variants.

@export var surface: String = "tile"

## Only bodies in this group count.
@export var body_group: String = ""

@export_group("Debug")
@export var debug_log: bool = false


func _ready() -> void:
	body_entered.connect(_on_entered)
	body_exited.connect(_on_exited)


func _counts(body: Node2D) -> bool:
	return body != null and (body_group == "" or body.is_in_group(body_group))


func _on_entered(body: Node2D) -> void:
	if not _counts(body):
		return
	var snd := get_node_or_null("/root/Sound")
	if snd and snd.has_method("_surface_enter"):
		snd._surface_enter(body, self)
		if debug_log:
			print("FloorSurface '%s': %s now on '%s'." % [name, body.name, surface])


func _on_exited(body: Node2D) -> void:
	if not _counts(body):
		return
	var snd := get_node_or_null("/root/Sound")
	if snd and snd.has_method("_surface_exit"):
		snd._surface_exit(body, self)
