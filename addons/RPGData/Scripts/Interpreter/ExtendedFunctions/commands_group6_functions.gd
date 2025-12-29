class_name CommandsGroup6
extends CommandHandlerBase


var teleport_transitions: TeleportTransitions


func _get_transfer_script() -> TeleportTransitions:
	if not teleport_transitions:
		teleport_transitions = TeleportTransitions.new()
		GameInterpreter.add_child(teleport_transitions)
	
	return teleport_transitions


# Command Set Transition Config (Code 52), button_id = 39
# Code 52 parameters { type, duration, transition_image*, transition_color*, invert* }
func _command_0052() -> void:
	debug_print("Processing command: Transition Config (code 52)")

	GameManager.game_state.current_transition = current_command.parameters.duplicate(true)


# get real direction from the direction parameter
# 0 = Hold, 1 = Up, 2 = Down, 3 = Left, 4 = Right
func _get_direction(direction: int, target: Variant) -> LPCCharacter.DIRECTIONS:
	var new_direction: LPCCharacter.DIRECTIONS = LPCCharacter.DIRECTIONS.DOWN
	if direction == 0: # Hold
		if target and "current_direction" in target:
			new_direction = target.current_direction
	elif direction == 1: # up
		new_direction = LPCCharacter.DIRECTIONS.UP
	elif direction == 2: # Down
		new_direction = LPCCharacter.DIRECTIONS.DOWN
	elif direction == 3: # Left
		new_direction = LPCCharacter.DIRECTIONS.LEFT
	elif direction == 4: # Right
		new_direction = LPCCharacter.DIRECTIONS.RIGHT

	return new_direction


func _start_transfer_animation(obj: Node, transfer_animation_data: Dictionary) -> void:
	var animation_id = transfer_animation_data.get("exit_animation", 0)
	if animation_id < 0 or animation_id >= TeleportTransitions.ExitAnimation.size():
		animation_id = 0
	var animation_time = transfer_animation_data.get("exit_time", 0.2)
	var transfer_script = _get_transfer_script()
	await transfer_script.play_exit_animation(obj, animation_id, animation_time)


func _set_start_tranfer_end_values(obj: Node, transfer_animation_data: Dictionary) -> void:
	var original_state = {
		"scale": obj.scale,
		"rotation": obj.rotation,
		"alpha": obj.modulate.a
	}
	obj.set_meta("teleport_restore_data", original_state)
	var animation_id = transfer_animation_data.get("exit_animation", 0)
	if animation_id < 0 or animation_id >= TeleportTransitions.ExitAnimation.size():
		animation_id = 0
	var transfer_script = _get_transfer_script()
	var values = transfer_script.get_exit_final_values(animation_id)
	obj.scale = values.scale
	obj.rotation = values.rotation
	obj.modulate.a = values.modulate_a


func _end_transfer_animation(obj: Node, transfer_animation_data: Dictionary) -> void:
	var animation_id = transfer_animation_data.get("entry_animation", 0)
	if animation_id < 0 or animation_id >= TeleportTransitions.EntryAnimation.size():
		animation_id = 0
	var animation_time = transfer_animation_data.get("entry_time", 0)
	var transfer_script = _get_transfer_script()
	await transfer_script.play_entry_animation(obj, animation_id, animation_time)


