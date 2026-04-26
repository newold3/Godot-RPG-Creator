class_name CharacterBaseMovement
extends RefCounted

var current_entity


## Calculates the grid movement duration based on speed
func calculate_grid_move_duration() -> void:
	var sp = 0.0000000000001 + (current_entity.movement_speed if !current_entity.is_running else current_entity.running_speed)
	current_entity.grid_move_duration = Vector2(
		current_entity.current_map_tile_size.x / sp,
		current_entity.current_map_tile_size.y / sp
	)


## Calculates the final motion vector and handles collision prediction
func get_motion(target_position: Vector2) -> Dictionary:
	var map = GameManager.current_map
	var motion = Vector2.ZERO
	var result = {"final_motion": motion, "current_motion": motion}
	var disable_motion: bool = false
	
	var possible_movements = get_possible_movements(target_position)
	
	if !possible_movements:
		disable_motion = true

	result.current_motion = target_position * Vector2(current_entity.current_map_tile_size)

	target_position.x = floor(target_position.x) if target_position.x < 0 else ceil(target_position.x)
	target_position.y = floor(target_position.y) if target_position.y < 0 else ceil(target_position.y)
	target_position *= Vector2(possible_movements)

	motion = target_position * Vector2(current_entity.current_map_tile_size)

	var backup_motion = motion

	var collision: KinematicCollision2D = current_entity.move_and_collide(motion, true)

	if collision:
		motion = Vector2i.ZERO

	if !motion and backup_motion and !current_entity.collision_disabled:
		if map:
			var event_count = map.get_events_in_place(current_entity.get_current_tile())
			
			if event_count > 1:
				motion = backup_motion
				current_entity.collision_disabled = true
				current_entity.call_deferred("_disable_collision_shape", true)

	if current_entity.collision_disabled:
		var event_count = map.get_events_in_place(current_entity.get_current_tile())
		
		if event_count <= 1:
			current_entity.collision_disabled = false
			current_entity.call_deferred("_disable_collision_shape", false)
		elif randi() % 10 > 2:
			motion = Vector2.ZERO
			
	if map and motion:
		var current_tile = current_entity.get_current_tile()
		
		if (
			not map.is_tile_block(current_tile) and
			not map.can_move_to_direction(current_tile, current_entity.current_direction) and
			not ((Input.is_key_pressed(KEY_CTRL) and OS.is_debug_build() and current_entity.movement_current_mode != current_entity.MOVEMENTMODE.EVENT) or current_entity.character_options.passable)
		):
			motion = Vector2.ZERO

	result.final_motion = motion if not disable_motion else Vector2.ZERO

	return result


