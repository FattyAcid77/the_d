# GameSystems — NPCs + Dialog, rebuilt for the new Sami player
One folder, everything you need. Put it at:  res://GameSystems/

Works with your new player as-is (sami_doctor.gd): it detects the "Player"
group / Player class, and the dialog pauses the game so your state machine,
push/pull, and inventory are never touched.

================================================================
## 1. ONE-TIME SETUP (do these first, ~2 minutes)
================================================================
A) Autoloads — Project > Project Settings > Globals (Autoload):
	 Flags          ->  res://FD_Testing/GameSystems/DialogV2/flags.gd
	 DialogManager  ->  res://FD_Testing/GameSystems/DialogV2/Scripts/dialog_manager.gd
   (Names must match exactly.)

B) Input Map — add an action named `interact`, bind a key (E is typical;
   NOT F — your push/pull already uses F).

C) Optional typewriter sound — the old mp3 was deleted with FD_Testing.
   Drop any SHORT blip sound at:
	 res://FD_Testing/GameSystems/DialogV2/dialogue_noise.mp3
   and it's picked up automatically. (Or drag any sound into the DialogUI
   root's `Type Sound` slot.) No sound file = silent typewriter, no errors.

================================================================
## 2. ADD YOUR FIRST NPC (5 minutes)
================================================================
1. Instance  res://FD_Testing/GameSystems/NPC/npc.tscn  into your level.
2. Make its identity: FileSystem dock -> right-click -> New Resource ->
   NPCResource. Save as e.g.  NPC/Resources/java.tres.  Fill in:
	 - npc_name       "Java"
	 - sprite_frames  the character's SpriteFrames (Idle_down, Walk_Side...)
     - portrait       optional face image
     - dialog         (see step 3)
3. Make its dialog: New Resource -> Dialog. Save as  java_dialog.tres.
     - On `branches` add a DialogBranch, set id = "entry"
	 - Add DialogLines to its `lines` — that's what they say
	 - Drop java_dialog.tres into the NPCResource's `dialog` slot
4. Drop java.tres onto the NPC instance's `npc_resource` slot.
5. Run. Walk up (a "!" shows), press interact.

Quick test with no resources at all: select the NPC's DialogTrigger and tick
`use_demo_dialog` — a built-in apple conversation plays.

Movement (optional — no behavior = standing NPC):
  - WANDER: add a child node to the NPC, type NPCBehaviorWander.
    Tune radius and walk/wait times in the inspector.
  - PATROL: add a child node, type NPCBehaviorPatrol, then add Marker2D
    children to IT and place them in the world — the NPC walks the loop.
  Exactly one behavior per NPC.

================================================================
## 3. WRITING DIALOG — the model
================================================================
Dialog (one per NPC)
 └─ branches: [DialogBranch]           "entry" plays first; others are topics
     └─ lines: [DialogLine]
		 ├─ text            what's said (BBCode ok; EMPTY = action-only step)
		 ├─ show_if_flag    skip line unless this flag is set
		 ├─ set_flags       flags set when the line shows
		 ├─ keywords        clickable words -> topics (see below)
		 ├─ choices         player buttons: set_flag / goto_branch / ends_dialog
		 ├─ Camera group    move_camera + target + time (cutscene pan)
		 └─ Action group    action_name/args (+ wait_for_action)

FLAGS = the game's memory. From ANY script:
    Flags.set_flag("apple_eaten")
    Flags.is_set("apple_eaten")
    Flags.add_flag("times_talked")           # counter
    Flags.to_dict() / from_dict(d)           # save / load

KEYWORDS (the apple mechanic): on a line, add a DialogKeyword:
    word = "apple", unlock_flag = "apple_eaten", topic_branch = "apple"
  Before the flag: plain text. After: the word lights up AND a topic button
  appears; both open the "apple" branch. `ask_once` = topic vanishes after.

