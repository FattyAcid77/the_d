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
| PlayerIdentity | res://FD_Testing/GameSystems/Identity/player_identity.gd |
| Profile | res://FD_Testing/GameSystems/MainMenu/profile.gd |

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
| Localization | Loc, translations.csv, LanguageSetting, audit tool |
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
| MainMenu | The menu room, its settings panel and radio, Profile |
| Identity | PlayerIdentity, AvatarView, IdentityLabel, the Discord probes |
| Debug | The F11 debug panel |
| PC | The in-game computer: PcScreen scene, PcTerminal, character files |
| Interactables | FlagArea, Readable, ItemSocket, WallClues, RadioCheck |
| FastGrabs | Ready-made scenes to drag into a level |

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
- The first-launch language choice is step one of the main menu's setup
  (section 24).
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

View controls, same standalone and as the Board's tab: drag the empty paper
or use the arrows to pan, mouse wheel zooms at the cursor, Space/Home snaps
back to the notes.

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

Settings tab: language dropdown, the six volume sliders and fullscreen
(live, saved through `Profile`). The controls row is a placeholder.
The rows are `BoardSettings`, the same control the main menu uses, so both
always match; `only_rows` picks which rows a copy shows.

---

## 15. Popup windows

Real OS windows on the player's desktop. Each is a `PopupWindowDef` .tres in
Windows/Defs/ with an `id`.

- `kind`: TEXT (`text`, `text_motion`, `text_speed`, `font_size`, `text_loop`),
  IMAGE (`image`, `image_fills_window`), PORTAL (`portal_scene` or
  `portal_same_world` + `portal_camera_position` / `portal_zoom`;
  `portal_follow` Fixed / Desktop / World, `portal_follow_scale`, `invert`,
  `smooth`, `portal_interactive` to hand the scene the mouse and keyboard for
  a mini-game), SOUND.
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
3. **SoundHook** node under any node, ours or theirs. `hooks` = what
   happens -> sound id, where "what happens" is one of:
   - a signal name: `opened`
   - an animation starting: `anim:open`
   - an animation finishing: `anim_end:open` (not for looping ones)
   - an AnimatedSprite2D reaching a frame: `frame:open:3`

   Animations are looked for on the target and inside it (an AnimatedSprite2D
   or AnimationPlayer child), but not inside other scenes placed under it, so
   a hook on a level never grabs every door. A door that closes by playing
   `open` backwards counts as `open` starting and finishing. `Target Path`
   points it at another node (the parent is the default). Wrong names print
   a warning listing what the node really has. With the FD Sound plugin all
   of this is picked from lists (section 23).

   On something that changes the room (the doors: `Door_reg` emits
   `player_entered_door` and loads the next scene straight after), keep
   `positional` off on the hook and on the sound's SoundDef. A positional
   sound lives in the level and is cut when the level goes; a flat one lives
   in Sound and plays through the change.

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

### Sound spy (F9)

In any debug run (from the editor, or a debug export) press F9 while playing.
Top right shows:

- `music` / `ambience`: the set playing and which of its layers are on, or
  the plain track's file name.
- `loops`: every loop running (`start_loop`, `loop(...)` in a cue).
- `moments`: each moment as it fires. Green = it played something (shown
  after the arrow). Red = nothing mapped, so it stayed silent. `x3` = the same
  line three times in a row.
- `sounds`: each library sound as it starts. Red `x door_crek` = that id isn't
  in the library, which is the usual reason something is silent.

**F10** empties the moments and sounds lists for a fresh log, whether the
spy is showing or not: clear, do the one thing you're testing, press F9 and
read only what that did. Music, ambience and loops stay, since they show
what's playing right now.

It only watches, it never changes anything, and mouse clicks go through it.
F9 and F10 work even while a popup window holds the keyboard. Release exports
don't have it. The keys are `KEY` and `CLEAR_KEY` at the top of
`Sound/sound_spy.gd`.

For code that wants the same feed: `Sound.moment_fired(moment, cue)` (cue is
`""` when nothing is mapped) and `Sound.sound_started(id, found)`.

