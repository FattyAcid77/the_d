class_name Dialog extends Resource
## Everything one NPC can say. Make one .tres per NPC (Right-click in the
## FileSystem dock -> New Resource -> Dialog) and drop it on that NPC's
## DialogTrigger (or on its NPCResource.dialog field).

## All conversation branches. One of them MUST have id = "entry".
@export var branches: Array[DialogBranch] = []


## Find a branch by id. Returns null if not found.
func get_branch(branch_id: String) -> DialogBranch:
	for b in branches:
		if b and b.id == branch_id:
			return b
	return null
