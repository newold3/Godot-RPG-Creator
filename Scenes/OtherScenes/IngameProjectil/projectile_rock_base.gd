class_name ParabolicProjectile
extends ProjectileBase

## Maximum visual height of the parabola in pixels.
@export var arc_height: float = 40.0
## Maximum visual scale at the peak of the parabola to simulate depth.
@export var max_scale: float = 1.3
## Rotation speed of the rock in radians per second.
@export var spin_speed: float = 15.0
## Normalized progress (0.0 to 1.0) when the projectile loses collision and goes high in the air.
@export var air_start_progress: float = 0.1
## Normalized progress (0.0 to 1.0) when the projectile starts descending and regains collision.
@export var air_end_progress: float = 0.3
## Extra vertical distance in pixels the projectile falls to simulate landing on the ground from hand height.
@export var landing_y_offset: float = 16.0

var _ground_position: Vector2
var _base_z_index: int = 0
var _is_airborne: bool = false


func setup(action_id: String, direction: String, start_pos: Vector2, custom_stats: Dictionary = {}) -> void:
	super.setup(action_id, direction, start_pos, custom_stats)
	
	arc_height = custom_stats.get("arc_height", arc_height)
	max_scale = custom_stats.get("max_scale", max_scale)
	spin_speed = custom_stats.get("spin_speed", spin_speed)
	max_distance = 150
	
	_ground_position = position
	_base_z_index = z_index


func shoot() -> void:
	super.shoot()
	position += _get_projectile_offset(direction_string)
	_ground_position = position


func _get_projectile_offset(direction: String) -> Vector2:
	var offset := Vector2.ZERO
	var dir_lower := direction.to_lower()
	
	match dir_lower:
		"left", "right":
			offset.x += 6
			offset.y -= 26
		"up":
			offset.y += 26
			
	return offset


func _play_initial_sound() -> void:
	_play_audio_from_path("res://addons/rpg_character_creator/sounds/swosh-05.ogg")


func _physics_process(delta: float) -> void:
	if is_queued_for_deletion():
		return
		
	var displacement = direction_vector * speed * delta
	_ground_position += displacement
	travelled_distance += displacement.length()
	
	var progress: float = 0.0
	if max_distance > 0.0:
		progress = clamp(travelled_distance / max_distance, 0.0, 1.0)
		
	var height_offset = sin(progress * PI) * arc_height
	var drop_offset = progress * landing_y_offset
	
	position = _ground_position + Vector2(0, -height_offset + drop_offset)
	
	var current_scale: float = 1.0 + (sin(progress * PI) * (max_scale - 1.0))
	sprite.scale = Vector2(current_scale, current_scale)
	
	sprite.rotation += spin_speed * delta
	
	_handle_airborne_state(progress)
	
	if travelled_distance >= max_distance:
		hit(null)
		
	if _is_animating:
		_process_animation(delta)


# Manages the collision state and z_index based on the projectile's flight progress.
func _handle_airborne_state(progress: float) -> void:
	if progress >= air_start_progress and progress < air_end_progress:
		if not _is_airborne:
			_is_airborne = true
			z_index = _base_z_index + 10
			
			if collision_shape:
				collision_shape.set_deferred("disabled", true)
				
	elif progress >= air_end_progress:
		if _is_airborne:
			_is_airborne = false
			z_index = _base_z_index
			
			if collision_shape:
				collision_shape.set_deferred("disabled", false)