In the editor, the FD Sound plugin (section 23) is the other half: it stops a
wrong id from being typed in the first place.

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
- Code-built Buttons and CheckBoxes: `add_child` first, then set `position`
  and `size`. A button made off-tree has already cached the window's
  direction, so in Arabic its position is mirrored off-canvas even with
  `layout_direction = LTR` set on it. Sliders don't show it; buttons do.
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
PlayerIdentity.get_display_name()   # nickname, else username, else the Windows user
PlayerIdentity.get_discord_id()     # "327538944063438848"
PlayerIdentity.get_username()       # the @name
PlayerIdentity.get_nickname()       # the name he picked in Discord
PlayerIdentity.get_pc_user()        # "Fahad-Alhawas"
PlayerIdentity.get_pc_name()        # "FAHAD-PC"
PlayerIdentity.get_discord_avatar() # Discord's picture only, null if it never answered
PlayerIdentity.get_pc_avatar()      # the Windows picture, even when Discord's is on show
PlayerIdentity.avatar_ready         # signal(texture) if it arrives later
PlayerIdentity.fetch()              # run the chain again
PlayerIdentity.forget()             # wipe the cached picture
```

Anything missing comes back as an empty string, never `<null>`, so a line can
be written without guarding it. Tokens for any text:

```gdscript
PlayerIdentity.format("PATIENT: {name} - {pc_user}@{pc_name}")
```

`{id}` `{username}` `{nickname}` `{name}` `{pc_user}` `{pc_name}`, and
`{wallpaper}` (the Wallpaper Engine wallpaper's title, empty otherwise). For the
team: an `IdentityLabel` (Label + `Identity/identity_label.gd`) with
`PATIENT: {name}` in `template` fills itself in, and refills if the identity
lands later.

Windows only, skipping Discord (the PC screen uses these):

```gdscript
PlayerIdentity.get_os_name()      # the Windows account name (USERNAME)
PlayerIdentity.get_os_picture()   # the account picture, or null
PlayerIdentity.get_wallpaper()    # the desktop wallpaper (first frame if it moves), or null
```

The Windows wallpaper comes from `%APPDATA%/Microsoft/Windows/Themes/TranscodedWallpaper`,
then `Themes/CachedFiles`. A solid colour gives null.

The account picture is tried in `AppData/.../AccountPictures`,
`Public/AccountPictures/<SID>`, `%TEMP%/<user>.bmp` and
`ProgramData/Microsoft/User Account Pictures/<user>.dat` (biggest wins). On
current Windows the SID folder and the .dat are admin-only, and the %TEMP%
copy only exists after the old User Accounts control panel has been opened,
so many players give none.

That's what `Identity/WindowsUserPicture.cs` is for: a small C# helper that
asks Windows itself (shell32's user-tile call), which writes a readable copy to
`%TEMP%/<user>.bmp` and returns its path. PlayerIdentity uses it first. It
needs the .NET build of Godot and the C# project built once (Build button, or
just run the game); anywhere else it is skipped quietly. If it still gives
nothing the PC uses the Discord picture (`discord_fallback`), and failing that
the art's silhouette. `identity_debug.gd` prints what the helper returned.

`PlayerIdentity.info` holds `source` (`discord`, `os`, `none`), `id`,
`username`, `global_name`, `avatar_hash`. Set `verbose = true` to print every
step and Discord's raw reply.

### Wallpaper Engine

Most players' real desktop is a Wallpaper Engine one, which never touches the
Windows setting. So at boot PlayerIdentity looks for it first, on a background
thread, without starting any command line:

1. Is `wallpaper64.exe` / `wallpaper32.exe` running, and where is it? Asked
   in-process by `Identity/WindowsDesktop.cs`. Installed but closed means the
   player sees the Windows wallpaper, so that one is used.
2. Which monitors are plugged in right now, main one first? Also
   `WindowsDesktop.cs` (Windows' own monitor list).
3. Which wallpaper is on the main monitor? `wallpaper_engine/config.json`
   files a wallpaper per monitor, keyed by the monitor's device path
   (`//?/DISPLAY#HWV62F5#...UID4353#{...}`), under the player's Windows user
   name. It never forgets old ones: every port, cable and GPU a monitor was
   ever on leaves an entry behind. The live one is the key that matches a
   monitor plugged in now. Wallpaper Engine's "layout" mode keys screens by
   position instead, and `MonitorPositionL0T0` is the main one.
4. That wallpaper's `project.json`: title, type, `contentrating`, and its
   preview. The preview is what we show for every type: scene and web
   wallpapers can't be rendered outside Wallpaper Engine, and Godot can't play
   the .mp4 of a video one. Most previews are animated gifs, small enough for
   the PC's 400x202 screen anyway.