ACTIONS — dialog asks the game to do something:
    DialogManager.action_requested.connect(_on_action)
    func _on_action(name, args):
        match name:
            "give_item": inventory.add(args[0])
            "open_gate": $Gate.open(); DialogManager.finish_action()
  (finish_action only needed when the line's wait_for_action is ticked.)

================================================================
## 4. WHAT'S ALREADY HANDLED (fixes baked in)
================================================================
- Typewriter + blip animate on EVERY line (advance-press can't skip).
- Interact or the X (top-right) closes cleanly; no reopen-loop; the X
  works from anywhere in a conversation.
- Arabic auto-detects: flows RTL and sits on the RIGHT; English LTR/left.
  The NPC name stays fixed in its plate for both.
  !! Arabic needs an Arabic-capable font (e.g. Noto Sans Arabic) assigned
  on the Text and NameLabel nodes, or letters show as boxes.
- Name and text have FIXED regions — nothing jumps between lines; text
  wraps inside the box; long names clip.
- The box uses text_box.png (NinePatchRect). Tuning knobs:
	where text sits   -> Box/Margin margins   (L50 T40 R50 B26)
	how frame borders stretch -> Box/BG patch margins (L35 T74 R24 B20)
	box height        -> Box offset_top (-260)
- Empty UI slots print a clear error naming the slot (no silent failure).
- NPCs stop during dialog (tree pause) and FACE the player when talked to.
- The "!" prompt is a plain Label — replace the Prompt node's child with
  your own art whenever you like (Qest.png was deleted with FD_Testing).

================================================================
## 5. FILE MAP
================================================================
DialogV2/
  flags.gd                    autoload: world memory
  dialog_ui.tscn              the box (your text_box.png, X button)
  dialog_trigger.tscn         drop under anything talkable ("!" prompt)
  Scripts/ dialog_manager.gd  autoload: owns the one DialogUI
           dialog_ui.gd       display engine (typewriter, RTL, topics)
           dialog_trigger.gd  proximity + interact + face player
           dialog.gd / dialog_branch.gd / dialog_line.gd
           dialog_choice.gd / dialog_keyword.gd    (the resources)
           demo_dialog.gd     built-in apple example (code = authoring guide)
NPC/
  npc.tscn                    base NPC (DialogTrigger already inside)
  Scripts/ npc.gd             resource-driven body + animations + facing
           npc_resource.gd    identity: name, art, portrait, DIALOG, speed
           npc_behavior.gd    behavior base
           npc_behavior_wander.gd / npc_behavior_patrol.gd
  Resources/                  put your .tres NPCs + dialogs here

================================================================
## 6. CUTSCENES — play a video like calling a function
================================================================
!! Godot can NOT play .mp4. Only .ogv (Ogg Theora). Your Test_Anime.mp4 is
already converted and included: Cutscene/test_anime.ogv
Convert future videos with:
  ffmpeg -i input.mp4 -c:v libtheora -q:v 8 -c:a libvorbis -q:a 5 output.ogv

SETUP: add a THIRD autoload —
  Cutscene  ->  res://FD_Testing/GameSystems/Cutscene/cutscene_player.gd

THE THREE WAYS TO TRIGGER IT (your three cases):

1) "When something happens" — from ANY script:
     Cutscene.play("res://FD_Testing/GameSystems/Cutscene/test_anime.ogv")
   or, to continue only after it ends:
     await Cutscene.play("res://FD_Testing/GameSystems/Cutscene/test_anime.ogv")

2) "When the player does this / goes there" — walk-in trigger:
   Add an Area2D, attach Cutscene/cutscene_trigger.gd, give it a
   CollisionShape2D, set `video_path`. `play_once` remembers via a flag;
   `set_flag_after` can unlock dialog reactions ("you saw that, right?").

