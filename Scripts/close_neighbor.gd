extends Node

## Thresholds adjusted to handle small offsets in UI alignment
var horizontal_threshold = 30
var vertical_threshold = 30


## Main function to get the closest focusable control
func get_closest_focusable_control(current: Control, direction: String, limit_to_parent: bool = false, extra_focusable_controls: Array = [], allow_h_warp: bool = true, allow_v_warp: bool = true) -> Control:
	if not current:
		return null
	
	var neighbor = get_explicit_neighbor(current, direction)
	if neighbor and is_control_focusable(neighbor):
		return neighbor
	
	var search_root = current.get_parent() if limit_to_parent else current.get_tree().current_scene
	if not search_root:
		return null
		
	var all_controls = get_all_focusable_controls(search_root)
	
	if not extra_focusable_controls.is_empty():
		for c in extra_focusable_controls:
			if c not in all_controls:
				all_controls.append(c)
	
	var focusable_candidates = all_controls.filter(func(c): return c != current and is_control_focusable(c))
	
	if focusable_candidates.is_empty():
		return null
	
	var best_control = find_closest_in_direction(current, focusable_candidates, direction)
	if best_control:
		return best_control
	
	return apply_wraparound_logic(current, focusable_candidates, direction, allow_h_warp, allow_v_warp)


## Search logic that prioritizes same row/column alignment
func find_closest_in_direction(current: Control, controls: Array, direction: String) -> Control:
	var current_center = current.get_global_rect().get_center()
	var candidates = []
	
	for control in controls:
		var c_center = control.get_global_rect().get_center()
		var is_valid = false
		match direction:
			"left": if c_center.x < current_center.x - 5: is_valid = true
			"right": if c_center.x > current_center.x + 5: is_valid = true
			"up": if c_center.y < current_center.y - 5: is_valid = true
			"down": if c_center.y > current_center.y + 5: is_valid = true
		
		if is_valid: candidates.append(control)
			
	if candidates.is_empty(): return null

	candidates.sort_custom(func(a, b):
		var a_c = a.get_global_rect().get_center()
		var b_c = b.get_global_rect().get_center()
		match direction:
			"left", "right":
				var a_al = abs(a_c.y - current_center.y) <= vertical_threshold
				var b_al = abs(b_c.y - current_center.y) <= vertical_threshold
				if a_al != b_al: return a_al
				return abs(a_c.x - current_center.x) < abs(b_c.x - current_center.x)
			"up", "down":
				var a_al = abs(a_c.x - current_center.x) <= horizontal_threshold
				var b_al = abs(b_c.x - current_center.x) <= horizontal_threshold
				if a_al != b_al: return a_al
				return abs(a_c.y - current_center.y) < abs(b_c.y - current_center.y)
	)
	
	var best = candidates[0]
	var best_c = best.get_global_rect().get_center()
	
	if (direction == "left" or direction == "right"):
		if abs(best_c.y - current_center.y) > vertical_threshold: return null
	
	if (direction == "up" or direction == "down"):
		if abs(best_c.x - current_center.x) > horizontal_threshold: return null
			
	return best


## Wraparound logic to jump between rows/columns or loop the menu
func apply_wraparound_logic(current: Control, controls: Array, direction: String, h_enabled: bool, v_enabled: bool) -> Control:
	var current_center = current.get_global_rect().get_center()
	match direction:
		"left": return find_wraparound_left(current_center, controls) if h_enabled else null
		"right": return find_wraparound_right(current_center, controls) if h_enabled else null
		"up": return find_wraparound_up(current_center, controls) if v_enabled else null
		"down": return find_wraparound_down(current_center, controls) if v_enabled else null
	return null


func get_explicit_neighbor(current: Control, direction: String) -> Control:
	if not current.has_meta("neighbors"): return null
	var neighbors = current.get_meta("neighbors")
	var path = neighbors.get(direction, "")
	if path == null or str(path).is_empty(): return null
	return current.get_node_or_null(path) as Control


func is_control_focusable(control: Control) -> bool:
	return is_instance_valid(control) and control.visible and \
		control.focus_mode != Control.FOCUS_NONE and \
		(not "disabled" in control or not control.disabled)


func get_all_focusable_controls(node: Node) -> Array:
	var controls = []
	if node is Control: controls.append(node)
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
	var left_side = controls.filter(func(c): return c.get_global_rect().get_center().x < current_center.x - horizontal_threshold)
	if left_side.is_empty():
		return find_bottommost_rightmost_control(controls)
	
	var target_x = -INF
	for c in left_side: target_x = max(target_x, c.get_global_rect().get_center().x)
	var col = left_side.filter(func(c): return abs(c.get_global_rect().get_center().x - target_x) <= horizontal_threshold)
	return find_bottommost_control(col)


func find_wraparound_down(current_center: Vector2, controls: Array) -> Control:
	var right_side = controls.filter(func(c): return c.get_global_rect().get_center().x > current_center.x + horizontal_threshold)
	if right_side.is_empty():
		return find_topmost_leftmost_control(controls)
	
	var target_x = INF
	for c in right_side: target_x = min(target_x, c.get_global_rect().get_center().x)
	var col = right_side.filter(func(c): return abs(c.get_global_rect().get_center().x - target_x) <= horizontal_threshold)
	return find_topmost_control(col)


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
