class_name BoltProjectile
extends ProjectileBase

## Handles specific offsets and sounds for crossbow bolt projectiles.


func setup(action_id: String, direction: String, start_pos: Vector2, custom_stats: Dictionary = {}) -> void:
	super.setup(action_id, direction, start_pos, custom_stats)
	
	var x = 0
	var y = 0
	
	if direction_string == "left" or direction_string == "right":
		y -= 32
	elif direction_string == "up":
		y += 26
		
	position += Vector2(x, y)


func _play_initial_sound() -> void:
	_play_audio_from_path("res://addons/rpg_character_creator/sounds/swosh-03.ogg")
