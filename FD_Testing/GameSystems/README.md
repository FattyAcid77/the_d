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
