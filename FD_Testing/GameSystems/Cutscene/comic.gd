class_name Comic extends Resource
## A comic cutscene: panels shown one after another, the player pressing
## interact to move to the next (unless a panel auto-advances).
##
## Play it:            Cutscene.play_comic(my_comic)
## Or await it:        await Cutscene.play_comic(my_comic)
## From a dialog line: action_name = "comic",
##                     action_args = ["res://path/to/my_comic.tres"],
##                     wait_for_action = ON

@export var panels: Array[ComicPanel] = []