5. The gif is decoded by `Identity/gif_decoder.gd` (pure GDScript) and the
   frames are cached in `user://identity/wallpaper/` until the preview changes.
   First decode is a second or two, later boots are instant.

`WindowsDesktop.cs` needs the .NET build and the C# project built once, like
`WindowsUserPicture.cs`. Without it the game falls back to `tasklist` and
`reg`, can't tell the monitors apart, and takes the first entry in the config,
which may be an old one.

```gdscript
PlayerIdentity.wallpaper_ready             # signal(first_frame) when the lookup is done
PlayerIdentity.is_wallpaper_ready()        # false while looking (starts it if nothing has)
PlayerIdentity.get_wallpaper_frames()      # SpriteFrames for an AnimatedSprite2D, null if it's still
PlayerIdentity.get_wallpaper_images()      # every frame as an Image
PlayerIdentity.get_wallpaper_delays()      # seconds per frame
PlayerIdentity.get_wallpaper_info()        # source, title, type, rating, workshop_id, screen, animated, skipped
PlayerIdentity.refresh_wallpaper()         # look again (e.g. after a settings toggle)
```

`source` is `wallpaper_engine`, `windows` or `none`. `screen` says how the
monitor was matched (`main monitor`, `second monitor`, `layout mode, main
monitor`, or `no monitor matched, first entry (may be old)`). `skipped` says
why a Wallpaper Engine wallpaper wasn't used.

Exports (edit the defaults in `player_identity.gd`, autoload exports are
decorative): `use_wallpaper_engine`, `wallpaper_max_rating` (Everyone by
default; anything rated higher falls back to the Windows wallpaper - the
Workshop is full of Mature ones and a streamer's desktop shouldn't end up on
stream), `wallpaper_max_frames` (150).

Limits: it's read once at game start, so a wallpaper changed mid-game shows
up next launch (or after `refresh_wallpaper()`). Only the main monitor's
wallpaper is used. A timed playlist isn't written to `config.json` on every
change, so with one running we get the last wallpaper picked by hand.

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
the picture arrived and the fault is in the UI node. For the wallpaper it
prints the monitors plugged in, whether Wallpaper Engine is running, its
folder, every monitor entry in config.json with the one that matched, and what
was used.

### Before shipping

Put one line in the store page or EULA saying the game may read the profile
picture from a running Discord client and the desktop wallpaper (Wallpaper
Engine included), and keep it local-only. That keeps it a horror trick instead
of a privacy complaint.

---

## 20. PC screen

A computer the player sits at. It powers on, logs in as the real player
(Windows account name and picture), then shows a small desktop with the
player's own wallpaper behind it. Everything lives in `PC/`.

### Putting a PC in a level

Area2D + `PC/pc_terminal.gd` + a CollisionShape2D, optional `Prompt` child.
Sami walks in, presses `interact`, the screen opens and the world pauses. The
X on the taskbar or Esc shuts it down and hands the game back.

| Export | What it does |
|---|---|
| `screen_scene` | The PC scene, `PC/pc_screen.tscn` by default |
| `require_flag` | The PC only works once this is set (power, a key). Empty = always |
| `used_flag` | Set the first time it opens |

`open()` opens it from code. Signals: `opened`, `closed`, `refused`.

### The scene

Open `PC/pc_screen.tscn`. The layout is the scene: every button, text box and
the clock sit on the 640x360 art in art pixels, so move them in the editor if
the art changes. Behaviour is in `pc_screen.gd`.

Root inspector:

| Group | Exports |
|---|---|
| Content | `characters` (the list, in order - keep it A-Z), `tutorial_text`, `instagram_url`, `x_url`, `use_24_hour` |
| Player | `use_player_wallpaper`, `wallpaper_brightness`, `animate_wallpaper`, `wallpaper_speed`, `pixelate_player_images`, `fallback_name`, `discord_fallback` |
| Wallpaper effects | `still_drift`, `still_flicker`, `moving_drift`, `moving_flicker`, `drift_zoom`, `drift_seconds`, `flicker_strength`, `flicker_every` (see below) |
| Timing | `off_seconds`, `power_seconds`, `login_seconds`, `login_fps`, `shutdown_seconds`, `fade_seconds` |
| Art | boot frames, login sheet, Arabic desktop, default page, `cursor` + `cursor_hotspot` |

Text size, colour and font are in `PC/pc_theme.tres`. With no font set there,
the default font is used in sharp (signed-distance) mode; a pixel font dropped
into `default_font` looks best.

### Characters

One `PcCharacter` .tres per person in `PC/Characters/`:

