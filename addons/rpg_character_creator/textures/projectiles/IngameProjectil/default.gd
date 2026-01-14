extends ProjectileBase


func _process(delta: float) -> void:
	var displacement = direction_vector * speed * delta
	position += displacement
	
	if direction_string == "left" or direction_string == "right":
		position.y += 25.0 * delta
		
	travelled_distance += displacement.length()
	if travelled_distance >= max_distance:
		destroy()

	if _is_animating:
		_process_animation(delta)
