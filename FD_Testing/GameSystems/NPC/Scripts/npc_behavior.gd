class_name NPCBehavior extends Node
## Base for NPC movement behaviors. Add ONE behavior node as a child of an
## NPC. Each frame the NPC calls tick(); the behavior's only job is to set
## npc.direction (a normalized Vector2, or ZERO to stand still).

var npc: NPC


func setup(owner_npc: NPC) -> void:
	npc = owner_npc


## Override in each behavior.
func tick(_delta: float) -> void:
	pass
