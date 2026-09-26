# Fast Grabs

Drag a scene from here into a level and fill in its inspector. To resize an
area: right-click the node -> Editable Children, then drag the shape. Every
copy has its own shape. Full notes: GameSystems README, sections 21-23.

## Interactables
- FlagArea - when Sami walks in / out, presses interact, or tunes the radio: set flags, play a sound, run actions.
- Readable - a note he reads: your PNG with our translated text on it.
- ItemSocket - a slot that wants one item (fuse box, keyhole). Put the art in Sprite's empty / red / green.
- WallClues - dates on the wall, one per Slot marker. Give it the digit and month PNGs.
- RadioCheck - the PC that checks the radio against a WallClues.
- PcTerminal - opens the PC screen.

## Items
- ItemPickup - an item lying in the world. Set `item`.

## Dialog
- DialogZone - walk in, a dialog starts.
- DialogTrigger - put under an NPC or anything talkable: interact starts its dialog.
- NPC - a character. Set its NPCResource.

## Sound
- MusicZone - the music for a room (a MusicSet and its layers, or one track).
- AmbienceZone - the room tone, same fields.
- FloorSurface - names the floor (wet, metal) so footsteps inside use that variant.
- SoundHook - add under any node, even the other dev's: its signals or animations -> sounds.

## Hazards
- ToxicArea - air that kills unless he holds his breath.
- DamageArea - glass, a blade, a hot pipe: hurts him.

## World
- MapRoom - one per room scene: tells the map which room he's in. Set its MapRoomDef; the shape is the room's bounds.
- WindowBlocker - an area a popup window can't be dragged over.
- ProgressStateMachine - one per level; add a ProgressState child per story state.
