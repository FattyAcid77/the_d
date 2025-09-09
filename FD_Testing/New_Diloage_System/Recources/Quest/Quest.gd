extends Resource

class_name Quest

##The Uniqe ID for each Quest
@export var quest_id: String
##The Quest name that gonna show in the Quest Logs
@export var quest_name: String
##That Current of the Quest, Is it Begin or still not started
@export var state: String = "not_started"
##The objectives that the played have at this moment at time
@export var objectives: Array[Objectives] = []
##The type of rewards the player can get from each objective
@export var rewards: Array[Rewards] = []


##Check if all objectives are complated or not
func is_completed() -> bool:
	for objective in objectives:
		if not objective.is_completed:
			return false
	return true

func objective_state(objective_id: String, quantity: int = 1) -> void:
	for objective in objectives:
		if objective.id == objective_id:
			if objective.target_type == "collection":
				objective.collected_quantity += quantity
				if objective.collected_quantity >= objective.required_quantity:
					objective.is_completed = true
			elif objective.target_type == "talk_to":
				objective.is_completed = true
			break
	
	if is_completed():
		state = "completed"
