class_name CharacterBaseNavigation
extends RefCounted

var current_entity


## Retrieves the opposite direction of the given direction
func get_opposite_direction(direction: int) -> int:
	match direction:
		RPGMapPassability.DIR_LEFT:
			return RPGMapPassability.DIR_RIGHT
		RPGMapPassability.DIR_RIGHT:
			return RPGMapPassability.DIR_LEFT
		RPGMapPassability.DIR_UP:
			return RPGMapPassability.DIR_DOWN
		RPGMapPassability.DIR_DOWN:
			return RPGMapPassability.DIR_UP
	return 0


## Sets the current and last direction manually
func set_direction(direction: int) -> void:
	current_entity.last_direction = direction
	current_entity.current_direction = direction


## Handles autonomous event movement logic depending on the movement type
func event_movement() -> void:
	if current_entity.is_jumping or GameManager.loading_game: 
		return
	
	var has_route = current_entity.route_commands and not current_entity.route_commands.list.is_empty()
	current_entity.previous_tile = current_entity.get_current_tile()
	
	if current_entity.is_moving or current_entity.busy or GameInterpreter.busy:
		if has_route and current_entity.route_commands.is_route_from_interpreter:
			update_process_route()
		return
	
	var type = 4 if has_route else current_entity.event_movement_type
	var movement_result: Vector2i
	
	match type:
		0:
			pass
		1:
			movement_result =  Vector2i(randi_range(0, 2) - 1, randi_range(0, 2) - 1)
		2:
			movement_result = _get_next_move_toward_player()
		3:
			movement_result = _get_next_move_away_from_player()
		4:
			update_process_route()
		5:
			movement_result = _get_next_move_toward_event()
			if movement_result:
				var motion_data = current_entity.get_motion(movement_result)
	
	if movement_result:
		await current_entity.move_event(movement_result, null)
		current_entity.end_movement.emit()
		
	if type == 2:
		if not current_entity.character_options.fixed_direction:
			var player = GameManager.current_player if not GameManager.current_player.is_on_vehicle else GameManager.current_player.current_vehicle
			var player_tile = player.get_current_tile()
			var self_tile = current_entity.get_current_tile()
			var delta_tile = player_tile - self_tile
			var map_size = GameManager.current_map.get_map_size_in_tiles()
			
			if abs(delta_tile.x) > map_size.x / 2:
				delta_tile.x -= sign(delta_tile.x) * map_size.x
			if abs(delta_tile.y) > map_size.y / 2:
				delta_tile.y -= sign(delta_tile.y) * map_size.y
				
			var motion = delta_tile
			var diagonal_movement_direction_mode = RPGSYSTEM.database.system.options.get("movement_mode", 0)
			
			match diagonal_movement_direction_mode:
				0: current_entity.set_vertical_look(motion)
				1: current_entity.set_horizontal_look(motion)
				2: current_entity.set_current_look(motion)
				
			current_entity.current_direction = current_entity.last_direction
	
	current_entity.update_virtual_tile()


