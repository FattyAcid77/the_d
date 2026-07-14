class_name NPCResource extends Resource
## Everything that makes one NPC "who they are". Make one .tres per NPC
## (FileSystem dock -> right-click -> New Resource -> NPCResource) and drop it
## on the NPC scene's `npc_resource` slot.
##
## The same NPC scene + a different NPCResource = a different character.

@export var npc_name: String = ""

## The character's animations. Expected names (any you have):
##   Idle_down / Idle_up / Idle_Side  and  Walk_down / Walk_up / Walk_Side
## (Side is flipped for left, same convention as the player.)
@export var sprite_frames: SpriteFrames

## Face shown in the dialog box. Optional.
@export var portrait: Texture2D

## This NPC's own conversation (a Dialog resource).
@export var dialog: Dialog

@export_group("Movement")
@export var move_speed: float = 60.0
