# GameSystems

Everything we built for FD, in one folder. It lives at
`res://FD_Testing/GameSystems/`.

The whole thing is data first: you make `.tres` files and place nodes, the
scripts read them. We don't touch the other developer's code (the player, the
inventory, the radio). Our stuff finds theirs by group name or `get_node_or_null`
and quietly does nothing if it isn't there.

Godot 4.6.3.

---

## 1. Setup

### Autoloads

Project > Project Settings > Globals (Autoload). Add these in this order.
Loc has to be first. Spell the names exactly.

| Name | Path |
|---|---|
| Loc | res://FD_Testing/GameSystems/Localization/loc.gd |
| Flags | res://FD_Testing/GameSystems/DialogV2/flags.gd |
| DialogManager | res://FD_Testing/GameSystems/DialogV2/Scripts/dialog_manager.gd |
| GameProgress | res://FD_Testing/GameSystems/Progress/game_progress.gd |
| LogBook | res://FD_Testing/GameSystems/LogBook/log_book.gd |
| Prescription | res://FD_Testing/GameSystems/Prescription/prescription.gd |
| Deaths | res://FD_Testing/GameSystems/Death/deaths.gd |
| BloodWorld | res://FD_Testing/GameSystems/Breath/blood_world.gd |
| MedicalItems | res://FD_Testing/GameSystems/Items/medical_items.gd |
| PopupWindows | res://FD_Testing/GameSystems/Windows/popup_windows.gd |
| RadioLink | res://FD_Testing/GameSystems/StatuePuzzle/radio_link.gd |
| Sound | res://FD_Testing/GameSystems/Sound/sound.gd |
| Bag | res://FD_Testing/GameSystems/Items/bag.gd |
| MapRooms | res://FD_Testing/GameSystems/Map/map_rooms.gd |
| Board | res://FD_Testing/GameSystems/Board/board.gd |

They're script autoloads, so their `@export` values don't show up in any
inspector. To change a default, change it in the script.

### Input Map

| Action | Used by | Key we use |
|---|---|---|
| interact | dialog, pickups, puzzles | E |
| hold_breath | BreathComponent | Shift |
| log | LogBook on its own (outside the Board) | L |

TAB opens the Board and isn't an action. A missing action won't crash
anything; `InputAccess` falls back to ui_accept and warns once.

### Project settings

- Display > Window > Subwindows > Embed Subwindows: off. The popup windows
  need to be real OS windows.
- Display > Window > Per-pixel transparency: on.
- Localization > Translations: add `translations.en.translation` and
  `translations.ar.translation`. Import `Localization/translations.csv` as
  Translation first.
- A default theme with a font that has Arabic glyphs, or Arabic is boxes.
- Internationalization > Rendering > Root Node Layout Direction: Locale.

### The player

Sami's scene needs to be in the group `Player`. Our components read his
`stats` by property name and back off with a warning if something's missing.

### Exported builds

Anything that loads content by scanning a folder goes through `res_list.gd`.
Plain `DirAccess` works in the editor and finds nothing in an exported build,
because the pck lists files as `.tres.remap`. If you write a new loader, use
`ResList.tres_files(dir)`.

---

## 2. Folder map

| Folder | What's in it |
|---|---|
| DialogV2 | Dialog resources, DialogManager, DialogUI, DialogZone, actions, Flags |
| NPC | NPC scene, NPCResource, wander/patrol behaviours |
| Localization | Loc, translations.csv, LanguageSetting, LanguagePrompt, audit tool |
| Windows | PopupWindows, defs, skins, WindowBlocker, RadioReactor |
| LogBook | LogBook autoload, entries, deductions |
| Board | The clipboard pause menu and its tabs |
| Map | MapRooms, MapRoom node, room defs and art |
| Items | Bag, MedicalItems, item defs, ItemPickup |
| Prescription | Password saves and checkpoints |
| Death | Deaths, DeathCause defs, death board |
| Health | WoundComponent, DamageArea, HealthWatcher |
| Breath | BreathComponent, ToxicArea, BloodWorld, BloodGrid, blood types |
| Progress | GameProgress state machine |
| StatuePuzzle | Radio-driven statue puzzle, RadioLink |
| ElectroPuzzle | Generator sequence and timed run |
| BossFight | Yazzed |
| Puzzle | Older speaker-number statue puzzle |
| Sound | Sound autoload, library, map, zones, beds |

---

## 3. Flags

