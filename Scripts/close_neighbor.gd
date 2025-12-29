var horizontal_threshold = 10 # 10 = original
var vertical_threshold = 50 # 50 = original


func get_closest_focusable_control(current: Control, direction: String, limit_to_parent: bool = false, extra_focusable_controls: Array = []) -> Control:
	if not current: 
		return null
	
	# Verificar primero los neighbors explícitos
	var neighbor = get_explicit_neighbor(current, direction)
	if neighbor and neighbor != current and is_control_focusable(neighbor):
		return neighbor
	
	# Obtener todos los controles focuseables
	var search_root = current.get_parent() if limit_to_parent else current.get_tree().current_scene
	if not search_root:
		return null
		
	var controls_to_search = get_all_focusable_controls(search_root)
	
	if not extra_focusable_controls.is_empty():
		controls_to_search.append_array(extra_focusable_controls)
	
	# Remover el control actual de la lista
	controls_to_search.erase(current)
	
	if controls_to_search.is_empty():
		return null
	
	# Buscar el control más cercano en la dirección especificada
	var best_control = find_closest_in_direction(current, controls_to_search, direction)
	
	# Si encontramos un control, devolverlo
	if best_control:
		return best_control
	
	# Si no hay control en esa dirección, aplicar lógica de wraparound
	return apply_wraparound_logic(current, controls_to_search, direction)

func get_explicit_neighbor(current: Control, direction: String) -> Control:
	var neighbor_path = ""
	
	match direction:
		"left":
			neighbor_path = current.focus_neighbor_left
		"right":
			neighbor_path = current.focus_neighbor_right
		"up":
			neighbor_path = current.focus_neighbor_top
		"down":
			neighbor_path = current.focus_neighbor_bottom
	
	if neighbor_path.is_empty():
		return null
		
	return current.get_node_or_null(neighbor_path)

func is_control_focusable(control: Control) -> bool:
	return control and control.focus_mode != Control.FOCUS_NONE and control.visible and not control.modulate.a == 0 and control.mouse_filter != Control.MOUSE_FILTER_IGNORE

func get_all_focusable_controls(node: Node) -> Array:
	var controls = []
	
	if node is Control and is_control_focusable(node):
		controls.append(node)
	
	for child in node.get_children():
		controls.append_array(get_all_focusable_controls(child))
	
	return controls

func find_closest_in_direction(current: Control, controls: Array, direction: String) -> Control:
	var current_rect = current.get_global_rect()
	var current_center = current_rect.get_center()
	
	var best_control = null
	var best_score = INF
	
	for control in controls:
		var control_rect = control.get_global_rect()
		var control_center = control_rect.get_center()
		
		var is_in_direction = false
		var score = 0.0
		
		match direction:
			"left":
				# El control debe estar completamente a la izquierda
				if control_rect.end.x <= current_rect.position.x:
					is_in_direction = true
					var distance = current_center.distance_to(control_center)
					var alignment_bonus = 1.0 / (1.0 + abs(control_center.y - current_center.y) * 0.01)
					score = distance / alignment_bonus
			
			"right":
				# El control debe estar completamente a la derecha
				if control_rect.position.x >= current_rect.end.x:
					is_in_direction = true
					var distance = current_center.distance_to(control_center)
					var alignment_bonus = 1.0 / (1.0 + abs(control_center.y - current_center.y) * 0.01)
					score = distance / alignment_bonus
			
			"up":
				# El control debe estar completamente arriba
				if control_rect.end.y <= current_rect.position.y:
					is_in_direction = true
					var distance = current_center.distance_to(control_center)
					var alignment_bonus = 1.0 / (1.0 + abs(control_center.x - current_center.x) * 0.01)
					score = distance / alignment_bonus
			
			"down":
				# El control debe estar completamente abajo
				if control_rect.position.y >= current_rect.end.y:
					is_in_direction = true
					var distance = current_center.distance_to(control_center)
					var alignment_bonus = 1.0 / (1.0 + abs(control_center.x - current_center.x) * 0.01)
					score = distance / alignment_bonus
		
		if is_in_direction and score < best_score:
			best_score = score
			best_control = control

	return best_control

func apply_wraparound_logic(current: Control, controls: Array, direction: String) -> Control:
	controls.erase(current)
	var current_rect = current.get_global_rect()
	var current_center = current_rect.get_center()
	
	match direction:
		"left":
			# Ir al control más a la derecha en la fila superior más cercana
			return find_wraparound_left(current_center, controls)
		
		"right":
			# Ir al control más a la izquierda en la fila inferior más cercana o al mas superior/izquierda
			var next_node = find_wraparound_right(current_center, controls)
			if next_node != current:
				return next_node
			else:
				next_node = find_topmost_leftmost_control(controls)
				return next_node
		
		"up":
			# Ir al control más abajo que esté alineado horizontalmente
			return find_wraparound_up(current_center, controls)
		
		"down":
			# Ir al control más arriba que esté alineado horizontalmente
			return find_wraparound_down(current_center, controls)
	
	# Fallback: devolver el primer control disponible
	return controls[0] if not controls.is_empty() else null

