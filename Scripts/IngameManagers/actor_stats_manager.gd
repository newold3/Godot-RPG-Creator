class_name ActorStatsManager
extends Node


func get_actor_parameter(actor_id: int, parameter_id: String) -> int:
	## Retrieves a specific core parameter (level, experience, or custom stat) from an actor.
	var result: int = 0
	parameter_id = parameter_id.to_lower()
	
	if GameManager.game_state.actors.has(actor_id):
		var actor: GameActor = GameManager.game_state.actors[actor_id]
		if parameter_id == "level":
			result = actor.current_level
		elif parameter_id == "experience":
			result = actor.current_experience
		elif parameter_id == "tp":
			pass 
		else:
			result = actor.get_parameter(parameter_id)
	
	return result


func get_actor_user_parameter(actor_id: int, parameter_id: int) -> float:
	## Retrieves a user-defined custom parameter from a specific actor.
	var result: float = 0.0
	
	if GameManager.game_state.actors.has(actor_id):
		var actor: GameActor = GameManager.game_state.actors[actor_id]
		result = actor.get_user_parameter(parameter_id)
		
	return result


func get_global_user_parameter(parameter_id: int) -> float:
	## Retrieves a global user parameter stored in the game state.
	var result: float = 0.0
	
	if GameManager.game_state.game_user_parameters.size() > parameter_id and parameter_id > 0:
		result = GameManager.game_state.game_user_parameters[parameter_id]
		
	return result


func set_actor_parameter(actor: GameActor, parameter_id: String, operation: int, amount: int) -> void:
	## Modifies an actor's parameter by adding, subtracting, or setting a specific value.
	parameter_id = parameter_id.to_lower()
	
	if parameter_id == "level":
		if operation == 0:
			actor.change_level(actor.current_level + amount)
		else:
			actor.change_level(actor.current_level + amount)
	elif parameter_id == "experience":
		actor.add_experience(amount)
	elif parameter_id == "tp":
		pass 
	else:
		actor.set_parameter(parameter_id, amount, operation)
	
	actor.parameter_changed.emit()


func get_enemy_parameter(enemy_id: int, parameter_id: String) -> int:
	## Retrieves a parameter value from a specific enemy in the database.
	var result: int = 0
	parameter_id = parameter_id.to_lower()
	
	if enemy_id > 0 and RPGSYSTEM.database.enemies.size() > enemy_id:
		var enemy: RPGEnemy = RPGSYSTEM.database.enemies[enemy_id]
		if parameter_id == "tp":
			pass 
		else:
			result = enemy.get_parameter(parameter_id)
	
	return result


func _get_weapon_or_armor_parameter(data: Variant, parameter: String, level: int) -> int:
	## Helper function to extract a parameter based on equipment level.
	if data is RPGWeapon or data is RPGArmor:
		return data.get_parameter(parameter, level)
	
	return 0


func get_weapon_parameter(weapon_id: int, parameter_id: String, weapon_level: int) -> int:
	## Retrieves a stat parameter from a specific weapon at a given level.
	if weapon_id > 0 and RPGSYSTEM.database.weapons.size() > weapon_id:
		return _get_weapon_or_armor_parameter(RPGSYSTEM.database.weapons[weapon_id], parameter_id, weapon_level)
		
	return 0


func get_armor_parameter(armor_id: int, parameter_id: String, armor_level: int) -> int:
	## Retrieves a stat parameter from a specific armor at a given level.
	if armor_id > 0 and RPGSYSTEM.database.armors.size() > armor_id:
		return _get_weapon_or_armor_parameter(RPGSYSTEM.database.armors[armor_id], parameter_id, armor_level)
		
	return 0


func is_actor_in_group(id: int) -> bool:
	## Checks if a specific actor ID is currently in the active party.
	if GameManager.game_state:
		for actor_id in GameManager.game_state.current_party:
			if actor_id == id:
				return true
	
	return false


func get_actor(id: int) -> GameActor:
	## Retrieves the GameActor instance from the active game state.
	if GameManager.game_state:
		for actor_id in GameManager.game_state.actors:
			if actor_id == id:
				return GameManager.game_state.actors[actor_id]
	
	return null


