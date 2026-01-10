extends Node

## Thresholds adjusted to handle small offsets in UI alignment
var horizontal_threshold = 30 
var vertical_threshold = 30


## Main function to get the closest focusable control
func get_closest_focusable_control(current: Control, direction: String, limit_to_parent: bool = false, extra_focusable_controls: Array = []) -> Control:
	if not current:
		return null
	
	# 1. Check explicit neighbors (the ones manually set in the inspector)
	var neighbor = get_explicit_neighbor(current, direction)
	if neighbor and neighbor != current and is_control_focusable(neighbor):
		return neighbor
	
	# 2. Collect all candidates
	var search_root = current.get_parent() if limit_to_parent else current.get_tree().current_scene
	if not search_root:
		return null
		
	var controls_to_search = get_all_focusable_controls(search_root)
	
	if not extra_focusable_controls.is_empty():
		for c in extra_focusable_controls:
			if c not in controls_to_search: 
				controls_to_search.append(c)
	
	controls_to_search.erase(current)
	
	if controls_to_search.is_empty():
		return null
	
	# 3. Primary Search: Find closest control with strict row/column priority
	var best_control = find_closest_in_direction(current, controls_to_search, direction)
	
	if best_control:
		return best_control
	
	# 4. Secondary Search: Apply wraparound logic if nothing was found in the same line
	return apply_wraparound_logic(current, controls_to_search, direction)


## Search logic that prioritizes same row/column alignment
func find_closest_in_direction(current: Control, controls: Array, direction: String) -> Control:
	var current_center = current.get_global_rect().get_center()
	var candidates = []
	
	# Filter only controls that are actually in the requested direction
	for control in controls:
		var c_center = control.get_global_rect().get_center()
		var is_valid = false
		
		match direction:
			"left":
				if c_center.x < current_center.x - 5: is_valid = true
			"right":
				if c_center.x > current_center.x + 5: is_valid = true
			"up":
				if c_center.y < current_center.y - 5: is_valid = true
			"down":
				if c_center.y > current_center.y + 5: is_valid = true
		
		if is_valid:
			candidates.append(control)
			
	if candidates.is_empty(): 
		return null

	# Strict Sorting: Alignment first, then distance
	candidates.sort_custom(func(a, b):
		var a_center = a.get_global_rect().get_center()
		var b_center = b.get_global_rect().get_center()
		
		match direction:
			"left", "right":
				var a_aligned = abs(a_center.y - current_center.y) <= vertical_threshold
				var b_aligned = abs(b_center.y - current_center.y) <= vertical_threshold
				if a_aligned != b_aligned: return a_aligned # Prioritize same row
				return abs(a_center.x - current_center.x) < abs(b_center.x - current_center.x)
				
			"up", "down":
				var a_aligned = abs(a_center.x - current_center.x) <= horizontal_threshold
				var b_aligned = abs(b_center.x - current_center.x) <= horizontal_threshold
				if a_aligned != b_aligned: return a_aligned # Prioritize same column
				return abs(a_center.y - current_center.y) < abs(b_center.y - current_center.y)
	)
	
	var best = candidates[0]
	var best_center = best.get_global_rect().get_center()
	
	# For horizontal movement: if the best candidate is not in the same row,
	# we return null to let apply_wraparound_logic handle the sequence jump.
	if (direction == "left" or direction == "right"):
		if abs(best_center.y - current_center.y) > vertical_threshold:
			return null
			
	return best


## Wraparound logic to jump between rows/columns or loop the menu
func apply_wraparound_logic(current: Control, controls: Array, direction: String) -> Control:
	var current_center = current.get_global_rect().get_center()
	
	match direction:
		"left":
			return find_wraparound_left(current_center, controls)
		"right":
			return find_wraparound_right(current_center, controls)
		"up":
			return find_wraparound_up(current_center, controls)
		"down":
			return find_wraparound_down(current_center, controls)
	
	return controls[0] if not controls.is_empty() else null