`Flags` is a dictionary of named booleans. Every system reads and writes it:
dialog branches pick themselves by flags, zones remember they fired, rooms
are discovered as `map:<id>`, checkpoints restore by setting flags.

```gdscript
Flags.set_flag("met_java")
Flags.clear_flag("met_java")
Flags.is_set("met_java")
```

Flag names are plain strings; a typo is a new flag and nothing warns. Keep one
list somewhere. Nothing writes flags to disk - the prescription codes are the
save system, so a checkpoint's `set_flags` must cover everything that should
survive a restart.

---

## 4. Localization

English text is the key. Write English everywhere; `translations.csv` maps it
to Arabic (`keys,en,ar`). Adding a language later is one more column.

```gdscript
Loc.set_language("ar")     # saved to user://language.cfg
Loc.current()              # "en" / "ar"
```

- `LanguageSetting` node: a self-building dropdown for any menu.
- `LanguagePrompt` node: first-launch chooser. `first_launch_prompt = false`
  in loc.gd turns it off while the menu is unfinished.
- `mirror_ui = false` in loc.gd stops the RTL mirroring.
- Any `draw_string` text must go through `tr()` or it stays English. Run
  `translation_audit.gd` (editor only) to list strings not yet in the CSV.

---

## 5. Dialog

### Resources

```
Dialog
 └─ branches: [DialogBranch]          "entry" plays first; others are topics
	 └─ lines: [DialogLine]
		 text            BBCode ok. Empty text = action-only step.
		 speaker_name    overrides the name in the box
		 show_if_flag    skip the line unless set
		 set_flags       set when the line shows
		 action_name / action_args / wait_for_action
		 sound_id        cue when the line appears (see Sound)
		 keywords        [DialogKeyword]  word -> topic branch, optional unlock_flag
		 choices         [DialogChoice]   text, goto branch, show_if_flag
		 npc_animation / player_animation
```

Branch selection: the first branch whose `require_flags` are all set wins, so
put specific branches above general ones.

### Starting a dialog

- NPC: put a `Dialog` on the `NPCResource`, walk up, press interact.
- `DialogZone` (Area2D + CollisionShape2D): Sami walks in, it starts.
  `once_only` remembers via a flag. `speaker` can point at an NPC in the level
  to borrow its name and portrait.
- `DialogTrigger` on any node.
- Code: `DialogManager.start(dialog, speaker_node)`.

The game pauses while a dialog runs. `DialogManager.is_active`.

### Actions (the verbs)

`action_name` on a line runs one of these directly:

```
set_flag / clear_flag / toggle_flag       [flag]
give_item / take_item                     [type, amount]
open_window / close_window                [window id]     close_all_windows
log_entry [id]    log_open
heal / hurt [amount]    bleed / stop_bleeding / kill [cause]
radio_tune [hz]   radio_open
play_sound [cue]  play_music [id, fade]   stop_music [fade]
play_set [set, "drums,bass"]  stop_set [category]
music_layer / ambience_layer [layer, on|off|auto]
progress_stage [state]
wait [seconds]    delay [seconds]    end_dialog
```

