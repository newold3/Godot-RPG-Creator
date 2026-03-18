class_name ArcaneProjectile
extends ProjectileBase

## Handles magic missiles with serpentine movement, custom VFX, and spell sounds.


@export var frequency: float = 12.0
@export var amplitude: float = 4.0

var _time_accum: float = 0.0


func setup(action_id: String, direction: String, start_pos: Vector2, custom_stats: Dictionary = {}) -> void:
	super.setup(action_id, direction, start_pos, custom_stats)
	
	frequency = custom_stats.get("frequency", frequency)
	amplitude = custom_stats.get("amplitude", amplitude)
	
	var extra_vfx = preload("uid://fyydv1ar20a").instantiate()
	add_child(extra_vfx)
	
	var blend_color = custom_stats.get("projectile_color", Color.WHITE)
	if extra_vfx is GPUParticles2D or extra_vfx is CPUParticles2D:
		extra_vfx.process_material.color = blend_color


func shoot() -> void:
	super.shoot()
	position += _get_projectile_offset(direction_string)


func _get_projectile_offset(direction: String) -> Vector2:
	var offset := Vector2.ZERO
	var dir_lower := direction.to_lower()
	
	match dir_lower:
		"down":
			offset.x += 32
			offset.y -= 32
		"left":
			offset.x += 24
		"right":
			offset.x -= 24
			offset.y -= 16
		"up":
			offset.x += 16
			offset.y += 24
			
	return offset


func _play_initial_sound() -> void:
	_play_audio_from_path("res://addons/rpg_character_creator/sounds/spell1.ogg")


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	
	_time_accum += delta
	
	var wave_velocity = cos(_time_accum * frequency) * amplitude * 60.0 * delta
	var perp_vector = Vector2(-direction_vector.y, direction_vector.x)
	
	position += perp_vector * wave_velocity
	
	if direction_string == "left" or direction_string == "right":
		position.y += 25.0 * delta
