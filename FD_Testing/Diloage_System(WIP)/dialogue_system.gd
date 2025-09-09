extends Node2D
#We Can Change The DialogueButton Scene Styles to sute our Game Needs, Under ThemeOverrides

#change This For the Dircotry of the Button.tcn
const DialogueButtonPreload = preload("res://FD_Testing/Diloage_System/DialogueButton.tscn")

#This to hold RichText And Sprite And keep code Clean
@onready var DialogueLabel: RichTextLabel = $HBoxContainer/VBoxContainer/RichTextLabel
@onready var SpeakerSprite: Sprite2D = $HBoxContainer/SpeakerParent/Sprite2D

# this is to make it ez of using it in the Main Scene, it will play in a loop unitl there are no next item
var dialogue: Array[DE]
var current_dialogue_item: int = 0
var next_item: bool = true

#change as need
var player_node: CharacterBody2D = null

func _ready() -> void:
	visible = false
	$HBoxContainer/VBoxContainer/ButtonContainer.visible = false
	
	#To get the player Ref, if it got lost at one point
	player_node = get_tree().get_first_node_in_group("player") as CharacterBody2D




func _process(_delta: float) -> void:
	#To check if the player Reached the End of the array, then we set the Player move to true
	if current_dialogue_item == dialogue.size():
		if !player_node:
			player_node = get_tree().get_first_node_in_group("player") as CharacterBody2D
			return
		player_node.can_move = true
		queue_free()
		return
	
	
	if next_item:
		#if there is a next item, its gonna change from that item
		next_item = false
		var i = dialogue[current_dialogue_item]
		
		#Check i for what kind of Dialogue its kind is,
		if i is DialogueFunction:
			if i.hide_dialogue_box:
				visible = false
			else:
				visible = true
			#calles the Custom Func in this scripts, passing its kind of Resource
			_function_resource(i)
		
		#Check its A choice
		elif i is DialogueChoice:
			visible = true
			_choice_resource(i)
		
		#check its Text
		elif i is DialogueText:
			visible = true
			_text_resource(i)
		
		#if there were in error or a choice wroing in the side of it
		else:
			print("There were no Viald Resource Added, Check the Rexource Please")
			current_dialogue_item += 1
			next_item = true




func _function_resource(i: DialogueFunction) -> void:
	#Get The Func Node that we want to call
	var target_node = get_node(i.target_path)
	if target_node.has_method(i.function_name):
		if i.function_arguments.size() == 0:
			target_node.call(i.function_name)
		else:
			target_node.callv(i.function_name, i.function_arguments)
	
	if i.wait_for_signal_to_continue:
		var signal_name = i.wait_for_signal_to_continue
		if target_node.has_signal(signal_name):
			var signal_state = { "done": false }
			var callable = func(_args): signal_state.done = true
			target_node.connect(signal_name, callable, CONNECT_ONE_SHOT)
			while not signal_state.done:
				await get_tree().process_frame
	
	current_dialogue_item += 1
	next_item = true


func  _choice_resource(i: DialogueChoice) -> void:
	DialogueLabel.name = i.speaker_name
	DialogueLabel.text = i.text
	DialogueLabel.visible_characters = -1
	if i.speaker_img:
		$HBoxContainer/SpeakerParent.visible = true
		SpeakerSprite.texture = i.speaker_img
		SpeakerSprite.hframes = i.speaker_img_Hframes
		SpeakerSprite.frame = min(i.speaker_img_select_frame, i.speaker_img_Hframes - 1)
	else:
		$HBoxContainer/SpeakerParent.visible = false
	$HBoxContainer/VBoxContainer/Button_Container.visible = true
	
	for item in i.choice_text.size():
		var DialogueButtonVar = DialogueButtonPreload.instantiate()
		DialogueButtonVar.text = i.choice_text[item]
		
		var function_resource: DialogueFunction = i.choice_function_call[item]
		if function_resource:
			DialogueButtonVar.connect("pressed",
			Callable(get_node(function_resource.target_path),function_resource.function_name).bindv(function_resource.function_arguments),
			CONNECT_ONE_SHOT)
			if function_resource.hide_dialogue_box:
				DialogueButtonVar.connect("pressed", hide, CONNECT_ONE_SHOT)
			
			DialogueButtonVar.connect("pressed",
			_choice_button_pressed.bind(get_node(function_resource.target_path), function_resource.wait_for_signal_to_continue),
			CONNECT_ONE_SHOT)
		else:
			DialogueButtonVar.connect("pressed", _choice_button_pressed.bind(null, ""), CONNECT_ONE_SHOT)
		
		$HBoxContainer/VBoxContainer/Button_Container.add_child(DialogueButtonVar)
	$HBoxContainer/VBoxContainer/Button_Container.get_child(0).grab_focus()



