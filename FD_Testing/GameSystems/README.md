# GameSystems — NPCs + Dialog, rebuilt for the new Sami player
One folder, everything you need. Put it at:  res://GameSystems/

Works with your new player as-is (sami_doctor.gd): it detects the "Player"
group / Player class, and the dialog pauses the game so your state machine,
push/pull, and inventory are never touched.

================================================================
## 1. ONE-TIME SETUP (do these first, ~2 minutes)
================================================================
A) Autoloads — Project > Project Settings > Globals (Autoload):
	 Flags          ->  res://GameSystems/DialogV2/flags.gd
	 DialogManager  ->  res://GameSystems/DialogV2/Scripts/dialog_manager.gd
   (Names must match exactly.)

B) Input Map — add an action named `interact`, bind a key (E is typical;
   NOT F — your push/pull already uses F).

C) Optional typewriter sound — the old mp3 was deleted with FD_Testing.
   Drop any SHORT blip sound at:
	 res://GameSystems/DialogV2/dialogue_noise.mp3
   and it's picked up automatically. (Or drag any sound into the DialogUI
   root's `Type Sound` slot.) No sound file = silent typewriter, no errors.

================================================================
## 2. ADD YOUR FIRST NPC (5 minutes)
================================================================
1. Instance  res://GameSystems/NPC/npc.tscn  into your level.
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
  Cutscene  ->  res://GameSystems/Cutscene/cutscene_player.gd

THE THREE WAYS TO TRIGGER IT (your three cases):

1) "When something happens" — from ANY script:
     Cutscene.play("res://GameSystems/Cutscene/test_anime.ogv")
   or, to continue only after it ends:
     await Cutscene.play("res://GameSystems/Cutscene/test_anime.ogv")

2) "When the player does this / goes there" — walk-in trigger:
   Add an Area2D, attach Cutscene/cutscene_trigger.gd, give it a
   CollisionShape2D, set `video_path`. `play_once` remembers via a flag;
   `set_flag_after` can unlock dialog reactions ("you saw that, right?").

3) "When this word appears" — from DIALOG:
   On a DialogLine (usually inside a keyword's topic branch), Action group:
	 action_name     = "cutscene"
	 action_args     = ["res://GameSystems/Cutscene/test_anime.ogv"]
	 wait_for_action = ON
   The conversation pauses, the video plays, the dialog continues itself.
   So: keyword "apple" -> topic branch "apple" -> first line empty text with
   the action = clicking the word plays the cutscene.

Behavior: fullscreen over everything, black bars keep the video's shape,
game pauses during playback (works mid-dialog too), and the player can skip
with `interact` (turn off via the `skippable` export on the autoload).