## Processes the current movement route command queue
func update_process_route() -> void:
	if current_entity.is_moving or current_entity.busy or current_entity.is_jumping or current_entity._processing_command_route:
		return
		
	current_entity._processing_command_route = true
	var result = await process_route_command()
	
	if result.action:
		match result.action:
			"move":
				var backup_direction = current_entity.current_direction
				
				if current_entity.is_on_vehicle and current_entity.current_vehicle:
					await current_entity.vehicle_movement(result.value, result.route, result.keep_direction)
				else:
					await current_entity.move_event(result.value, result.route, result.keep_direction)
					
				if result.keep_direction:
					current_entity.current_direction = backup_direction
					current_entity.run_animation()
					
				GameManager.game_state.stats.steps += 1
			"jump":
				if current_entity.is_on_vehicle and current_entity.current_vehicle:
					await current_entity.vehicle_jump_to(result.value, result.route, result.start_fx, result.end_fx)
				else:
					await current_entity.jump_to(result.value, result.route, result.start_fx, result.end_fx)
					
				var steps = max(abs(result.value.x), abs(result.value.y))
				GameManager.game_state.stats.steps += steps
				
	current_entity.route_command_index += 1
	
	if current_entity.route_commands:
		if current_entity.route_command_index >= current_entity.route_commands.list.size():
			if current_entity.route_commands.repeat:
				current_entity.route_command_index = 0
			else:
				var wrapped_position = GameManager.current_map.get_wrapped_position(current_entity.position)
				
				if wrapped_position != current_entity.position:
					var offset = wrapped_position - current_entity.position
					
					if current_entity.is_in_group("player"):
						var camera = GameManager.get_camera()
						if camera:
							camera.global_position += offset
							
					current_entity.position = wrapped_position
					current_entity.shift_history_and_followers(offset)
					
				current_entity.route_commands.finished.emit()
				current_entity.route_commands = null
				
				if current_entity.is_on_vehicle and current_entity.current_vehicle:
					current_entity.current_vehicle.reset_force_movement()
		elif current_entity.is_on_vehicle and current_entity.current_vehicle:
			if not _is_movement_route_command(current_entity.route_commands.list[current_entity.route_command_index]):
				current_entity.current_vehicle.reset_force_movement()
	elif current_entity.is_on_vehicle and current_entity.current_vehicle:
		current_entity.current_vehicle.reset_force_movement()
		
	current_entity._processing_command_route = false


## Calculates the next tile step required to reach a specific target tile
func _get_next_move_toward_target(target: Vector2i, target_screen_position: Vector2) -> Vector2i:
	var map = GameManager.current_map
	
	if map:
		var current = current_entity.get_current_tile()
		
		if Input.is_key_pressed(KEY_CTRL) and OS.is_debug_build():
			var diff = target - current
			var step_x = sign(diff.x)
			var step_y = sign(diff.y)
			return Vector2i(step_x, step_y)
			
		var next = map.pathfinder.get_next_tile(current_entity, current, target)
		
		if next != null:
			var diff = next - current
			var map_size = map.get_map_size_in_tiles()
			
			if map.infinite_horizontal_scroll:
				var half_width = map_size.x / 2
				if diff.x > half_width:
					diff.x -= map_size.x
				elif diff.x < -half_width:
					diff.x += map_size.x
					
			if map.infinite_vertical_scroll:
				var half_height = map_size.y / 2
				if diff.y > half_height:
					diff.y -= map_size.y
				elif diff.y < -half_height:
					diff.y += map_size.y
					
			return diff
			
	return Vector2i.ZERO


## Wraps the logic to retrieve the next step specifically targeting the player
func _get_next_move_toward_player() -> Vector2i:
	var goal = GameManager.current_player.get_current_tile() if not GameManager.current_player.is_on_vehicle else GameManager.current_player.current_vehicle.get_current_tile()
	var target_screen_position: Vector2 = GameManager.current_player.get_global_transform_with_canvas().origin
	
	return _get_next_move_toward_target(goal, target_screen_position)


## Wraps the logic to retrieve the next step toward another tracked event
func _get_next_move_toward_event() -> Vector2i:
	var goal = Vector2i.ZERO
	var target_screen_position: Vector2 = Vector2.ZERO
	var page = current_entity.get("current_event_page")
	
	if page and GameManager.current_map:
		var event = GameManager.current_map.get_in_game_event_by_uniq_id(page.movement_to_target)
		
		if event and event.has_method("get_current_tile"):
			goal = event.get_current_tile()
			target_screen_position = event.get_global_transform_with_canvas().origin
	else:
		return goal
	
	return _get_next_move_toward_target(goal, target_screen_position)


