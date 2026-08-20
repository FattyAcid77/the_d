@tool
class_name RadioMaker_v1Puzzle
extends Resource
## Every radio signal in the game, in one file.
##
## You never edit this by hand and you never open it in the Inspector. The
## "Radio" dock at the bottom of the editor IS the editor for this file.
##
## Each signal is a plain Dictionary, on purpose: a Resource per signal would
## show up as rows of Inspector clutter, which is the thing we are getting rid
## of. The keys, all of them:
##
##   id            String   the name you typed in the Maker. A node in the
##                          level picks its signal by this name.
##   type          int      0 = MAIN, wakes the radio on its own when the
##                          player walks in range
##                          1 = SIDE, stays silent until the dial finds it
##   frequency     int      530..1700, always a multiple of 10
##   radius        float    how far the signal carries, in pixels
##   order         int      MAIN only: the lowest unfinished one broadcasts
##   puzzle_id     String   a GameState id. The signal goes quiet once solved.
##   reward        int      what happens when caught, see RadioMaker_v1Signal.Reward
##   reward_value  String   the node path, flag name or puzzle id it needs

const MIN_HZ: int = 530
const MAX_HZ: int = 1700
const STEP_HZ: int = 10

## How close the dial has to sit before the player catches a SIDE signal.
## Mirrors `RadioSignals.BAND_FULL`, kept as a plain number here so the Maker
## still runs if the autoload is missing.
const BAND: int = 30

@export var entries: Array[Dictionary] = []


## A blank signal with every key present, so nothing reads as null later on.
static func blank(id: String = "new_signal") -> Dictionary:
	return {
		"id": id,
		"type": 1,
		"frequency": 630,
		"radius": 400.0,
		"order": 0,
		"puzzle_id": "",
		"reward": 0,
		"reward_value": "",
	}


## The signal with this name, or an empty Dictionary if there is none.
func find(id: String) -> Dictionary:
	for e in entries:
		if str(e.get("id", "")) == id:
			return e
	return {}


func ids() -> PackedStringArray:
	var out: PackedStringArray = []
	for e in entries:
		out.append(str(e.get("id", "")))
	return out


## Everything wrong with the puzzle right now, written the way you would say
## it out loud. The Maker shows these live under the dial.
func problems() -> PackedStringArray:
	var out: PackedStringArray = []
	var seen: Dictionary = {}
	for e in entries:
		var id: String = str(e.get("id", ""))
		if id == "":
			out.append("A signal has no name.")
		elif seen.has(id):
			out.append("Two signals are both called \"%s\"." % id)
		else:
			seen[id] = true
		var hz: int = int(e.get("frequency", 0))
		if hz < MIN_HZ or hz > MAX_HZ or hz % STEP_HZ != 0:
			out.append("\"%s\" sits at %d Hz, which the dial can never reach." % [id, hz])
		if float(e.get("radius", 0.0)) <= 0.0:
			out.append("\"%s\" has no reach, so the player can never get near it." % id)
		if int(e.get("type", 1)) == 1 and str(e.get("reward_value", "")) == "":
			out.append("\"%s\" does nothing when the player finds it." % id)
		# MAIN signals have no catch event at all in radio_signal_manager.gd — they
		# only wake the radio up — so a reward hung on one would never fire.
		if int(e.get("type", 1)) == 0 and str(e.get("reward_value", "")) != "":
			out.append("\"%s\" is MAIN, so its reward never runs. MAIN signals only wake the radio; make it SIDE if it should do something." % id)
	out.append_array(_too_close())
	return out


## Two SIDE signals inside one catch band are impossible to tell apart: tuning
## to either one lands on both. This is the mistake the dial exists to show.
func _too_close() -> PackedStringArray:
	var out: PackedStringArray = []
	for i in entries.size():
		for j in range(i + 1, entries.size()):
			var a: Dictionary = entries[i]
			var b: Dictionary = entries[j]
			if int(a.get("type", 1)) != 1 or int(b.get("type", 1)) != 1:
				continue
			var gap: int = absi(int(a.get("frequency", 0)) - int(b.get("frequency", 0)))
			if gap < BAND:
				out.append("\"%s\" and \"%s\" are only %d Hz apart, too close to tell apart. Keep them %d or more."
					% [a.get("id", ""), b.get("id", ""), gap, BAND])
	return out
