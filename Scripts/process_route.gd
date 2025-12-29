extends RefCounted

var instance: Node


func update_process_route() -> void:
	if not instance:
		return
		
	if instance.is_moving or instance.busy or instance.is_jumping:
		return
		
	var result = await process_route_command()
	if result.action:
		match result.action:
			"move":
				await instance.move_event(result.value, result.route)
			"jump":
				await instance.jump_to(result.value, result.route, result.start_fx, result.end_fx)
				
	instance.route_command_index += 1
	if instance.route_commands:
		if instance.route_command_index >= instance.route_commands.list.size():
			if instance.route_commands.repeat:
				instance.route_command_index = 0
			else:
				var wrapped_position = GameManager.current_map.get_wrapped_position(instance.position)
				if wrapped_position != instance.position:
					if instance.is_in_group("player"):
						var camera = GameManager.get_camera()
						if camera:
							camera.global_position += (wrapped_position - instance.position)
					instance.position = wrapped_position
				instance.route_commands.finished.emit()
				instance.route_commands = null


func process_route_command() -> Dictionary:
	var result: Dictionary = {"action": null, "value": Vector2i()}
	var command: RPGMovementCommand
	var backup_direction = instance.current_direction
	if instance.route_commands:
		result.route = instance.route_commands
		if instance.route_command_index < instance.route_commands.list.size():
			command = instance.route_commands.list[instance.route_command_index]
		else:
			return result
	else:
		return result

	if command:
		var params: Array = command.parameters
		match command.code:
			# Column 1
			1: # Move Down
				result.action = "move"
				result.value = Vector2i(0, 1)
			4: # Move Left
				result.action = "move"
				result.value = Vector2i(-1, 0)
			7: # Move Right
				result.action = "move"
				result.value = Vector2i(1, 0)
			10: # Move Up
				result.action = "move"
				result.value = Vector2i(0, -1)
			13: # Move Bottom Left
				result.action = "move"
				result.value = Vector2i(-1, 1)
			16: # Move Bottom Right
				result.action = "move"
				result.value = Vector2i(1, 1)
			19: # Move Top Left
				result.action = "move"
				result.value = Vector2i(-1, -1)
			22: # Move Top Right
				result.action = "move"
				result.value = Vector2i(1, -1)
			25: # Random Movement
				result.action = "move"
				result.value = Vector2i(randi_range(0, 2) - 1, randi_range(0, 2) - 1)
			28, 31: # Move To/Away From The Player
				var player = GameManager.current_player if not GameManager.current_player.is_on_vehicle else GameManager.current_player.current_vehicle
				if player and player != self:
					result.action = "move"
					# Move To Player = Code 28, Move Away From Player = Code 31
					if command.code == 28:
						result.value = instance._get_next_move_toward_player()
					else:
						result.value = instance._get_next_move_away_from_player()
			34: # Step Forward
				result.action = "move"
				match instance.current_direction:
					instance.DIRECTIONS.LEFT: result.value = Vector2i(-1, 0)
					instance.DIRECTIONS.DOWN: result.value = Vector2i(0, 1)
					instance.DIRECTIONS.RIGHT: result.value = Vector2i(1, 0)
					instance.DIRECTIONS.UP: result.value = Vector2i(0, -1)
			37: # Take A Step Back
				result.action = "move"
				match instance.current_direction:
					instance.DIRECTIONS.LEFT: result.value = Vector2i(1, 0)
					instance.DIRECTIONS.DOWN: result.value = Vector2i(0, -1)
					instance.DIRECTIONS.RIGHT: result.value = Vector2i(-1, 0)
					instance.DIRECTIONS.UP: result.value = Vector2i(0, 1)
			40: # Jump
				var jump_amount: Vector2i = command.parameters[0]
				result.action = "jump"
				result.value = jump_amount
				result.start_fx = command.parameters[1]
				result.end_fx = command.parameters[2]
			43: # Wait
				var wait_time: float = command.parameters[0]
				instance.busy = true
				var timer = instance.get_tree().create_timer(wait_time)
				timer.timeout.connect(func(): instance.busy = false)
			46: # Change Z-Index
				var z: int = command.parameters[0]
				instance.z_index = z
				instance.character_options.z_index = z
			# Column 2
			2: # Look Down
				if not instance.character_options.fixed_direction: instance.current_direction = instance.DIRECTIONS.DOWN
			5: # Look Left
				if not instance.character_options.fixed_direction: instance.current_direction = instance.DIRECTIONS.LEFT
			8: # Look Right
				if not instance.character_options.fixed_direction: instance.current_direction = instance.DIRECTIONS.RIGHT
			11: # Look Up
				if not instance.character_options.fixed_direction: instance.current_direction = instance.DIRECTIONS.UP
			14: # Turn 90º Left
				if not instance.character_options.fixed_direction:
					match instance.current_direction:
						instance.DIRECTIONS.LEFT: instance.current_direction = instance.DIRECTIONS.UP
						instance.DIRECTIONS.DOWN: instance.current_direction = instance.DIRECTIONS.LEFT
						instance.DIRECTIONS.RIGHT: instance.current_direction = instance.DIRECTIONS.DOWN
						instance.DIRECTIONS.UP: instance.current_direction = instance.DIRECTIONS.RIGHT
			17: # Turn 90º Right
				if not instance.character_options.fixed_direction:
					match instance.current_direction:
						instance.DIRECTIONS.LEFT: instance.current_direction = instance.DIRECTIONS.DOWN
						instance.DIRECTIONS.DOWN: instance.current_direction = instance.DIRECTIONS.RIGHT
						instance.DIRECTIONS.RIGHT: instance.current_direction = instance.DIRECTIONS.UP
						instance.DIRECTIONS.UP: instance.current_direction = instance.DIRECTIONS.LEFT
			20: # Turn 180º
				if not instance.character_options.fixed_direction:
					match instance.current_direction:
						instance.DIRECTIONS.LEFT: instance.current_direction = instance.DIRECTIONS.RIGHT
						instance.DIRECTIONS.DOWN: instance.current_direction = instance.DIRECTIONS.UP
						instance.DIRECTIONS.RIGHT: instance.current_direction = instance.DIRECTIONS.LEFT
						instance.DIRECTIONS.UP: instance.current_direction = instance.DIRECTIONS.DOWN
			23: # Turn 90º Random
				if not instance.character_options.fixed_direction:
					var turn_left = randi() % 2 == 0
		
					if turn_left:
						match instance.current_direction:
							instance.DIRECTIONS.LEFT: instance.current_direction = instance.DIRECTIONS.UP
							instance.DIRECTIONS.DOWN: instance.current_direction = instance.DIRECTIONS.LEFT
							instance.DIRECTIONS.RIGHT: instance.current_direction = instance.DIRECTIONS.DOWN
							instance.DIRECTIONS.UP: instance.current_direction = instance.DIRECTIONS.RIGHT
					else:
						match instance.current_direction:
							instance.DIRECTIONS.LEFT: instance.current_direction = instance.DIRECTIONS.DOWN
							instance.DIRECTIONS.DOWN: instance.current_direction = instance.DIRECTIONS.RIGHT
							instance.DIRECTIONS.RIGHT: instance.current_direction = instance.DIRECTIONS.UP
							instance.DIRECTIONS.UP: instance.current_direction = instance.DIRECTIONS.LEFT
			26: # Look Random
				if not instance.character_options.fixed_direction:
					var random_dir = randi() % 4
					match random_dir:
						0: instance.current_direction = instance.DIRECTIONS.LEFT
						1: instance.current_direction = instance.DIRECTIONS.DOWN
						2: instance.current_direction = instance.DIRECTIONS.RIGHT
						3: instance.current_direction = instance.DIRECTIONS.UP
			29, 32: # Look Player / Look Opposite Player
				if not instance.character_options.fixed_direction:
					var player = GameManager.current_player if not GameManager.current_player.is_on_vehicle else GameManager.current_player.current_vehicle
					if player:
						var direction
						
						if command.code == 29:  # Look Player
							direction = (player.global_position - instance.global_position).normalized()
						else:  # Look Opposite Player (32)
							direction = (instance.global_position - player.global_position).normalized()
						
						if abs(direction.x) > abs(direction.y):
							instance.current_direction = instance.DIRECTIONS.RIGHT if direction.x > 0 else instance.DIRECTIONS.LEFT
						else:
							instance.current_direction = instance.DIRECTIONS.DOWN if direction.y > 0 else instance.DIRECTIONS.UP
			35, 38: # Switch ON/OFF
				var game_state = GameManager.game_state
				if game_state:
					var switch_id: int = command.parameters[0]
					if game_state.game_switches.size() > switch_id and switch_id > 0:
						var is_enabled = (command.code == 35) 
						if game_state.game_switches[switch_id] != is_enabled:
							game_state.game_switches[switch_id] = is_enabled
							GameManager.current_map.map_need_refresh = true
			41: # Change Speed
				var new_speed: int = command.parameters[0]
				instance.movement_speed = new_speed
				instance.character_options.movement_speed = new_speed
			44: # Change Frequency
				var new_movement_frequency: float = command.parameters[0]
				instance.event_movement_frequency = new_movement_frequency
				instance.character_options.movenet_frequency = new_movement_frequency
			# Column 3
			3: # Walking Animation ON
				instance.character_options.walking_animation = true
			6: # Walking Animation OFF
				instance.character_options.walking_animation = false
			9: # Idle Animation ON
				instance.character_options.idle_animation = true
			12: # Idle Animation OFF
				instance.character_options.idle_animation = false
			15: # Fix Direction ON
				instance.character_options.fixed_direction = true
			18: # Fix Direction OFF
				instance.character_options.fixed_direction = false
			21: # Walk Trought ON
				instance.character_options.passable = true
			24: # Walk Trought
				instance.character_options.passable = false
			27: # Invisible ON
				instance.visible = false
				instance.character_options.visible = false
			30: # Invisible OFF
				instance.visible = true
				instance.character_options.visible = true
			33: # Change Graphic
				instance.propagate_call("change_actor_graphics", [command.parameters[0]])
				instance.character_options.current_graphics = command.parameters[0]
			36: # Change Opacity
				instance.modulate.a = command.parameters[0]
				instance.character_options.current_opacity = command.parameters[0]
			39: # Change Blend Mode
				instance.propagate_call("change_blend_mode", [command.parameters[0]])
				instance.character_options.blend_mode = command.parameters[0]
			42: # Play SE
				var parameters = command.parameters
				var path = parameters[0]
				var volume = parameters[1]
				var pitch1 = parameters[2]
				var pitch2 = parameters[3]
				var pitch = randf_range(pitch1, pitch2)
				GameManager.play_se(path, volume, pitch)
			45: # Script
				GameInterpreter.code_eval.execute(command.parameters[0])
	
	if backup_direction != instance.current_direction:
		instance.last_direction = instance.current_direction
	
	return result
