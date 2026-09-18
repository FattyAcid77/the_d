class_name Comic extends Resource
## A comic cutscene: panels shown one after another, the player pressing
## interact to move to the next (unless a panel auto-advances).

@export var panels: Array[ComicPanel] = []