func get_actor_weapon(id: int) -> GameWeapon:
	## Retrieves the currently equipped weapon object for a given actor.
	if GameManager.game_state:
		for actor_id in GameManager.game_state.actors:
			if actor_id == id:
				var actor: GameActor = GameManager.game_state.actors[actor_id]
				if actor.current_gear.size() > 0:
					return actor.current_gear[0]
				else:
					return null
	
	return null


func get_actor_weapon_db(id: int) -> RPGWeapon:
	## Retrieves the database entry for the currently equipped weapon of an actor.
	if GameManager.game_state:
		for actor_id in GameManager.game_state.actors:
			if actor_id == id:
				var actor: GameActor = GameManager.game_state.actors[actor_id]
				if actor.current_gear.size() > 0:
					var weapon: GameWeapon = actor.current_gear[0]
					if RPGSYSTEM.database.weapons.size() > weapon.id:
						return RPGSYSTEM.database.weapons[weapon.id]
					else:
						return null
				else:
					return null
	
	return null


func get_real_actor(id: int) -> RPGActor:
	## Retrieves the base actor data directly from the system database.
	if id > 0 and RPGSYSTEM.database.actors.size() > id:
		return RPGSYSTEM.database.actors[id]
	
	return null


func add_party_member(actor_id: int, initialize: bool) -> void:
	## Adds an actor to the party safely. Instantiates them if they don't exist yet.
	if GameManager.game_state and not is_actor_in_group(actor_id):
		if actor_id > 0 and RPGSYSTEM.database.actors.size() > actor_id:
			GameManager.game_state.current_party.append(actor_id)

			var actor: GameActor = get_actor(actor_id)
			if not actor:
				actor = GameActor.new(actor_id)
				GameManager.game_state.actors[actor_id] = actor
				
			if initialize:
				actor.initialize()


func remove_party_member(actor_id: int) -> void:
	## Removes an actor from the active party array.
	if GameManager.game_state and is_actor_in_group(actor_id):
		for i in range(GameManager.game_state.current_party.size()):
			if GameManager.game_state.current_party[i] == actor_id:
				GameManager.game_state.current_party.remove_at(i)
				break


func change_formation(actor_id1: int, actor_id2: int) -> void:
	## Swaps the position of two actors within the active party.
	if GameManager.game_state and is_actor_in_group(actor_id1) and is_actor_in_group(actor_id2):
		if is_party_member_locked(actor_id1) or is_party_member_locked(actor_id2):
			return
			
		var p1 = GameManager.game_state.current_party.find(actor_id1)
		var p2 = GameManager.game_state.current_party.find(actor_id2)
		
		var temp = GameManager.game_state.current_party[p1]
		GameManager.game_state.current_party[p1] = GameManager.game_state.current_party[p2]
		GameManager.game_state.current_party[p2] = temp
		
		if GameManager.main_scene:
			GameManager.main_scene.update_party_visuals()


func is_party_member_locked(actor_id: int) -> bool:
	## Checks if a specific actor is locked in the party formation.
	if GameManager.game_state:
		return actor_id in GameManager.game_state.party_member_locked
		
	return false


func change_leader(leader_id: int, is_locked: bool) -> void:
	## Forces a specific actor to become the party leader and optionally locks them.
	if GameManager.game_state:
		for i in range(GameManager.game_state.current_party.size()):
			if GameManager.game_state.current_party[i] == leader_id:
				GameManager.game_state.current_party.remove_at(i)
				break
				
		GameManager.game_state.current_party.insert(0, leader_id)

		while GameManager.game_state.current_party.size() > RPGSYSTEM.database.system.party_active_members:
			GameManager.game_state.current_party.resize(GameManager.game_state.current_party.size() - 1)

		if is_locked:
			GameManager.game_state.party_member_locked.append(leader_id)
		else:
			for i in range(GameManager.game_state.party_member_locked.size()):
				if GameManager.game_state.party_member_locked[i] == leader_id:
					GameManager.game_state.party_member_locked.remove_at(i)
					break
