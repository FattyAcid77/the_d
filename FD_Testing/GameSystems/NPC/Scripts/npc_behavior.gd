class_name NPCBehavior extends Node
## Base for NPC movement behaviors. Add one behavior node as a child of an
## NPC.

var npc: NPC


func setup(owner_npc: NPC) -> void:
	npc = owner_npc


## Override in each behavior.
func tick(_delta: float) -> void:
	pass