func get_explicit_neighbor(current: Control, direction: String) -> Control:
	var neighbor_path = ""
	match direction:
		"left": neighbor_path = current.focus_neighbor_left
		"right": neighbor_path = current.focus_neighbor_right
		"up": neighbor_path = current.focus_neighbor_top
		"down": neighbor_path = current.focus_neighbor_bottom
	
	return current.get_node_or_null(neighbor_path) if not neighbor_path.is_empty() else null


func is_control_focusable(control: Control) -> bool:
	var focuseable = control and \
		control.focus_mode != Control.FOCUS_NONE and \
		control.visible and \
		control.modulate.a > 0 and \
		(not "disabled" in control or not control.disabled)
	return control and control.focus_mode != Control.FOCUS_NONE and control.visible and control.modulate.a > 0


func get_all_focusable_controls(node: Node) -> Array:
	var controls = []
	if node is Control and is_control_focusable(node):
		controls.append(node)
	for child in node.get_children():
		controls.append_array(get_all_focusable_controls(child))
	return controls


func find_wraparound_left(current_center: Vector2, controls: Array) -> Control:
	var above = controls.filter(func(c): return c.get_global_rect().get_center().y < current_center.y - vertical_threshold)
	if above.is_empty(): 
		return find_bottommost_rightmost_control(controls)
	
	var target_y = -INF
	for c in above: target_y = max(target_y, c.get_global_rect().get_center().y)
	var row = above.filter(func(c): return abs(c.get_global_rect().get_center().y - target_y) <= vertical_threshold)
	return find_rightmost_control(row)


func find_wraparound_right(current_center: Vector2, controls: Array) -> Control:
	var below = controls.filter(func(c): return c.get_global_rect().get_center().y > current_center.y + vertical_threshold)
	if below.is_empty(): 
		return find_topmost_leftmost_control(controls)
	
	var target_y = INF
	for c in below: target_y = min(target_y, c.get_global_rect().get_center().y)
	var row = below.filter(func(c): return abs(c.get_global_rect().get_center().y - target_y) <= vertical_threshold)
	return find_leftmost_control(row)


func find_wraparound_up(current_center: Vector2, controls: Array) -> Control:
	var same_col = controls.filter(func(c): return abs(c.get_global_rect().get_center().x - current_center.x) <= horizontal_threshold)
	return find_bottommost_control(same_col if not same_col.is_empty() else controls)


func find_wraparound_down(current_center: Vector2, controls: Array) -> Control:
	var same_col = controls.filter(func(c): return abs(c.get_global_rect().get_center().x - current_center.x) <= horizontal_threshold)
	return find_topmost_control(same_col if not same_col.is_empty() else controls)


func find_topmost_control(controls: Array) -> Control:
	var best = null
	var min_y = INF
	for c in controls:
		var y = c.get_global_rect().get_center().y
		if y < min_y:
			min_y = y
			best = c
	return best


func find_bottommost_control(controls: Array) -> Control:
	var best = null
	var max_y = -INF
	for c in controls:
		var y = c.get_global_rect().get_center().y
		if y > max_y:
			max_y = y
			best = c
	return best


func find_leftmost_control(controls: Array) -> Control:
	var best = null
	var min_x = INF
	for c in controls:
		var x = c.get_global_rect().get_center().x
		if x < min_x:
			min_x = x
			best = c
	return best


func find_rightmost_control(controls: Array) -> Control:
	var best = null
	var max_x = -INF
	for c in controls:
		var x = c.get_global_rect().get_center().x
		if x > max_x:
			max_x = x
			best = c
	return best


func find_topmost_leftmost_control(controls: Array) -> Control:
	var best = null
	var min_score = INF
	for c in controls:
		var p = c.get_global_rect().get_center()
		var score = p.y * 1000 + p.x
		if score < min_score:
			min_score = score
			best = c
	return best


func find_bottommost_rightmost_control(controls: Array) -> Control:
	var best = null
	var max_score = -INF
	for c in controls:
		var p = c.get_global_rect().get_center()
		var score = p.y * 1000 + p.x
		if score > max_score:
			max_score = score
			best = c
	return best
