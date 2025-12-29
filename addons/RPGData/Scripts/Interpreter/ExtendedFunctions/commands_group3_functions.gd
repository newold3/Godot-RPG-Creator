class_name CommandsGroup3
extends CommandHandlerBase


# Command Control Switches (Code 17), button_id = 12
# Code 17 (Parent) parameters { operation_type, from, to }
func _command_0017() -> void:
	debug_print("Processing command: Contros Switches (code 17)")
	
	# Retrieve the operation type (0 = ON, 1 = OFF) and the range of switches to modify
	var operation_type = current_command.parameters.get("operation_type", 0)
	var from = current_command.parameters.get("from", 1)
	var to = current_command.parameters.get("to", from)
	
	# Generate a script to iterate over the specified range of switches and set their values
	var script: String = ""
	script += "for i in range(%s, %s, 1): " % [from, to + 1]
	script += "\n\tif GameManager.game_state.game_switches.size() > i: "
	script += "\n\t\tGameManager.game_state.game_switches[i] = %s" % (true if operation_type == 0 else false)

	# Execute the generated script
	interpreter.code_eval.execute(script)

	# Refresh the current map if it exists
	if GameManager.current_map:
		GameManager.current_map.need_refresh = true
		await GameManager.current_map.get_tree().process_frame
		await GameManager.current_map.get_tree().process_frame
		await GameManager.current_map.get_tree().process_frame