func find_wraparound_left(current_center: Vector2, controls: Array) -> Control:
	# Buscar controles que estén en filas superiores
	var controls_above = []
	
	for control in controls:
		var control_center = control.get_global_rect().get_center()
		if control_center.y < current_center.y - horizontal_threshold:
			controls_above.append(control)
	
	# Si no hay controles arriba, buscar en la fila más abajo
	if controls_above.is_empty():
		return find_bottommost_rightmost_control(controls)
	
	# Encontrar la fila más cercana arriba
	var closest_row_y = -INF
	for control in controls_above:
		var control_center = control.get_global_rect().get_center()
		if control_center.y > closest_row_y:
			closest_row_y = control_center.y
	
	# Filtrar controles en esa fila
	var row_controls = []
	for control in controls_above:
		var control_center = control.get_global_rect().get_center()
		if abs(control_center.y - closest_row_y) <= horizontal_threshold:
			row_controls.append(control)
	
	# Devolver el más a la derecha de esa fila
	return find_rightmost_control(row_controls)

func find_wraparound_right(current_center: Vector2, controls: Array) -> Control:
	# Buscar controles que estén en filas inferiores
	var controls_below = []
	
	for control in controls:
		var control_center = control.get_global_rect().get_center()
		if control_center.y > current_center.y + vertical_threshold:
			controls_below.append(control)
	
	# Si no hay controles abajo, buscar en la fila más arriba
	if controls_below.is_empty():
		return find_topmost_leftmost_control(controls)
	
	# Encontrar la fila más cercana abajo
	var closest_row_y = INF
	for control in controls_below:
		var control_center = control.get_global_rect().get_center()
		if control_center.y < closest_row_y:
			closest_row_y = control_center.y
	
	# Filtrar controles en esa fila
	var row_controls = []
	for control in controls_below:
		var control_center = control.get_global_rect().get_center()
		if abs(control_center.y - closest_row_y) <= vertical_threshold:
			row_controls.append(control)
	
	# Devolver el más a la izquierda de esa fila
	return find_leftmost_control(row_controls)

func find_wraparound_up(current_center: Vector2, controls: Array) -> Control:
	# Buscar el control más abajo que esté alineado o cerca horizontalmente
	var best_control = null
	var best_y = -INF
	
	for control in controls:
		var control_center = control.get_global_rect().get_center()
		var horizontal_distance = abs(control_center.x - current_center.x)
		
		if horizontal_distance <= horizontal_threshold and control_center.y > best_y:
			best_y = control_center.y
			best_control = control
	
	# Si no encuentra uno alineado, buscar simplemente el más abajo
	if not best_control:
		return find_bottommost_control(controls)
	
	return best_control

func find_wraparound_down(current_center: Vector2, controls: Array) -> Control:
	# Buscar el control más arriba que esté alineado o cerca horizontalmente
	var best_control = null
	var best_y = INF
	
	for control in controls:
		var control_center = control.get_global_rect().get_center()
		var horizontal_distance = abs(control_center.x - current_center.x)
		
		if horizontal_distance <= horizontal_threshold and control_center.y < best_y:
			best_y = control_center.y
			best_control = control

	# Si no encuentra uno alineado, buscar simplemente el más arriba
	if not best_control:
		return find_topmost_control(controls)

	return best_control

# Funciones auxiliares optimizadas
func find_topmost_control(controls: Array) -> Control:
	var best_control = null
	var best_y = INF
	
	for control in controls:
		var y = control.get_global_rect().get_center().y
		if y < best_y:
			best_y = y
			best_control = control
	
	return best_control

func find_bottommost_control(controls: Array) -> Control:
	var best_control = null
	var best_y = -INF
	
	for control in controls:
		var y = control.get_global_rect().get_center().y
		if y > best_y:
			best_y = y
			best_control = control
	
	return best_control

func find_leftmost_control(controls: Array) -> Control:
	var best_control = null
	var best_x = INF
	
	for control in controls:
		var x = control.get_global_rect().get_center().x
		if x < best_x:
			best_x = x
			best_control = control
	
	return best_control

func find_rightmost_control(controls: Array) -> Control:
	var best_control = null
	var best_x = -INF
	
	for control in controls:
		var x = control.get_global_rect().get_center().x
		if x > best_x:
			best_x = x
			best_control = control
	
	return best_control

func find_topmost_leftmost_control(controls: Array) -> Control:
	var best_control = null
	var best_score = INF
	
	for control in controls:
		var center = control.get_global_rect().get_center()
		var score = center.y * 1000 + center.x  # Priorizar Y, luego X
		if score < best_score:
			best_score = score
			best_control = control
	
	return best_control

func find_bottommost_rightmost_control(controls: Array) -> Control:
	var best_control = null
	var best_score = -INF
	
	for control in controls:
		var center = control.get_global_rect().get_center()
		var score = center.y * 1000 + center.x  # Priorizar Y, luego X
		if score > best_score:
			best_score = score
			best_control = control
	
	return best_control
