class_name ChaseHealthBar extends Node2D

# The rat's hearts drawn as the ECG readout. Grey is charge you still have; a
# segment going solid black is one you have lost, and they black out right to
# left. Full is every segment grey, empty is the whole trace black.
#
# The face beside it carries the same reading in its own language — one idle per
# level, and it only ever leaves that idle to flinch.

## Segments the bar art is drawn with. Health is scaled onto these, so the bar
## still reads right if the runner's max health changes.
const LEVELS: int = 4

const ANIM_HURT := "hurt"
const ANIM_DIED := "died"

## The face for each level, indexed by segments left: none, one, half, most,
## full. Drawn that way on the sheet, so the order here is the sheet's order.
const FACE: Array[String] = ["died", "alert", "idle3", "idle2", "idle1"]

@onready var bar: AnimatedSprite2D = $Bar
@onready var icon: AnimatedSprite2D = $Icon

var _level: int = LEVELS


func _ready() -> void:
	bar.animation_finished.connect(_settle)
	icon.animation_finished.connect(_on_face_finished)
	_settle()
	icon.play(FACE[_level])


## `hurt` is what turns a silent update into the flash — the opening state has
## to be able to set the readout without one.
func show_health(current: int, max_health: int, hurt: bool) -> void:
	var span: float = maxf(float(max_health), 1.0)
	_level = clampi(ceili(float(current) * LEVELS / span), 0, LEVELS)

	if not hurt:
		_settle()
		icon.play(FACE[_level])
		return

	bar.play("hit_%d" % _level)
	# `died` opens with the same three frames as `hurt` and carries on from
	# there, so the killing blow plays it alone rather than flinching twice.
	icon.play(ANIM_DIED if _level == 0 else ANIM_HURT)


# Back to beating, at whatever's left — including nothing, which the sheet draws
# as the whole trace blacked out.
func _settle() -> void:
	bar.play("beat_%d" % _level)


# Only the flinch hands the face back to an idle. `died` is non-looping too, and
# settling after that one would just restart it forever.
func _on_face_finished() -> void:
	if icon.animation == ANIM_HURT:
		icon.play(FACE[_level])