- `icon` - the full 640x360 icon layer from the art file. The PC crops it.
- `text` - the page text. English here, Arabic as a row in translations.csv.
  BBCode works (`[b]`, `[color=#...]`).
- `page_art` - optional page that replaces the plain one (the classified
  file). Export it without the little pointer.

Seven icons show at once; the arrows or the mouse wheel scroll the rest. The
pointer above the page is its own piece (`COMPUTER_UI_page_pointer.png`) and
moves under whichever icon is picked, so page art never carries one.

### Art

`PC/Art/` keeps the artist's file names, so a re-export drops straight in.
Made from the artist's layers, redo them if the originals change:
`COMPUTER_UI_page.png` (a page with the pointer removed),
`COMPUTER_UI_page_pointer.png`, `COMPUTER_UI_screen_glare.png` (the glass
streaks alone, added over the wallpaper) and `COMPUTER_UI_clock_digits.png`
(0-9, 4x6 each, drawn either side of the colon in the art).

### The moving wallpaper

A Wallpaper Engine wallpaper plays on the screen at its own timing (see
section 19 for how it's found). If the PC opens before the lookup has
finished, it shows the Windows one and swaps the moving one in when it lands.

Only wallpapers whose preview is a gif move. Scene wallpapers animate inside
Wallpaper Engine's own renderer, and many ship a still `preview.jpg`; those
arrive as a still, like the Windows wallpaper.

### Wallpaper effects

Two effects give the screen life, switched separately for the two kinds of
wallpaper, so e.g. flicker on both but drift only on stills:

| Export | Still wallpaper | Moving wallpaper |
|---|---|---|
| Drift: a slow zoom in and back out, wandering across the picture | `still_drift` (on) | `moving_drift` (off) |
| Flicker: a faint shimmer with a dip now and then | `still_flicker` (on) | `moving_flicker` (on) |

Tuning, shared by both: `drift_zoom` (how close it gets, 1.15),
`drift_seconds` (one zoom in and out, 30), `flicker_strength` (how dark,
0.2), `flicker_every` (average seconds between dips, 4). Switching any of them
while the PC is up eases in or out instead of jumping. Keep the flicker
gentle: strong fast flicker is hard on photosensitive players.

The drift never shows the picture's edge, and every art pixel stays one
solid pixel while it moves (`PC/pc_wallpaper.gdshader` samples once per art
pixel), so it still reads as the old monitor.

All of it is live from code, for dialog and cutscene beats:

```gdscript
var pc := get_tree().get_first_node_in_group("pc_screen") as PcScreen
pc.wallpaper_speed = 0.25       # slows the frames and the drift
pc.wallpaper_speed = 0.0        # freezes both on the spot
pc.wallpaper_speed = -1.0       # plays both backwards
pc.zoom_wallpaper(1.5, 4.0)     # push in over 4 seconds, drift or not; 1.0 goes back
pc.flicker_wallpaper(0.3, 0.9)  # one hard dip right now, even with flicker off
pc.still_flicker = false        # any switch, any time
pc.is_wallpaper_moving()        # which set of switches is in charge
```

### While it is up

- Every key is swallowed, so TAB and the log key can't open anything under it.
- The mouse is made visible and the cursor swapped; both come back on close.
  If the game ever sets its own custom cursor, re-apply it on `closed`.
- SoundMap moments: `PcScreen.powered_on`, `logged_in`, `shut_down`,
  `closed`, `data_toggled`, `app_opened`, `app_closed`,
  `character_selected`, `scrolled`, `link_opened`, and `PcTerminal.opened`,
  `closed`, `refused`.
- `app_opened` / `app_closed` carry `"characters"`, `"tutorial"` or `"media"`.

---

## 21. Interactables (the fuse box puzzle, and the parts it's made of)

Five drop-in nodes in `Interactables/`. Each is an Area2D with a
CollisionShape2D and an optional `Prompt` child shown when the player is near.
All of them are general; the fuse puzzle is one wiring.

**FlagArea** - "when X happens here, do Y". `fires_on`:
Walk in / Walk out / Press interact / Radio tuned.

- What it does, in this order: `set_flags`, `clear_flags`, `sound_id` (an id
  or a full cue), the `triggered` signal, then `actions` one after another.
  `actions` is the same list a dialog line has (`open_window`, `give_item`,
  `play_set`, `kill`, `checkpoint`, `state`, custom...). `wait` / `delay` in
  it pause before the next step; the `wait` tick box does nothing here.
- Radio: `radio_frequency` with decimals (23.12), `radio_tolerance` (0.0001 =
  exact), `radio_player_inside` (on: Sami has to stand in the area),
  `radio_must_be_open`, `radio_hold_seconds`. It works while the game is
  paused, and fires once per tuning: the dial has to leave the number and
  come back to fire again.
- When: `require_flag`, `hide_flag`, `once_only` (on by default, remembered
  in `done_flag`, or a flag made from the node's path if that's empty),
  `cooldown` for areas that fire again.
- Interact never fires while a dialog is running (that press belongs to the
  dialog). `fire()` fires it from code with the same checks.
- Its SoundMap moment is `FlagArea.triggered`. Leave that row empty and use
  `sound_id` per area; a value in the map plays for every FlagArea.

**Readable** - a note the player reads. `image` (your PNG), `text` (ours,
translated), `text_area` as fractions of the image, font and colour,
`open_sound_id` / `close_sound_id`, `read_flag`. Fills the screen, pauses the
game, closes on interact or Esc.

**ItemSocket** - a slot that wants one item: `item_type` from the Bag,
`consume`, `inserted_flag`, `solved_flag`. A `Sprite` child that is an
AnimatedSprite2D with animations `empty` / `red` / `green` (or a Sprite2D with
the three textures). On insert: red, hold, flicker red/green `flicker_count`
times, green, `solved_flag`. Without the item: `needs_item` signal and
`missing_sound_id`. `insert()` from code skips the Bag check.

**WallClues** - dates on the wall, one per `Marker2D` child (three by
default), all random, and one of them - also random - is the answer. No tell;
the player gambles. `digits` (0-9 PNGs) and `months` (Jan-Dec PNGs) build each
piece. On the wall from the start unless `reveal_flag` is set. `reshuffle()`
rerolls; a checkpoint reload rerolls on its own. `answer_frequency()` returns
23.12 for 23 December.

**RadioCheck** - the PC. `wall` points at the WallClues, `tolerance`
(0.0001 = exact), `require_flag` is the fuse: before it, interact plays
`no_power_sound_id` and emits `no_power`, nothing else. Powered and right:
`success_flag`. Powered and wrong: opens `minigame_window_id` - a
PopupWindowDef of kind PORTAL with `portal_scene` = your mini-game scene and
`portal_interactive` on - takes focus, pauses the game. The scene's root emits
`won` / `lost` (names are exports). Lost: `lose_death_cause` kills the player,
the checkpoint reload rerolls the wall (with no death cause set the wall
reshuffles in place). Won: window closes, try another date.

The fuse puzzle, wired: WallClues on the wall from the start -> ItemPickup
(fuse) -> ItemSocket (`item_type = fuse`, `solved_flag = fusebox_solved`) ->
RadioCheck (`require_flag = fusebox_solved`, `wall` = the WallClues,
`success_flag = cctv_on`, `no_power_sound_id = fail_pc`) -> you swap the CCTV
sprite on `cctv_on`.

`RadioLink.frequency_exact()` reads the radio with decimals for the new dial.

Overlapping interactables all answer the same interact press. Keep their
collision shapes apart.

---

## 22. Fast Grabs

`FastGrabs/` is a shelf of ready-made scenes. Drag one from the FileSystem
dock into a level, fill in its inspector, done. Each comes with its collision
shape, a `Prompt` placeholder (an "E" label; swap in your art) where the node
uses one, and default values.

| Folder | Grabs |
|---|---|
| Interactables | FlagArea, Readable, ItemSocket, WallClues, RadioCheck, PcTerminal |
| Items | ItemPickup |
| Dialog | DialogZone, DialogTrigger, NPC |
| Sound | MusicZone, AmbienceZone, FloorSurface, SoundHook |
| Hazards | ToxicArea, DamageArea |
| World | MapRoom, WindowBlocker, ProgressStateMachine |

Two things to know:

- **Resizing the area**: the children of a dropped scene are hidden. Right-click
  the node in the Scene tree -> **Editable Children**, then drag the shape's
  handles.
- **Every copy has its own shape.** The shapes are Local to Scene, so resizing
  one door's area leaves the other doors alone. ItemSocket's SpriteFrames are
  per copy too, so each socket can have its own art.

DialogTrigger and NPC are inherited from `DialogV2/dialog_trigger.tscn` and
`NPC/npc.tscn`: change those and the grabs follow. `FastGrabs/README.md` has
one line per grab.

---

## 23. FD Sound plugin (editor): sounds, flags and ids

An editor plugin in `addons/fd_sound/`. It ships in its own zip because Godot
only loads plugins from `res://addons/`.

**Install once**: put the `fd_sound` folder in `res://addons/` (next to any
addons you already have), then Project Settings -> Plugins -> tick
**FD Sound**. The tick is saved in project.godot, so everyone who pulls the
project has it.

It knows every **SoundDef** and **MusicSet** the game will find: it reads
`LIBRARY_DIRS` and `SETS_DIRS` from the Sound autoload, so a file outside
those folders isn't listed (the game wouldn't find it either). A new or
edited file shows up as soon as it's saved.

