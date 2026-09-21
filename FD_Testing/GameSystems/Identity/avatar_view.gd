class_name AvatarView
extends TextureRect
## Drop this anywhere in a UI scene and it shows the player's own picture as
## soon as PlayerIdentity has one. No code needed from the production team.

signal revealed

## Shown while there is no picture yet, and kept if none is ever found.
@export var fallback_texture: Texture2D
## Stay invisible until a real picture arrives, for a reveal moment.
@export var hide_until_ready: bool = false
## Wait this long after the picture arrives before showing it.
@export var reveal_delay: float = 0.0


func _ready() -> void:
	var pi := get_node_or_null("/root/PlayerIdentity")
	if pi == null:
		push_warning("AvatarView: PlayerIdentity autoload is missing.")
		texture = fallback_texture
		return
	texture = fallback_texture
	if hide_until_ready:
		visible = false
	if pi.has_avatar():
		_show(pi.get_avatar())
	else:
		pi.avatar_ready.connect(_show)


func _show(tex: Texture2D) -> void:
	if reveal_delay > 0.0:
		await get_tree().create_timer(reveal_delay).timeout
	texture = tex
	visible = true
	revealed.emit()
