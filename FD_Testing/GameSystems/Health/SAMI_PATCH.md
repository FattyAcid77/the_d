# Optional patch: hold-breath ANIMATIONS in sami_doctor.gd

You only need this if you want real hold-breath **animations**.
Without it the breath mechanic already works — each stage just tints Sami
a colder blue instead (`stage_tints` on the Breath node).

## Why a patch is needed

Sami's walk/idle states call `UpdateAnimation()` **every frame**, which
plays `Walk_down`, `Idle_Side`, etc. So if the breath component played
`Hold_2`, the state machine would overwrite it on the very next frame.

The fix is to let `UpdateAnimation()` know about the breath, so it builds
the breath animation name itself instead of fighting over it.

## The patch (2 small changes in sami_doctor.gd)

**1. Add this variable near the top, with the other vars:**

```gdscript
@onready var breath: Node = get_node_or_null("Breath")
```

**2. Replace your `UpdateAnimation()` with this version:**

```gdscript
func UpdateAnimation(state: String) -> void:
	# --- breath override: play Hold_<stage>_<dir> while holding ---
	if breath and breath.is_holding:
		var hold_name: String = "Hold_%d_%s" % [breath.stage + 1, AnimDirection()]
		if anim.sprite_frames and anim.sprite_frames.has_animation(hold_name):
			if anim.animation != hold_name:
				anim.play(hold_name)
			return
		# no directional version? try a plain one
		var plain: String = "Hold_%d" % (breath.stage + 1)
		if anim.sprite_frames and anim.sprite_frames.has_animation(plain):
			if anim.animation != plain:
				anim.play(plain)
			return
	# --- normal behaviour (your original code) ---
	var anim_name: String = state + "_" + AnimDirection()
	if anim.animation == anim_name:
		return
	anim.play(anim_name)
```

> Keep your own version's signature/details if they differ — the only new
> part is the block at the top. Everything after the comment is your
> original logic.

## Animation names to add to his SpriteFrames

Directional (best):

    Hold_1_down  Hold_1_up  Hold_1_Side
    Hold_2_down  Hold_2_up  Hold_2_Side
    Hold_3_down  Hold_3_up  Hold_3_Side
    Hold_4_down  Hold_4_up  Hold_4_Side

Or simple non-directional, if that's enough:

    Hold_1   Hold_2   Hold_3   Hold_4

The patch tries the directional name first and falls back to the plain one,
so you can start with four animations and add directions later.

Missing animations are skipped safely — he just keeps his normal walk/idle
art and the stage tint.

## Where the nodes go on Sami

    Sami_Doctor
    ├── Sprite2D
    ├── CollisionShape2D
    ├── AreaIndicator
    ├── Camera2D
    ├── Statemachine        (Idle / Walk / Drag / Rotate / Death)
    ├── Breath              <- BreathComponent   (breath_component.gd)
    ├── Wounds              <- WoundComponent    (wound_component.gd)
    ├── HealthWatcher       <- optional (wound_component can handle death)
    └── UI

The names `Breath` and `Wounds` matter — toxic areas, damage areas and the
health watcher find them by those exact names.