## Evaluates passability for given motion vector
func get_possible_movements(motion: Vector2, is_jump_action: bool = false) -> Vector2i:
	var result: Vector2i = Vector2i.ZERO

	motion.x = floor(motion.x) if motion.x < 0 else ceil(motion.x)
	motion.y = floor(motion.y) if motion.y < 0 else ceil(motion.y)

	if !motion or !current_entity.can_move:
		return Vector2i.ZERO

	if (Input.is_key_pressed(KEY_CTRL) and OS.is_debug_build() and current_entity.movement_current_mode != current_entity.MOVEMENTMODE.EVENT) or current_entity.character_options.passable:
		return Vector2i(
			1 if motion.x != 0 else 0,
			1 if motion.y != 0 else 0
		)

	var map = GameManager.current_map
	
	if not map:
		return result

	var current_tile = current_entity.get_current_tile()

	var dx = int(motion.x)
	var dy = int(motion.y)

	var horizontal_tile = map.get_wrapped_tile(current_tile + Vector2i(dx, 0))
	var vertical_tile = map.get_wrapped_tile(current_tile + Vector2i(0, dy))
	var diagonal_tile = map.get_wrapped_tile(current_tile + Vector2i(dx, dy))

	var can_move_horizontally = dx != 0 and get_tile_passability(horizontal_tile, motion) != Vector2i.ZERO
	var can_move_vertically = dy != 0 and get_tile_passability(vertical_tile, motion) != Vector2i.ZERO
	var can_move_diagonally = dx != 0 and dy != 0 and get_tile_passability(diagonal_tile, motion) != Vector2i.ZERO

	if is_jump_action:
		var is_target_passable = true
		var target_tile_for_check = Vector2i.ZERO

		if dx != 0 and dy != 0:
			if not can_move_diagonally: is_target_passable = false
			target_tile_for_check = diagonal_tile
		elif dx != 0:
			if not can_move_horizontally: is_target_passable = false
			target_tile_for_check = horizontal_tile
		elif dy != 0:
			if not can_move_vertically: is_target_passable = false
			target_tile_for_check = vertical_tile

		if not is_target_passable:
			return Vector2i.ZERO

		var events_at_target = map.get_in_game_events_in(target_tile_for_check)
		
		if not current_entity.is_in_group("player") and GameManager.current_player and GameManager.current_player.get_current_tile() == target_tile_for_check:
			events_at_target.append(GameManager.current_player)

		for entity in events_at_target:
			if entity == current_entity: continue

			var is_solid_entity = false
			
			if entity.is_in_group("player") or entity is RPGVehicle:
				is_solid_entity = !entity.is_passable() if entity.has_method("is_passable") else true
			elif "character_options" in entity and entity.character_options:
				is_solid_entity = not entity.character_options.passable

			if is_solid_entity:
				return Vector2i.ZERO

		return Vector2i(1 if dx != 0 else 0, 1 if dy != 0 else 0)

	if can_move_horizontally and can_move_vertically and can_move_diagonally:
		result = Vector2i(1, 1)
	elif can_move_horizontally:
		result.x = 1
	elif can_move_vertically:
		result.y = 1

	if result.x != 0 and not map.is_tile_passable_from_direction(current_entity.get_current_tile(), current_entity.current_direction, true):
		result.x = 0

	if result.y != 0 and not map.is_tile_passable_from_direction(current_entity.get_current_tile(), current_entity.current_direction, true):
		result.y = 0

	if current_entity.movement_current_mode == current_entity.MOVEMENTMODE.FREE:
		if result == Vector2i.ZERO:
			result = _try_move_with_free_mode(current_tile, motion)
		elif result.x + result.y == 1:
			if result.x == 1:
				result.y = _try_move_with_free_mode(current_tile, Vector2(0, motion.y)).y
			else:
				result.x = _try_move_with_free_mode(current_tile, Vector2(motion.x, 0)).x

	return result


## Checks if a specific tile allows movement
func get_tile_passability(target_tile: Vector2i, motion: Vector2) -> Vector2i:
	var result: Vector2i = Vector2i.ZERO
	var map = GameManager.current_map
	
	if map:
		if map.is_passable(target_tile, current_entity.current_direction):
			if map.can_move_over_terrain(target_tile, current_entity.can_move_on_terrains):
				result.x = 1 if motion.x != 0 else 0
				result.y = 1 if motion.y != 0 else 0

	return result


## Calculates slide adjustments for free movement mode
func _try_move_with_free_mode(current_tile: Vector2i, motion: Vector2) -> Vector2i:
	var result: Vector2i = Vector2i.ZERO
	var map = GameManager.current_map

	if map:
		var current_position = current_entity.global_position
		var snapped = map.get_tile_position(current_tile)
		
		if (motion.x < 0 and current_position.x > snapped.x + 2) or (motion.x > 0 and current_position.x < snapped.x - 2):
			result.x = 1
			
		if (motion.y < 0 and current_position.y > snapped.y + 2) or (motion.y > 0 and current_position.y < snapped.y - 4):
			result.y = 1

	return result


## Sets vertical direction priority
func set_vertical_look(motion: Vector2) -> void:
	if motion.y < 0:
		current_entity.last_direction = current_entity.DIRECTIONS.UP
	elif motion.y > 0:
		current_entity.last_direction = current_entity.DIRECTIONS.DOWN
	elif motion.x < 0:
		current_entity.last_direction = current_entity.DIRECTIONS.LEFT
	elif motion.x > 0:
		current_entity.last_direction = current_entity.DIRECTIONS.RIGHT


## Sets horizontal direction priority
func set_horizontal_look(motion: Vector2) -> void:
	if motion.x < 0:
		current_entity.last_direction = current_entity.DIRECTIONS.LEFT
	elif motion.x > 0:
		current_entity.last_direction = current_entity.DIRECTIONS.RIGHT
	elif motion.y < 0:
		current_entity.last_direction = current_entity.DIRECTIONS.UP
	elif motion.y > 0:
		current_entity.last_direction = current_entity.DIRECTIONS.DOWN


## Sets current direction based on diagonal keys
func set_current_look(motion: Vector2) -> void:
	var dir_pressed_count = 0
	
	if motion.x < 0: dir_pressed_count += 1
	if motion.x > 0: dir_pressed_count += 1
	if motion.y < 0: dir_pressed_count += 1
	if motion.y > 0: dir_pressed_count += 1
	
	if dir_pressed_count == 1:
		set_vertical_look(motion)


