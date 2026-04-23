extends HBoxContainer

# Drag your PlayerHealth.tres into this slot as well!
@export var stats: HealthData 
@export var full_sprite: Texture2D
@export var empty_sprite: Texture2D

func _ready() -> void:
	if stats:
		# Listen for changes in the resource
		stats.health_changed.connect(update_ui)
		stats.max_health_changed.connect(generate_hearts)
		
		# Generate the initial UI
		generate_hearts(stats.max_health)

# Automatically spawns TextureRects based on Max Health
func generate_hearts(max_hp: int) -> void:
	# First, delete any existing hearts (useful if max HP changes mid-game)
	for child in get_children():
		child.queue_free()
		
	# Spawn a new TextureRect for every point of Max HP
	for i in range(max_hp):
		var heart = TextureRect.new()
		heart.texture = full_sprite
		heart.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED # Keeps the image looking nice
		add_child(heart)
		
	# Make sure the UI reflects current health after generating
	update_ui(stats.current_health)

func update_ui(current_health: int) -> void:
	var hearts = get_children()
	
	for i in range(hearts.size()):
		if i < current_health:
			hearts[i].texture = full_sprite
		else:
			hearts[i].texture = empty_sprite
