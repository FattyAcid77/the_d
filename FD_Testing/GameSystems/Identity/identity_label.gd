class_name IdentityLabel
extends Label
## Drop-in Label for the production team: write the template with tokens and it
## fills itself in, e.g. "PATIENT: {name}" or "{pc_user}@{pc_name}".
## Tokens: {id} {username} {nickname} {name} {pc_user} {pc_name} {wallpaper}

## The text with tokens. Leave empty to use whatever is already in Text.
@export_multiline var template: String = ""
## Refill when the identity arrives later, not only at _ready.
@export var follow_updates: bool = true


func _ready() -> void:
	if template == "":
		template = text
	var pi := get_node_or_null("/root/PlayerIdentity")
	if pi == null:
		push_warning("IdentityLabel: PlayerIdentity autoload is missing.")
		return
	_fill()
	if follow_updates:
		pi.identity_ready.connect(func(_info): _fill())
		pi.wallpaper_ready.connect(func(_tex): _fill())


func _fill() -> void:
	var pi := get_node_or_null("/root/PlayerIdentity")
	if pi:
		text = pi.format(template)