3) "When this word appears" — from DIALOG:
   On a DialogLine (usually inside a keyword's topic branch), Action group:
	 action_name     = "cutscene"
	 action_args     = ["res://FD_Testing/GameSystems/Cutscene/test_anime.ogv"]
	 wait_for_action = ON
   The conversation pauses, the video plays, the dialog continues itself.
   So: keyword "apple" -> topic branch "apple" -> first line empty text with
   the action = clicking the word plays the cutscene.

Behavior: fullscreen over everything, black bars keep the video's shape,
game pauses during playback (works mid-dialog too), and the player can skip
with `interact` (turn off via the `skippable` export on the autoload).

================================================================
## 7. STATUE PUZZLE — four speakers, two sides, three moods
================================================================
The statue reacts in stages: all wrong = sad, one full side right = it
moves (next sprite), both sides right = it SPEAKS (your dialog system).

FASTEST START: instance  Puzzle/statue_puzzle_example.tscn  into a level
and run — 4 speakers pre-wired (right = 1&4, left = 2&3, answers 1/4/2/3).
Walk to a speaker, press interact (E) to cycle its number.

MAKE IT YOURS:
- StatueSprite: assign SpriteFrames with 3 animations: "sad", "half",
  "solved" (names changeable on the PuzzleStatue).
- Answers: the 4 target numbers on the PuzzleStatue (Answers group).
- The statue's speech: make a Dialog resource, drop it in `dialog`,
  set `statue_name` / `portrait`. It speaks ONCE automatically on solve.
  Want it talkable again afterwards? Add a DialogTrigger to the statue
  with the same (or another) Dialog.
- Optional: `solve_cutscene` (.ogv) plays BEFORE it speaks.
- `solved_flag` (default "statue_solved") is set on solve — other NPCs
  can react via show_if_flag, doors can open, etc. Solved state persists;
  on reload the statue starts awake and the speakers lock.

THE TELLS (your choice: per-speaker feedback):
- A correct speaker tints its number green (`tell_color`) and can play a
  hum: drop a short sound into the speaker's `hum_stream`.
- Turn `per_speaker_tell` OFF on the statue for the harder side-only mode.

VISUALS ARE PLACEHOLDERS: the speaker is a gray box + number so it runs
today — replace the Body/NumberLabel/Prompt children with your pixel art
whenever; the script only needs the node names to stay.

Signals for extra juice: `side_solved("right"/"left")` fires once per
side (rumble, sound, light); `puzzle_solved` fires at the end.

================================================================
## 8. GAME PROGRESS — one state machine for the whole game
================================================================
SETUP: autoload #4 —
  GameProgress -> res://FD_Testing/GameSystems/Progress/game_progress.gd

HOW IT WORKS
- The current state is ONE name (e.g. "Start", "Act2"), stored in Flags
  ("game_state") so it saves/loads with everything else.
- Each LEVEL gets a ProgressStateMachine node with ProgressState children — the
  child's NODE NAME is the state name (your empty-node-per-state idea):
			ProgressStateMachine
	  ├── Start
	  ├── Met_Java
	  └── Act2
  On level load, the machine enters the child matching the current state.
  A level only needs children for states that matter to it.

WHAT A STATE CAN DO (all in the inspector)
- show_groups / hide_groups: node groups turned on/off (visible + process)
- set_flags: flags set on enter
- auto_advance_when_flag + next_state: OPTIONAL — when that flag turns on,
  the game moves to next_state by itself
- or extend progress_state.gd and override _enter()/_exit() for custom code

CHANGING STATE
- From code, anywhere:        GameProgress.goto_state("Act2")
- From DIALOG: a line with    action_name="state", action_args=["Act2"]
- Automatically: the auto_advance fields above

================================================================
## 9. LOGBOOK — the Outer Wilds knowledge map
================================================================
SETUP: autoload #5 —
  LogBook -> res://FD_Testing/GameSystems/LogBook/log_book.gd
Optional: Input Map action "log" (M/Tab). No action? M works as fallback.

IT'S ALL FLAGS: an entry appears on the board when ANY of its facts' flags
is set; facts reveal one by one; a line connects two entries when both are
discovered. Your dialogs/cutscenes/puzzle already set flags — the map
fills in on its own.

ADD KNOWLEDGE (no code): create a LogEntry .tres in LogBook/Entries/:
  id, title, picture, color, board_position, facts (flag + text),
  links_to (other entry ids). Two examples are included (FD + Statue)
  wired to flags you already use: "Video", "apple_eaten", "statue_solved".

BOARD CONTROLS: M opens/closes. Drag or arrows to pan, wheel or +/- to
zoom, click a card to read its facts, Esc closes.

================================================================
## 10. LOGBOOK v2 — draggable cards + DEDUCTIONS
================================================================
- Cards can be dragged around their home spot (springy, max 50px —
  JIGGLE_RADIUS in log_book.gd). Click = read; drag = move.
- DEDUCTIONS (connect-the-clues): make a LogDeduction .tres in Entries/:
  required_entries (the correct set of entry ids), board_position,
  result_title/text/color, result_flag.
  When ALL required entries are discovered, a "+" card appears showing
  "0 / N". Click it (turns green = connect mode), then click entries to
  connect (blue lines). At N connections it judges: all correct -> the
  card becomes the result entry, result_flag is raised (dialogs react!),
  golden lines to its sources stay forever. Wrong -> the card SHAKES and
  says "1 wrong" / "2 wrong"; fix your connections and it re-judges.
- Example included: 4 clue entries + deduction_azoz.tres. Set flags
  apple_eaten, ahmed_saw_apple, crumbs_in_azoz_room (+ fd_in_bathroom as
  the decoy) and solve who ate the apple.
- Your input action name lives at the top: OPEN_ACTION in log_book.gd.

================================================================
## 11. COMIC CUTSCENES — panel by panel
================================================================
A Comic = a list of ComicPanels. Each panel: a looping .ogv video OR an
image, optional sound on appear, set_flags on appear, and either waits
for "interact" or auto-advances after N seconds.
- Make one: New Resource -> Comic, add ComicPanel elements. Example:
  Cutscene/example_comic.tres
- Play: await Cutscene.play_comic(load("res://...tres"))
- From dialog: action_name "comic", args ["res://...tres"], wait ON.
- GIF/MP4 cannot play in Godot — convert:
  ffmpeg -i input.gif -c:v libtheora -q:v 8 output.ogv
- Single-video mode (Cutscene.play) still works exactly as before.

================================================================
## 12. NPCs STICKING TO THE PLAYER — fixed
================================================================
CAUSE: player and NPCs are both CharacterBody2D. Once their shapes overlap
even slightly, neither can push the other out, so they jam together — and a
wandering NPC kept walking into the player, making it look "glued".

THE FIX (already in npc.gd / the behaviors):
- PERSONAL SPACE: an NPC closer than `separation_radius` (22px) to the
  player or another NPC is gently pushed away, with the force growing the
  closer they get. Works even when the NPC is standing still — which is
  exactly when the player walks into them. Tune on each NPC:
  `separation_strength` (140), `separation_radius` (22),
  `separate_from_npcs`. Set strength to 0 to turn it off.
- GIVE UP WHEN BLOCKED: `npc.is_blocked` is true when the NPC bumps the
  player or another NPC. Wander instantly picks a new direction; Patrol
  skips to the next point after `give_up_after` seconds.

IF YOU'D RATHER NPCs NOT BLOCK THE PLAYER AT ALL (also valid, common in
top-down games): put NPCs on their own collision layer and remove that
layer from the player's collision MASK — the player then walks through
NPCs and sticking is impossible. The DialogTrigger still works, because
Area2D detection uses its own layer/mask.

