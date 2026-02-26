class_name BoomerangProjectile
extends ProjectileBase

## How much the speed increases per second while returning to the shooter.
@export var return_acceleration: float = 800.0

var is_returning: bool = false
var _hit_targets: Array[Node2D] = []



## Initializes the boomerang, applying offsets, z-index logic, and extra VFX.
func setup(action_id: String, direction: String, start_pos: Vector2, custom_stats: Dictionary = {}) -> void:
	super.setup(action_id, direction, start_pos, custom_stats)
	
	var x = 0
	var y = 0
	
	if direction_string == "left" or direction_string == "right":
		y -= 32
		x -= 16
		z_index = 20
	elif direction_string == "down":
		y += 8
		z_index = 20
	else:
		z_index = 1
		
	position += Vector2(x, y)
	
	var extra_fx = preload("uid://dlql3isoj0b1o").instantiate()
	add_child(extra_fx)



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



func hit(target: Node2D = null) -> void:
	if _is_destroyed or is_queued_for_deletion():
		return
		
	if target:
		if target in _hit_targets:
			return
			
		if target == player:
			if is_returning:
				super.hit(player)
			return
			
		_hit_targets.append(target)
		
	if not is_returning:
		_start_return()



func _start_return() -> void:
	is_returning = true



func _on_body_entered(body: Node2D) -> void:
	if body == player:
		if is_returning:
			hit(body)
		return
		
	hit(body)



func _on_area_entered(area: Area2D) -> void:
	var body = area.get_parent()
	if not body:
		return
		
	if body == player:
		if is_returning:
			hit(body)
		return
		
	hit(body)
