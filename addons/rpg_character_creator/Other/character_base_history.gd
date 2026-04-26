class_name CharacterBaseHistory
extends RefCounted

var current_entity


## Evaluates if the current state warrants recording a new movement snapshot
func _smart_record_history() -> void:
	if current_entity.is_lifting:
		return

	var dist_sq = current_entity.global_position.distance_squared_to(current_entity._last_recorded_pos)
	var has_moved = dist_sq > current_entity.MIN_RECORD_DIST_SQ
	var scale_diff = (current_entity.scale - current_entity._last_recorded_scale).length_squared()
	var has_scaled = scale_diff > 0.0001

	if has_moved or current_entity.is_jumping or has_scaled or current_entity.movement_history.is_empty():
		_add_snapshot()


## Pushes a new state dictionary into the movement history array
func _add_snapshot(snapshot: Dictionary = {}) -> void:
	var visual_rect = Rect2()
	var body_node = current_entity.get_node_or_null("%Body")
	
	if body_node:
		visual_rect = body_node.region_rect
	
	if not snapshot:
		snapshot = {
			"pos": current_entity.global_position,
			"scale": current_entity.scale,
			"modulate": current_entity.modulate,
			"z_index": current_entity.z_index,
			"region_rect": visual_rect,
			"flip_h": body_node.flip_h if body_node else false,
			"direction": current_entity.current_direction,
			"rotation": current_entity.rotation,
			"animation": current_entity.current_animation,
			"is_jumping": current_entity.is_jumping,
			"is_dual": current_entity.is_dual_animation,
			"frame": current_entity.current_frame
		}
	
	current_entity.movement_history.push_back(snapshot)
	current_entity._last_recorded_pos = snapshot.pos 
	
	if snapshot.has("scale"):
		current_entity._last_recorded_scale = snapshot.scale
	else:
		current_entity._last_recorded_scale = current_entity.scale
	
	if current_entity.movement_history.size() > current_entity.MAX_HISTORY_SIZE:
		current_entity.movement_history.pop_front()


## Wipes all previously recorded historical data points
func clear_movement_history() -> void:
	current_entity.movement_history.clear()


## Retrieves a specific snapshot from the history given a trailing offset
func get_history_step(step_offset: int) -> Dictionary:
	if current_entity.movement_history.is_empty():
		return {}
	
	var index = current_entity.movement_history.size() - 1 - step_offset
	
	if index < 0:
		return current_entity.movement_history[0]
	
	return current_entity.movement_history[index]


## Shifts the character's movement history and triggers the safe wrap for followers
func shift_history_and_followers(offset: Vector2) -> void:
	current_entity.target_position += offset
	current_entity._last_recorded_pos += offset
	
	for snapshot in current_entity.movement_history:
		if snapshot.has("pos"): snapshot.pos += offset
		if snapshot.has("jump_start_pos"): snapshot.jump_start_pos += offset
		if snapshot.has("jump_target"): snapshot.jump_target += offset
		if snapshot.has("followers_position"):
			for key in snapshot.followers_position.keys():
				snapshot.followers_position[key] += offset
				
	if current_entity.is_in_group("player"):
		var followers = current_entity.get_tree().get_nodes_in_group("follower")
		for f in followers:
			if f.has_method("apply_map_wrap_offset"):
				f.apply_map_wrap_offset(offset)


## Safely applies a geometric offset to a follower mid-movement rebuilding its tween
func apply_map_wrap_offset(offset: Vector2) -> void:
	var was_moving = current_entity.is_moving
	
	if was_moving and current_entity.movement_tween and current_entity.movement_tween.is_valid():
		current_entity.movement_tween.kill()
		
	current_entity.position += offset
	current_entity.global_position += offset
	current_entity.target_position += offset
	current_entity._last_recorded_pos += offset
	
	for snapshot in current_entity.movement_history:
		if snapshot.has("pos"): snapshot.pos += offset
		if snapshot.has("jump_start_pos"): snapshot.jump_start_pos += offset
		if snapshot.has("jump_target"): snapshot.jump_target += offset
		if snapshot.has("followers_position"):
			for key in snapshot.followers_position.keys():
				snapshot.followers_position[key] += offset
				
	if was_moving:
		var current_motion = current_entity.target_position - current_entity.position
		
		if current_motion != Vector2.ZERO:
			current_entity.movement_tween = current_entity.create_tween()
			current_entity.movement_tween.tween_interval(0.001)
			var distance = current_motion.length()
			var base_distance = current_entity.current_map_tile_size.x
			var max_movement_time = max(current_entity.grid_move_duration.x, current_entity.grid_move_duration.y)
			var remaining_time = max_movement_time * (distance / base_distance)
			current_entity.movement_tween.tween_method(current_entity._update_position.bind([current_entity.position]), current_entity.position, current_entity.target_position, remaining_time)
			current_entity.movement_tween.finished.connect(current_entity._on_grid_movement_finished.bind(current_entity.target_position))
		else:
			current_entity.is_moving = false
			current_entity.end_movement.emit()