func _perform_transfer(obj: Node, tile: Vector2i, direction: LPCCharacter.DIRECTIONS, transfer_animation_data: Dictionary, wait_animation: bool, center_camera: bool = false) -> void:
	# Animation start
	var target = obj
	if "is_on_vehicle" in obj and obj.is_on_vehicle and obj.current_vehicle:
		target = obj.current_vehicle
	
	if wait_animation:
		await _start_transfer_animation(target, transfer_animation_data)
	else:
		_start_transfer_animation(target, transfer_animation_data)
	# Set new position for obj
	await GameManager.current_map.set_event_position(target, tile, direction, center_camera)
	if "previous_tile" in obj:
		obj.previous_tile = tile
	if "current_virtual_tile" in obj:
		obj.current_virtual_tile = tile
	if target is RPGVehicle:
		target.previous_tile = tile
		var vehicle_position: RPGMapPosition = RPGMapPosition.new(
			GameManager.current_map.internal_id,
			tile
		)
		var transport_id = target.vehicle_type
		if transport_id == 0: # Land Vehicle
			GameManager.game_state.land_transport_start_position = vehicle_position
		elif transport_id == 1: # Sea Vehicle
			GameManager.game_state.sea_transport_start_position = vehicle_position
		elif transport_id == 2: # Air Vehicle
			GameManager.game_state.air_transport_start_position = vehicle_position
		
	# Animation end
	if wait_animation:
		await _end_transfer_animation(target, transfer_animation_data)
	else:
		_end_transfer_animation(target, transfer_animation_data)


# Perform player transfer with delay
# All commnands in the current page are processed before the transfer
# any other transfer command in the page replaces the previous one
func _perform_player_transfer_with_delay(_interpreter, params: Dictionary) -> void:
	await _perform_player_transfer(params)


# Perform player transfer
func _perform_player_transfer(params: Dictionary) -> void:
	if not GameManager.current_player:
		debug_print("No player loaded, cannot transfer player")
		return
	
	var backup_busys = [interpreter.busy, interpreter.busy2, interpreter.busy3]

	var current_event = GameManager.current_player
	var map_id = params.get("map_id", -1)
	var tile = params.get("tile", Vector2i())
	var direction = params.get("direction", -1)
	var wait_animation = params.get("wait_animation", true)
	var transfer_animation = params.get("transfer_animation", {})

	GameManager._transfer_direction = direction
	
	var transfer_on_same_map: bool = false
	if GameManager.current_map:
		var current_map_id = GameManager.current_map.internal_id
		if current_map_id == map_id:
			transfer_animation = params.get("transfer_animation", {})
			var camera = GameManager.get_camera()
			if camera and camera.is_following(current_event):
				await _perform_transfer(current_event, tile, direction, transfer_animation, wait_animation, true)
			else:
				await _perform_transfer(current_event, tile, direction, transfer_animation, wait_animation, false)
				
			transfer_on_same_map = true
	
	# teleport to other map
	interpreter.busy = true
	interpreter.busy2 = true
	interpreter.busy3 = true
	if not transfer_on_same_map:
		await _transfer_to_oher_map(map_id, tile, direction, current_event, transfer_animation)
	
	interpreter.busy = backup_busys[0]
	interpreter.busy2 = backup_busys[1]
	interpreter.busy3 = backup_busys[2]


func _transfer_to_oher_map(map_id: int, tile: Vector2i, direction: int, current_event: Variant, transfer_animation: Dictionary) -> void:
	var target = current_event
	if "is_on_vehicle" in current_event and current_event.is_on_vehicle and current_event.current_vehicle:
		target = current_event.current_vehicle
	# 1) We need perform start animation
	await _start_transfer_animation(target, transfer_animation)
	
	var transport_id = -1 if not target is RPGVehicle else target.vehicle_type
	if target is RPGVehicle:
		var vehicle_position: RPGMapPosition = RPGMapPosition.new(
			map_id,
			tile
		)
		if transport_id == 0: # Land Vehicle
			GameManager.game_state.land_transport_start_position = vehicle_position
		elif transport_id == 1: # Sea Vehicle
			GameManager.game_state.sea_transport_start_position = vehicle_position
		elif transport_id == 2: # Air Vehicle
			GameManager.game_state.air_transport_start_position = vehicle_position
		

	GameManager.game_state.current_map_position = tile
	GameManager.main_scene.scene_changed.connect(
		func():
			GameManager.main_scene.get_main_camera().clear_targets()
			GameManager.current_map.set_event_position(current_event, tile, direction, true)
			current_event.previous_tile = tile
			current_event.current_virtual_tile = tile
			if transport_id != -1:
				var vehicle = GameManager.current_map.get_in_game_vehicle_in(tile)
				if vehicle:
					current_event.current_vehicle = vehicle
					vehicle.start(current_event)
					_set_start_tranfer_end_values(vehicle, transfer_animation)
				
	, CONNECT_ONE_SHOT)
	var start_map_path = RPGSYSTEM.map_infos.get_map_by_id(map_id)
	if start_map_path and ResourceLoader.exists(start_map_path):
		GameManager.game_state.current_map_id = map_id
		await GameManager.change_scene(start_map_path)
	else:
		debug_print("Starting map no found (Map with id %s). Exiting..." % map_id)
		await GameManager.change_scene("res://Scenes/EndScene/scene_end.tscn")

	target = current_event
	if "is_on_vehicle" in current_event and current_event.is_on_vehicle and current_event.current_vehicle:
		target = current_event.current_vehicle

	await _end_transfer_animation(target, transfer_animation)


