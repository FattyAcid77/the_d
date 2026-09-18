# Localization — fix for the `layout_direction` crash

## The error you saw

	Invalid assignment of property or key 'layout_direction'
	with value of type 'int' on a base object of type 'Window'.

	loc.gd:105  _apply_mirror
	loc.gd:91   _apply
	loc.gd:47   _ready

Those three lines are NOT three errors. They are the call path of ONE error:
`_ready` calls `_apply`, which calls `_apply_mirror`, which is where it broke.
It showed up 29 times because `_apply_mirror` runs on every language apply
(startup, first-launch prompt, settings dropdown).

## What was wrong

Old line 105:

	root.layout_direction = dir

`get_tree().root` is a **Window**, not a Control. That property assignment is
rejected on Window in this Godot build, so the whole mirror aborted.

There was a second, quieter bug right under it: the loop set every Control to
`LAYOUT_DIRECTION_INHERITED`, meaning they all inherited from the root — which
had just failed. So even with no error, nothing would ever have mirrored.

## What changed

Only `_apply_mirror` and the helper below it. Everything else in `loc.gd` is
byte-for-byte what you already had.

* The root window now goes through the setter **method**, guarded by
  `has_method("set_layout_direction")`, so it silently skips on builds that
  don't support it instead of throwing.
* `_all_controls` became `_top_controls`: it collects only Controls whose
  parent is NOT a Control, and stops descending there. Each of those gets the
  direction set **explicitly**, and their children inherit from them. The
  mirror no longer depends on the root Window working at all.
* `Control.LAYOUT_DIRECTION_RTL` and `Window.LAYOUT_DIRECTION_RTL` are the same
  numeric value, so using the Control constant for both is safe.

## One project setting worth turning on

    Project Settings > Internationalization > Rendering
    > Root Node Layout Direction  ->  Based on Application Locale

Then Godot mirrors the root window itself whenever `TranslationServer.set_locale()`
changes, and `Loc` only has to handle UI that was already built when the player
switched — which is exactly what the new loop does.

## Files in this zip

    loc.gd                 <- CHANGED (the fix)
    language_setting.gd    <- unchanged
    language_prompt.gd     <- unchanged
    translation_audit.gd   <- unchanged

**`translations.csv` is deliberately NOT in this zip.** Yours has your Arabic
in it. Do not overwrite it — just drop these four .gd files over the old ones.

## How to test

1. Copy the four files into `res://FD_Testing/GameSystems/Localization/`.
2. Run the game. The Errors tab should be clean of the layout_direction error.
3. Open a dialog box, then switch to Arabic in your settings menu. The box
   should flip to right-anchored, and buttons/portraits swap sides, live.