# Command Control Variables (Code 18), button_id = 13
# Code 18 (Parent) parameters { from, to, operation_type, operand_type, value1, value2, value3 }
func _command_0018() -> void:
	debug_print("Processing command: Control Numeric Variables (code 18)")
	
	# Define the list of operations that can be performed on variables
	var operations = ["=", "+=", "-=", "*=", "/=", "%=",]
	
	# Retrieve the range of variables to modify
	var from = current_command.parameters.get("from", 1)
	var to = current_command.parameters.get("to", from)
	
	# Retrieve the operation type and clamp it to the valid range of operations
	var operation_type = clamp(current_command.parameters.get("operation_type", 0), 0, operations.size() - 1)
	
	# Retrieve the operand type and values used for the operation
	var operand_type = current_command.parameters.get("operand_type", 0)
	var value1 = current_command.parameters.get("value1", null)
	var value2 = current_command.parameters.get("value2", null)
	var value3 = current_command.parameters.get("value3", null)
	
	# Initialize the target value to be used in the operation
	var target_value: int = 0

	match operand_type:
		0: # Set fixed value
			target_value = value1
		1: # Set variable value
			if GameManager.game_state.game_variables.size() > value1:
				target_value =  GameManager.game_state.game_variables[value1]
		2: # Set Random Value
			target_value = randi_range(value1, value2)
		3: # Game Data
			match value1:
				0: # Item
					target_value = GameManager.get_item_amount(value2)
				1: # Weapon
					target_value = GameManager.get_weapon_amount(value2)
				2: # Armor
					target_value = GameManager.get_armor_amount(value2)
				3: # Actor
					var parameters = PackedStringArray(["Level", "Experience"]) + RPGSYSTEM.database.types.main_parameters
					if value3 >= 0 and value3 < parameters.size():
						target_value = GameManager.get_actor_parameter(value2, parameters[value3])
					elif value3 > parameters.size(): # user paramater
						var user_parameter_id = value3 - parameters.size() - 1
						target_value = GameManager.get_actor_user_parameter(value2, user_parameter_id)
				4: # Enemy
					var parameters = [
						"hp", "mp", "max_hp", "max_mp", "attack", "defense",
						"magic_attack", "magic_defense", "agility", "luck", "tp"
					]
					if value3 >= 0 and value3 < parameters.size():
						target_value = GameManager.get_enemy_parameter(value2, parameters[value3])
				5: # Character
					var current_target = GameManager.current_player if value2 == 0 else current_interpreter.obj
					if current_target:
						match value3:
							0: # Map X
								target_value = current_target.get_current_tile().x
							1: # Map Y
								target_value = current_target.get_current_tile().y
							2: # Direction
								if current_target == GameManager.current_player:
									target_value = GameManager.game_state.player.current_direction
							3: # Screen X
								target_value = current_target.get_global_transform_with_canvas().origin.x
							4: # Screen Y
								target_value = current_target.get_global_transform_with_canvas().origin.y
							5: # Global Position X
								target_value = current_target.get_global_transform().origin.x
							6: # Global Position Y
								target_value = current_target.get_global_transform().origin.y
							7: # Z-Index
								target_value = current_target.z_index
				6: # Party Member
					if GameManager.game_state.current_party.size() > value2:
						target_value = GameManager.game_state.current_party[value2]
				7: # Last Action Performed
					match value2:
						0: # ID of the Last Used Skill
							target_value = GameManager.battle_last_actions.last_used_skill_id
						1: # ID of the Last Used Item
							target_value = GameManager.battle_last_actions.last_used_item_id
						2: # ID of the Last Actor to Act
							target_value = GameManager.battle_last_actions.last_actor_to_act_id
						3: # ID of the Last Enemy Battler to Act
							target_value = GameManager.battle_last_actions.last_enemy_to_act_id
						4: # ID of the Last Targeted Actor
							target_value = GameManager.battle_last_actions.last_targeted_actor_id
						5: # ID of the Last Targeted Enemy
							target_value = GameManager.battle_last_actions.last_targeted_enemy_id
				8: # Other
					match value2:
						0: # Current Map ID
							if GameManager.current_map:
								target_value = GameManager.current_map.internal_id
						1: # Party Member Count
							target_value = GameManager.game_state.current_party.size()
						2: # Gold
							target_value = GameManager.game_state.current_gold
						3: # Steps
							target_value = GameManager.game_state.stats.steps
						4: # Play Time
							target_value = GameManager.game_state.stats.play_time
						5: # Current Timer Value
							target_value = GameManager.game_state.current_timer
						6: # Save Count
							target_value = GameManager.game_state.stats.save_count
						7: # Battle Count
							target_value = GameManager.game_state.stats.battles.total_played
						8: # Win Count
							target_value = GameManager.game_state.stats.battles.won
						9: # Escape Count
							target_value = GameManager.game_state.stats.battles.escaped
						10: # Quests Failed
							target_value = GameManager.game_state.stats.missions.failed
						11: # Quests in Progress
							target_value = GameManager.game_state.stats.missions.in_progress
						12: # Total Completed Quest
							target_value = GameManager.game_state.stats.missions.completed
						13: # Total Enemy Kills
							target_value = GameManager.game_state.stats.enemy_kills.get(value2, 0)
						14: # Total Money Earned
							target_value = GameManager.game_state.stats.total_money_earned
						15: # Total Quest Found
							target_value = GameManager.game_state.stats.missions.total_found
						16: # Total Relationships Started
							target_value = GameManager.game_state.stats.relationships.size()
						17: # Total Relationships Maximized
							target_value = GameManager.game_state.stats.relationships.values().filter(
								func(relationship: GameRelationship):
									return relationship.current_level >= relationship.max_level
							).size()
						18: # Total Archievements Unlocked
							target_value = GameManager.game_state.stats.achievements.size()
						19: # Global User Parameter
							if GameManager.game_state.game_user_parameters > value3 and value3 > 0:
								target_value = GameManager.game_state.game_user_parameters[value3]
				9: # Level Profession
					if value2 > 0 and RPGSYSTEM.database.professions.size() > value2:
						var profession = RPGSYSTEM.database.professions[value2]
						target_value = GameManager.get_profession_level(profession)
				10: # stat
					match value2:
						0: # steps
							target_value = GameManager.game_state.stats.steps
						1: # play time
							target_value = GameManager.game_state.stats.play_time
						2: # Enemy
							target_value = GameManager.game_state.stats.enemy_kills.get(value2, 0)
						3: # Skill
							target_value = GameManager.game_state.stats.skills.get(value2, 0)
						4, 5, 6: # items sold, purchased and found
							var stat_value_id = "0_" + str(value3)
							if value2 == 4:
								target_value = GameManager.game_state.stats.items_sold.get(stat_value_id, 0)
							elif value2 == 5:
								target_value = GameManager.game_state.stats.items_purchased.get(stat_value_id, 0)
							else:
								target_value = GameManager.game_state.stats.items_found.get(stat_value_id, 0)
						7, 8, 9: # weapons sold, purchased and found
							var stat_value_id = "1_" + str(value3)
							if value2 == 7:
								target_value = GameManager.game_state.stats.items_sold.get(stat_value_id, 0)
							elif value2 == 8:
								target_value = GameManager.game_state.stats.items_purchased.get(stat_value_id, 0)
							else:
								target_value = GameManager.game_state.stats.items_found.get(stat_value_id, 0)
						10, 11, 12: # armors sold, purchased and found
							var stat_value_id = "2_" + str(value3)
							if value2 == 10:
								target_value = GameManager.game_state.stats.items_sold.get(stat_value_id, 0)
							elif value2 == 11:
								target_value = GameManager.game_state.stats.items_purchased.get(stat_value_id, 0)
							else:
								target_value = GameManager.game_state.stats.items_found.get(stat_value_id, 0)
						13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30: # battle
							var stats = GameManager.game_state.stats.battles
							var option = [
								"won", "lost", "drawn", "escaped", "total_played",
								"current_win_streak", "longest_win_streak", "current_lose_streak",
								"longest_lose_streak", "longest_battle_time", "shortest_battle_time",
								"total_combat_turns", "total_time_in_battle", "total_experience_earned",
								"total_damage_received", "total_damage_done",
								"total_used_skills", "total_critiques_performed"
							][value2 - 13]
							target_value = stats.get(option)
						31: # Total items extracted with a profession
							var stats = GameManager.game_state.stats.extractions.items_found.get(value3, {})
							target_value = 0
							for item: Dictionary in stats.values():
								for quantity: int in item.values():
									target_value += quantity
						32, 33, 34, 35, 36, 37, 38: # extraction
							var stats = GameManager.game_state.stats.extractions
							var option = [
								"total_success", "total_failure",
								"total_finished", "total_unfinished", "critical_performs",
								"super_critical_performs", "resources_interactions"
							][value2 - 32]
							target_value = stats.get(option)
						39, 40, 41, 42, 43, 44, 45, 46, 47, 48: # others
							var option = [
								"save_count", "game_progress", "total_money_earned",
								"total_money_spent", "player_deaths", "chests_opened",
								"secrets_found", "max_level_reached", "dialogues_completed", "rare_items_found"
							][value2 - 39]
							target_value = GameManager.game_state.stats[option]
						49, 50, 51, 52: # mission
							var stats = GameManager.game_state.stats.missions
							var option = [
								"completed", "in_progress", "failed", "total_found"
							][value2 - 49]
							target_value = stats.get(option)
						_: # User stat
							var base_options = [
								"steps", "play_time", "enemy_kills", "skills",
								"items_sold", "items_purchased", "items_found",
								"weapons_sold", "weapons_purchased", "weapons_found",
								"armors_sold", "armors_purchased", "armors_found",
								"battles/won", "battles/lost", "battles/drawn", "battles/escaped", "battles/total_played",
								"battles/current_win_streak", "battles/longest_win_streak", "battles/current_lose_streak",
								"battles/longest_lose_streak", "battles/longest_battle_time", "battles/shortest_battle_time",
								"battles/total_combat_turns", "battles/total_time_in_battle", "battles/total_experience_earned",
								"battles/total_damage_received", "battles/total_damage_done",
								"battles/total_used_skills", "battles/total_critiques_performed",
								"extractions/total_items_found", "extractions/total_success", "extractions/total_failure",
								"extractions/total_finished", "extractions/total_unfinished", "extractions/critical_performs",
								"extractions/super_critical_performs", "extractions/resources_interactions",
								"save_count", "game_progress", "total_money_earned", "total_money_spent", "player_deaths", "chests_opened", "secrets_found", "max_level_reached", "dialogues_completed", "rare_items_found",
								"missions/completed", "missions/in_progress", "missions/failed", "missions/total_found"
							]
							var user_stat_id = value2 - base_options.size() - 1
							var stat: String
							if user_stat_id >= 0 and RPGSYSTEM.database.types.user_stats.size() > user_stat_id:
								stat = RPGSYSTEM.database.types.user_stats[user_stat_id]
							else:
								stat = ""
							if stat:
								target_value = GameManager.game_state.stats.user_stats.get(stat, 0)
					
		4: # Script
			var code = value1.replace("\\n", "\n").replace("\\t", "\t")
			var result: int = str(interpreter.code_eval.execute(code)).to_int()
			target_value = result
	
	# Check for division or modulo by zero errors
	if target_value == 0 and [4, 5].has(operation_type):
		debug_print(str(["Error: Division or Modulo by Zero", GameInterpreter.current_command, GameInterpreter.current_interpreter.obj]))
	else:
		# Generate a script to iterate over the specified range of variables and apply the operation
		var script: String = ""
		script += "for i in range(%s, %s, 1): " % [from, to + 1]
		script += "\n\tif GameManager.game_state.game_variables.size() > i: "
		script += "\n\t\tGameManager.game_state.game_variables[i] %s " % operations[operation_type]
		script += str(target_value)
		#print(script)  # Debug: Print the generated script
		interpreter.code_eval.execute(script)  # Execute the generated script
	
	# Refresh the current map if it exists
	if GameManager.current_map:
		GameManager.current_map.need_refresh = true
		await GameManager.current_map.get_tree().process_frame
		await GameManager.current_map.get_tree().process_frame
		await GameManager.current_map.get_tree().process_frame

