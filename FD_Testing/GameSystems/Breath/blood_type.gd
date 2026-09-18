class_name BloodType extends Resource
## One kind of blood. The breath mechanic has four stages and each stage
## bleeds a different type, so the colour tells the player how long they've
## been holding on - and the type is what the floor puzzle checks.

@export var id: String = ""

## What it looks like on the floor.
@export var color: Color = Color(0.6, 0.05, 0.05)

## Played where this blood spills (positional if the def says so).
@export var sound_id: String = ""

## your drawing for this blood.
@export var texture: Texture2D

## Spin each splat a random amount so repeats don't look copy-pasted.
@export var random_rotation: bool = true

## Size of the stain on the ground.
@export var stain_scale: float = 1.0

## Does this blood change the ground it lands on?
@export var affects_ground: bool = false

## Flag set the first time this type is spilled
@export var first_spill_flag: String = ""
