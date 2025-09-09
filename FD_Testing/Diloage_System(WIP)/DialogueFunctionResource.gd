extends DE
class_name DialogueFunction

#This is for the path to the node that have the Func that we need to call
@export var target_path: NodePath
#the name of the Func so the
@export var function_name: String
#if the func needs any array inputs that it needs
@export var function_arguments: Array

#This is when we want to hide the box while the Func is playing
@export var hide_dialogue_box: bool
@export var wait_for_signal_to_continue: String = ""