# Command Text Variable (Code 61), button_id = 113
# Code 61 (Parent) parameters { id, value }
func _command_0061() -> void:
	debug_print("Processing command: Control Text Variable (code 61)")
	
	var id = current_command.parameters.get("id", 0)
	var value = current_command.parameters.get("value", "")
	
	if GameManager.game_state.game_text_variables.size() > id:
		GameManager.game_state.game_text_variables[id] = value


# Command Control Self Switches (Code 19), button_id = 14
# Code 19 (Parent) parameters { operation_type, switch_id }
func _command_0019() -> void:
	debug_print("Processing command: Control Self Switches (code 19)")
	
	var operation_type = current_command.parameters.get("operation_type", 0)
	var switch_id = current_command.parameters.get("switch_id", 0)
	
	if GameManager.current_map:
		var map_id = GameManager.current_map.internal_id
		var switch_name = RPGSYSTEM.system.self_switches.get_self_switch_name(switch_id)
		if switch_name:
			var switch_key = "%s_%s" % [map_id, switch_id]
			GameManager.game_state.game_self_switches[switch_key] = operation_type == 0
			GameManager.current_map.need_refresh = true
			await GameManager.current_map.get_tree().process_frame
			await GameManager.current_map.get_tree().process_frame
			await GameManager.current_map.get_tree().process_frame