## Processes standard grid-based continuous movement
func grid_movement() -> void:
	if current_entity.is_moving or Vector2(current_entity.movement_vector) == Vector2.ZERO or current_entity.busy or current_entity.is_jumping or GameInterpreter.is_busy() or GameManager.loading_game:
		return

	var motion_data = get_motion(current_entity.movement_vector)
	var motion = motion_data.final_motion

	if !motion:
		var push_target = current_entity._get_pushable_event_in_direction(current_entity.movement_vector)
		
		if push_target:
			current_entity.try_push_event(push_target, current_entity.movement_vector)
			return

		if current_entity._auto_target_tile == Vector2i(-1, -1) and Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down") == Vector2.ZERO:
			current_entity.movement_vector = Vector2.ZERO
			current_entity.current_animation = "idle"
			current_entity.run_animation()

		_animate_contact_area.call_deferred(motion_data.current_motion)
		current_entity.end_movement.emit()
		
		return

	start_movement(motion_data)

	if current_entity.movement_tween:
		if current_entity.movement_tween.finished.is_connected(_on_grid_movement_finished):
			current_entity.movement_tween.finished.disconnect(_on_grid_movement_finished)
		current_entity.movement_tween.finished.connect(_on_grid_movement_finished.bind(current_entity.target_position))


## Processes pixel-based free movement
func free_movement(delta: float) -> void:
	if !current_entity.movement_vector or current_entity.busy or current_entity.is_jumping or GameManager.loading_game:
		return

	if abs(current_entity.movement_vector.y) > 1 or abs(current_entity.movement_vector.x) > 1:
		current_entity._reset(true)
		return

	var current_movement_vector = current_entity.movement_vector
	var possible_movements = get_possible_movements(current_entity.movement_vector)

	if possible_movements:
		current_entity.movement_vector *= Vector2(possible_movements)
		
		if current_entity.movement_vector.length_squared() > 0:
			current_entity.movement_vector = current_entity.movement_vector.normalized()
			
		current_entity.movement_vector = current_entity.movement_vector * (current_entity.movement_speed if !current_entity.is_running else current_entity.running_speed)
		current_entity.velocity = current_entity.movement_vector
		current_entity.move_and_slide()
		current_entity.start_motion.emit(current_entity.velocity * delta)
		current_entity.velocity = Vector2.ZERO
	else:
		current_entity.velocity = Vector2.ZERO
		var push_target = current_entity._get_pushable_event_in_direction(current_movement_vector)
		
		if push_target:
			current_entity.try_push_event(push_target, current_movement_vector)
			return

		if current_entity._auto_target_tile != Vector2i(-1, -1) and not ControllerManager.is_action_pressed("Mouse Left"):
			current_entity._auto_target_tile = Vector2i(-1, -1)
			current_entity.movement_vector = Vector2.ZERO
			current_entity.current_animation = "idle"
			current_entity.run_animation()
		elif current_entity._auto_target_tile == Vector2i(-1, -1) and Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down") == Vector2.ZERO:
			current_entity.movement_vector = Vector2.ZERO
			current_entity.current_animation = "idle"
			current_entity.run_animation()

	if GameManager.current_map:
		current_entity.update_virtual_tile(current_entity.velocity * delta)
		var tile_size: Vector2 = GameManager.get_map_tile_size()
		current_entity.cumulative_steps += (current_movement_vector * delta).length()
		var steps_to_add = int(current_entity.cumulative_steps / tile_size.x)
		
		if steps_to_add > 0:
			GameManager.game_state.stats.steps += steps_to_add
			current_entity.cumulative_steps = int(current_entity.cumulative_steps) % int(tile_size.x)

	current_entity.end_movement.emit()


## Initiates the physics and visual movement tweening
func start_movement(motion_data: Dictionary) -> void:
	if current_entity.movement_tween:
		current_entity.movement_tween.kill()

	current_entity.movement_tween = current_entity.create_tween()
	current_entity.movement_tween.tween_interval(0.001)

	current_entity.is_moving = true
	var final_motion = motion_data.final_motion
	var current_motion = motion_data.current_motion
	
	if not final_motion:
		current_entity.is_moving = false
		return

	current_entity.target_position = current_entity.position + final_motion
	var start_position = current_entity.position
	var max_movement_time = max(current_entity.grid_move_duration.x, current_entity.grid_move_duration.y)
	var distance = final_motion.length()
	var base_distance = current_entity.current_map_tile_size.x
	var time = max_movement_time * (distance / base_distance)

	current_entity.movement_tween.tween_method(_update_position.bind([current_entity.position]), current_entity.position, current_entity.target_position, time)
	current_entity.movement_tween.tween_callback(func(): current_entity.end_movement.emit())

	_animate_contact_area.call_deferred(motion_data.current_motion)


