class_name CommandsGroup4
extends CommandHandlerBase


# Command Conditional Branch (Codes 21, 22, 23), button_id = 16
# Code 21 (Parent) parameters { item_selected, value1, value2, value3, value4 }
# Code 22 (Else) parameters { }
# Code 23 (End) parameters { }
func _command_0021() -> void:
	debug_print("Processing command: Conditional Branck (code 21)")
	
	var item_selected = current_command.parameters.get("item_selected", 0)
	var value1 = current_command.parameters.get("value1", null)
	var value2 = current_command.parameters.get("value2", null)
	var value3 = current_command.parameters.get("value3", null)
	var value4 = current_command.parameters.get("value4", null)
	var value5 = current_command.parameters.get("value5", null)
	var value6 = current_command.parameters.get("value6", null)

	var condition_met: bool = false

	match item_selected:
		0: # Switch
			if value1 > 0 and GameManager.game_state.game_switches.size() > value1:
				if (GameManager.game_state.game_switches[value1] == 1 and value2 == 0) or \
					(GameManager.game_state.game_switches[value1] == 0 and value2 == 1):
					condition_met = true
		1: # Variable
			if value1 > 0 and GameManager.game_state.game_variables.size() > value1:
				var variable_value: int = GameManager.game_state.game_variables[value1]
				var target_value: int = 0
				if value3 == 0: # Constant Value
					target_value = value4
				elif value4 > 0 and GameManager.game_state.game_variables.size() > value4: # variable value
					target_value = GameManager.game_state.game_variables[value4]
				
				match value2:
					0: # Equal
						if variable_value == target_value:
							condition_met = true
					1: # Greater than or equal to
						if variable_value >= target_value:
							condition_met = true
					2: # Less than or equal to
						if variable_value <= target_value:
							condition_met = true
					3: # Greater than
						if variable_value > target_value:
							condition_met = true
					4: # Less than
						if variable_value < target_value:
							condition_met = true
					5: # Not equal
						if variable_value != target_value:
							condition_met = true
		2: # Self Switch
			if GameManager.current_map:
				var switch_id = value1
				var map_id = GameManager.current_map.internal_id
				var switch_name = RPGSYSTEM.system.self_switches.get_self_switch_name(switch_id)
				if switch_name:
					var switch_key = "%s_%s" % [map_id, switch_id]
					if switch_key in GameManager.game_state.game_self_switches:
						if GameManager.game_state.game_self_switches[switch_key] == (value2 == 0):
							condition_met = true
		3: # Timer
			var timer_id = value4
			var operation = value1
			var minutes = value2
			var seconds = value3
			var total_timer = minutes * 60 + seconds
			if GameManager.game_state.active_timers.has(timer_id):
				var timer_data: Dictionary = GameManager.game_state.active_timers[timer_id]
				if timer_data:
					if operation == 0 and timer_data.current_time >= total_timer:
						condition_met = true
					elif operation == 1 and timer_data.current_time <= total_timer:
						condition_met = true
		4: # Actor
			if GameManager.game_state.actors.has(value1):
				var actor_id = value1
				match value2:
					0: # is in Party
						if GameManager.game_state.current_party.has(actor_id):
							condition_met = true
					1: # Name
						if GameManager.game_state.actors[actor_id].name == value3:
							condition_met = true
					2: # Class
						if GameManager.game_state.actors[actor_id].current_class == value3:
							condition_met = true
					3: # Has Skill
						if GameManager.game_state.actors[actor_id].current_skills.has(value3):
							condition_met = true
					4: # Has Weapon
						var current_weapon = GameManager.game_state.actors[actor_id].gear.filter(
							func(obj: Variant):
								if obj is GameWeapon and obj.id == value2:
									return obj
						)
						if current_weapon.size() > 0:
							condition_met = true
					5: # Has Armor
						var current_armor = GameManager.game_state.actors[actor_id].gear.filter(
							func(obj: Variant):
								if obj is GameArmor and obj.id == value2:
									return obj
						)
						if current_armor.size() > 0:
							condition_met = true
					6: # State
						var current_state = GameManager.game_state.actors[actor_id].states.filter(
							func(obj: GameState):
								if obj.id == value2:
									return obj
						)
						if current_state.size() > 0:
							condition_met = true
					7: # Parameter
						var parameters = PackedStringArray(["Level", "Experience"]) + RPGSYSTEM.database.types.main_parameters
						var target_value = value6
						var target_param = value4
						var variable_value
						if target_param >= 0 and parameters.size() > target_param:
							var real_param = parameters[target_param].replace(" ", "_").to_upper()
							variable_value  = GameManager.get_actor_parameter(actor_id, real_param)
						elif target_param > parameters.size():
							var user_parameter_id = target_param - parameters.size() - 1
							variable_value = GameManager.get_actor_user_parameter(actor_id,  user_parameter_id)

						match value5:
							0: # Equal
								if variable_value == target_value:
									condition_met = true
							1: # Greater than or equal to
								if variable_value >= target_value:
									condition_met = true
							2: # Less than or equal to
								if variable_value <= target_value:
									condition_met = true
							3: # Greater than
								if variable_value > target_value:
									condition_met = true
							4: # Less than
								if variable_value < target_value:
									condition_met = true
							5: # Not equal
								if variable_value != target_value:
									condition_met = true

		5: # Enemy TODO
			var enemy_battler_id = value1
			if value2 == 0: # Appeared
				pass
			elif value2 == 1: # Has State
				var state_id = value3
		6: # Character Param
			var target: Variant
			if value1 == 0:
				target = GameManager.current_player
			elif GameManager.current_map:
				var event_id = 0 if value1 == 1 else value1 - 2
				target = GameManager.current_map.get_in_game_event_by_pos(event_id)
			if target:
				if value2 < 4:
					var direction = GameManager.current_player.DIRECTIONS.DOWN if value2 == 0 \
						else GameManager.current_player.DIRECTIONS.LEFT if value2 == 1 \
						else GameManager.current_player.DIRECTIONS.RIGHT if value2 == 2 \
						else GameManager.current_player.DIRECTIONS.UP
					if target.current_direction == direction:
						condition_met = true
				else:
					match value2:
						4: # Is In My Tile
							if current_interpreter.obj and current_interpreter.obj.has_method("get_current_tile") and target.has_method("get_current_tile") and current_interpreter.obj.get_current_tile() == target.get_current_tile():
								condition_met = true
						5: # Is Out Of My Tile
							if current_interpreter.obj and current_interpreter.obj.has_method("get_current_tile") and target.has_method("get_current_tile") and current_interpreter.obj.get_current_tile() != target.get_current_tile():
								condition_met = true
						6: # Is Jumping
							if target.is_jumping:
								condition_met = true
						7: # Is Passable
							if target.has_method("is_passable") and target.is_passable():
								condition_met = true
						8: # Is On Vehicle
							if target == GameManager.current_player and target.is_on_vehicle:
								condition_met = true
		7: # Vehicle
			if GameManager.current_vehicle and GameManager.current_vehicle.vahicle_type == value1:
				condition_met = true
		8: # Gold
			if GameManager.game_state.current_gold >= value1:
				condition_met = true
		9: # Has Item	
			var item_id = value1
			if GameManager.game_state.items.has(item_id):
				var items = GameManager.game_state.items[item_id]
				for item: GameItem in items:
					if item.quantity > 0:
						condition_met = true
						break
		10: # Has Weapon
			var item_id = value1
			var include_equiped = value2
			if GameManager.game_state.weapons.has(item_id):
				var items = GameManager.game_state.weapons[item_id]
				for item: GameWeapon in items:
					if item.quantity > 0 and (include_equiped or item.total_equipped < item.quantity):
						condition_met = true
						break
		11: # Has Armor
			var item_id = value1
			var include_equiped = value2
			if GameManager.game_state.armors.has(item_id):
				var items = GameManager.game_state.armors[item_id]
				for item: GameArmor in items:
					if item.quantity > 0 and (include_equiped or item.total_equipped < item.quantity):
						condition_met = true
						break
		13: # Script
			var sc = value1
			var result = await interpreter.code_eval.execute(sc)
			if result == true:
				condition_met = true
		14: # text variable
			if value1 > 0 and GameManager.game_state.game_text_variables.size() > value1:
				var variable_value: String = GameManager.game_state.game_text_variables[value1]
				var target_value: String = ""
				if value3 == 0: # Constant Value
					target_value = value4
				elif value4 > 0 and GameManager.game_state.game_text_variables.size() > value4: # variable value
					target_value = GameManager.game_state.game_text_variables[value4]
				
				match value2:
					0: # Equal
						if variable_value == target_value:
							condition_met = true
					1: # Greater than or equal to
						if variable_value >= target_value:
							condition_met = true
					2: # Less than or equal to
						if variable_value <= target_value:
							condition_met = true
					3: # Greater than
						if variable_value > target_value:
							condition_met = true
					4: # Less than
						if variable_value < target_value:
							condition_met = true
					5: # Not equal
						if variable_value != target_value:
							condition_met = true
		15: # Profession
			var profession_id = value1
			if profession_id > 0 and RPGSYSTEM.database.professions.size() > profession_id:
				var profession = RPGSYSTEM.database.professions[profession_id]
				var current_value = GameManager.get_profession_level(profession)
				var target_value = value3
				var prefession_condition = value2
				
				match prefession_condition:
					0: # Equal
						if current_value == target_value:
							condition_met = true
					1: # Greater than or equal to
						if current_value >= target_value:
							condition_met = true
					2: # Less than or equal to
						if current_value <= target_value:
							condition_met = true
					3: # Greater than
						if current_value > target_value:
							condition_met = true
					4: # Less than
						if current_value < target_value:
							condition_met = true
					5: # Not equal
						if current_value != target_value:
							condition_met = true
			
		16: # Relationship
			var event = current_interpreter.obj
			if event and "current_event" in event and event is RPGEvent and GameManager.current_map:
				var relationship_condition = value2
				var current_value = GameManager.get_event_relationship_level(event.current_event.id)
				var target_value = value3
				
				match relationship_condition:
					0: # Equal
						if current_value == target_value:
							condition_met = true
					1: # Greater than or equal to
						if current_value >= target_value:
							condition_met = true
					2: # Less than or equal to
						if current_value <= target_value:
							condition_met = true
					3: # Greater than
						if current_value > target_value:
							condition_met = true
					4: # Less than
						if current_value < target_value:
							condition_met = true
					5: # Not equal
						if current_value != target_value:
							condition_met = true
		17: # Global user parameters
			var variable_value: float = GameManager.get_global_user_parameter(value1)
			var target_value: float = 0
			if value3 == 0: # Constant Value
				target_value = value4
			else: # variable value
				target_value = GameManager.get_global_user_parameter(value4)
			
			match value2:
				0: # Equal
					if variable_value == target_value:
						condition_met = true
				1: # Greater than or equal to
					if variable_value >= target_value:
						condition_met = true
				2: # Less than or equal to
					if variable_value <= target_value:
						condition_met = true
				3: # Greater than
					if variable_value > target_value:
						condition_met = true
				4: # Less than
					if variable_value < target_value:
						condition_met = true
				5: # Not equal
					if variable_value != target_value:
						condition_met = true
		
	# If the condition is not met, skip to the corresponding Else or End command
	if not condition_met:
		var current_index = current_interpreter.command_index + 1
		var current_indent = current_command.indent

		while true:
			var command = current_interpreter.get_command(current_index)
			if command:
				# Check if the command is at the same indentation level
				if command.indent == current_indent:
					if command.code == 22: # Else
						# Move to the command after Else
						current_index += 1
						break
					elif command.code == 23: # End
						# Stop at the End command
						break
			else:
				# Exit the loop if no more commands are found
				break

			current_index += 1

		# Jump to the determined command index
		current_interpreter.go_to(current_index - 1)


