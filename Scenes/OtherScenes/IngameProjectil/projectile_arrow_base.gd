class_name ArrowProjectile
extends ProjectileBase

## Handles specific offsets and sounds for arrow projectiles.


func setup(action_id: String, direction: String, start_pos: Vector2, custom_stats: Dictionary = {}) -> void:
	super.setup(action_id, direction, start_pos, custom_stats)
	
	var x = 0
	var y = 0
	
	if direction_string == "down":
		y -= 8
	elif direction_string == "left" or direction_string == "right":
		y -= 26
	elif direction_string == "up":
		y -= 2
		
	position += Vector2(x, y)


func _play_initial_sound() -> void:
	_play_audio_from_path("res://addons/rpg_character_creator/sounds/swosh-01.ogg")