## Applies internal position update step for tweens
func _update_position(new_position: Vector2, old_position_cache: Array) -> void:
	if current_entity.is_invalid_event: return
	
	current_entity.position = new_position
	current_entity.update_virtual_tile(new_position - old_position_cache[0])
	old_position_cache[0] = current_entity.position


## Animates the contact area dimensions during movement
func _animate_contact_area(final_motion: Vector2) -> void:
	if (current_entity.contact_area_tween and current_entity.contact_area_tween.is_running()):
		return

	var node = current_entity.get_node_or_null("%ContactArea")
	
	if GameManager.current_map and node and node.get_child_count() == 1:
		var collision_shape = node.get_child(0)
		
		if collision_shape is CollisionShape2D and collision_shape.shape is RectangleShape2D:
			var max_movement_time = max(current_entity.grid_move_duration.x, current_entity.grid_move_duration.y)
			var distance = final_motion.length()
			var base_distance = current_entity.current_map_tile_size.x
			var time = max_movement_time * (distance / base_distance)
			
			if not collision_shape.has_meta("_original_position_and_size"):
				collision_shape.set_meta("_original_position_and_size",
					{"position": collision_shape.position, "size": collision_shape.shape.size}
				)
				
			var tile_size: Vector2 = GameManager.get_map_tile_size()

			current_entity.contact_area_tween = current_entity.create_tween()
			current_entity.contact_area_tween.set_parallel(true)
			
			current_entity.contact_area_tween.tween_method(
				_set_contact_area_size.bind(collision_shape, final_motion),
				tile_size.x * 0.8125,
				tile_size.x * 1.3,
				time * 0.1
			).set_delay(time * 0.1)
			
			current_entity.contact_area_tween.tween_method(
				_set_contact_area_size.bind(collision_shape, final_motion),
				tile_size.x * 1.3,
				tile_size.x * 0.8125,
				time * 0.1
			).set_delay(time * 0.3)


## Modifies the internal physical area dimension specifically
func _set_contact_area_size(width: float, collision_shape: CollisionShape2D, motion: Vector2) -> void:
	var original_data = collision_shape.get_meta("_original_position_and_size")
	var original_size = original_data.size
	var original_position = original_data.position

	var new_size = original_size
	var new_position = original_position

	if motion.x != 0:
		var diff = abs(original_size.x - width) / 2.0
		if motion.x > 0:
			diff *= -1
		new_size.x = width
		new_position.x = original_position.x - diff

	elif motion.y != 0:
		var diff = abs(original_size.y - width) / 2.0
		new_size.y = width
		if motion.y > 0:
			diff *= -1
		new_position.y = original_position.y - diff

	collision_shape.position = new_position
	collision_shape.shape.size = new_size


## Resolves final alignment and camera tracking on grid movement completion
func _on_grid_movement_finished(target_position: Vector2) -> void:
	var wrapped_position = GameManager.current_map.get_wrapped_position(target_position)
	
	if wrapped_position != target_position:
		var offset = wrapped_position - target_position
		var camera = GameManager.get_camera()
		
		if camera:
			if camera.targets.size() > 1:
				camera.instantaneous_positioning()
			else:
				camera.global_position += offset
				
		current_entity.position = wrapped_position
		current_entity.shift_history_and_followers(offset)
	else:
		current_entity.position = target_position

	GameManager.game_state.stats.steps += 1
	current_entity.is_moving = false
	current_entity.movement_vector = Vector2.ZERO
	current_entity.end_movement.emit()