================================================================
## 12. AUTOMATIC BRANCH SELECTION (no clicking)
================================================================
When the player talks, the NPC picks WHAT TO SAY by itself: branches are
checked IN ORDER and the FIRST one whose conditions pass is played.

>>> THE ONE RULE: most specific branch FIRST, default greeting LAST. <<<

Each branch has (group "When this branch plays"):
  require_flags     ALL of these must be set     (empty = no requirement)
  blocked_by_flags  if ANY is set, branch hidden (this is how a branch
					disappears when the story moves on)
  play_once         play it a single time, ever

EXAMPLE — FD reacting to the apple story:
  branches (in this order!):
   1. "azoz_did_it"  require_flags=["azoz_eaten_apple"]
   2. "apple"        require_flags=["apple_eaten"]
					 blocked_by_flags=["azoz_eaten_apple"]
   3. "entry"        (no conditions — the fallback greeting)

  No flags        -> talks: entry
  apple_eaten     -> talks: apple
  azoz_eaten_apple-> talks: azoz_did_it   (apple is now invisible forever)

Nothing is clicked. You control exactly what shows and hides, and a branch
stays hidden until YOU set the flag that reveals it.

(The topic-hub/keyword system still exists for NPCs where you DO want the
player choosing — just tick `is_topic`. Leave it off for this model.)

================================================================
## 13. PRESCRIPTION SAVES — old-school password codes
================================================================
SETUP: autoload #6 —
  Prescription -> res://FD_Testing/GameSystems/Prescription/prescription.gd

Codes look like medicine:  "Nazomel 250mg". They encode a CHECKPOINT
number + a checksum — wrong or invented medicine = "does not exist".

1) DEFINE checkpoints: PrescriptionCheckpoint .tres in Checkpoints/:
   number (0-255, PERMANENT — never renumber!), state_name, set_flags,
   optional scene to load. Two examples included (0 = start, 1 = statue).
2) REACH one when the player passes a save point:
   code: Prescription.reach(1)   or dialog action "checkpoint", args [1]
   -> popup shows the new prescription; the player writes it down.
3) SHOW it again: Prescription.show_current() or action "prescription_show"
   (a nurse NPC: "your current prescription is...").
4) ENTER a code: Prescription.open_entry() — hook to a main-menu button —
   or dialog action "prescription_entry" (an in-world pharmacist).
   Four dials (syllables + dose), no keyboard needed, Arabic-safe.

!! NEVER change the syllable tables or checkpoint numbers after release —
   they ARE the players' written-down codes.
Popup texts are exports on the autoload (set them to Arabic if you like).

================================================================
## 14. LOGBOOK UI — the clipboard
================================================================
The board is now drawn as the clipboard art (BOARD_UI.png):
- The world behind is BLURRED (blur_background.gdshader; falls back to a
  plain dim if the shader is missing).
- Opening SLIDES the clipboard up from the bottom (slide_seconds export),
  closing slides it back down.
- The board is INFINITE by default (infinite_board export): pan forever in
  any direction. Notes are still CLIPPED to the paper (a SubViewport does
  the clipping, so nothing spills onto the wooden frame at any zoom).
  Press HOME or SPACE to snap back to your notes if you pan into emptiness.
  Turn infinite_board OFF to limit panning to the notes plus a margin.
- Fit knobs: board_scale (how much screen the clipboard fills) and
  paper_rect (x/y/w/h fractions of the paper window inside the art).
- Cards are the note PNGs: on a LogEntry set `note_icon` (Notes/Note_1.png
  ...), `icon_scale`, and `icon_tilt` for a hand-pinned look. Card size
  comes from the texture, so different notes are different sizes.
  Drop new note art from the artist into LogBook/Notes/ any time.
- Paper area is measured from the art (PAPER_L/T/R/B constants). If the
  artist changes the clipboard, update those four fractions.

