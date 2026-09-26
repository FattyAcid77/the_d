class_name PcCharacter extends Resource
## One file on the PC's character list. The icon is the full 640x360 layer
## straight from the art file; the PC crops it down to its slot by itself.

## The icon layer, like COMPUTER_UI_maryam_icon.png.
@export var icon: Texture2D
## Text in the page under the list. English here, Arabic in translations.csv. BBCode works.
@export_multiline var text: String = ""
## Art that replaces the plain page, like the classified file. Export it without the little pointer.
@export var page_art: Texture2D