## Initiates directed movement to specific vectors bypassing input
func move_event(new_pos: Vector2, route: RPGMovementRoute = null, keep_direction: bool = false) -> void:
	if current_entity.is_moving or current_entity.busy or current_entity.is_jumping: return
	
	var has_route = current_entity.route_commands and not current_entity.route_commands.list.is_empty()
	
	if has_route and not current_entity.route_commands.is_route_from_interpreter and GameInterpreter.is_busy():
		return
		
	var motion_data = get_motion(new_pos)
	var motion = motion_data.final_motion
	
	if motion:
		if not current_entity.character_options.fixed_direction and not keep_direction:
			var diagonal_movement_direction_mode = RPGSYSTEM.database.system.options.get("movement_mode", 0)
			match diagonal_movement_direction_mode:
				0: set_vertical_look(motion)
				1: set_horizontal_look(motion)
				2: set_current_look(motion)
			current_entity.current_direction = current_entity.last_direction
			
		current_entity.current_animation = "walk"
		current_entity.run_animation()
	else:
		if route and !route.skippable:
			current_entity.route_command_index -= 1
			
		current_entity.call_deferred("_animation_to_idle")
		_animate_contact_area.call_deferred(motion_data.current_motion)
		return
		
	current_entity.event_start_movement.emit()
	start_movement(motion_data)
	
	if current_entity.movement_tween and current_entity.movement_tween.is_valid():
		current_entity.movement_tween.tween_callback(
			func():
				current_entity.is_moving = false
				current_entity.call_deferred("_animation_to_idle")
		)
		await current_entity.movement_tween.finished
		
		var wrapped_position = GameManager.current_map.get_wrapped_position(current_entity.position)
		
		if wrapped_position != current_entity.position:
			var offset = wrapped_position - current_entity.position
			current_entity.position = wrapped_position
			current_entity.shift_history_and_followers(offset)


## Handles logic wrapper for vehicle driven displacements
func vehicle_movement(motion: Vector2, route: RPGMovementRoute = null, keep_direction: bool = false) -> void:
	current_entity.is_moving = true
	var vehicle_position = current_entity.current_vehicle.global_position
	
	await current_entity.current_vehicle.force_movement(motion, keep_direction)
	
	var new_vehicle_position = current_entity.current_vehicle.global_position
	
	if vehicle_position == new_vehicle_position and !route.skippable:
		current_entity.route_command_index -= 1
		
	current_entity.is_moving = false
	current_entity.end_movement.emit()


