class_name StatueResponse extends Resource
## One thing the statue answers to. the rule (deliberately backwards, so the
## player has to work it out): happy = wrong frequencies.

enum Mood { HAPPY, SAD }

@export_group("What triggers it")
## Which speakers must be tuned, e.g.
@export var speakers: Array[int] = [0]

## The frequency each of those speakers must hold, in the same order.
@export var frequencies: Array[int] = [800]

## Which stage this belongs to (1..4).
@export var stage: int = 1

@export_group("What the statue does")
@export var mood: Mood = Mood.HAPPY

## What it says.
@export var spoken: String = "29"

## Optional flag set the first time this exact answer is heard.
@export var heard_flag: String = ""

## Played when the statue gives this response.
@export var sound_id: String = ""


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
