extends DE
class_name DialogueChoice

#the speaker Info, name, and anime that we want to display while He Choose
@export var Speaker_name: String
@export var Speaker_img: Texture
@export var Speaker_img_Hframes: int = 1
@export var Speaker_img_select_frame: int = 0

#the text that gonna show above the Choice
@export_multiline var text: String

#the choices in a arrya, and if we want to call a Func from another Node
@export var choice_text: Array[String]
@export var choice_function_call: Array[DialogueFunction]