# Parse transfer parameters for the player
func _transfer_player(params: Dictionary) -> void:
	if not GameManager.current_player:
		debug_print("No player loaded, cannot transfer player")
		return
	
	if interpreter.showing_message:
		await interpreter.end_message()

	var type = params.get("type", 0)
	var direction = params.get("direction", -1)
	var value = params.get("value", {})
	var new_location = {"map_id": -1, "tile": Vector2i(), "direction": -1}
	var transfer_animation = params.get("transfer_animation", {})

	if type == 0: # Manual Settings
		var assigned_map_id = value.get("assigned_map_id", -1)
		var assigned_x = value.get("assigned_x", -1)
		var assigned_y = value.get("assigned_y", -1)
		new_location = {"map_id": assigned_map_id, "tile": Vector2i(assigned_x, assigned_y)}
	elif type == 1: # Variable Settings
		var map_id = value.get("map_id", -1)
		var x = value.get("x", -1)
		var y = value.get("y", -1)
		new_location = {"map_id": map_id, "tile": Vector2i(x, y)}
	var map_path = RPGMapsInfo.map_infos.get_path_from_id(new_location.map_id)

	if map_path.is_empty() or not ResourceLoader.exists(map_path):
		return
	
	new_location.direction = _get_direction(direction, GameManager.current_player)
	new_location.transfer_animation = transfer_animation

	var delay_transfer = params.get("delay_transfer", false)

	if delay_transfer:
		# Delays the transfer until the current interpreter finishes
		# Note: If there is another player transfer command in the queue, it is discarded
		if current_interpreter.all_commands_processed.is_connected(_perform_player_transfer_with_delay):
			current_interpreter.all_commands_processed.disconnect(_perform_player_transfer_with_delay)
		current_interpreter.all_commands_processed.connect(_perform_player_transfer_with_delay.bind(new_location))
	else:
		# Perform immediate transfer
		await _perform_player_transfer(new_location)


func _update_vehicle_position(map_id: int, vehicle_type: int, vehicle_position: Vector2i, direction: int, transfer_animation: Dictionary = {}, wait_animation: bool = true) -> void:
	if GameManager.current_map:
		if GameManager.current_map.internal_id == map_id:
			var vehicle_found: bool = false
			for vehicle in GameManager.current_map.current_ingame_vehicles:
				if "vehicle_type" in vehicle and int(vehicle.vehicle_type) == vehicle_type:
					var real_direction = _get_direction(direction, vehicle)
					await _perform_transfer(vehicle, vehicle_position, real_direction, transfer_animation, wait_animation, false)
					vehicle_found = true
					return
			if not vehicle_found:
				GameManager.current_map._setup_vehicles()


