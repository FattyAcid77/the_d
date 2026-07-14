class_name DialogKeyword extends Resource
## One clickable word inside a line.
## It only "lights up" (becomes clickable + shows as a topic button) when
## its unlock_flag is set. Clicking it opens the branch named in `topic_branch`.

## The exact word in the line text to turn into a link (e.g. "apple").
@export var word: String = ""

## Flag required before this word lights up. Leave EMPTY to always show it.
@export var unlock_flag: String = ""

## Which branch id to jump to when the word (or its topic button) is clicked.
@export var topic_branch: String = ""

## Label for the topic button. If empty, the word itself is used.
@export var topic_label: String = ""

## If true, the topic disappears once the player has fully asked about it.
## If false (default), they can keep asking.
@export var ask_once: bool = false
