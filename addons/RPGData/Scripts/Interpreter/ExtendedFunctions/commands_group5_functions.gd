class_name CommandsGroup5
extends CommandHandlerBase


# Command Change Actor parameters
func _parse_actor_command_parameters(parameter_id: String) -> void:
	# Retrieve parameters from the current command
	var actor_type = current_command.parameters.get("actor_type", 0)
	var actor_id = current_command.parameters.get("actor_id", 0)
	var operand = current_command.parameters.get("operand", 0)
	var operand_type = current_command.parameters.get("operand_type", 0)
	var operand_value = current_command.parameters.get("operand_value", 0)

	# Determine the list of actor IDs based on the actor type
	var actor_ids = []
	if actor_type == 0: # Fixed value
		if actor_id == 0: # Entire Party
			actor_ids = GameManager.game_state.current_party
		else: # Specific Actor ID
			actor_ids.append(actor_id)
	elif actor_type == 1 and actor_id > 0 and GameManager.game_state.game_variables.size() > actor_id: # Variable value
		var real_actor_id = GameManager.game_state.game_variables[actor_id]
		actor_ids.append(real_actor_id)
	
	# Determine the target value based on the operand type
	var target_value = 0
	if operand_type == 0: # Fixed value
		target_value = operand_value
	elif operand_type == 1: # Variable value
		if operand_value > 0 and GameManager.game_state.game_variables.size() > operand_value:
			target_value = GameManager.game_state.game_variables[operand_value]

	# Apply the parameter change to each actor in the list
	for id in actor_ids:
		if GameManager.game_state.actors.has(id):
			var actor: GameActor = GameManager.game_state.actors[id]
			if actor:
				# Use the GameManager to set the actor's parameter
				GameManager.set_actor_parameter(
					actor, 
					parameter_id,
					operand,
					target_value
				)
	

# Command Change Actor HP (Code 37), button_id = 25
# Code 37 (Parent) parameters { actor_type, actor_id, operand, operand_type, operand_value }
func _command_0037() -> void:
	debug_print("Processing command: Change Actor HP (code 37)")

	_parse_actor_command_parameters("hp")


# Command Change Actor MP (Code 38), button_id = 26
# Code 38 (Parent) parameters { actor_type, actor_id, operand, operand_type, operand_value }
func _command_0038() -> void:
	debug_print("Processing command: Change Actor MP (code 38)")

	_parse_actor_command_parameters("mp")


# Command Change Actor TP (Code 39), button_id = 27
# Code 39 (Parent) parameters { actor_type, actor_id, operand, operand_type, operand_value }
func _command_0039() -> void:
	debug_print("Processing command: Change Actor TP (code 39)")
	
	_parse_actor_command_parameters("tp")


# Command Change Actor State (Code 40), button_id = 28
# Code 40 (Parent) parameters { actor_type, actor_id, operand, state_id }
func _command_0040() -> void:
	debug_print("Processing command: Change Actor State (code 40)")
	
	# Retrieve parameters from the current command
	var actor_type = current_command.parameters.get("actor_type", 0)
	var actor_id = current_command.parameters.get("actor_id", 0)
	var operand = current_command.parameters.get("operand", 0)
	var state_id = current_command.parameters.get("state_id", 0)
	
	# Determine the list of actor IDs based on the actor type
	var actor_ids = []
	if actor_type == 0: # Fixed value
		if actor_id == 0: # Entire Party
			actor_ids = GameManager.game_state.current_party
		else: # Specific Actor ID
			actor_ids.append(actor_id)
	elif actor_type == 1 and actor_id > 0 and GameManager.game_state.game_variables.size() > actor_id: # Variable value
		var real_actor_id = GameManager.game_state.game_variables[actor_id]
		actor_ids.append(real_actor_id)
	
	# Apply the state change to each actor in the list
	for id: int in actor_ids:
		if GameManager.game_state.actors.has(id):
			var actor: GameActor = GameManager.game_state.actors[id]
			if actor:
				if operand == 0: # Add state
					# Ensure the state ID is valid before adding it
					if state_id > 0 and RPGSYSTEM.database.states.size() > state_id:
						var real_state: RPGState = RPGSYSTEM.database.states[state_id]
						actor.add_state(real_state)
				elif operand == 1: # Remove state
					# Filter and remove the specified state from the actor's current states
					var states = actor.current_states.filter(
						func(state: GameState) -> bool:
							return state.id == state_id
					)
					for state in states:
						actor.current_states.erase(state)