`wait` holds the line on screen. `delay` takes the box off screen, waits,
and the next spoken line brings it back. `give_item`/`take_item` go through
the Bag (the `type` field of the MedicalItem, case doesn't matter).

`action_name` is a dropdown; each entry shows the args it wants
(`give_item  [type; amount]`). Pick `custom` and type a name in
`custom_action` to emit your own `action_requested(name, args)`. Other
systems answer these through that signal: `checkpoint`,
`prescription_show`, `prescription_entry`, `state`. `wait_for_action` pauses
the line until `DialogManager.finish_action()` is called.

More than one action on a line: add `DialogActionStep`s to `more_actions`;
they run in order after the first, each with its own args and wait.
Details and examples: `DialogV2/ACTIONS.md`.

### Sounds in a line

- `sound_id` fires when the line appears. Full cue syntax.
- `[sfx:scream]` inside the text fires when the typewriter reaches that spot.
  Markers never display. If the player skips the typing, pending cues still
  fire. Translators place the marker where the word lands in Arabic.

---

## 6. NPCs

Instance `NPC/npc.tscn`, give it an `NPCResource`:

- `npc_name`, `sprite_frames`, `portrait`, `dialog`
- `voice_blip` + `voice_pitch_min/max` - this character's typewriter sound
- `footstep_sound_id` + `footstep_frames` - which walk frames are foot contacts
- animation names, `resting_animation`, `use_direction_animations`,
  `face_player_on_dialog`

Movement: add one child of `NPCBehaviorWander` (radius, walk/wait times) or
`NPCBehaviorPatrol` (Marker2D children as the route). No child = stands still.
`npc.is_blocked` is true on any frame the NPC pushed against something; Wander
stops and waits when it bumps into Sami, Patrol gives up on that point after
`give_up_after`.

Dialog lines can override the NPC's animation for the line
(`npc_animation`); the direction state machine is suspended while it plays.

---

## 7. Items and the Bag

`Bag` is our inventory: 4x3 small slots and 2 big ones, stacking, drag to
reorder.

```gdscript
Bag.add("bandage", 1)     Bag.remove("bandage", 1)
Bag.has("bandage")        Bag.count_of("bandage")
```

`MedicalItem` (.tres in Items/Items/): `type`, `display_name`, `effect`,
`texture`, `max_stack` (defaults to 1 - set it or nothing stacks),
`needs_big_slot`, `action` (NOTHING / BANDAGE / CUT / HEAL / FULL_HEAL),
`pickup_sound_id`, `use_sound_id`. `MedicalItems.get_item(type)` finds it.

`ItemPickup` (Area2D in the level): `item_type`, `amount`; raises the flag
`item:<type>` on pickup. Mutations inside button callbacks must be deferred.

---

## 8. Health, breath, blood

Add these as children of Sami:

- `WoundComponent` - hp and bleeding, reads Sami's `stats` by property name.
  `damaged / healed / bleeding_started / bleeding_stopped / died`.
- `BreathComponent`, named exactly `Breath` - hold `hold_breath` to stop
  breathing. `stage_seconds x stage_count` of air, `stage_animations` or
  `stage_tints`, `recover_seconds`. While holding, the world muffles (see
  Sound). If `is_bleeding`, each stage spills the `BloodType` in
  `stage_blood[stage]`.
- `HealthWatcher` - turns hp reaching zero into a death.

In the level:

- `ToxicArea` (Area2D): inside it without holding = `grace_seconds` then death
  by `death_cause`. `inside_sound_id` loops while inside.
- `DamageArea` (Area2D): hurts on contact.
- `BloodGrid`: tracks spilled blood cells for the blood puzzle.
- `BloodWorld` autoload: `spilled(type, world_pos)`; blood types in
  Breath/Types/.

---

## 9. Death

`Deaths.kill("bleeding")`. Causes are `DeathCause` .tres in Death/Causes/:
`id`, `title`, `note`, board art, `sound_id`. The death board animates in,
then retry from the last checkpoint. `Deaths.player_died(cause_id)`,
`Deaths.is_dead`.

---

## 10. Prescription saves

Codes look like medicine (`Nazomel 250mg`) and encode a checkpoint number
plus a checksum. There is no disk save.

- `PrescriptionCheckpoint` .tres in Prescription/Checkpoints/: `number`
  (0-255, never renumber after release), `state_name`, `set_flags`, `scene`,
  `sound_id`.
- Reach one: `Prescription.reach(1)` or action `checkpoint [1]`. The popup
  shows the code.
- Show it again: `Prescription.show_current()` / action `prescription_show`.
- Enter one: `Prescription.open_entry()` (menu button) / action
  `prescription_entry`. Four dials, no keyboard.

Never change the syllable tables after release - they are the players'
written-down codes.

---

## 11. Game progress

One state name (`"Start"`, `"Act2"`) lives in the flag `game_state`. Each
level has a `ProgressStateMachine` with `ProgressState` children named after
states. On load, the matching child enters: `show_groups`, `hide_groups`,
`set_flags`, optional `auto_advance_when_flag` -> `next_state`.

```gdscript
GameProgress.goto_state("Act2")        # or action state ["Act2"]
```

---

## 12. LogBook

Entries are `LogEntry` .tres in LogBook/Entries/, revealed by `reveal_flag`.
`LogDeduction`: `required_entries`, `board_position`, `result_*`,
`result_flag`. When all required entries are known a "+" card appears; the
player connects entries to it; all correct raises `result_flag`.
`LogComment` adds side notes. Cards drag with a spring. Signals: `opened`,
`closed`, `deduction_solved`, `deduction_wrong`.

---

## 13. Map

One `MapRoom` node (Node2D + CollisionShape2D over the floor) per room scene
with a `room_id`. One `MapRoomDef` .tres per room in Map/Rooms/: `id`,
`display_name`, `art` (that room drawn on the 640x360 map canvas, rest
transparent), `require_flag`, `known_from_start`, `sound_id`. Position on the
map comes from the art's opaque pixels; `map_rect` only if that fails.

```gdscript
MapRooms.discover("morgue")   MapRooms.reveal_all = true   MapRooms.forget_all()
```

---

## 14. Board (pause menu)

TAB opens the clipboard: Inventory, LogBook, Map, Settings. Art loads itself
from Board/Art/; tab hitboxes come from the art's opaque pixels. Everything is
laid out on the 640x360 art canvas, scaled 94% and centred, so nothing uses
raw screen pixels. Signals: `opened(tab)`, `closed`, `tab_changed(tab)`.

Settings tab: language dropdown and the six volume sliders (live, saved).
Fullscreen and controls rows are placeholders.

---

## 15. Popup windows

Real OS windows on the player's desktop. Each is a `PopupWindowDef` .tres in
Windows/Defs/ with an `id`.

- `kind`: TEXT (`text`, `text_motion`, `text_speed`, `font_size`, `text_loop`),
  IMAGE (`image`, `image_fills_window`), PORTAL (`portal_scene` or
  `portal_same_world` + `portal_camera_position` / `portal_zoom`;
  `portal_follow` Fixed / Desktop / World, `portal_follow_scale`, `invert`,
  `smooth`), SOUND.
- `placement`: FIXED, RANDOM, NEAR_PLAYER, CENTER, EDGE (+ `offset`,
  `random_margin`).
- Look: `size`, `title`, `borderless`, `transparent`, `background_color`,
  `icon`, `always_on_top`, `depth`, `user_can_drag`, `user_can_resize`,
  `unfocusable`. A `WindowSkin` replaces the OS chrome with nine-slice art.
- Enter/leave: `fade_seconds`, `grow_in`, `shake_pixels`.
- `close_mode`: TIMER (`lifetime`), USER, FLAG (`close_flag`), NEVER.
  `once_only`, `open_flag`, `closed_flag`.
- Morph: `change_to` another id after `change_after` seconds. `change_morph`
  keeps the same OS window and swaps its contents. `change_max_steps` stops
  loops.
- Sound: `open_sound`, `sound` (loops while open), `close_sound`.

```gdscript
PopupWindows.open_id("id")   .close_id("id")   .close_all()   .is_open("id")
```

Level pieces:

- `WindowBlocker` (Area2D over a thing in the level): a dragged window stops
  there, `new_title` / `new_text` swap in, `bump_sound`, `bump_shake`,
  `set_flag`. `WindowSpace` does the desktop-to-world maths.
- `RadioReactor` + `RadioBand`: the radio drives a portal scene. Each band:
  `frequency` +- `tolerance`, action SHOW / HIDE / PLAY_ANIM / MODULATE /
  MOVE_TO / SET_FLAG / CALL_METHOD / NOTHING on a `target`, `latch`,
  `hold_seconds`, `sound`.

`portal_same_world` is off by default; leave it off unless you know why.
`borderless_fullscreen` on PopupWindows is off by default. Portals cost a
SubViewport each.

---

## 16. Puzzles

### Radio statue (StatuePuzzle/)

Reads the other developer's radio through `RadioLink` (no changes to their
code; if the radio isn't in the project it returns the minimum frequency and
warns once). Four `RadioSpeaker` areas (`speaker_index` 0-3) follow the radio
while Sami stands by them. The `RadioStatue` hears them and answers with a
`StatueResponse`: HAPPY = wrong frequency, decoy number; SAD = right, real
number, with its own `sound_id`. Real numbers go on the `NumberBoard`; order
them to finish.

