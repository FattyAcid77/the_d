# What was broken, and what I changed

I ran your package through a real Godot 4.4.1 build — imported it, ran it
headless, and exercised every scene and system — rather than reading the code
and guessing. Everything below is a bug the engine actually reported.

**Result: 0 parse errors, 0 runtime errors.** Before this pass there were
2 parse errors, 3 hard runtime errors, and a per-frame error flood.

---

## 1. Broken asset paths — `res://GameSystems/` instead of `res://FD_Testing/GameSystems/`

**This is the one that stopped the game.** Seven files still had the old
prefix from before the project was reorganised:

| File | What it broke |
|---|---|
| `DialogV2/Scripts/dialog_manager.gd` | **the whole dialog system** |
| `DialogV2/Scripts/dialog_ui.gd` | typing sound |
| `DialogV2/dialog_ui.tscn` | script + text_box.png |
| `DialogV2/dialog_trigger.tscn` | script |
| `NPC/npc.tscn` | script + trigger scene |
| `Puzzle/puzzle_speaker.tscn` | script |
| `Puzzle/statue_puzzle_example.tscn` | script + speaker scene |

The engine said:

```
ERROR: Cannot open file 'res://GameSystems/DialogV2/dialog_ui.tscn'.
SCRIPT ERROR: Cannot call method 'instantiate' on a null value.
          at: _ready (dialog_manager.gd:31)
```

DialogManager is an **autoload**, so this crashed during startup, before your
menu ever drew. All seven paths fixed.

## 2. `layout_direction` on Window — your original error

Reproduced exactly on 4.4.1. `get_tree().root` is a **Window**, not a Control,
and that property assignment is rejected. Fixed in `loc.gd`: the root now goes
through the setter method guarded by `has_method()`, and each top-level
Control is set explicitly instead of inheriting from a root that refused.

There was a second, silent bug underneath: the old loop set every Control to
`LAYOUT_DIRECTION_INHERITED`, so even without the error **nothing would ever
have mirrored for Arabic**. It mirrors now — verified live.

## 3. Two parse errors (these files would not load at all)

* `Localization/translation_audit.gd:124` — `var prefix := field + ...`
  couldn't infer a type from an untyped Array element.
* `Death/death_state.gd:28` — `var frames := player.anim.sprite_frames`,
  same cause.

Both given explicit types. The audit tool and the death state now load.

## 4. PopupWindows crashed on open

```
ERROR: Parent node is busy setting up children, `add_child()` failed.
```

`open()` called `get_tree().root.add_child(w)` directly. When a window is
requested from a dialog line or a signal, the tree is mid-setup and the call
is refused — the window silently never appeared. Now deferred via `_attach()`,
which adds **and then** positions the window, one frame later. Same pattern
you used for the other dev's inventory.

## 5. Thousands of errors per second from a missing input action

Eleven scripts polled `Input.is_action_just_pressed("interact")` inside
`_process`. If "interact" isn't in your Input Map, that's a **hard error every
frame** — the run log was tens of thousands of identical lines, hiding every
real problem underneath. This is almost certainly the "a lot of errors" you saw.

New file `input_access.gd` (`class InputAccess`) — a plain static helper, not
an autoload, nothing to register. It checks the action exists, falls back to
`ui_accept`, and warns **once**. All 14 call sites rewritten.

**Do this once:** Project Settings → Input Map → add `interact`, bind it to E.
Until then everything still works on Enter/Space.

## 6. `boss_fight_test.tscn` depended on `res://icon.svg`

Six Sprite2D nodes pointed at a file outside the package, so the test scene
threw parse errors for anyone whose project lacks Godot's default icon.
Swapped for a built-in GradientTexture2D. The package is now fully
self-contained — **zero** references outside `res://FD_Testing/GameSystems/`.

## 7. DialogManager could take the game down

Even with the path fixed, a missing UI scene would crash the autoload on
`_ready`. It now reports the problem with `push_error` and disables dialog
instead of killing startup, and `start_dialog()` no-ops safely.

---

# The off switches you asked for

Your main menu isn't finished, so nothing should be grabbing the screen.

**The window takeover was the biggest offender.** `PopupWindows` had
`borderless_fullscreen = true` **by default** — at startup it forced the game
window borderless, resized it to your entire monitor, and moved it to 0,0,
before any menu drew. That alone looks exactly like "the game doesn't run".
**It now defaults to `false`**, and is guarded so it can't fire headless.

**The language prompt** covers the screen and pauses the game on first run.
Two ways off:

* untick **`enabled`** on the LanguagePrompt node in the Inspector, or
* set **`first_launch_prompt = false`** in `loc.gd` to kill every one at once.

Either way the node frees itself in `_ready` and touches nothing — no drawing,
no pause. It also no longer hard-depends on `Loc` existing.

**The RTL mirror**: `mirror_ui = false` in `loc.gd`.

README sections 26 and 27 cover all of this.

---

# Not bugs — leave these alone

* `Death/death_state.gd` extends `state`, and several scripts type against
  `Player`. Those are the other dev's classes and only exist in your real
  project. I stubbed them to test; **don't add my stubs**.
* `WoundComponent` / `HealthWatcher` warn when the player has no `stats`.
  That's them degrading gracefully, exactly as designed.
* `DialogV2/dialogue_noise.mp3` is referenced but not in the package. It's
  wrapped in `ResourceLoader.exists()`, so it's optional — drop the file in
  and it gets picked up automatically.

---

# How to test

1. Replace your whole `FD_Testing/GameSystems/` folder with this one.
2. Open the project — the FileSystem dock should show **no missing dependency
   errors** (those red files with broken-link icons).
3. Run the game. It should boot to your scene with a clean Errors panel.
4. Add the `interact` action to shut up the one remaining warning.
5. Switch to Arabic in your settings menu with a dialog box open — it should
   flip right-anchored, live, with no errors.