# Command Actor Recover All (Code 41), button_id = 29
# Code 41 (Parent) parameters { actor_type, actor_id }
func _command_0041() -> void:
	debug_print("Processing command: Actor Recover All (code 41)")

	var actor_type = current_command.parameters.get("actor_type", 0)
	var actor_id = current_command.parameters.get("actor_id", 0)

	if actor_type == 0: # Fixed value
		if actor_id == 0: # Entery Party
			for id in GameManager.game_state.current_party:
				if GameManager.game_state.actors.has(id):
					var actor: GameActor = GameManager.game_state.actors[id]
					if actor:
						actor.recover_all()
						actor.parameter_changed.emit()
		else: # Actor ID
			if GameManager.game_state.actors.has(actor_id):
				var actor: GameActor = GameManager.game_state.actors[actor_id]
				if actor:
					actor.recover_all()
					actor.parameter_changed.emit()
	elif actor_type == 1 and actor_id > 0 and GameManager.game_state.game_variables.size() > actor_id: # variable value
		var real_actor_id = GameManager.game_state.game_variables[actor_id]
		if GameManager.game_state.actors.has(real_actor_id):
			var actor: GameActor = GameManager.game_state.actors[real_actor_id]
			if actor:
				actor.recover_all()
				actor.parameter_changed.emit()


# Command Change Actor Experience (Code 42), button_id = 30
# Code 42 (Parent) parameters { actor_type, actor_id, operand, operand_type, operand_value, show_level_up }
func _command_0042() -> void:
	debug_print("Processing command: Change Actor Experience (code 42)")

	_parse_actor_command_parameters("experience")
	var show_level_up = current_command.parameters.get("show_level_up", false) # TODO


# Command Change Actor Level (Code 43), button_id = 31
# Code 43 (Parent) parameters { actor_type, actor_id, operand, operand_type, operand_value, show_level_up }
func _command_0043() -> void:
	debug_print("Processing command: Change Actor Level (code 43)")

	_parse_actor_command_parameters("level")
	var show_level_up = current_command.parameters.get("show_level_up", false) # TODO


# Command Change Actor Parameter (Code 44), button_id = 32
# Code 44 (Parent) parameters { actor_type, actor_id, operand, operand_type, operand_value, parameter_id }
func _command_0044() -> void:
	debug_print("Processing command: Change Actor Parameter (code 44)")

	var parameters = [
		"hp", "mp", "max_hp", "max_mp", "attack", "defense",
		"magic_attack", "magic_defense", "agility", "luck"
	]
	var parameter_id = current_command.parameters.get("parameter_id", 0)
	_parse_actor_command_parameters(parameters[parameter_id])


# Command Change Actor Skill (Code 45), button_id = 33
# Code 45 (Parent) parameters { actor_type, actor_id, operand, skill_id }
func _command_0045() -> void:
	debug_print("Processing command: Change Actor Skill (code 45)")

	# Retrieve parameters from the current command
	var actor_type = current_command.parameters.get("actor_type", 0)
	var actor_id = current_command.parameters.get("actor_id", 0)
	var operand = current_command.parameters.get("operand", 0)
	var skill_id = current_command.parameters.get("skill_id", 0)

	# Ensure the skill ID is valid before proceeding
	if skill_id > 0 and RPGSYSTEM.database.skills.size() > skill_id:
		var actor_ids = []

		# Determine the list of actor IDs based on the actor type
		if actor_type == 0: # Fixed value
			if actor_id == 0: # Entire Party
				actor_ids = GameManager.game_state.current_party
			else: # Specific Actor ID
				actor_ids.append(actor_id)
		elif actor_type == 1 and actor_id > 0 and GameManager.game_state.game_variables.size() > actor_id: # Variable value
			var real_actor_id = GameManager.game_state.game_variables[actor_id]
			actor_ids.append(real_actor_id)
		
		# Apply the skill change to each actor in the list
		for id in actor_ids:
			if GameManager.game_state.actors.has(id):
				var actor: GameActor = GameManager.game_state.actors[id]
				if actor:
					if operand == 0: # Add skill
						# Add the skill if it is not already in the actor's skill lists
						if not skill_id in actor.current_skills and not skill_id in actor.extra_skills:
							actor.extra_skills.append(skill_id)
					elif operand == 1: # Remove skill
						# Remove the skill from the extra skills list if it exists
						if skill_id in actor.extra_skills:
							for i in range(actor.extra_skills.size()):
								if actor.extra_skills[i] == skill_id:
									actor.extra_skills.remove_at(i)
									break
						# Remove the skill from the current skills list if it exists
						if skill_id in actor.current_skills:
							for i in range(actor.current_skills.size()):
								if actor.current_skills[i] == skill_id:
									actor.current_skills.remove_at(i)
									break


