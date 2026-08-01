class_name BloodType extends Resource
## One kind of blood. The breath mechanic has four stages and each stage
## bleeds a different type, so the colour tells the player how long they've
## been holding on — and the type is what the floor puzzle checks.

## Used by the puzzle grid ("A", "B", "O", "toxic"...). Must be unique.
@export var id: String = ""

## What it looks like on the floor.
@export var color: Color = Color(0.6, 0.05, 0.05)

## YOUR DRAWING for this blood. Drop the .png here and it's used instead of
## the placeholder blob. Tip: set the image's Import > Filter to OFF so it
## stays crisp pixel art.
@export var texture: Texture2D

## Spin each splat a random amount so repeats don't look copy-pasted.
## Turn OFF if your art has a "correct" way up.
@export var random_rotation: bool = true

## Size of the stain on the ground.
@export var stain_scale: float = 1.0

## Does this blood change the ground it lands on? (For the puzzle: only
## the right types react.)
@export var affects_ground: bool = false

## Flag set the first time this type is spilled — handy for dialog
## ("your blood looked wrong back there...").
@export var first_spill_flag: String = ""
