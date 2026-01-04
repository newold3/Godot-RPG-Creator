var horizontal_threshold = 10 # 10 = original
var vertical_threshold = 50 # 50 = original


func get_closest_focusable_control(current: Control, direction: String, limit_to_parent: bool = false, extra_focusable_controls: Array = []) -> Control:
	if not current:
		return null
	
	# Check explicit neighbors first
	var neighbor = get_explicit_neighbor(current, direction)
	if neighbor and neighbor != current and is_control_focusable(neighbor):
		return neighbor
	
	# Get all focusable controls
	var search_root = current.get_parent() if limit_to_parent else current.get_tree().current_scene
	if not search_root:
		return null
		
	var controls_to_search = get_all_focusable_controls(search_root)
	
	if not extra_focusable_controls.is_empty():
		controls_to_search.append_array(extra_focusable_controls)
	
	# Remove current control from list
	controls_to_search.erase(current)
	
	if controls_to_search.is_empty():
		return null
	
	# Find closest control in specified direction
	var best_control = find_closest_in_direction(current, controls_to_search, direction)
	
	# If control found, return it
	if best_control:
		return best_control
	
	# If no control in that direction, apply wraparound logic
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
				# Control must be completely to the left
				if control_rect.end.x <= current_rect.position.x:
					is_in_direction = true
					var distance = current_center.distance_to(control_center)
					var alignment_bonus = 1.0 / (1.0 + abs(control_center.y - current_center.y) * 0.01)
					score = distance / alignment_bonus
			
			"right":
				# Control must be completely to the right
				if control_rect.position.x >= current_rect.end.x:
					is_in_direction = true
					var distance = current_center.distance_to(control_center)
					var alignment_bonus = 1.0 / (1.0 + abs(control_center.y - current_center.y) * 0.01)
					score = distance / alignment_bonus
			
			"up":
				# Control must be completely above
				if control_rect.end.y <= current_rect.position.y:
					is_in_direction = true
					var distance = current_center.distance_to(control_center)
					var alignment_bonus = 1.0 / (1.0 + abs(control_center.x - current_center.x) * 0.01)
					score = distance / alignment_bonus
			
			"down":
				# Control must be completely below
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
			# Go to the rightmost control in the nearest upper row
			return find_wraparound_left(current_center, controls)
		
		"right":
			# Go to the leftmost control in the nearest lower row or the topmost/leftmost
			var next_node = find_wraparound_right(current_center, controls)
			if next_node != current:
				return next_node
			else:
				next_node = find_topmost_leftmost_control(controls)
				return next_node
		
		"up":
			# Go to the lowest control horizontally aligned
			return find_wraparound_up(current_center, controls)
		
		"down":
			# Go to the highest control horizontally aligned
			return find_wraparound_down(current_center, controls)
	
	# Fallback: return the first available control
	return controls[0] if not controls.is_empty() else null

func find_wraparound_left(current_center: Vector2, controls: Array) -> Control:
	# Find controls in upper rows
	var controls_above = []
	
	for control in controls:
		var control_center = control.get_global_rect().get_center()
		if control_center.y < current_center.y - horizontal_threshold:
			controls_above.append(control)
	
	# If no controls above, search in the bottommost row
	if controls_above.is_empty():
		return find_bottommost_rightmost_control(controls)
	
	# Find the nearest row above
	var closest_row_y = - INF
	for control in controls_above:
		var control_center = control.get_global_rect().get_center()
		if control_center.y > closest_row_y:
			closest_row_y = control_center.y
	
	# Filter controls in that row
	var row_controls = []
	for control in controls_above:
		var control_center = control.get_global_rect().get_center()
		if abs(control_center.y - closest_row_y) <= horizontal_threshold:
			row_controls.append(control)
	
	# Return the rightmost of that row
	return find_rightmost_control(row_controls)

func find_wraparound_right(current_center: Vector2, controls: Array) -> Control:
	# Find controls in lower rows
	var controls_below = []
	
	for control in controls:
		var control_center = control.get_global_rect().get_center()
		if control_center.y > current_center.y + vertical_threshold:
			controls_below.append(control)
	
	# If no controls below, search in the topmost row
	if controls_below.is_empty():
		return find_topmost_leftmost_control(controls)
	
	# Find the nearest row below
	var closest_row_y = INF
	for control in controls_below:
		var control_center = control.get_global_rect().get_center()
		if control_center.y < closest_row_y:
			closest_row_y = control_center.y
	
	# Filter controls in that row
	var row_controls = []
	for control in controls_below:
		var control_center = control.get_global_rect().get_center()
		if abs(control_center.y - closest_row_y) <= vertical_threshold:
			row_controls.append(control)
	
	# Return the leftmost of that row
	return find_leftmost_control(row_controls)

func find_wraparound_up(current_center: Vector2, controls: Array) -> Control:
	# Find the lowest control aligned or close horizontally
	var best_control = null
	var best_y = - INF
	
	for control in controls:
		var control_center = control.get_global_rect().get_center()
		var horizontal_distance = abs(control_center.x - current_center.x)
		
		if horizontal_distance <= horizontal_threshold and control_center.y > best_y:
			best_y = control_center.y
			best_control = control
	
	# If none aligned found, simply find the lowest one
	if not best_control:
		return find_bottommost_control(controls)
	
	return best_control

func find_wraparound_down(current_center: Vector2, controls: Array) -> Control:
	# Find the highest control aligned or close horizontally
	var best_control = null
	var best_y = INF
	
	for control in controls:
		var control_center = control.get_global_rect().get_center()
		var horizontal_distance = abs(control_center.x - current_center.x)
		
		if horizontal_distance <= horizontal_threshold and control_center.y < best_y:
			best_y = control_center.y
			best_control = control

	# If none aligned found, simply find the highest one
	if not best_control:
		return find_topmost_control(controls)

	return best_control

# Optimized helper functions
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
	var best_y = - INF
	
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
	var best_x = - INF
	
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
		var score = center.y * 1000 + center.x # Prioritize Y, then X
		if score < best_score:
			best_score = score
			best_control = control
	
	return best_control

func find_bottommost_rightmost_control(controls: Array) -> Control:
	var best_control = null
	var best_score = - INF
	
	for control in controls:
		var center = control.get_global_rect().get_center()
		var score = center.y * 1000 + center.x # Prioritize Y, then X
		if score > best_score:
			best_score = score
			best_control = control
	
	return best_control
