class_name DialogKeyword extends Resource
## One clickable word inside a line. It only "lights up" (becomes clickable +
## shows as a topic button) when its unlock_flag is set.

@export var word: String = ""

## Flag required before this word lights up.
@export var unlock_flag: String = ""

## Which branch id to jump to when the word (or its topic button) is clicked.
@export var topic_branch: String = ""

## Label for the topic button.
@export var topic_label: String = ""

## If true, the topic disappears once the player has fully asked about it.
@export var ask_once: bool = false
