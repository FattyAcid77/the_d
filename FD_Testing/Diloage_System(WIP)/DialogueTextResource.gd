extends DE
class_name DialogueText

#The name and Anime of the speaker
@export var speaker_name: String
@export var speaker_img: Texture
@export var speaker_img_Hframes: int = 1
@export var speaker_img_rest_frame: int = 0

#The text that gonna be shown in the Box with the speed for it
@export_multiline var text: String
@export_range(0.1,30.0,0.1) var text_speed: float

# The volume and the Diffrint tones for it (علشان الجاوة)
@export var text_sound: AudioStream
@export var text_volume_db: int
@export var text_volume_pitch_min: float =0.85
@export var text_volume_pitch_max: float = 1.15


#i do not fully understand, but from what i trid this is the Camera position for when we want to make Cutscene happens
#while the text is playing.....from my understading
@export var camera_position: Vector2 = Vector2(999.999, 999.999)
@export_range(0.05,10.0,0.05) var camera_transition_time: float = 1.0