# Command Change Actor Equipment (Code 46), button_id = 34
# Code 46 (Parent) parameters { actor_id, equipment_type_id, item_id }
func _command_0046() -> void:
	debug_print("Processing command: Change Actor Equipment (code 46)")

	# Retrieve the actor ID, equipment type, and item ID from the command parameters
	var actor_id = current_command.parameters.get("actor_id", 0)
	var equipment_type_id = current_command.parameters.get("equipment_type_id", 0)
	var item_id = current_command.parameters.get("item_id", 0)

	# Check if the actor exists in the game state
	if actor_id in GameManager.game_state.actors:
		var actor: GameActor = GameManager.game_state.actors[actor_id]

		# Change the actor's equipment based on the specified type and item
		actor.change_equipment(equipment_type_id, item_id, 1)


# Command Change Actor Name (Code 47), button_id = 35
# Code 47 (Parent) parameters { actor_id, name }
func _command_0047() -> void:
	debug_print("Processing command: Change Actor Name (code 47)")

	# Retrieve the actor ID and the new name from the command parameters
	var actor_id = current_command.parameters.get("actor_id", 0)
	var name = current_command.parameters.get("name", "")

	# Check if the actor exists in the game state
	if actor_id in GameManager.game_state.actors:
		var actor: GameActor = GameManager.game_state.actors[actor_id]
		# Update the actor's name and emit a signal to notify about the change
		actor.current_name = name
		actor.parameter_changed.emit()


# Command Change Actor Class (Code 48), button_id = 36
# Code 48 (Parent) parameters { actor_id, class_id, keep_level }
func _command_0048() -> void:
	debug_print("Processing command: Change Actor Class (code 48)")

	# Retrieve the actor ID, class ID, and whether to keep the current level from the command parameters
	var actor_id = current_command.parameters.get("actor_id", 0)
	var class_id = current_command.parameters.get("class_id", 0)
	var keep_level = current_command.parameters.get("keep_level", false)

	# Check if the actor exists in the game state
	if actor_id in GameManager.game_state.actors:
		var actor: GameActor = GameManager.game_state.actors[actor_id]
		# Change the actor's class, optionally keeping their current level
		actor.set_class(class_id, keep_level)
		# Emit a signal to notify that the actor's parameters have changed
		actor.parameter_changed.emit()


# Command Change Profession (Code 300), button_id = 128
# Code 300 (Parent) parameters { type, profession_id, reset_level, level, preserve_level, action_type }
func _command_0300() -> void:
	debug_print("Processing command: Change Profession (code 300)")

	var profession_id = current_command.parameters.get("profession_id", 1)
	var type = current_command.parameters.get("type", 0)
	
	if not profession_id in GameManager.game_state.profession_levels:
		GameManager.game_state.profession_levels[profession_id] = {"level": 1, "sub_level": 1, "available": false, "experience": 0}
	
	if type == 0:
		# Remove Profession
		GameManager.game_state.profession_levels[profession_id].available = false
		if current_command.parameters.get("reset_level", false):
			GameManager.game_state.profession_levels[profession_id].level = 1
			GameManager.game_state.profession_levels[profession_id].sub_level = 1
	else:
		# Add Profession
		GameManager.game_state.profession_levels[profession_id].available = true
		if current_command.parameters.get("action_type", 0) == 1:
			GameManager.game_state.profession_levels[profession_id].level = int(current_command.parameters.get("level", 1))
	
	if GameManager.current_map:
		GameManager.current_map.refresh_extraction_events()