================================================================
## 15. DEATH — animation, clipboard, retry from checkpoint
================================================================
SETUP: autoload #7 —
  Deaths -> res://FD_Testing/GameSystems/Death/deaths.gd
Then on the autoload set `main_menu_scene` (what QUIT loads).

SAMI'S DEATH STATE: add a Node named exactly "Death" under his
Statemachine and attach Death/death_state.gd. When the art is ready, add
animations named Death_down / Death_up / Death_Side (or just "Death") to
his SpriteFrames — the state picks whichever exists. No art yet = he
simply freezes, no errors.

KILL THE PLAYER:
	Deaths.kill("bleeding")            # id of a DeathCause
	Deaths.kill("bleeding", 1.5)       # longer animation beat
	dialog line: action_name = "kill", action_args = ["bleeding"]

WHAT HAPPENS (in order):
  1. input off, Sami's Death state plays his death animation
  2. the clipboard SLIDES UP from the bottom
  3. the board ANIMATION plays: BoardAnim/death_board_00..19.png
	 (your GIF, converted to 20 PNG frames — Godot can't play .gif)
  4. the writing appears: REAL-WORLD time of death, the cause, and the
	 CheckMark.png next to it
  5. RETRY / QUIT become clickable (disabled until then)
Timing knobs: default_anim_seconds, slide_seconds, frame_seconds,
write_delay. Placement knobs: header_pos, time_label_pos, time_value_pos,
cause_label_pos, cause_value_pos, check_pos, retry_rect, quit_rect.
IMPORTANT: the board art ALREADY DRAWS its own words (DECEASED, TIME:,
CAUSE OF DEATH, the three checkbox rows, RETRY, QUIT). So the screen only
adds TWO things on top: the clock value, and the CHECK MARK on the right
row. RETRY/QUIT are invisible hitboxes sitting on the printed boxes.
Placement knobs (measured from the art): time_value_pos, check_first_pos,
check_row_spacing, retry_rect, quit_rect.
Each DeathCause has a `row` (0 = Bleeding, 1 = Infection, 2 = Unknown) —
that's which printed box gets ticked. Leave its `label` empty since the
names are printed; fill it only if you also want the cause written out.

CAUSES OF DEATH: DeathCause .tres files in Death/Causes/ (id + label +
note). Three examples included. Every cause the player has ever died from
is remembered as a flag "died_of:<id>", and "death_count" counts deaths —
so a "ways you have died" collection screen is easy later.

RETRY: restores the player's last prescription checkpoint (flags, state,
scene). No checkpoint yet? It reloads the scene, and if you called
Deaths.set_respawn(pos) it puts them back there.
QUIT: loads main_menu_scene.

TUNING THE CLIPBOARD TEXT: the positions of TIME / CAUSE / checkboxes /
RETRY / QUIT are exports on the Deaths autoload, as fractions of the art
(time_value_pos, cause_value_pos, check_pos, retry_rect, quit_rect).
Nudge them until they sit on the drawn lines.

================================================================
## 16. HEALTH -> DEATH, and the DEATH BOARD AS SPRITEFRAMES
================================================================
HP HITS 0 = DEATH: add Health/health_watcher.gd as a CHILD NODE of Sami.
It reads his `stats` resource and calls Deaths.kill() at 0. It auto-detects
the health property name (current_health / health / hp / ...) and PRINTS
which one it found on first run — if it guesses wrong, type the right name
into `health_property`. Set `death_cause` to the DeathCause id you want.

BOARD ANIMATION IS NOW A SPRITEFRAMES: Death/board_frames.tres, animation
name "death", 20 frames at 6.67 fps with the last frame held. Open it in
Godot's SpriteFrames panel to reorder frames, change per-frame duration,
or add new ones — no code. `anim_speed_scale` on the Deaths autoload
multiplies the speed. (Your GIF is already converted into these frames.)

================================================================
## 17. HOLD BREATH, BLOOD, TOXIC AIR, BLOOD PUZZLE
================================================================
SETUP: autoload #8 —
  BloodWorld -> res://FD_Testing/GameSystems/Breath/blood_world.gd
Input Map: add an action `hold_breath` (e.g. Shift or Ctrl).

A) THE MECHANIC — add Breath/breath_component.gd as a child of Sami,
   NAMED EXACTLY "Breath" (toxic areas and the health watcher look it up
   by that name).
   - 4 stages x 4 seconds = 16 seconds total (stage_seconds, stage_count).
   - While holding, he CANNOT suffocate.
   - `stage_animations`: e.g. ["Hold_1","Hold_2","Hold_3","Hold_4"] — add
     those to his SpriteFrames when the art is ready. Until then each
	 stage tints him a colder blue (stage_tints), so it's already readable.
   - `recover_seconds`: breathing time needed before holding again.
   - Signals: breath_started / stage_changed(stage) / breath_released /
	 breath_failed / blood_spilled — hook UI, sound, camera shake to these.