### Electro (ElectroPuzzle/)

`ElectroGen` areas with `order_index`; flip in order or everything resets.
Then `after_switches_dialog`, then a timed run with `chase_music`, lights,
`callout_lines`, to the main gen (`is_main`, optional `required_hz` on the
radio). `on_fail`: RESET_ONLY / KILL_PLAYER / RELOAD_CHECKPOINT. Test scene:
`electro_puzzle_test.tscn`.

### Yazzed (BossFight/)

Three stages: TV drops and he charges into it; TV lifts and you chip his hp
to `stage3_hp`; fast bouncy stage with `wall_feint_chance`, second TV hit
ends it and `won_flag` is raised. Every timing and speed is an export on
`yazzed_boss.gd` / `boss_tv.gd`. `BossFight.reset_fight()` on death.

### Puzzle/ (older)

The speaker-number statue puzzle before the radio version. Keep or delete.

---

## 17. Sound

### Categories and buses

Six sliders: Master, Music, Ambience, SFX, UI, Dialog. Each is a bus. At
startup Sound reuses any bus that already exists by name (the project layout
has Master, EffectPass, Music, SFX, UI, PuzzleSFX) and creates only the
missing ones: Ambience -> EffectPass, Dialog -> Master. Sliders are relative
to each bus's volume as the layout set it, so a slider at full is exactly the
mix in the layout. Saved to `user://sound.cfg`.

