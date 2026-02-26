class_name ParabolicProjectile
extends ProjectileBase

## Maximum visual height of the parabola in pixels.
@export var arc_height: float = 40.0
## Maximum visual scale at the peak of the parabola to simulate depth.
@export var max_scale: float = 1.3
## Rotation speed of the rock in radians per second.
@export var spin_speed: float = 15.0

var _ground_position: Vector2


## Initializes the projectile, applies specific offsets, and stores the base starting position.
func setup(action_id: String, direction: String, start_pos: Vector2, custom_stats: Dictionary = {}) -> void:
	super.setup(action_id, direction, start_pos, custom_stats)
	
	arc_height = custom_stats.get("arc_height", arc_height)
	max_scale = custom_stats.get("max_scale", max_scale)
	spin_speed = custom_stats.get("spin_speed", spin_speed)
	max_distance = 150
	
	var x = 0
	var y = 0
	
	if direction_string == "down":
		x += 0
	elif direction_string == "left" or direction_string == "right":
		x += 6
		y -= 26
	elif direction_string == "up":
		x += 0
		y += 26
		
	position += Vector2(x, y)
	_ground_position = position


func _play_initial_sound() -> void:
	_play_audio_from_path("res://addons/rpg_character_creator/sounds/swosh-05.ogg")


## Calculates movement and parabolic arc, modifying the root position directly.
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
	
	position = _ground_position + Vector2(0, -height_offset)
	
	var current_scale: float = 1.0 + (sin(progress * PI) * (max_scale - 1.0))
	sprite.scale = Vector2(current_scale, current_scale)
	
	sprite.rotation += spin_speed * delta
	
	if travelled_distance >= max_distance:
		hit(null)
		
	if _is_animating:
		_process_animation(delta)
