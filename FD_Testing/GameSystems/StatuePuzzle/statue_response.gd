class_name StatueResponse extends Resource
## One thing the statue answers to.
##
## THE RULE (deliberately backwards, so the player has to work it out):
##   HAPPY = wrong frequencies. The number it says is a DECOY.
##   SAD   = right frequencies. That number is REAL and goes on the board.
##
## A response can need ANY number of speakers at once — that's what makes
## the four stages work:
##   STAGE 1: speakers [0]           one speaker (top left)
##   STAGE 2: speakers [0, 2]        the two on the left
##   STAGE 3: speakers [1, 3]        the two on the right
##   STAGE 4: speakers [0, 1, 2, 3]  all four together
##
## Make one .tres per answer in StatuePuzzle/Responses/.

enum Mood { HAPPY, SAD }

@export_group("What triggers it")
## Which speakers must be tuned, e.g. [0] or [0,2] or [0,1,2,3].
@export var speakers: Array[int] = [0]

## The frequency each of those speakers must hold, IN THE SAME ORDER.
## Must be multiples of 10 between 530 and 1700.
@export var frequencies: Array[int] = [800]

## Which stage this belongs to (1..4). The statue only listens to responses
## for the stage the player has reached.
@export var stage: int = 1

@export_group("What the statue does")
@export var mood: Mood = Mood.HAPPY

## What it says. A single number ("29"), or a sequence for the later
## stages ("20 40 60") — spaces separate the numbers.
@export var spoken: String = "29"

## Optional flag set the first time this exact answer is heard.
@export var heard_flag: String = ""


## True if this is a real answer (sad) rather than a decoy.
func is_answer() -> bool:
	return mood == Mood.SAD


## The spoken text split into individual numbers.
func numbers() -> PackedStringArray:
	return spoken.strip_edges().split(" ", false)


## How many speakers this response uses.
func speaker_count() -> int:
	return speakers.size()


## Does the current tuning match this response exactly?
## `tuning` is speaker_index -> hz.
func matches(tuning: Dictionary) -> bool:
	if speakers.is_empty() or speakers.size() != frequencies.size():
		return false
	for i in speakers.size():
		var idx: int = speakers[i]
		if not tuning.has(idx):
			return false
		if int(tuning[idx]) != frequencies[i]:
			return false
	return true
