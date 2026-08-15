# Everything a dialog line can DO

On any **DialogLine**, open the **Action** group in the Inspector and fill in:

```
action_name = "give_item"
action_args = ["bandage", 2]
```

`action_args` is a plain Array. Click **Add Element** once per argument, in
the order shown below.

**A line with empty `text` and an action is a pure "do something" step** — no
box appears, it just happens and the dialog moves straight on. That's how you
put an action *between* two spoken lines.

**Your own custom actions still work.** Any `action_name` not in this list is
emitted as `DialogManager.action_requested(name, args)` exactly as before, so
nothing you already wired up breaks. Built-in verbs are emitted too, so you
can still listen in on them for sound or screen shake.

---

## Flags — world memory

| action_name | args | what it does |
|---|---|---|
| `set_flag` | `["talked_to_java"]` | Sets a flag. |
| `clear_flag` | `["talked_to_java"]` | Unsets it. |
| `toggle_flag` | `["lights_on"]` | Flips it. |

This is the one you'll use most. Everything else in the game — which branch
an NPC picks, which windows open, which items exist — reads flags.

## Items

| action_name | args | what it does |
|---|---|---|
| `give_item` | `["bandage", 2]` | Puts 2 bandages in the inventory. Amount optional, defaults to 1. |
| `take_item` | `["scalpel", 1]` | Removes it. |

The name is the MedicalItem's **`type`** field, not its display name.

`give_item` goes through the same inventory route ItemPickup uses, and raises
the item's `pickup_flag` and `item:<type>` just like walking over it would.
`take_item` needs a remove function on your inventory — if it warns in the
Output panel, tell me the real function name and I'll wire it exactly.

## Windows

| action_name | args | what it does |
|---|---|---|
| `open_window` | `["whisper_1"]` | Opens that PopupWindowDef by id. |
| `close_window` | `["whisper_1"]` | Closes it. |
| `close_all_windows` | *(none)* | Closes every popup. |

A character can make a real window appear on the player's desktop mid-sentence.

## Logbook

| action_name | args | what it does |
|---|---|---|
| `log_entry` | `["ahmed_story"]` | Raises that flag. Logbook entries are gated by flags, not unlocked directly — this is the real route. |
| `log_open` | *(none)* | Opens the logbook. |

## Health and blood

| action_name | args | what it does |
|---|---|---|
| `heal` | `[2]` | Heals by that much. |
| `hurt` | `[1, "scalpel"]` | Damages by that much. Second arg is the DeathCause if it kills him. |
| `bleed` | `["cut"]` | Opens a wound so he bleeds. Arg is the cause. |
| `stop_bleeding` | *(none)* | Stops it. |
| `kill` | `["bleeding"]` | Kills him, blaming that DeathCause. |

These go through the player's **WoundComponent**, so he needs one on him
(found via the `Player` group, or the `wound_component` group).

`kill` runs your whole death sequence — a character can end him mid-sentence.

## Radio

| action_name | args | what it does |
|---|---|---|
| `radio_tune` | `[1120]` | Tunes to that frequency. |
| `radio_open` | *(none)* | Raises the flag `radio_should_open`. |

Goes through `RadioLink`, so the other developer's radio code is untouched.
Tuning works directly. **Opening and closing the radio does not** — that's
their code's job, so `radio_open` just raises a flag their side can watch.

## Story

| action_name | args | what it does |
|---|---|---|
| `progress_stage` | `["hospital_night"]` | Moves the game to that state (a GameProgress state NAME, not a number). |
| `play_cutscene` | `["res://vids/apple.ogv"]` | Plays a video by path. Pass a Comic resource instead to play a comic. |

## Flow control

| action_name | args | what it does |
|---|---|---|
| `wait` | `[1.5]` | Holds the dialog for 1.5 seconds. |
| `end_dialog` | *(none)* | Ends the dialog right here, skipping the rest. |

`wait` is the good one for timing. An empty line with `wait` = a silent beat
before the next thing is said.

---

## `wait_for_action` — the one that trips people up

Also in the Action group. It means: **stop the dialog until my game says
carry on.** Only tick it for your own custom actions, and only if your handler
calls `DialogManager.finish_action()` when it's finished. If you tick it and
never call that, the dialog freezes forever.

Built-in verbs don't need it. They finish on their own.

---

## Worked example — the apple

Four lines on one branch:

**Line 1** — text: `Somebody got to it before you.`

**Line 2** — text empty, `action_name = "wait"`, `action_args = [1.0]`
→ a silent beat.

**Line 3** — text: `Don't look at me.`
`set_flags = ["java_denied_apple"]`
→ set_flags on the line is simpler than the `set_flag` action when you just
want a flag alongside a spoken line. Use the action when you need a flag on
its own, or in a specific order with other actions.

**Line 4** — text empty, `action_name = "open_window"`,
`action_args = ["whisper_1"]`
→ a window appears on the desktop the moment he stops talking.

---

## Writing your own

Nothing changed here. Pick any name that isn't in the table:

```gdscript
func _ready() -> void:
    DialogManager.action_requested.connect(_on_dialog_action)

func _on_dialog_action(action_name: String, args: Array) -> void:
    match action_name:
        "unlock_door":
            $Door.unlock(args[0])
            DialogManager.finish_action()   # only if wait_for_action is ON
```

If you find yourself writing the same custom action in three levels, tell me
and I'll add it to the built-in list.