B) BLEEDING — set `is_bleeding = true` on the Breath node when Sami is cut
   (from your damage code). Then each stage spills the BloodType in
   `stage_blood[stage]`. Four are included in Breath/Types/ (blood_stage1..4)
   going from bright red to almost black-purple, so the colour tells the
   player how long they've been holding on. `affects_ground` marks the
   types that react with the floor.

C) TOXIC AIR — add an Area2D with Breath/toxic_area.gd + a CollisionShape2D.
   Inside it, NOT holding your breath = `grace_seconds` then death.
   Holding your breath pauses the countdown. `active_flag` / `disabled_flag`
   let a room become dangerous (or get fixed) as the story moves.
   Signals: player_entered / player_exited / warning(time_left) for UI.

D) THE FLOOR PUZZLE — add a Node2D with Breath/blood_grid.gd where the
   top-left of the grid should sit. It's a @tool script: the grid DRAWS
   ITSELF IN THE EDITOR so you can line it up with your tiles.
   - `columns`, `rows`, `cell_size` — any shape you want.
   - `wanted`: one blood-type id per cell, left-to-right/top-to-bottom;
	 "" = that cell doesn't matter. Wanted cells are highlighted in-editor
     with their id written on them.
   - Bleed the right type on the right cell -> `solved_flag` is raised.
   - `lock_cells` stops a correct cell from being ruined; without it the
     player can cover a mistake by bleeding the right type on top.
   - `clear_grid()` wipes it (a mop, a lever, a cutscene).
   Cells are matched by BloodType `id`, so the puzzle is "which blood goes
   where" — i.e. how long Sami must hold his breath before bleeding on each
   spot. Grids register themselves; spills anywhere find them automatically.

================================================================
## 18. DAMAGE & BLEEDING (the "damage code")
================================================================
WHERE THE NODES GO ON SAMI (all DIRECT children, names matter):
    Sami_Doctor
    ├── Statemachine   (Idle / Walk / Drag / Rotate / Death)
    ├── Breath         <- breath_component.gd   ("Breath")
    ├── Wounds         <- wound_component.gd    ("Wounds")
    └── ...
The Breath component must NOT go inside the Statemachine — that node only
collects `state` children, and other systems look up "Breath" as a direct
child of the player.

A) WOUNDS — Health/wound_component.gd, child named "Wounds".
   Hurt him from anywhere:
       $Wounds.take_damage(1)                    # plain hit
       $Wounds.take_damage(1, "bleeding", true)  # a hit that CUTS
       $Wounds.cut("bleeding")                   # cut, no damage
   Patch him up:
       $Wounds.bandage()      /  $Wounds.heal(1)  /  $Wounds.full_heal()
   It finds your HealthData automatically (same auto-detect as the health
   watcher, and it PRINTS what it found). A wound sets Breath.is_bleeding
   for you — that's the link that makes the 4 breath stages spill blood.
   Options: bleed_damage (health lost per second while bleeding, 0 = none),
   bleed_seconds (auto-clot, 0 = until bandaged), drip_while_bleeding +
   drip_blood (a blood trail between the stage spills),
   invulnerable_seconds, handle_death.
   Signals: damaged / wound_opened / wound_closed / health_changed / died.

B) HAZARDS — Health/damage_area.gd on an Area2D + CollisionShape2D.
   damage, opens_wound (turns a hazard into a CUT), cause_id,
   once_per_entry vs repeating (repeat_seconds), one_shot,
   active_flag / disabled_flag so hazards appear and get cleaned up.

C) HEALTH -> DEATH: WoundComponent already kills him at 0 health
   (handle_death). Use HealthWatcher INSTEAD if damage comes from other
   devs' code that doesn't go through Wounds — don't use both with
   handle_death on, or you'd double-fire.

D) BREATH ANIMATIONS: see Health/SAMI_PATCH.md — his states call
   UpdateAnimation() every frame, so hold-breath animations need a 2-line
   hook in sami_doctor.gd. Without the patch everything still works; the
   stages just tint him instead.

================================================================
## 19. RADIO STATUE PUZZLE (speakers + statue + board)
================================================================
Uses the other dev's radio: it only READS RadioGlobal.radio, and changes
nothing in their code.

THE LOOP
  The speakers are dead on their own. Stand next to one and it follows the
  radio LIVE — tuning the radio retunes that speaker. Walk away and it
  keeps the last frequency. The statue hears the speakers and answers with
  a MOOD + a NUMBER:
      HAPPY = wrong frequency, the number is a DECOY
      SAD   = right frequency, the number is REAL
  Real numbers go on the BOARD. Once they're all collected, the player
  drags the tiles into the right order to finish.

A) SPEAKERS — Area2D + CollisionShape2D + StatuePuzzle/radio_speaker.gd.
   Set `speaker_index` 0..3. Optional children: HzLabel (shows the tuned
   frequency — turn `show_hz` off for a harder puzzle) and Ring (shown
   while the player is inside).

