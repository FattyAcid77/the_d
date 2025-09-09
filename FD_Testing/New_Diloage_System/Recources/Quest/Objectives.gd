###A Resource type that helps us mangae the All Objective infos that we need to handle to show in the quest logs

extends Resource

class_name Objectives


##Uniqe ID for each objective the player needs to do
@export var id: String
##A short/long description that helps the player know what to do
@export var description: String
##The ID of the NPC or Item that needs to talk or hold to finish the Objective
@export var target_id: String
##Choose what kind of Objective this is, 
##a talk to NPC Objective or needs to find a Item to finsih the Quest
@export var target_type: String
##What Dialog gonna start while the Objective is going,
## or while we doing the Objective what Dialog will start
@export var objective_dialog: String = ""
##The amount of set item needs to get so the Objective will be finished
@export var required_quantity: int = 0
##The amount of set item that the player is holding at this moment
@export var collected_quantity: int = 0
##The current state of this Objective
@export var is_completed:bool = false