## Calculates the best possible immediate step to maximize distance from the player
func _get_next_move_away_from_player() -> Vector2i:
	var directions = [
		Vector2i(0, -1), Vector2i(1, 0),
		Vector2i(0, 1), Vector2i(-1, 0),
		Vector2i(1, -1), Vector2i(1, 1),
		Vector2i(-1, -1), Vector2i(-1, 1),
	]
	var my_tile: Vector2i = current_entity.get_current_tile()
	var player_tile = GameManager.current_player.get_current_tile() if not GameManager.current_player.is_on_vehicle else GameManager.current_player.current_vehicle.get_current_tile()
	var map = GameManager.current_map
	var map_size = map.get_map_size_in_tiles()
	var infinite_x = map.infinite_horizontal_scroll
	var infinite_y = map.infinite_vertical_scroll
	var current_dist_sq = _get_wrapped_distance_sq(my_tile, player_tile, map_size, infinite_x, infinite_y)
	
	if current_dist_sq >= current_entity.MAX_FLEE_DISTANCE_SQUARED:
		return Vector2i(0, 0)

	var best_move = Vector2i.ZERO
	var max_distance = current_dist_sq

	for dir in directions:
		var raw_neighbor = my_tile + dir
		var wrapped_neighbor = raw_neighbor
		
		if infinite_x:
			wrapped_neighbor.x = posmod(wrapped_neighbor.x, map_size.x)
		if infinite_y:
			wrapped_neighbor.y = posmod(wrapped_neighbor.y, map_size.y)
			
		if map.is_passable(wrapped_neighbor, map.pathfinder.vector2_to_direction(dir), current_entity):
			var dist = _get_wrapped_distance_sq(wrapped_neighbor, player_tile, map_size, infinite_x, infinite_y)
			
			if dist > max_distance:
				max_distance = dist
				best_move = dir
	
	var motion = best_move
	
	if motion:
		if motion.x == 0:
			current_entity.current_direction = current_entity.DIRECTIONS.UP if motion.y < 0 else current_entity.DIRECTIONS.DOWN
		elif motion.y == 0:
			current_entity.current_direction = current_entity.DIRECTIONS.LEFT if motion.x < 0 else current_entity.DIRECTIONS.RIGHT
			
		current_entity.last_direction = current_entity.current_direction

	return motion


## Helper distance calculation accounting for map wrapping mechanics
func _get_wrapped_distance_sq(from_pos: Vector2i, to_pos: Vector2i, size: Vector2i, inf_x: bool, inf_y: bool) -> float:
	var dx = abs(from_pos.x - to_pos.x)
	var dy = abs(from_pos.y - to_pos.y)
	
	if inf_x:
		dx = min(dx, size.x - dx)
	if inf_y:
		dy = min(dy, size.y - dy)
		
	return float(dx * dx + dy * dy)


## Checks if a specific command ID is a movement type command
func _is_movement_route_command(command: RPGMovementCommand) -> bool:
	return command.code in [1,4,7,10,13,16,19,22,25,28,31,34,37,40]


## Converts current direction into its relative left rotated direction
func _rotate_left(direction: int) -> int:
	match direction:
		current_entity.DIRECTIONS.UP: return current_entity.DIRECTIONS.LEFT
		current_entity.DIRECTIONS.LEFT: return current_entity.DIRECTIONS.DOWN
		current_entity.DIRECTIONS.DOWN: return current_entity.DIRECTIONS.RIGHT
		current_entity.DIRECTIONS.RIGHT: return current_entity.DIRECTIONS.UP
	return direction


## Converts current direction into its relative right rotated direction
func _rotate_right(direction: int) -> int:
	match direction:
		current_entity.DIRECTIONS.UP: return current_entity.DIRECTIONS.RIGHT
		current_entity.DIRECTIONS.RIGHT: return current_entity.DIRECTIONS.DOWN
		current_entity.DIRECTIONS.DOWN: return current_entity.DIRECTIONS.LEFT
		current_entity.DIRECTIONS.LEFT: return current_entity.DIRECTIONS.UP
	return direction


