class_name ArrowProjectile
extends ProjectileBase

## Handles specific offsets and sounds for arrow projectiles.


func setup(action_id: String, direction: String, start_pos: Vector2, custom_stats: Dictionary = {}) -> void:
	super.setup(action_id, direction, start_pos, custom_stats)


func shoot() -> void:
	super.shoot()
	position += _get_projectile_offset(direction_string)


# Calculates the visual offset based on the facing direction.
func _get_projectile_offset(direction: String) -> Vector2:
	var offset := Vector2.ZERO
	var dir_lower := direction.to_lower()
	
	match dir_lower:
		"down":
			offset.y -= 26
		"left", "right":
			offset.y -= 26
		"up":
			offset.y = 8
			
	return offset


func _play_initial_sound() -> void:
	_play_audio_from_path("res://addons/rpg_character_creator/sounds/swosh-01.ogg")
