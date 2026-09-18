class_name NPCResource extends Resource
## Everything that makes one NPC "who they are". Make one .tres per NPC
## (FileSystem dock -> right-click -> New Resource -> NPCResource) and drop it
## on the NPC scene's `npc_resource` slot.

@export var npc_name: String = ""

## The character's animations.
@export var sprite_frames: SpriteFrames

## Face shown in the dialog box.
@export var portrait: Texture2D

## This NPC's own conversation (a Dialog resource).
@export var dialog: Dialog

@export_group("Voice")
## This character's typewriter blip - a short sound per letter while they speak.
@export var voice_blip: AudioStream
## Every letter picks a random pitch between these two.
@export var voice_pitch_min: float = 0.9
@export var voice_pitch_max: float = 1.1

@export_group("Footsteps")
## Played on each footstep while walking.
@export var footstep_sound_id: String = ""
## Which frames of the walk animation are foot-contacts (0-based).
@export var footstep_frames: Array[int] = [0, 2]

@export_group("Animation")
## the animation this NPC plays on its own, with nobody around - smoking, polishing, twitching.
@export var resting_animation: String = ""

## off for an NPC that never walks - a statue, a body, someone in a bed.
@export var use_direction_animations: bool = true

## Turn to look at Sami when a conversation starts.
@export var face_player_on_dialog: bool = true


@export_group("Movement")
@export var move_speed: float = 60.0