# Command Change User Parameter (Code 302), button_id = 130
# Code 302 (Parent) parameters { param_id, value }
func _command_0302() -> void:
	debug_print("Processing command: Change User Parameter (code 302)")
	
	var target_id = current_command.parameters.get("target_id", 0)
	var param_id = current_command.parameters.get("param_id", 1)
	var value = current_command.parameters.get("value", 0)
	
	if GameManager.game_state.game_user_parameters.size() != RPGSYSTEM.database.types.user_parameters.size():
		GameManager.game_state.game_user_parameters.resize(RPGSYSTEM.database.types.user_parameters.size())
	
	if param_id > 0 and GameManager.game_state.game_user_parameters.size() > param_id:
		if target_id == 0:
			GameManager.game_state.game_user_parameters[param_id] = value
		elif RPGSYSTEM.database.actors.size() > target_id:
			var actor: GameActor = GameManager.get_actor(target_id)
			if actor.user_params.size() != RPGSYSTEM.database.types.user_parameters.size():
				actor.user_params.resize(RPGSYSTEM.database.types.user_parameters.size())
			if actor and actor.user_params.size() > param_id:
				actor.user_params[param_id] = value


# Command Change Stat Value (Code 303), button_id = 131
# Code 303 (Parent) parameters { param_id, value }
func _command_0303() -> void:
	debug_print("Processing command: Change Stat Value (code 303)")
	
	var stat_id = current_command.parameters.get("stat_id", 1)
	var value = current_command.parameters.get("value", 1)
	
	var default_stats = ["", "chests_opened", "secrets_found", "rare_items_found"]
	
	if stat_id < default_stats.size() and stat_id > 0:
		GameManager.game_state.stats[default_stats[stat_id]] += value
	
	else:
		var user_stat_id = stat_id - default_stats.size() - 1
		if user_stat_id >= 0 and RPGSYSTEM.database.types.user_stats.size() > user_stat_id:
			var stat: String = RPGSYSTEM.database.types.user_stats[user_stat_id]
			if stat:
				if not stat in GameManager.game_state.stats.user_stats:
					GameManager.game_state.stats.user_stats[stat] = 0
				GameManager.game_state.stats.user_stats[stat] += value


# Command Control Timer Dialog (Code 20), button_id = 15
# Code 20 (Parent) parameters { operation_type, minutes, seconds, timer_scene, timer_id, timer_title, extra_config }
func _command_0020() -> void:
	debug_print("Processing command: Control Timer (code 20)")

	GameManager.manage_timer(current_command.parameters)


# Command Manage Quest (Code xxx), button_id = 125
# Code xxx (Parent) parameters { }