# Command Start Loop (Codes 24, 25), button_id = 17
# Code 24 (Parent) parameters { }
# Code 25 (Repeat / End) parameters { }
func _command_0024() -> void:
	debug_print("Processing command: Start Loop (code 24)")
	
	# Set the start index of the loop to the current command index
	current_interpreter.loop.start_index = current_interpreter.command_index

	# Initialize variables to traverse commands
	var current_index = current_interpreter.command_index + 1
	var current_indent = current_command.indent

	# Iterate through the commands to find the corresponding "Repeat / End" command
	while true:
		var command = current_interpreter.get_command(current_index)
		if command:
			# Check if the command is at the same indentation level
			if command.indent == current_indent:
				if command.code == 25: # Repeat / End
					# Set the end index of the loop and exit the loop
					current_interpreter.loop.end_index = current_index
					break
		else:
			# Exit the loop if no more commands are found
			break

		# Move to the next command
		current_index += 1


# Code 25 (Repeat / End) parameters { }
func _command_0025() -> void:
	debug_print("Processing command: Repeat Loop (code 25)")
	
	# Check if the loop start index is valid
	if current_interpreter.loop.start_index != -1:
		# Jump back to the start of the loop
		current_interpreter.go_to(current_interpreter.loop.start_index)



# Command Break Loop (Code 26), button_id = 18
# Code 26 (Parent) parameters { }
func _command_0026() -> void:
	debug_print("Processing command: Break Loop (code 26)")
	# Check if the loop end index is valid
	if current_interpreter.loop.end_index != -1:
		# Jump to the end of the loop
		current_interpreter.go_to(current_interpreter.loop.end_index)
	
	# Reset the loop indices to indicate the loop has ended
	current_interpreter.loop.end_index = -1
	current_interpreter.loop.start_index = -1