## Extracts and executes the next command from the route list queue
func process_route_command() -> Dictionary:
	var result: Dictionary = {"action": null, "value": Vector2i(), "target": current_entity, "keep_direction": false}
	var command: RPGMovementCommand
	var backup_direction = current_entity.current_direction
	
	if current_entity.route_commands:
		result.route = current_entity.route_commands
		if current_entity.route_command_index < current_entity.route_commands.list.size():
			command = current_entity.route_commands.list[current_entity.route_command_index]
		else:
			return result
	else:
		return result
	
	if current_entity.is_in_group("player") and current_entity.is_on_vehicle and current_entity.current_vehicle:
		result.target = current_entity.current_vehicle

	if command:
		var params: Array = command.parameters
		match command.code:
			1: 
				result.action = "move"
				result.value = Vector2i(0, 1)
			4: 
				result.action = "move"
				result.value = Vector2i(-1, 0)
			7: 
				result.action = "move"
				result.value = Vector2i(1, 0)
			10: 
				result.action = "move"
				result.value = Vector2i(0, -1)
			13: 
				result.action = "move"
				result.value = Vector2i(-1, 1)
			16: 
				result.action = "move"
				result.value = Vector2i(1, 1)
			19: 
				result.action = "move"
				result.value = Vector2i(-1, -1)
			22: 
				result.action = "move"
				result.value = Vector2i(1, -1)
			25: 
				result.action = "move"
				result.value = Vector2i(randi_range(0, 2) - 1, randi_range(0, 2) - 1)
			28, 31: 
				if not current_entity.is_in_group("player"):
					var player = GameManager.current_player if not GameManager.current_player.is_on_vehicle else GameManager.current_player.current_vehicle
					if player and player != current_entity:
						result.action = "move"
						if command.code == 28:
							result.value = _get_next_move_toward_player()
						else:
							result.value = _get_next_move_away_from_player()
			34: 
				result.action = "move"
				match result.target.current_direction:
					current_entity.DIRECTIONS.LEFT: result.value = Vector2i(-1, 0)
					current_entity.DIRECTIONS.DOWN: result.value = Vector2i(0, 1)
					current_entity.DIRECTIONS.RIGHT: result.value = Vector2i(1, 0)
					current_entity.DIRECTIONS.UP: result.value = Vector2i(0, -1)
				result.keep_direction = true
			37: 
				result.action = "move"
				match result.target.current_direction:
					current_entity.DIRECTIONS.LEFT: result.value = Vector2i(1, 0)
					current_entity.DIRECTIONS.DOWN: result.value = Vector2i(0, -1)
					current_entity.DIRECTIONS.RIGHT: result.value = Vector2i(-1, 0)
					current_entity.DIRECTIONS.UP: result.value = Vector2i(0, 1)
				result.keep_direction = true
			40: 
				var jump_amount: Vector2i = command.parameters[0]
				result.action = "jump"
				result.value = jump_amount
				result.start_fx = command.parameters[1]
				result.end_fx = command.parameters[2]
			43: 
				var wait_time: float = command.parameters[0]
				result.target.busy = true
				current_entity.busy = true
				var timer = current_entity.get_tree().create_timer(wait_time)
				timer.timeout.connect(
					func():
						if is_instance_valid(result.target):
							result.target.busy = false
						current_entity.busy = false
				)
			46: 
				var z: int = command.parameters[0]
				result.target.z_index = z
				current_entity.character_options.z_index = z
			2: 
				if not current_entity.character_options.fixed_direction: result.target.current_direction = current_entity.DIRECTIONS.DOWN
			5: 
				if not current_entity.character_options.fixed_direction: result.target.current_direction = current_entity.DIRECTIONS.LEFT
			8: 
				if not current_entity.character_options.fixed_direction: result.target.current_direction = current_entity.DIRECTIONS.RIGHT
			11: 
				if not current_entity.character_options.fixed_direction: result.target.current_direction = current_entity.DIRECTIONS.UP
			14: 
				if not current_entity.character_options.fixed_direction:
					result.target.current_direction = _rotate_left(result.target.current_direction)
			17: 
				if not current_entity.character_options.fixed_direction:
					result.target.current_direction = _rotate_right(result.target.current_direction)
			20: 
				if not current_entity.character_options.fixed_direction:
					match result.target.current_direction:
						current_entity.DIRECTIONS.LEFT: result.target.current_direction = current_entity.DIRECTIONS.RIGHT
						current_entity.DIRECTIONS.DOWN: result.target.current_direction = current_entity.DIRECTIONS.UP
						current_entity.DIRECTIONS.RIGHT: result.target.current_direction = current_entity.DIRECTIONS.LEFT
						current_entity.DIRECTIONS.UP: result.target.current_direction = current_entity.DIRECTIONS.DOWN
			23: 
				if not current_entity.character_options.fixed_direction:
					var turn_left = randi() % 2 == 0
					if turn_left:
						result.target.current_direction = _rotate_left(result.target.current_direction)
					else:
						result.target.current_direction = _rotate_right(result.target.current_direction)
			26: 
				if not current_entity.character_options.fixed_direction:
					var random_dir = randi() % 4
					match random_dir:
						0: result.target.current_direction = current_entity.DIRECTIONS.LEFT
						1: result.target.current_direction = current_entity.DIRECTIONS.DOWN
						2: result.target.current_direction = current_entity.DIRECTIONS.RIGHT
						3: result.target.current_direction = current_entity.DIRECTIONS.UP
			29, 32: 
				if not current_entity.character_options.fixed_direction and not current_entity.is_in_group("player"):
					var player = GameManager.current_player if not GameManager.current_player.is_on_vehicle else GameManager.current_player.current_vehicle
					if player:
						var direction
						if command.code == 29:
							direction = (player.global_position - current_entity.global_position).normalized()
						else:
							direction = (current_entity.global_position - player.global_position).normalized()
						if abs(direction.x) > abs(direction.y):
							current_entity.current_direction = current_entity.DIRECTIONS.RIGHT if direction.x > 0 else current_entity.DIRECTIONS.LEFT
						else:
							current_entity.current_direction = current_entity.DIRECTIONS.DOWN if direction.y > 0 else current_entity.DIRECTIONS.UP
			35, 38: 
				var game_state = GameManager.game_state
				if game_state:
					var switch_id: int = command.parameters[0]
					if game_state.game_switches.size() > switch_id and switch_id > 0:
						var is_enabled = (command.code == 35) 
						if game_state.game_switches[switch_id] != is_enabled:
							game_state.game_switches[switch_id] = is_enabled
							GameManager.current_map.map_need_refresh = true
			41: 
				var new_speed: int = command.parameters[0]
				if result.target == current_entity:
					current_entity.movement_speed = new_speed
				else:
					result.target.vehicle_speed = new_speed
				current_entity.character_options.movement_speed = new_speed
			44: 
				if result.target == current_entity and not current_entity.is_in_group("player"):
					var new_movement_frequency: float = command.parameters[0]
					current_entity.event_movement_frequency = new_movement_frequency
					current_entity.character_options.movement_frequency = new_movement_frequency
			3: 
				current_entity.character_options.walking_animation = true
			6: 
				current_entity.character_options.walking_animation = false
			9: 
				current_entity.character_options.idle_animation = true
			12: 
				current_entity.character_options.idle_animation = false
			15: 
				current_entity.character_options.fixed_direction = true
			18: 
				current_entity.character_options.fixed_direction = false
			21: 
				current_entity.character_options.passable = true
			24: 
				current_entity.character_options.passable = false
			27: 
				result.target.visible = false
				current_entity.character_options.visible = false
			30: 
				result.target.visible = true
				current_entity.character_options.visible = true
			33: 
				result.target.propagate_call("change_actor_graphics", [command.parameters[0]])
				current_entity.character_options.current_graphics = command.parameters[0]
			36: 
				result.target.modulate.a = command.parameters[0]
				current_entity.character_options.current_opacity = command.parameters[0]
			39: 
				result.target.propagate_call("change_blend_mode", [command.parameters[0]])
				current_entity.character_options.blend_mode = command.parameters[0]
			42: 
				var path = command.parameters[0]
				var volume = command.parameters[1]
				var pitch1 = command.parameters[2]
				var pitch2 = command.parameters[3]
				var pitch = randf_range(pitch1, pitch2)
				GameManager.play_se(path, volume, pitch)
			45: 
				GameInterpreter.code_eval.execute(command.parameters[0])
	
	if backup_direction != result.target.current_direction:
		result.target.last_direction = result.target.current_direction
		if result.target != current_entity:
			current_entity.current_direction = result.target.current_direction
			current_entity.last_direction = result.target.current_direction
			current_entity.run_animation()
	
	current_entity._last_route_movement = result.value
	
	return result
