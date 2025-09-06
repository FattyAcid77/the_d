extends Control
#When we want to Make a Translite from English And Arabic Left to Right, we can use Lebel.Horizontal Alignment, etc

@onready var panel: Panel = $CanvasLayer/Panel
@onready var dialog_box: VBoxContainer = $CanvasLayer/Panel/DialogBox
@onready var dialog_speaker: Label = $CanvasLayer/Panel/DialogBox/Dialog_Speaker
@onready var dialog_text: Label = $CanvasLayer/Panel/DialogBox/Dialog_Text
@onready var dialog_options: HBoxContainer = $CanvasLayer/Panel/DialogBox/DialogOptions


func _ready() -> void:
	hide_dialog()

##Show the Dialog Box 
func show_dialog(speaker, text, options):
	panel.visible = true
	
	dialog_speaker.text = speaker
	dialog_text.text = text
	
	for option in dialog_options.get_children():
		dialog_options.remove_child(option)
	
	for option in options.keys():
		var button = Button.new()
		button.text = option
		button.add_theme_font_size_override("font_size", 20)
		button.pressed.connect(_on_option_selected.bind(option))
		dialog_options.add_child(button)
	
##Handels The Response Selection
func _on_option_selected(option):
	get_parent().handle_dialog_choice(option)
	

##Hides the Dialog Box
func hide_dialog():
	panel.visible = false
	Dialog_Global.player.can_move = true


##Close Dialog
func _on_close_button_pressed() -> void:
	hide_dialog()
