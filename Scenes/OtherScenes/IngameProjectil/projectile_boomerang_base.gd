class_name BoomerangProjectile
extends ProjectileBase

## How much the speed increases per second while returning to the shooter.
@export var return_acceleration: float = 800.0

var is_returning: bool = false


func setup(action_id: String, direction: String, start_pos: Vector2, custom_stats: Dictionary = {}) -> void:
	super.setup(action_id, direction, start_pos, custom_stats)
	
	var dir_lower := direction.to_lower()
	if dir_lower == "left" or dir_lower == "right" or dir_lower == "down":
		z_index = 20
	else:
		z_index = 1
		
	var extra_fx = preload("uid://dlql3isoj0b1o").instantiate()
	add_child(extra_fx)


func shoot() -> void:
	super.shoot()
	position += _get_projectile_offset(direction_string)


func _get_projectile_offset(direction: String) -> Vector2:
	var offset := Vector2.ZERO
	var dir_lower := direction.to_lower()
	
	match dir_lower:
		"left", "right":
			offset.x -= 16
			offset.y -= 32
		"down":
			offset.y += 8
			
	return offset


func _physics_process(delta: float) -> void:
	if not is_returning:
		var displacement = direction_vector * speed * delta
		position += displacement
		travelled_distance += displacement.length()
		
		if travelled_distance >= max_distance:
			_start_return()
	else:
		speed += return_acceleration * delta
		
		if is_instance_valid(player):
			var return_offset = Vector2.ZERO
			match direction_string:
				"left":
					return_offset.y = -32
				"right":
					return_offset.y = -32
					return_offset.x = -16
				"down":
					return_offset.y = -32
			
			var target_point = player.global_position + return_offset
			var return_dir = (target_point - global_position).normalized()
			
			position += return_dir * speed * delta
			
			if global_position.distance_to(target_point) < 20.0:
				super.hit(player)
		else:
			destroy()
			
	if _is_animating:
		_process_animation(delta)


func hit(_target: Node2D = null) -> void:
	if not is_returning:
		_start_return()


func _start_return() -> void:
	is_returning = true