# Command Exit Event Processing (Code 27), button_id = 19
# Code 27 (Parent) parameters { }
func _command_0027() -> void:
	debug_print("Processing command: Exit Event Processing (code 27)")  
	# End the current event processing
	current_interpreter.end()
	current_interpreter.force_stop.emit(current_interpreter)


# Command Select Common Event (Code 28), button_id = 20
# Code 28 (Parent) parameters { id }
func _command_0028() -> void:
	debug_print("Processing command: Select Common Event (code 28)")
	
	# Retrieve the common event ID from the command parameters
	var common_event_id: int = current_command.parameters.get("id", 0)
	
	# Check if the common event ID is valid and exists in the database
	if common_event_id > 0 and RPGSYSTEM.database.common_events.size() > common_event_id:
		# Retrieve the common event from the database
		var event = RPGSYSTEM.database.common_events[common_event_id]
		
		# Get the list of commands associated with the common event
		var commands = event.list
		
		# Start the common event by passing its commands to the interpreter
		# All commands of this new interpreter will be processed before continuing
		# to process the parameters of the current interpreter.
		# The object of this new interpreter will be the same as that of the current interpreter.
		await interpreter.start_common_event(current_interpreter.obj, commands)


# Command Set Label (Code 29), button_id = 21
# Code 29 (Parent) parameters { text }
func _command_0029() -> void:
	debug_print("Processing command: Set Label (code 29)")
	
	pass # This command does not need any processing