# Command Upgrade Profession (Code 301), button_id = 129
# Code 301 (Parent) parameters { profession_id }
func _command_0301() -> void:
	debug_print("Processing command: Upgrade Profession (code 301)")

	var profession_id = current_command.parameters.get("profession_id", 1)
	if  profession_id > 0 and RPGSYSTEM.database.professions.size() > profession_id:
		if profession_id in GameManager.game_state.profession_levels:
			var profession = RPGSYSTEM.database.professions[profession_id]
			var level: Dictionary = GameManager.game_state.profession_levels[profession_id]
			if level.get("current_level_completed", false):
				if level.level + 1 <= profession.levels.size():
					level.sub_level = 1
					level.level += 1
					level.experience = 0
					if level.level != profession.levels.size(): # not max level reached
						level.erase("current_level_completed")
					#if profession.call_global_event_on_level_up:
						#if profession.target_global_event > 0 and RPGSYSTEM.database.common_events.size() > profession.target_global_event:
							#var global_event: RPGCommonEvent = RPGSYSTEM.database.common_events[profession.target_global_event]
							#GameInterpreter.start_common_event(null, global_event.list)



# Command Change Actor Nickname (Code 49), button_id = 37
# Code 49 (Parent) parameters { actor_id, nickname }
func _command_0049() -> void:
	debug_print("Processing command: Change Actor Nickname (code 49)")

	# Retrieve the actor ID and the new nickname from the command parameters
	var actor_id = current_command.parameters.get("actor_id", 0)
	var nickname = current_command.parameters.get("nickname", "")

	# Check if the actor exists in the game state
	if actor_id in GameManager.game_state.actors:
		var actor: GameActor = GameManager.game_state.actors[actor_id]
		# Update the actor's nickname and emit a signal to notify about the change
		actor.current_nickname = nickname
		actor.parameter_changed.emit()


# Command Change Actor Profile (Code 50, 51), button_id = 38
# Code 50 (Line 1) parameters { actor_id }
# Code 51 (All Other Lines) parameters { line }
func _command_0050() -> void:
	debug_print("Processing command: Change Actor Profile (code 50)")

	# Retrieve the actor ID and initialize a variable to store profile lines
	var actor_id = current_command.parameters.get("actor_id", 0)
	var lines: String = ""

	# Start iterating through subsequent commands to collect profile lines
	var current_index = current_interpreter.command_index + 1
	var current_indent = current_command.indent

	while true:
		
		var command = current_interpreter.get_command(current_index)
		if command:
			# Check if the command is at the same indentation level
			if command.indent == current_indent:
				if command.code == 51: # Collect additional profile lines
					if lines.is_empty():
						lines = command.parameters.get("line", "")
					else:
						lines += "\n" + command.parameters.get("line", "")
				else: # Stop if a non-profile command is encountered
					break
		else: # Stop if no more commands are found
			break

		current_index += 1

	# Update the actor's profile if the actor exists
	if actor_id in GameManager.game_state.actors:
		var actor: GameActor = GameManager.game_state.actors[actor_id]
		actor.current_profile = lines
		actor.parameter_changed.emit()
	
	# Adjust the interpreter's command index to the last processed command
	current_interpreter.go_to(current_index - 1)


# Command Add Or Remove Trait (Code 62), button_id = 114
# Code 62 parameters { actor_id, type, RPGTrait }
func _command_0062() -> void:
	debug_print("Processing command: Add Or Remove Trait (code 62)")

	# Retrieve the actor ID, type of operation (add/remove), and the trait to modify
	var actor_id = current_command.parameters.get("actor_id", 0)
	var type = current_command.parameters.get("type", 0)
	var tr: RPGTrait = current_command.parameters.get("RPGTrait", null)

	# Ensure the trait is valid before proceeding
	if tr:
		if actor_id == 0: # Apply to the entire party
			for id in GameManager.game_state.current_party:
				if GameManager.game_state.actors.has(id):
					var actor: GameActor = GameManager.game_state.actors[id]
					if actor:
						# Add or remove the trait based on the type parameter
						if type == 0: # Add Trait
							actor.add_trait(tr)
						elif type == 1: # Remove Trait
							actor.remove_trait(tr)
		else: # Apply to a specific actor by ID
			if GameManager.game_state.actors.has(actor_id):
				var actor: GameActor = GameManager.game_state.actors[actor_id]
				if actor:
					# Add or remove the trait based on the type parameter
					if type == 0: # Add Trait
						actor.add_trait(tr)
					elif type == 1: # Remove Trait
						actor.remove_trait(tr)
