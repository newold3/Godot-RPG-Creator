class_name CommandsGroup2
extends CommandHandlerBase


# Command Change Gold (Code 12), button_id = 7
# Code 12 (Parent) parameters { operation_type, value_type, value }
func _command_0012() -> void:
	debug_print("Processing command: Change Gold (code 12)")
	# Get the operation type: 0 = increase, 1 = decrease
	var operation_type = current_command.parameters.get("operation_type", 0) 
	
	# Get the value type: 0 = fixed value, 1 = variable reference
	var value_type = current_command.parameters.get("value_type", 1) 
	
	var value: int
	if value_type == 0:
		# If value type is fixed, retrieve the fixed value
		value = current_command.parameters.get("value", 0)
	else:
		# If value type is variable, retrieve the variable ID and get its value
		var id = current_command.parameters.get("value", 1)
		value = GameManager.get_variable(id)

	# Adjust the current gold based on the operation type
	# Increase gold if operation_type is 0, otherwise decrease it
	GameManager.game_state.current_gold += value if operation_type == 0 else -value


# Command Change Items (Code 13), button_id = 8
# Code 13 (Parent) parameters { operation_type, value_type, value, item_id }
func _command_0013() -> void:
	debug_print("Processing command: Change Items (code 13)")
	
	# Get the operation type: 0 = increase, 1 = decrease
	var operation_type = current_command.parameters.get("operation_type")
	
	# Get the value type: 0 = fixed value, 1 = variable reference
	var value_type = current_command.parameters.get("value_type")
	
	# Get the item ID to modify
	var item_id = current_command.parameters.get("item_id")

	var value: int
	if value_type == 0:
		# If value type is fixed, retrieve the fixed value
		value = current_command.parameters.get("value", 0)
	else:
		# If value type is variable, retrieve the variable ID and get its value
		var id = current_command.parameters.get("value", 1)
		value = GameManager.get_variable(id)
	
	# Adjust the item amount based on the operation type
	# Increase item amount if operation_type is 0, otherwise decrease it
	if operation_type == 0:
		GameManager.add_item_amount(item_id, value)
	else:
		GameManager.remove_item_amount(item_id, value)
	
	# Refresh the map if it exists
	if GameManager.current_map:
		GameManager.current_map.need_refresh = true


# Command Change Weapons (Code 14), button_id = 9
# Code 14 (Parent) parameters { operation_type, value_type, value, item_id, include_equipment }
func _command_0014() -> void:
	debug_print("Processing command: Change Weapons (code 14)")
	
	# Get the operation type: 0 = increase, 1 = decrease
	var operation_type = current_command.parameters.get("operation_type")
	
	# Get the value type: 0 = fixed value, 1 = variable reference
	var value_type = current_command.parameters.get("value_type")
	
	# Get the weapon ID to modify
	var item_id = current_command.parameters.get("item_id")
	
	# Determine whether to include equipped weapons in the operation
	var include_equipment = current_command.parameters.get("include_equipment", false)
	
	# Current level for this weapon
	var level = current_command.parameters.get("level", 1)

	var value: int
	if value_type == 0:
		# If value type is fixed, retrieve the fixed value
		value = current_command.parameters.get("value", 0)
	else:
		# If value type is variable, retrieve the variable ID and get its value
		var id = current_command.parameters.get("value", 1)
		value = GameManager.get_variable(id)
	
	# Adjust the weapon amount based on the operation type
	# Increase weapon amount if operation_type is 0, otherwise decrease it
	if operation_type == 0:
		GameManager.add_weapon_amount(item_id, value, level)
	else:
		GameManager.remove_weapon_amount(item_id, value, include_equipment)
	
	# Refresh the map if it exists
	if GameManager.current_map:
		GameManager.current_map.need_refresh = true


# Command Change Armors (Code 15), button_id = 10
# Code 15 (Parent) parameters { operation_type, value_type, value, item_id, include_equipment }
func _command_0015() -> void:
	debug_print("Processing command: Change Armors (code 15)")
	
	# Get the operation type: 0 = increase, 1 = decrease
	var operation_type = current_command.parameters.get("operation_type")
	
	# Get the value type: 0 = fixed value, 1 = variable reference
	var value_type = current_command.parameters.get("value_type")
	
	# Get the armor ID to modify
	var item_id = current_command.parameters.get("item_id")
	
	# Determine whether to include equipped armors in the operation
	var include_equipment = current_command.parameters.get("include_equipment", false)

	# Current level for this weapon
	var level = current_command.parameters.get("level", 1)

	var value: int
	if value_type == 0:
		# If value type is fixed, retrieve the fixed value
		value = current_command.parameters.get("value", 0)
	else:
		# If value type is variable, retrieve the variable ID and get its value
		var id = current_command.parameters.get("value", 1)
		value = GameManager.get_variable(id)
		
	# Adjust the armor amount based on the operation type
	# Increase armor amount if operation_type is 0, otherwise decrease it
	if operation_type == 0:
		GameManager.add_armor_amount(item_id, value, level)
	else:
		GameManager.remove_armor_amount(item_id, value, include_equipment)
	
	# Refresh the map if it exists
	if GameManager.current_map:
		GameManager.current_map.need_refresh = true


# Command Change Party Members (Code 16), button_id = 11
# Code 16 (Parent) parameters { operation_type, actor_id, initialize }
func _command_0016() -> void:
	debug_print("Processing command: Change Party Member (code 16)")
	
	# Get the operation type: 0 = add member, 1 = remove member
	var operation_type = current_command.parameters.get("operation_type")
	
	# Get the actor ID to add or remove
	var actor_id = current_command.parameters.get("actor_id")
	
	# Determine whether to initialize the actor when adding
	var initialize = current_command.parameters.get("initialize", false)

	if operation_type == 0:
		# Add the actor to the party, initializing if specified
		GameManager.add_party_member(actor_id, initialize)
	else:
		# Remove the actor from the party
		GameManager.remove_party_member(actor_id)
	
	# Refresh the map if it exists
	if GameManager.current_map:
		GameManager.current_map.need_refresh = true


# Command Change Leader (Code 36), button_id = 109
# Code 36 (Parent) parameters { leader_id, is_locked }
func _command_0036() -> void:
	debug_print("Processing command: Change Leader (code 36)")
	
	var leader_id = current_command.parameters.get("leader_id")
	var is_locked = current_command.parameters.get("is_locked", false)

	GameManager.change_leader(leader_id, is_locked)

	if GameManager.current_map:
		GameManager.current_map.need_refresh = true


# Command Combar Experience Mode Leader (Code 60), button_id = 115
# Code 60 (Parent) parameters { type }
func _command_0060() -> void:
	debug_print("Processing command: Change Experience Mode (code 60)")
	
	var type = current_command.parameters.get("type")

	GameManager.set_combat_experience_mode_leader(type)