func _text_resource(i: DialogueText) -> void:
	DialogueLabel.name = i.speaker_name
	$AudioStreamPlayer.stream = i.text_sound
	$AudioStreamPlayer.volume_db = i.text_volume_db
	var camera: Camera2D = get_viewport().get_camera_2d()
	if camera and i.camera_position != Vector2(999.999, 999.999):
		var camera_tween: Tween = create_tween().set_trans(Tween.TRANS_SINE)
		camera_tween.tween_property(camera, "global_position", i.camera_position, i.camera_transition_time)
		
	if !i.speaker_img:
		$HBoxContainer/SpeakerParent.visible = false
	else:
		$HBoxContainer/SpeakerParent.visible = true
		SpeakerSprite.texture = i.speaker_img
		SpeakerSprite.hframes = i.speaker_img_Hframes
		SpeakerSprite.frame = 0
	
	DialogueLabel.visible_characters = 0
	DialogueLabel.text = i.text
	var text_without_square_brackets: String = _text_without_square_brackets(i.text)
	var total_characters: int = text_without_square_brackets.length()
	var character_timer: float = 0.0
	while DialogueLabel.visible_characters < total_characters:
		if Input.is_action_just_pressed("ui_cancel"):
			DialogueLabel.visible_characters = total_characters
			break
		
		character_timer += get_process_delta_time()
		if character_timer >= (1.0 / i.text_speed) or text_without_square_brackets[DialogueLabel.visible_characters] == "":
			var character: String = text_without_square_brackets[DialogueLabel.visible_characters]
			DialogueLabel.visible_characters += 1
			if character != " ":
				$AudioStreamPlayer.pitch_scale = randf_range(i.text_volume_pitch_min, i.text_volume_pitch_max)
				$AudioStreamPlayer.play()
				if i.speaker_img_Hframes != 1:
					if SpeakerSprite.frame < i.speaker_img_Hframes - 1:
						SpeakerSprite.frame += 1
					else:
						SpeakerSprite.frame = 0
			character_timer = 0.0
		
		await  get_tree().process_frame
	SpeakerSprite.frame = min(i.speaker_img_rest_frame, i.speaker_img_Hframes-1)
	
	while true:
		await get_tree().process_frame
		if DialogueLabel.visible_characters == total_characters:
			if Input.is_action_just_pressed("ui_accept"):
				current_dialogue_item += 1
				next_item = true





 
#Custom Func
func _choice_button_pressed(target_node: Node, wait_for_signal_to_continue:String):
	$HBoxContainer/VBoxContainer/Button_Container.visible = false
	for i in $HBoxContainer/VBoxContainer/Button_Container.get_children():
		i.queue_free()
	
	if wait_for_signal_to_continue:
		var signal_name = wait_for_signal_to_continue
		if target_node.has_signal(signal_name):
			var signal_state = { "done": false}
			var callable = func (_args): signal_state.done = true
			target_node.connect(signal_name, callable, CONNECT_ONE_SHOT)
			while not signal_state.done:
				await get_tree().process_frame
	
	current_dialogue_item += 1
	next_item = true



func _text_without_square_brackets(text: String) -> String:
	var result: String = ""
	var inside_bracket: bool = false
	
	for i in text: 
		if i == "[":
			inside_bracket = true
			continue
		
		if i == "]":
			inside_bracket = false
			continue
		
		if !inside_bracket:
			result += i
			
	return result
