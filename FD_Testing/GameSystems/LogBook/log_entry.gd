class_name LogEntry extends Resource
## One card on the knowledge board (like an Outer Wilds ship-log entry).
## Save these as .tres files inside  GameSystems/LogBook/Entries/  — the
## LogBook loads everything in that folder automatically, so adding
## knowledge to the game = adding one file. No code.
##
## An entry APPEARS on the board once ANY of its facts' flags is set.
## Facts inside it reveal one by one as their flags are set.

## Unique id, used by other entries' `links_to` (e.g. "java", "statue").
@export var id: String = ""

## If ON, this card is on the board from the very start — no flag needed.
## Good for the starting "anchor" card of the map.
@export var always_visible: bool = false

## Title shown on the card.
@export var title: String = ""

## Optional picture on the card (portrait, screenshot, drawing).
@export var picture: Texture2D

@export_group("Note art")
## The pinned-note image for this entry (Notes/Note_1.png etc). Cards are
## sized from this texture, so different notes are naturally different sizes.
@export var note_icon: Texture2D

## Multiplies the note's natural size on the board.
@export var icon_scale: float = 1.0

## Small rotation for a hand-pinned look (degrees, e.g. -6 .. 6).
@export var icon_tilt: float = 0.0

## Card color — use it to group themes (people, places, mysteries...).
@export var color: Color = Color(0.85, 0.65, 0.25)

## Where the card sits on the board (any coordinates; the board pans/zooms).
@export var board_position: Vector2 = Vector2.ZERO

## The knowledge inside this entry.
@export var facts: Array[LogFact] = []

## Ids of entries this one connects to. A line is drawn when BOTH sides
## are discovered.
@export var links_to: Array[String] = []


func is_discovered() -> bool:
	if always_visible:
		return true
	for f in facts:
		if f and f.flag != "" and Flags.is_set(f.flag):
			return true
	return false


func known_facts() -> Array[LogFact]:
	var out: Array[LogFact] = []
	for f in facts:
		if f == null:
			continue
		# empty flag = always known (use for intro text on always_visible cards)
		if f.flag == "" or Flags.is_set(f.flag):
			out.append(f)
	return out