# Parse transfer parameters for the vehicle
func _transfer_vehicle(params: Dictionary) -> void:
	var type = params.get("type", 0)
	var direction = params.get("direction", -1)
	var vehicle_type = params.get("vehicle_id", -1)
	var value = params.get("value", {})
	var new_location = {"map_id": -1, "tile": Vector2i()}
	var transfer_animation = params.get("transfer_animation", {})
	var wait_animation = params.get("wait_animation", true)

	if type == 0: # Manual Settings
		var assigned_map_id = value.get("assigned_map_id", -1)
		var assigned_x = value.get("assigned_x", -1)
		var assigned_y = value.get("assigned_y", -1)
		new_location = {"map_id": assigned_map_id, "tile": Vector2i(assigned_x, assigned_y)}
	elif type == 1: # Variable Settings
		var map_id = value.get("map_id", -1)
		var x = value.get("x", -1)
		var y = value.get("y", -1)
		new_location = {"map_id": map_id, "tile": Vector2i(x, y)}
	
	var vehicle_position: RPGMapPosition = RPGMapPosition.new(new_location.map_id, new_location.tile)

	if vehicle_type == 0: # Land Vehicle
		GameManager.game_state.land_transport_start_position = vehicle_position
	elif vehicle_type == 1: # Sea Vehicle
		GameManager.game_state.sea_transport_start_position = vehicle_position
	elif vehicle_type == 2: # Air Vehicle
		GameManager.game_state.air_transport_start_position = vehicle_position

	await _update_vehicle_position(vehicle_position.map_id, vehicle_type, vehicle_position.position, direction, transfer_animation)

# Parse transfer parameters for the event
func _transfer_event(params: Dictionary) -> void:
	if not GameManager.current_map:
		debug_print("No map loaded, cannot transfer event")
		return

	var type = params.get("type", 0)
	var direction = params.get("direction", -1)
	var value = params.get("value", {})
	var new_location: Vector2i = Vector2i()
	var transfer_animation = params.get("transfer_animation", {})
	var wait_animation = params.get("wait_animation", true)

	if type == 0: # Manual Settings
		var assigned_x = value.get("assigned_x", -1)
		var assigned_y = value.get("assigned_y", -1)
		new_location = Vector2i(assigned_x, assigned_y)
	elif type == 1: # Variable Settings
		var x = value.get("x", -1)
		var y = value.get("y", -1)
		new_location = Vector2i(x, y)

	var event_id = value.get("event_id", -1)
	var swap_event_id = value.get("swap_event_id", -1)

	if event_id == -1:
		debug_print("Invalid event ID for transfer")
		return

	var current_event = GameManager.current_map.get_in_game_event_by_pos(event_id - 1) if event_id > 0 else current_interpreter.obj
	
	var direction1: LPCCharacter.DIRECTIONS = _get_direction(direction, current_event)

	if not current_event:
		debug_print("Event not found in map with ID: %s" % event_id)	
		return

	if swap_event_id != -1:
		var swap_event = GameManager.current_map.get_in_game_event_by_pos(swap_event_id - 1) if event_id > 0 else current_interpreter.obj
		if not swap_event:
			debug_print("Swap event not found in map with ID: %s" % swap_event_id)
			return
		if not "get_current_tile" in current_event or not "get_current_tile" in swap_event:
			debug_print("Event does not have a get_current_tile method")
			return
		var tile1 = current_event.get_current_tile()
		var tile2 = swap_event.get_current_tile()
		var direction2: LPCCharacter.DIRECTIONS = _get_direction(0, swap_event)
		_perform_transfer(current_event, tile2, direction1, transfer_animation, wait_animation, false)
		await _perform_transfer(swap_event, tile1, direction2, transfer_animation, wait_animation, false)
	else:
		await _perform_transfer(current_event, new_location, direction1, transfer_animation, wait_animation, false)