Any player you create yourself: `BusRoute.use(p, "SFX")`.

### The library

A sound is a `SoundDef` .tres: `id`, `stream`, `category`, `volume_db`,
`pitch_min/max` (random pitch per play), `positional`, `max_distance`,
`surface_variants`. Found anywhere under `Sound/Library/` or
`res://Sounds/Resource/`, subfolders included (`LIBRARY_DIRS` in sound.gd).
A def with no stream is silent, not an error. An unknown id warns once and
lists the ids it did load.

```gdscript
Sound.play("door")   Sound.sfx_at("drip", pos)   Sound.play_stream(stream, "SFX")
Sound.play_music("track")   Sound.stop_music(1.5)
Sound.start_loop("key", "hum")   Sound.stop_loop("key")
Sound.set_volume("Music", 0.5)   Sound.has_sound("id")
```

### Cue syntax

Used in the SoundMap, a DialogLine's `sound_id`, `[sfx:...]` in text, and the
`play_sound` verb:

```
paper                       once
paper, jingle               both
loop drone / loop(0.5) drone      start a loop (fade in)
stop drone / stop(0.3) drone      end it (fade out)
delay(1) scream             wait first
delay(2) loop(1) drone      combine
```

### When a sound plays - three doors for the production team

1. **The thing's own resource.** `sound_id` on MedicalItem (pickup/use),
   DeathCause, MapRoomDef, PrescriptionCheckpoint, DialogLine,
   StatueResponse, BloodType; voice and footsteps on NPCResource. Wins over
   the map.
2. **The SoundMap** (`Sound/sound_map.tres`). Every signal on every system is
   listed as `Class.signal` (Bag.item_added, ElectroPuzzle.puzzle_solved,
   Board.opened...). Type a cue next to it. Autoloads are attached by Sound;
   world nodes call `SoundLink.attach(self)` in `_ready`. Per-frame signals
   are excluded (`SKIP_SIGNALS`). `Sound.debug_log = true` prints the live
   list.
3. **SoundHook** node under any node, ours or theirs: `hooks` = signal ->
   sound id. Connects itself. A wrong signal name prints the real list.

For you: declare signals, `SoundLink.attach(self)` first thing in `_ready`,
`Sound.event("Thing.happened", self)` where there's no signal, and one
`match` arm in `Sound._resource_sound()` when a new resource gets a sound
field.

### Floors

`FloorSurface` (Area2D + shape) with `surface = "wet"`. On the footstep def,
`surface_variants: wet -> sami_step_wet`. Any sound played from a body inside
the area swaps. Newest area wins.

### Music and ambience beds

A `MusicSet` (Sound/Sets/) is a piece as stems: `layers` (`MusicLayer`: name,
stream, volume_db, on_by_default, ducks_in_dialog), `bpm`, `beats_per_bar`,
`flag_layers`, `layer_fade`, `set_fade`, `category` Music or Ambience. All
stems play in sync; a room chooses which are audible.

`MusicZone` / `AmbienceZone`: `music_set`, `layers` (base mix),
`delayed_layers` (name -> seconds after entering), `flag_layers` (name ->
flag), `align` Bar / Beat / Now. Nested zones: innermost wins; leaving the
last zone keeps the mix. A different set crossfades. Changes wait for the
bar, then fade. Layers marked `ducks_in_dialog` dip during dialog; the rest
stay. The simple mode (`music_id` / `music_stream`, one track per room) still
works on the same node.

Composer brief: every stem the same length and tempo, looping cleanly, a
whole number of bars, and tell us the BPM and time signature.

### Breath muffle

While Sami holds his breath a low-pass filter on Master closes and the volume
dips, more the longer he holds; it fades back on release. Exports on Sound:
`muffle_min_cutoff_hz`, `muffle_volume_db`, `muffle_curve`,
`muffle_release`. The filter is added disabled and removed on exit, so the
bus layout is untouched. `Sound.set_muffle(0..1)` from anywhere.