B) STATUE — Node2D + StatuePuzzle/radio_statue.gd.
   - `speakers`: drag the four speaker nodes in, in index order
   - `responses`: the StatueResponse .tres files it can answer to
   - `sprite` + anim_idle / anim_happy / anim_sad
   - `board`: the NumberBoard node
   - `combo_speakers`: which two form the second half (default 2 and 3)
   A speech bubble shows what it says; real answers show in blue.

C) RESPONSES — StatueResponse .tres in StatuePuzzle/Responses/:
   speaker_a + hz_a (and speaker_b + hz_b with `use_second` for combos),
   mood (HAPPY = decoy, SAD = real), and `spoken` — one number, or a
   sequence separated by spaces ("17 88") for combos.
   Seven examples are included: three decoys, two single answers, one
   combo decoy and one combo answer.

D) COMBOS — when BOTH combo speakers hold a frequency, a button appears
   next to the statue. Pressing it plays them together and the statue
   answers with a whole sequence.

E) BOARD — Area2D + StatuePuzzle/number_board.gd.
   - While the statue is sad, walk to the board and press interact to
	 WRITE that number down. The FIRST one writes itself (auto_write_first)
	 so the player learns what the board is for.
   - Press interact again (nothing pending) to OPEN the board and drag
	 tiles to reorder. Matching `solution` raises `solved_flag`.
   - `starting_numbers` puts jumbled numbers on it from the start.

FREQUENCIES: the radio is an int, 530..1700, moving in steps of 10 (L1/R1
= +/-10, L2/R2 = +/-100). So every target must be a MULTIPLE OF 10 in that
range, or the player can never reach it.

================================================================
## 20. ELECTRO PUZZLE (sequence -> timed run -> main generator)
================================================================
TEST IT: instance ElectroPuzzle/electro_puzzle_test.tscn into a level with
Sami. Three switches, a main gen, an ice patch and a water patch, all
placeholder rectangles.

THE FLOW
 1. SEQUENCE — flip the three gens in order (order_index 0,1,2). Wrong
	order = buzz, everything resets. Right order = they blow.
 2. SAMI'S LINE — `after_switches_dialog` plays once ("We need to go to the
    main Gen"). It pauses; the timer waits for it.
 3. THE RUN — countdown starts, lights flicker, chase music plays, Haji
    shouts `callout_lines` every `callout_every` seconds WITHOUT pausing.
 4. MAIN GEN — reach it and flip it. If its `required_hz` is set, the RADIO
	must be tuned there too (multiple of 10, 530..1700) — that's your
	"explode it with the radio" ending.
 5. FAIL — timer hits 0. `on_fail`: RESET_ONLY / KILL_PLAYER /
	RELOAD_CHECKPOINT.

PIECES
- electro_gen.gd (Area2D): order_index, is_main, floor_number, required_hz,
  optional Sprite (anim off/on/blown), Light, Prompt children.
- electro_puzzle.gd (Node): the brain. Drag the gens + main_gen + lights in.
  Signals: switch_accepted / sequence_wrong / run_started / run_tick /
  callout / run_failed / puzzle_solved. Flags: electro_switches_done,
  electro_puzzle_solved.
- power_lights.gd (CanvasLayer): darkness + flicker, countdown bar, and the
  non-blocking callout line. Connect run_started -> on_run_started and
  run_tick -> on_run_tick (already wired in the test scene).
- floor_effect.gd (Area2D): ICE (slides past corners), WATER (wades),
  PUSH (a current). Can also deal damage_per_second and open wounds.
  It never touches Sami's movement code — it runs after him and nudges him
  with move_and_collide, so the other dev's player script stays untouched.

FLOORS: your 2 / 2 / 1 layout is just `floor_number` on each gen plus where
you place them; the puzzle doesn't care which room they're in.

================================================================
## 21. DEATH SCREEN — new art + hand-drawn clock
================================================================
- The board animation now uses the NEW 26-frame GIF, extracted to
  Death/BoardAnim/ and wired into Death/board_frames.tres (SpriteFrames,
  animation "death"). Edit timing/order in Godot's SpriteFrames panel.
- The new art has FOUR checkbox rows: Bleeding / Infection / Suffocation /
  Unknown. The DeathCause `row` values are set to 0/1/2/3 to match, so
  Deaths.kill("suffocation") ticks the third box.
- THE CLOCK IS DRAWN WITH YOUR NUMBER IMAGES. Numbers-0-9.png was sliced
  into Death/Digits/digit_0..9.png and the time is built from those
  sprites — no font needed. Knobs on the Deaths autoload:
    use_digit_images (off = fall back to the font)
    digit_spacing, colon_width, digit_scale, time_value_pos
  Digits are baseline-aligned automatically since they're different
  heights, and drawn with Nearest filtering so they stay crisp.

