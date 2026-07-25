class_name LogFact extends Resource
## One piece of knowledge. It appears in the log the moment its flag is set —
## and your dialog lines / cutscene triggers / puzzle already set flags,
## so learning happens with zero extra wiring.

## The flag that reveals this fact (e.g. "apple_eaten", "statue_solved").
@export var flag: String = ""

## What the player reads in the log once they know it.
@export_multiline var text: String = ""