# Command Transfer Player/Vehicle/Events (Code 53), button_ids = 40, 41, 42
# Code 53 parameters { target, type, vehicle_id*, direction*,
# value (dictionary assigned_map_id*, assigned_x*, assigned_y* or dictionary map_id*, x*, y*)
# event_id*, swap_event_id*, *delay_transfer }
# targets = button_id 40 -> 0 Player, button_id 41 -> 1 Vehicle, button_id 42 -> 2 Event
func _command_0053() -> void:
	debug_print("Processing command: Transfer Player/Vehicle/Events (code 53)")

	var target = current_command.parameters.get("target", 0)
	if target == 0: # Transfer Player
		await _transfer_player(current_command.parameters)
	elif target == 1: # Transfer Vehicle
		await _transfer_vehicle(current_command.parameters)
	elif target == 2: # Transfer Event
		await _transfer_event(current_command.parameters)
	else:
		debug_print("Invalid target for command 53: %s" % target)


# Command Scroll / Zoom Map (Code 54), button_id = 43
# Code 54 parameters { type, duration, wait, direction*, amount*, zoom* }
func _command_0054() -> void:
	debug_print("Processing command: Scroll / Zoom Map (code 54)")

	var type = current_command.parameters.get("type", 0)
	var duration = current_command.parameters.get("duration", 0.5)
	var wait = current_command.parameters.get("wait", true)

	var camera = GameManager.get_camera()
	var map = GameManager.current_map

	if camera and map:
		camera.set_process(false)
		if type == 0: # Scroll Map
			# 0 = Up, 1 = Down, 2 = Left, 3 = Right
			var direction = current_command.parameters.get("direction", 0)
			var amount = current_command.parameters.get("amount", 1)
			if amount != 0:
				var real_amount = amount * map.tile_size
				var t = GameManager.create_tween()
				var p = camera.global_position
				camera.set_process(false)
				match direction:
					0: # Up
						t.tween_property(camera, "global_position:y", p.y - real_amount.y, duration)
					1: # Down
						t.tween_property(camera, "global_position:y", p.y + real_amount.y, duration)
					2: # Left
						t.tween_property(camera, "global_position:x", p.x - real_amount.x, duration)
					3: # Right
						t.tween_property(camera, "global_position:x", p.x + real_amount.x, duration)
				
		elif type == 1: # Zoom Map
			var zoom = current_command.parameters.get("zoom", 2.0)
			if zoom > 0.0:
				var t = GameManager.create_tween()
				t.tween_property(camera, "zoom", Vector2(zoom, zoom), duration)
		
		elif type == 2: # Reset Scroll And Zoom
			camera.set_process(true)
			var data = camera.get_target_position_and_zoom()
			var t = GameManager.create_tween()
			t.set_parallel(true)
			t.tween_property(camera, "zoom", data.zoom, duration)
			t.tween_property(camera, "global_position", data.position, duration)
	
	
	if wait and duration > 0 and current_interpreter.obj:
		# Create a timer for the specified duration and wait for it to timeout
		await current_interpreter.obj.get_tree().create_timer(duration).timeout


# Command Set Movement Route (Codes 57, 58), button_id = 44
# Code 57 parameters { target, loop, skippable, wait }
# Code 58 parameters { movement_command }
func _command_0057() -> void:
	debug_print("Processing command: Set Movement Route (code 57)")

	var command_list: Array[RPGEventCommand] = []
	# Start iterating through subsequent commands to collect profile lines
	var current_index = current_interpreter.command_index + 1
	var current_indent = current_command.indent

	while true:
		var command = current_interpreter.get_command(current_index)
		if command:
			# Check if the command is at the same indentation level
			if command.indent == current_indent:
				if command.code == 58: # Movement Data
					command_list.append(command)
				else: # Stop if a non-movement command is encountered
					break
		else: # Stop if no more commands are found
			break

		current_index += 1
	
	var target_id = current_command.parameters.get("target", 0)
	
	var target: Variant
	match target_id:
		-1: # Current player
			if GameManager.current_player:
				target = GameManager.current_player
		0: # This event:
			target = current_interpreter.obj
		_: # event with id target_id
			if GameManager.current_map:
				target = GameManager.current_map.get_in_game_event_by_id(target_id)
			else:
				target = current_interpreter.obj

	if target and "route_commands" in target and "route_command_index" in target and command_list.size() > 0:
		var route: RPGMovementRoute = RPGMovementRoute.new()
		route.target = target_id
		route.repeat = current_command.parameters.get("loop", false)
		route.skippable = current_command.parameters.get("skippable", true)
		route.wait = current_command.parameters.get("wait", false)
		route.is_route_from_interpreter = true
		var list: Array[RPGMovementCommand] = []
		for c: RPGEventCommand in command_list:
			var route_command = c.parameters.get("movement_command", null)
			list.append(route_command)
		route.list = list
		target.route_command_index = 0
		target.route_commands = route
		
		if route.wait:
			await route.finished