================================================================
## 22. CONNECTING TO THE OTHER DEV'S RADIO
================================================================
SETUP: autoload —
  RadioLink -> res://FD_Testing/GameSystems/StatuePuzzle/radio_link.gd
(Their side needs RadioGlobal and WaveCanvas20 as autoloads, and the
Radio-Panel inside Sami's UI at UI/Tools/Radio-Panel.)

HOW THEIR RADIO ACTUALLY WORKS
  RadioGlobal.radio   int, 530..1700  <- the ONE source of truth
  radio_ui.gd derives WaveCanvas20.wavelength from it (amplitude is fixed)
  Tuning keys: Freq_U / Freq_D = +/-10,  Amp_U / Amp_D = +/-100
  Radio_button (Q) opens/closes the radio; radio_panel.gd SPAWNS the UI
  and frees it when closed.

>>> IMPORTANT: tuning only works while the radio UI is OPEN, because
	radio_ui.gd is the node reading those keys. It doesn't exist when the
    radio is shut. So the player: opens the radio, tunes, and the speaker
	they're standing in follows along live. <<<

RadioLink gives our systems a safe front door — it never writes to their
code and degrades quietly if the radio isn't in the project:
  RadioLink.available()              is the radio system present?
  RadioLink.frequency()              current Hz
  RadioLink.is_tuned_to(hz, tol)     for puzzle checks
  RadioLink.is_open()                is the radio UI on screen?
  RadioLink.is_reachable(hz)         can the player actually dial this?
  RadioLink.set_frequency(hz)        force it (cutscenes/tests; snaps to 10)
  RadioLink.wavelength() / amplitude()
  signals: frequency_changed(hz) / radio_opened / radio_closed

WHO USES IT
- RadioSpeaker (statue puzzle): follows RadioGlobal.radio live while the
  player stands in it. `needs_radio_open` (default ON) means it only
  listens while the radio UI is up — turn it off for a looser feel.
- ElectroGen (main generator): `required_hz` uses RadioLink.is_tuned_to().
- RadioStatue: on startup it WARNS about any response frequency that isn't
  reachable (not a multiple of 10, or outside 530..1700), so a puzzle can
  never be accidentally impossible.

NOTE: their radio_panel.gd adds itself to the group "radio_panel" — that's
how RadioLink.is_open() finds it without any node paths.

================================================================
## 23. YAZZED BOSS FIGHT
================================================================
TEST: instance BossFight/boss_fight_test.tscn into a level with Sami and
walk into the trigger. Everything uses Godot's icon as a placeholder.
(If your project has icon.png rather than icon.svg, repoint the texture.)

THE THREE STAGES
 1. The TV DROPS. Yazzed charges with a readable 1s wind-up and slams into
	it himself. One TV hit -> stage 2.
 2. The TV LIFTS AWAY. Chip his HP with traps and throwables until it hits
	`stage3_hp` (50 by default) -> the TV comes back down.
 3. He's FAST (0.5s wind-up) and BOUNCY. The first charge and the bounce
    right after hunt Sami; sometimes he charges a WALL on purpose to come
    back from a strange angle (`wall_feint_chance`). Later bounces are
    random and NEVER toward the TV. Dodge late so he overshoots into it.
	Second TV hit = dead -> `victory_comic` plays (Nada's panels).
 Sami dying: call BossFight.reset_fight() — Yazzed goes back to full.

PIECES (every number below is an export)
- yazzed_boss.gd: max_hp, telegraph/rest/speed per stage, stun_seconds,
  max_bounces, wall_feint_chance, bounce_speed_keep, contact damage +
  cooldown, anim names (idle/telegraph/charge/stunned/hurt/dead), and
  built-in squash-stretch + wind-up rattle so it reads with NO art.
- boss_tv.gd: drop_height, drop_seconds, land bounce, lift_seconds,
  max_hits, hit particles, anim names. Joins group "boss_tv" so stage-3
  bounces know to avoid it.
- boss_object.gd: kind = TRAP / THROWABLE / HAZARD. boss_damage,
  player_damage + cuts, debuff_seconds + debuff_name, throw_speed/range,
  boss_can_push + push_speed, one_use + respawn_seconds, spin and hop.
  Throwables: interact to pick up, interact again to throw.
- boss_juice.gd: shake(), hit_stop(), flash(), zoom_punch() — all tunable.
  The TV shakes the screen on landing and on every hit.
- boss_fight.gd: wires it together. intro_dialog, stage_pause, stage3_hp,
  victory_comic / victory_video, won_flag, health bar.

SIGNALS to hang more juice on: charge_started, charge_ended, wall_hit,
tv_hit, player_hit, stunned_started, damaged, died, stage_changed,
boss_damaged, fight_won, fight_reset.