# Command Jump To Label (Code 30), button_id = 22
# Code 30 (Parent) parameters { text }
func _command_0030() -> void:
	debug_print("Processing command: Jump To Label (code 30)")
	
	# Retrieve the label name from the command parameters
	var label_name: String = current_command.parameters.get("text", "")
	
	# Check if the label name is not empty
	if label_name != "":
		var current_index = 0

		# Iterate through all commands to find the label
		while true:
			var command = current_interpreter.get_command(current_index)
			if command:
				# Check if the command is a label (Code 29)
				if command.code == 29: # Label
					# Check if the label's text matches the desired label name
					if command.parameters.get("text", "") == label_name:
						# Jump to the label's command index
						current_interpreter.go_to(current_index)
						break
			else:
				# Exit the loop if no more commands are found
				break

			# Move to the next command
			current_index += 1

	# If the label is not found, print a debug message
	debug_print("Label not found: %s" % label_name)



# Command Comment (Codes 31, 32), button_id = 23
# Code 31 (Parent) parameters: { first_line }
# Code 32 (Comment Line) parameters: { line }
func _command_0031() -> void:
	debug_print("Processing command: Comment (code 31)")
	
	# Start from the next command index
	var current_index = current_interpreter.command_index + 1
	# Get the indentation level of the current command
	var current_indent = current_command.indent

	# Initialize a variable to store the full commentary
	var full_comentary = current_command.parameters.get("first_line", "") # Retrieve the first line of the comment

	# Loop through subsequent commands to gather all comment lines
	while true:
		var command = current_interpreter.get_command(current_index) # Get the command at the current index
		if command:
			# Break the loop if the command is not a comment (Code 32) or if the indentation level changes
			if (command.indent == current_indent and not command.code == 32) or \
			command.indent != current_indent:
				break
			else:
				# Append the comment line to the full commentary
				full_comentary += "\n" + command.parameters.get("line", "")
		else:
			# Exit the loop if no more commands are found
			break

		# Move to the next command
		current_index += 1

	# Skip to the last processed command index
	current_interpreter.go_to(current_index - 1)

	if not full_comentary.empty():
		# Emit a signal containing the full commentary.
		# This signal can be utilized to display the comment in the game or handle it further.
		# For instance, it could be leveraged to process commands in a custom manner,
		# similar to how some plugins/scripts work in RPG Maker (if you are familiar with that program).
		interpreter.notes_found.emit(full_comentary)


# Command Wait (Code 33), button_id = 24
# Code 33 (Parent) parameters { duration, is_local }
func _command_0033() -> void:
	debug_print("Processing command: Wait (code 33)")
	
	# Retrieve the duration parameter from the command
	var duration = current_command.parameters.get("duration", 0)
	var is_local_wait = current_command.parameters.get("is_local", false)
	
	# Check if the duration is greater than 0 and the interpreter object exists
	if duration > 0 and current_interpreter.obj:
		# Create a timer for the specified duration and wait for it to timeout
		if current_interpreter.is_parallel() and is_local_wait:
			current_interpreter.paused = true
			var t = current_interpreter.obj.get_tree().create_timer(duration)
			t.timeout.connect(current_interpreter.set.bind("paused", false))
		else:
			await current_interpreter.obj.get_tree().create_timer(duration).timeout
