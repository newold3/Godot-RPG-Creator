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
	
	var x = 0
	var y = 0
	
	if direction_string == "down":
		x += 32
		y = -32
	elif direction_string == "left":
		x = 24
		y = 0
	elif direction_string == "right":
		x -= 24
		y = -16
	elif direction_string == "up":
		x += 16
		y += 24
		
	position += Vector2(x, y)
	
	var extra_vfx = preload("uid://fyydv1ar20a").instantiate()
	add_child(extra_vfx)
	
	var blend_color = custom_stats.get("projectile_color", Color.WHITE)
	if extra_vfx is GPUParticles2D or extra_vfx is CPUParticles2D:
		extra_vfx.process_material.color = blend_color



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