---

## 18. Known traps

- Paths are `res://FD_Testing/GameSystems/...`, not `res://GameSystems/`.
- Name collisions in the shared project: `State` -> `BossState`, `Action` ->
  `MedAction`, `Window.Flags` shadows the `Flags` autoload inside
  popup_window.gd (use `/root/Flags` there).
- `get_first_node_in_group()` needs an explicit cast.
- Root Controls with `MOUSE_FILTER_STOP` over the full screen eat every click.
- Board and LogBook coordinates are fractions of the 640x360 art, scaled and
  centred; raw pixels drift.
- `@export` on script autoloads does nothing in the inspector.
- Warnings, not crashes: most systems warn and go inert when something is
  missing. An empty Output panel is the green light; a wall of warnings is
  the bug list.

---

## 19. Player identity (the Discord trick)

`PlayerIdentity` finds the player's own profile picture before you need it, so
any UI can show it back to them later. Discord first, the Windows account
picture second, nothing third. The result is cached in
`user://identity/avatar.png`, so the second session works offline.

### One-time setup (FD)

1. discord.com/developers/applications → New Application (any name; the player
   never sees it).
2. Copy the **Application ID** into `client_id` at the top of
   `Identity/player_identity.gd`. `@export` on an autoload does nothing, so it
   must be the default in the script.
3. That is all. There is no RPC Origins box to fill any more - that program is
   closed. Leave `rpc_origin` empty: Discord lets a connection through when it
   carries no Origin header at all, which is how it tells a local game from a
   random web page. Sending one gets you rejected with 4001.

No addon, no .dll, no GDExtension. If `client_id` is left empty the whole
Discord half is skipped and only the Windows picture is tried.

### How it finds the picture

| Order | Where | Works on |
|---|---|---|
| 1 | `\\.\pipe\discord-ipc-N`, the documented IPC transport | Windows |
| 2 | `ws://127.0.0.1:6463-6472`, the RPC websocket | any OS |
| 3 | `%APPDATA%/Microsoft/Windows/AccountPictures` | Windows |

Discord answers a connection with a `READY` event that carries the logged-in
user (`id`, `username`, `global_name`, `avatar` hash). We read it and hang up:
no login screen, no permission dialog, nothing appears in Discord, and the
player has no idea. The picture itself is one GET to
`cdn.discordapp.com/avatars/<id>/<hash>.png`. Nothing is uploaded anywhere.

If Discord is closed, or the app is not registered, or the build hides the user
from an unauthorised app, every step fails quietly and the game carries on with
the fallback picture. Never let the scare depend on the picture being there.

### Using it

Drop an `AvatarView` (TextureRect + `Identity/avatar_view.gd`) into the scene.
Exports: `fallback_texture`, `hide_until_ready`, `reveal_delay`. It binds
itself and fires `revealed` when the face appears.

From code:

```gdscript
if PlayerIdentity.has_avatar():
    $Photo.texture = PlayerIdentity.get_avatar()
PlayerIdentity.get_display_name()   # "FD", or the Windows user name
PlayerIdentity.avatar_ready         # signal(texture) if it arrives later
PlayerIdentity.fetch()              # run the chain again
PlayerIdentity.forget()             # wipe the cached picture
```

`PlayerIdentity.info` holds `source` (`discord`, `os`, `none`), `id`,
`username`, `global_name`, `avatar_hash`. Set `verbose = true` to print every
step and Discord's raw reply.

### Why the pipe path looks odd

`\\?\pipe\discord-ipc-N`, not the usual `\\.\pipe\...`. Godot pushes every
path through `simplify_path()` before opening it, which strips the "." segment
and leaves `\\pipe\discord-ipc-0` - a network share to a machine called
"pipe". That is the `err 7` (file not found) you get on every pipe even with
Discord running. The `\\?\` form is the same device namespace and survives.

### When nothing shows up

Attach `Identity/identity_debug.gd` to a Node in an empty scene and press F6.
It prints the autoload, the client id, every Discord pipe, Discord's raw reply
and the final result, whatever `verbose` is set to. It also says outright when
the picture arrived and the fault is in the UI node.

### Before shipping

Put one line in the store page or EULA saying the game may read the profile
picture from a running Discord client, and keep it local-only. That keeps it a
horror trick instead of a privacy complaint.
