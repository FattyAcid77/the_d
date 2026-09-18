class_name SoundMap extends Resource
## Moment -> sound table the production team edits (Sound/sound_map.tres).
## Value can be a list: "paper, loop board_music" / "stop board_music".

@export var events: Dictionary[String, String] = {}


func sound_for(event_name: String) -> String:
	return str(events.get(event_name, ""))
