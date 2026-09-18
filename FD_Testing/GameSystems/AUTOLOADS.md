# The autoload list — copy this exactly

Project Settings → Globals (Autoload). **Order matters**: `Loc` must be first
so text is set before anything draws. Everything else follows the order below.

The "Node Name" column is what you type in the Name box. It is case-sensitive
and the code looks these up by name, so a typo means that system silently
does nothing.

| # | Node Name | Path |
|---|---|---|
| 1 | `Loc` | `res://FD_Testing/GameSystems/Localization/loc.gd` |
| 2 | `Flags` | `res://FD_Testing/GameSystems/DialogV2/flags.gd` |
| 3 | `DialogManager` | `res://FD_Testing/GameSystems/DialogV2/Scripts/dialog_manager.gd` |
| 4 | `Cutscene` | `res://FD_Testing/GameSystems/Cutscene/cutscene_player.gd` |
| 5 | `GameProgress` | `res://FD_Testing/GameSystems/Progress/game_progress.gd` |
| 6 | `LogBook` | `res://FD_Testing/GameSystems/LogBook/log_book.gd` |
| 7 | `Prescription` | `res://FD_Testing/GameSystems/Prescription/prescription.gd` |
| 8 | `Deaths` | `res://FD_Testing/GameSystems/Death/deaths.gd` |
| 9 | `BloodWorld` | `res://FD_Testing/GameSystems/Breath/blood_world.gd` |
| 10 | `MedicalItems` | `res://FD_Testing/GameSystems/Items/medical_items.gd` |
| 11 | `PopupWindows` | `res://FD_Testing/GameSystems/Windows/popup_windows.gd` |
| 12 | `RadioLink` | `res://FD_Testing/GameSystems/StatuePuzzle/radio_link.gd` |
| 13 | `Bag` | `res://FD_Testing/GameSystems/Items/bag.gd` |
| 14 | `MapRooms` | `res://FD_Testing/GameSystems/Map/map_rooms.gd` |
| 15 | `Board` | `res://FD_Testing/GameSystems/Board/board.gd` |

**13, 14 and 15 are the new ones.** If the board does nothing when you press
TAB, number 15 is missing.

---

## NOT autoloads — do not add these

These are `class_name` scripts you attach to nodes, or plain helpers. Adding
them as autoloads will cause errors:

`InputAccess`, `HealthAccess`, `WindowSpace`, `DialogActions`, `MapRoom`,
`MapRoomDef`, `WindowSkin`, `WindowBlocker`, `RadioReactor`, `RadioBand`,
`DialogZone`, `BoardInventory`, `BoardMap`, `BoardSettings`,
`LanguageSetting`, `LanguagePrompt`, and every `*_component.gd`.

---

## Checking it worked

Run the game and look at the Output panel. You should see:

    Loc: language = en (English)
    PopupWindows: loaded N window definitions.

Then press **TAB**. The clipboard should appear.

If nothing happens, one of these is true:
* `Board` isn't in the autoload list (most likely)
* another node is eating the TAB key before the board sees it
* something else is drawn on a CanvasLayer above 90