The two kinds are handled differently because they do different jobs:
**SoundDef** is one sound with an id; **MusicSet** is one piece of music as
stems, mixed by layers.

**SoundDef fields** - every `sound_id`, `*_sound_id` and `music_id` field:

- The text box stays, so cues (`delay(1) scream, loop(0.5) drone`) can still
  be typed.
- A mark after it: green tick = the first id in the box exists; red cross =
  it doesn't, and the game will stay silent there. Hover it for details.
- Search button: a list of every sound with its category. Type to filter,
  click to pick. For `music_id` the Music tracks come first.
- Play button: hear it in the editor, with its volume and pitch. Press again
  to stop.

**MusicSet (.tres)** - "Preview this set" at the top of its inspector: tick
the layers, press play. All stems start together; ticking or unticking while
it plays fades that layer in or out, so you can find the mix for a room
before placing a zone.

**MusicZone / AmbienceZone** - `layers` becomes tick boxes read from the
zone's own `music_set`, plus "Hear this room's mix". A name that the set
doesn't have (a typo, or a stem that was renamed) shows in red; untick it to
remove it.

**Dialog lines and action steps** (this includes a FlagArea's `actions`) - a
"Sound for this action" row. Pick fills the first arg, depending on the verb:

| Verb | The list |
|---|---|
| play_sound | sounds (SoundDef) |
| play_music | sounds, Music tracks first |
| play_set | music sets (MusicSet) |
| music_layer | layer names of the Music sets |
| ambience_layer | layer names of the Ambience sets |

The other args stay as they are (`play_set`'s layer list, say). Every pick
goes through undo like a normal edit.

**SoundHook** - `hooks` becomes a table. The top line says which node it
listens to. Each hook is two lines:

- The dropdown: what happens, taken from that node. Its own signals first,
  then its animations (`open  starts`, `open  frame 2`, `open  finishes`),
  then the engine's built-in signals. A choice already used by another hook
  is greyed out.
- `plays`: the sound, with the same search, play button and tick/cross as any
  sound field.

"Add hook" adds the next free one, the bin button removes one. A saved hook
the node doesn't have any more (renamed signal or animation) stays in the
list in red as "(not on this node)", so nothing disappears quietly: pick the
new name. Change `Target Path` and the lists follow. Godot sorts the hooks
alphabetically when the scene is saved; order doesn't matter.

### Flags and ids

The plugin also knows every **flag** and every **id** in the project, so
they're picked, not typed.

**Flag fields** - every field that holds a flag (`require_flag`, `hide_flag`,
`show_if_flag`, `done_flag`, `read_flag`, `close_flag`...): text box, search
list of every flag in the project (with how often each is set and read), and
a mark. What the mark means depends on what the field does with the flag:

| The field... | Green tick | Yellow sign | No mark |
|---|---|---|---|
| waits for the flag (require, hide, show, reveal, unlock, active...) | something sets it | nothing sets it: waits forever | - |
| clears it (`clear_flags`) | something sets it | nothing sets it: probably a typo | - |
| sets it (`set_flags`, `done_flag`, `read_flag`...) | something reads it | - | nothing reads it yet (fine) |

Hover the mark to see exactly where: "hospital.tscn > Opener",
"nurse_talk.tres", "door.gd:12".

**Flag lists** (`set_flags`, `clear_flags`, `require_flags`,
`blocked_by_flags`): one row per flag, each with its own list and mark;
"Add flag" and the bin button.

What counts as setting a flag: any field that sets one, a dialog
`set_flag` / `toggle_flag` action, `Flags.set_flag("...")` in any script
(the other dev's too), and the flags the game makes by itself:
`item:<type>` when an item is picked up or given, `died_of:<cause>`,
`window_seen:<id>`, `map:<room>`, and any `"prefix:" + something` a script
builds.

**Id fields** get the same row, filled from the folders the game loads them
from, with a red cross when the id doesn't exist:

| Field | Comes from |
|---|---|
| `death_cause`, `cause_id`, `lose_death_cause`, `fail_death_cause`... | `Death/Causes` |
| `item_type` | `Items` (each MedicalItem's `type`) |
| `*window_id` | `Windows/Defs` (each def's `id`, not its file name) |
| `room_id` | `Map/Rooms` |
| `state_name`, `next_state` | the ProgressState nodes in your levels |

A window's id is not its file name: `win_stuck_note.tres` has the id
`stuck_note`. The list always shows the real one.

**Dialog and FlagArea actions**: Pick also fills `set_flag`, `clear_flag`,
`toggle_flag` (a flag), `open_window`, `close_window` (a window), `give_item`,
`take_item` (an item), `kill` (a death cause) and `progress_stage` (a state).

Two limits:
- The lists come from saved files. A flag you just typed in an unsaved scene
  shows up everywhere once you save (Ctrl+S).
- A script that builds a flag name at runtime (`"door_" + str(n)`) can't be
  seen, so a flag set that way may show yellow. The hover text says so.

Not covered: the SoundMap is still typed by hand; the spy (section 17) shows
when it names an id that doesn't exist.

---

## 24. Main menu

`MainMenu/main_menu.tscn` is the whole menu. Make it the project's main scene
(Project Settings > Application > Run > Main Scene) and add the `Profile`
autoload. It's a real scene like the PC: open it and everything is in the
inspector.

### The room

The art is a loop of 640x360 frames in a grid (`Art/menu_english.png`,
`menu_arabic.png`, and the two `menu_finished_*` sheets that show once the
game is finished). Only the sheet for the current language is loaded.

- Export new sheets as a grid, not one long strip. A strip of 36 frames is
  23,040 px wide and graphics cards stop at 16,384. Any number of columns
  works; `frame_count` trims empty cells at the end.
- `fps` sets the loop speed. `buzz_frames` are the frames the door light cuts
  out on; `buzz_sound_id` plays on them.
- `menu_preview.png` is only there so the room shows in the editor.

### The things you can click

Each one is a `MenuHotspot` under `Hotspots`: a Polygon2D whose points are its
outline on the art. Select it and drag the points; the orange tint is only
visible in the editor. Per hotspot: `action`, `enabled`, `label` (English,
Arabic from the CSV), `label_at`, `hover_sound_id`, `press_sound_id`, and
`highlight` (a full 640x360 lit layer from the artist; empty = the art under
the outline brightens).

| Hotspot | Does |
|---|---|
| Door | Pushes into the doorway until the light fills the screen, clears Flags, loads `new_game_scene` |
| Chair | First press shows "Leave? Press again", second press quits |
| Dominoes | Opens settings |
| Radio | On / off |
| KnobBack, KnobNext | Previous / next station (a knob on a silent radio switches it on) |
| Counter | Load save. Off (`enabled`) until it's designed |

Arrow keys and the d-pad walk the hotspots in scene order (left to right),
Enter / A presses. TAB and the in-game shortcuts are blocked while the menu
is up.

The door push centres on `door_opening` (the lit doorway on the art). The
light is full a quarter of the way before the push ends and holds for
`door_hold_seconds`, so no room shows round the edges before the first scene.

### Intro

`intro_video` plays before anything else, then the first-launch setup, then
the room. Godot only plays Theora video (.ogv), not .mp4, so convert it once:

```
ffmpeg -i intro.mp4 -c:v libtheora -q:v 8 -c:a libvorbis -q:a 6 intro.ogv
```

Renaming an .mp4 to .ogv doesn't convert it. The menu checks the file first:
a wrong one prints a red error in Output saying what it really is, and the
game goes straight on to the setup or the room. A film that stops moving
mid-way is skipped after a second and a half, with an error too.

Drop the .ogv in the project and drag it onto `intro_video`. By default it
plays on the first launch only; `intro_every_launch` plays it every time. To
see the first launch again, delete `profile.cfg` in the game's user folder
(Windows: `%APPDATA%/Godot/app_userdata/<project name>/`) or call
`Profile.forget_all()`.
Any key, click or pad button skips it (`intro_skippable`), after a short grace
so the click that opened the game doesn't. The film keeps its shape with black
round it. `intro_category` picks the volume slider its sound follows.

### Radio

`Radio` (MenuRadio) holds `tracks`, a list of `RadioTrack` resources. Each one
takes either a library `sound_id` or the audio file itself in `stream`
(`volume_db` trims it), and `locked_until_heard`. A locked track plays static
in its slot until that music has played anywhere in the game (play_music, a
MusicZone, a loop or a one-shot of a Music sound; stems of a MusicSet don't
count). The static is `static_stream` (the file) or `static_sound_id`; with
neither, a locked station is silent. The id is the `id` field inside the
SoundDef, not its file name.

Every station change prints a line to Output saying what plays and why
(`MenuRadio: station 2/4 -> static: 'song_d' is locked until the player hears
it in game`). A station that can't play is silent, and a warning names the
problem and lists the Music ids that did load. `debug_log` turns the lines
off. The radio plays on the Music bus. While it's on, the room
tone (`ambience_sound_id`) drops by `radio_duck_db`.

Radio art, on MainMenu: `radio_playing_art` while a station plays,
`radio_static_art` on static. Either can be one image or a sheet of frames
(`radio_art_fps`). `radio_art_frame` is the size of one frame and
`radio_art_position` where its top-left corner sits; the defaults (640x360
at 0,0) are for full-canvas layers. A state with no art shows a glow on
`radio_dial_rect` instead.

### Settings and the first launch

`Settings` (MenuSettings) is the panel the dominoes open: language, the six
volumes, fullscreen. On the first launch, after the intro, the same rows
come one page at a time before the room shows: language (written in both languages),
volume, display, with Back / Next / Done. Esc closes the panel, or goes back
a page during setup. In Arabic, Back and Next swap sides.

Until the artist's panel exists it's a plain dark box. Set `background` (a
full 640x360 image) and move `panel_rect` to where the paper is; the rows and
buttons are laid out inside it. `first_run = false` on MainMenu skips the
setup.

### Profile

What the game remembers between launches, outside of saves, in
`user://profile.cfg`:

```gdscript
Profile.needs_first_run()     # true until the setup is done
Profile.is_finished()         # set when the flag game_finished is set
Profile.has_heard("song_id")  # music heard in game
Profile.set_fullscreen(on)    # borderless, so popup windows still work
Profile.forget_all()          # next launch is a first launch (testing)
```

Mark the ending with `game_finished` in the last dialog's `set_flags` (or a
checkpoint's). It only ever turns on; New Game clearing the flags doesn't
undo it. Don't turn on PopupWindows' `borderless_fullscreen` as well; the two
would fight over the window.

---

## 25. Debug panel (F11)

For testing without replaying the game. Press **F11** in any debug run (from
the editor, or a debug export). The game pauses and the mouse shows; **F11** or
**Esc** closes it and everything goes back as it was. Exported release builds
don't have it. Flags adds it by itself, nothing to set up.

**Flags** - "Set now" lists every flag that's set, with its value if it isn't
just `true` (`game_state = Basement`). Click one to clear it. "Not set" lists
every other flag the project uses: read from every level, dialog and script
(the other dev's too), plus the ones the game makes (`item:medkit`,
`died_of:bleeding`, `window_seen:...`). Click one to set it. The search box
filters both; type a name that isn't there and press Enter to set it anyway.
"Clear all" clears every flag one by one, so everything listening reacts.

The usual move: a once-only FlagArea, DialogZone or pickup already fired -
find its done flag in "Set now", click it, walk in again.

**Jump**
- Checkpoints: every Prescription checkpoint. Click one and the game does
  exactly what entering its code does: its flags, its progress state, its
  scene.
- Progress states in this scene: the ProgressStates of the level you're in,
  the current one marked with `>`. Click to go there.
- Reload this room: restarts the level. Flags stay as they are.

**Items** - every item with how many are in the Bag; +1 / -1.

**Player** - Heal fully, Stop bleeding, Hurt 1, Start bleeding. "Die of..."
lists every death cause: click one to close the panel and die of it, to check
the death board.

**Windows** - every popup window by id; click to open it, "(open)" marks the
ones open. The game is paused, so a window that moves or fades starts once you
close the panel. Close all windows is at the bottom.

F11 and Esc work even while a popup window holds the keyboard. TAB is kept
away from the Board while the panel is open. The key is `KEY` at the top of
`Debug/debug_panel.gd` if F11 clashes with something.

In an exported debug build the Flags tab can't read the project's files, so
"Not set" only has the flags seen during that run and the ones the game makes.
