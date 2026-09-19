class_name Dialog extends Resource
## Everything one NPC can say. Make one .tres per NPC (Right-click in the
## FileSystem dock -> New Resource -> Dialog) and drop it on that NPC's
## DialogTrigger (or on its NPCResource.dialog field).

@export var branches: Array[DialogBranch] = []


## Find a branch by id.
func get_branch(branch_id: String) -> DialogBranch:
	for b in branches:
		if b and b.id == branch_id:
			return b
	return null