# Command Get In/Out Vehicle (Code 59), button_id = 45
# Code 59 parameters { type, transport_id* }
func _command_0059() -> void:
	debug_print("Processing command: Get In/Out Vehicle (code 59)")
	
	var type = current_command.parameters.get("type", 0)

	if type == 0 and GameManager.current_map and GameManager.game_state and GameManager.current_player: # Get In Vehicle
		var vehicle_position: RPGMapPosition = RPGMapPosition.new(
			GameManager.current_map.internal_id,
			GameManager.current_player.get_current_tile()
		)
		var transport_id = current_command.parameters.get("transport_id", 0)
		if transport_id == 0: # Land Vehicle
			GameManager.game_state.land_transport_start_position = vehicle_position
		elif transport_id == 1: # Sea Vehicle
			GameManager.game_state.sea_transport_start_position = vehicle_position
		elif transport_id == 2: # Air Vehicle
			GameManager.game_state.air_transport_start_position = vehicle_position

		var direction = GameManager.current_player.current_direction
		
		_update_vehicle_position(vehicle_position.map_id, transport_id, vehicle_position.position, direction)

		var current_vehicle = GameManager.current_map.get_in_game_vehicle_in(vehicle_position.position)
		if current_vehicle and "start" in current_vehicle:
			current_vehicle.start(GameManager.current_player)
			var new_direction = GameManager.current_player.get_opposite_direction(direction)
			if "set_direction" in current_vehicle:
				current_vehicle.set_direction(new_direction)
				GameManager.current_player.set_direction(new_direction)
				if current_vehicle.has_signal("start_movement"):
					current_vehicle.start_movement.emit()


	elif type == 1 and GameManager.current_player: # Get Out Vehicle
		if "is_on_vehicle" in GameManager.current_player and GameManager.current_player.is_on_vehicle:
			if "current_vehicle" in GameManager.current_player:
				var vehicle = GameManager.current_player.current_vehicle
				if vehicle and "end" in vehicle and "can_disembark" in vehicle and vehicle.can_disembark():
					vehicle.end()


# Command Manage Camera Targets (Code 123), button_id = 126
# Code 123 parameters { targets }
func _command_0123() -> void:
	var camera = GameManager.get_camera()
	
	if not camera:
		return
	
	camera.clear_targets()
		
	var targets: PackedInt32Array = current_command.parameters.get("targets", [])
	var priorities: PackedInt32Array = current_command.parameters.get("priorities", [])
	
	for i: int in targets.size():
		var target = targets[i]
		if target == 0 and GameManager.current_player:
			var priority = 5 if priorities.size() == 0 else priorities[0]
			var node = GameManager.current_player if not GameManager.current_player.is_on_vehicle else GameManager.current_player.current_vehicle
			camera.add_target_to_array(node, priority)
		elif target > 0 and GameManager.current_map:
			var event = GameManager.current_map.get_in_game_event_by_pos(target - 1)
			if event:
				var priority = 5 if priorities.size() <= i else priorities[i]
				camera.add_target_to_array(event, priority)