## Processes jump mechanics along with shadow positioning and follower snapshot
func jump_to(new_pos: Vector2, route: RPGMovementRoute = null, start_fx: Dictionary = {}, end_fx: Dictionary = {}) -> void:
	if current_entity.is_moving or current_entity.busy or current_entity.is_jumping:
		return

	var possible_movement = get_possible_movements(new_pos, true)
	var motion = null if !possible_movement else new_pos * Vector2(current_entity.current_map_tile_size)

	if motion:
		current_entity.update_virtual_tile(motion)

		if not current_entity.character_options.fixed_direction:
			match RPGSYSTEM.database.system.options.get("movement_mode", 0):
				0: set_vertical_look(motion)
				1: set_horizontal_look(motion)
				2: set_current_look(motion)
			current_entity.current_direction = current_entity.last_direction

		var start_pos = current_entity.position
		var end_pos = current_entity.position + motion
		var distance = motion.length()
		var jump_height = min(current_entity.MAX_JUMP_HEIGHT, distance * 0.5)
		var jump_duration = clamp(distance * 0.1, 0.25, 0.45) 

		if current_entity.has_method("get_shadow_data"):
			var shadow_data = current_entity.call("get_shadow_data")
			if shadow_data is Dictionary and "sprite_shadow" in shadow_data and shadow_data.sprite_shadow is Node:
				var is_horizontal_jump = (motion.y == 0)
				var s = shadow_data.sprite_shadow
				s.set_meta("is_jumping", true)
				s.set_meta("jumping_shadow_global_position", current_entity.global_position)
				s.set_meta("jumping_shadow_parent", current_entity)
				s.set_meta("jumping_horizontal_mode", is_horizontal_jump)
				s.set_meta("jumping_start_position", start_pos)
				s.set_meta("jumping_target_position", end_pos)

		current_entity.is_jumping = true
		current_entity.force_animation_enabled = true
		current_entity.current_animation = "start_jump"
		current_entity.current_frame = 0
		
		var followers = current_entity.get_tree().get_nodes_in_group("follower")
		var map = {}
		
		for f in followers:
			map[f.follower_id] = f.global_position
			
		var visual_rect = Rect2()
		var body_node = current_entity.get_node_or_null("%Body")
		
		if body_node:
			visual_rect = body_node.region_rect
			
		current_entity._add_snapshot({
			"event": "start_jump",
			"jump_start_pos": start_pos,
			"jump_target": end_pos,
			"jump_height": jump_height,
			"jump_duration": jump_duration,
			"followers_position": map,
			"pos": current_entity.global_position,
			"scale": current_entity.scale,
			"modulate": current_entity.modulate,
			"z_index": current_entity.z_index,
			"region_rect": visual_rect,
			"flip_h": body_node.flip_h if body_node else false,
			"direction": current_entity.current_direction,
			"rotation": current_entity.rotation,
			"animation": current_entity.current_animation,
			"is_jumping": current_entity.is_jumping
		})

		if current_entity.movement_tween:
			current_entity.movement_tween.kill()

		current_entity.movement_tween = current_entity.create_tween()
		current_entity.movement_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)

		if start_fx:
			current_entity.movement_tween.tween_callback(GameManager.play_se.bind(
				start_fx.get("path", ""), start_fx.get("volume", 0.0), start_fx.get("pitch", 1.0)
			))

		current_entity.movement_tween.tween_property(current_entity, "scale", Vector2(0.94, 0.55), 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		current_entity.movement_tween.tween_callback(current_entity._smart_record_history) 
		current_entity.movement_tween.tween_interval(0.02)

		current_entity.movement_tween.tween_callback(
			func():
				var dust = current_entity.JUMP_PARTICLES.instantiate()
				dust.position = current_entity.position
				current_entity.get_parent().add_child(dust)
		)

		current_entity.movement_tween.tween_interval(0.001)
		current_entity.movement_tween.set_parallel(true)

		current_entity.movement_tween.tween_property(current_entity, "scale", Vector2(1.02, 1.04), 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

		current_entity.movement_tween.tween_method(
			func(t): 
				current_entity.position = start_pos.lerp(end_pos, t) - Vector2(0, sin(t * PI) * jump_height)
		, 0.0, 1.0, jump_duration
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

		if end_fx:
			current_entity.movement_tween.tween_callback(GameManager.play_se.bind(
				end_fx.get("path", ""), end_fx.get("volume", 0.0), end_fx.get("pitch", 1.0)
			)).set_delay(jump_duration - 0.05)

		current_entity.movement_tween.tween_callback(current_entity.set.bind("current_frame", 0)).set_delay(jump_duration * 0.65)
		current_entity.movement_tween.tween_callback(
			func():
				current_entity.current_animation = "end_jump"
				current_entity.run_animation()
		).set_delay(jump_duration * 0.65)

		current_entity.movement_tween.set_parallel(false)
		current_entity.movement_tween.tween_interval(0.01)

		current_entity.movement_tween.tween_callback(
			func():
				var dust = current_entity.JUMP_PARTICLES.instantiate()
				dust.position = current_entity.position
				current_entity.get_parent().add_child(dust)
		)

		current_entity.movement_tween.tween_property(current_entity, "scale", Vector2(1.1, 0.90), 0.1).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CIRC)
		current_entity.movement_tween.tween_callback(current_entity._smart_record_history)
		current_entity.movement_tween.tween_property(current_entity, "scale", Vector2(1.0, 1.0), 0.15).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)

		current_entity.movement_tween.tween_callback(
			func():
				current_entity.is_jumping = false
				current_entity.force_animation_enabled = false
				current_entity._add_snapshot({"event": "end_jump"})

				if current_entity.has_method("get_shadow_data"):
					var shadow_data = current_entity.call("get_shadow_data")
					if shadow_data is Dictionary and "sprite_shadow" in shadow_data and shadow_data.sprite_shadow is Node:
						shadow_data.sprite_shadow.set_meta("is_jumping", false)

				current_entity.scale = Vector2.ONE 
		)

		await current_entity.movement_tween.finished


## Triggers the vehicle logic to execute jump trajectory
func vehicle_jump_to(new_pos: Vector2, route: RPGMovementRoute = null, start_fx: Dictionary = {}, end_fx: Dictionary = {}) -> void:
	if current_entity.is_moving or current_entity.busy or current_entity.is_jumping:
		return

	current_entity.is_jumping = true

	await current_entity.current_vehicle.jump_to(new_pos, route, start_fx, end_fx)

	current_entity.is_jumping = false


## Determines whether a physical movement logic is actively running
func is_processin_moving() -> bool:
	return current_entity.is_moving or (current_entity.movement_tween and current_entity.movement_tween.is_valid() and current_entity.movement_tween.is_running())


## Instantly halts the ongoing movement interpolations
func kill_movement() -> void:
	if current_entity.movement_tween and current_entity.movement_tween.is_valid():
		current_entity.movement_tween.kill()
