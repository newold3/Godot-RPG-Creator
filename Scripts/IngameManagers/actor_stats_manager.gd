class_name ActorStatsManager
extends Node


enum SCOPE {
	NONE,
	ONE,
	ALL,
	RANDOM
}


func get_actor_parameter(actor_id: int, parameter_id: String) -> int:
	## Retrieves a specific core parameter (level, experience, or custom stat) from an actor.
	var result: int = 0
	parameter_id = parameter_id.to_lower()
	var actor = get_actor(actor_id)
	
	if actor:
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
	
	var actor = get_actor(actor_id)
	if actor:
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
		if operation == 0: # Add
			actor.change_level(actor.current_level + amount)
		elif operation == 1: # Subtract
			actor.change_level(max(1, actor.current_level - amount))
	elif parameter_id == "experience":
		actor.add_experience(amount)
	elif parameter_id == "tp":
		pass 
	else:
		actor.set_parameter(parameter_id, amount, operation)
	
	actor.parameter_changed.emit()


func get_skills_for_actor(actor: GameActor, _sort_mode: int = 0) -> Array:
	var items: Array = []
	if not actor: 
		return items
	var raw_skills = actor.get_skills()
	for skill_id in raw_skills:
		var skill_info = raw_skills[skill_id]
		var real_skill: RPGSkill = actor.get_real_skill(skill_id)
		if not real_skill:
			continue
		var mp_cost = real_skill.mp_cost if "mp_cost" in real_skill else 0
		var usable_in_menu = true
		if "occasion" in real_skill:
			var occasion = real_skill.occasion
			usable_in_menu = RPGActionManager.Ocassion.ALWAYS or occasion ==  RPGActionManager.Ocassion.MENU_SCREEN or (GameManager.is_on_battle and occasion ==  RPGActionManager.Ocassion.BATTLE_SCREEN)
		var current_mp = actor.get_parameter("mp")
		var has_enough_mp = current_mp >= mp_cost
		var is_disabled = skill_info.get("sealed", false) or not usable_in_menu or not has_enough_mp
		var dict_item = {
			"item": null,
			"real_item": real_skill,
			"name": skill_info.get("name", ""),
			"icon": skill_info.get("icon"),
			"item_color": Color.WHITE,
			"quantity": 0,
			"item_type": 5,
			"item_id": skill_info.get("id", 0),
			"is_disabled": is_disabled,
			"is_new": false,
			"date_added": 0,
			"is_perishable": false,
			"mp_cost": mp_cost,
			"description": skill_info.get("description", "")
		}
		if "occasion" in real_skill:
			var scope: RPGScope = real_skill.scope
			var target_id = SCOPE.ONE if scope.number == 0 \
				else SCOPE.ALL if scope.number == 1 \
				else SCOPE.RANDOM
			var targets_amount = scope.random
			dict_item["target_id"] = target_id
			dict_item["targets_amount"] = targets_amount
		items.append(dict_item)
	var sort_func: Callable = func(a, b):
		if a.is_disabled != b.is_disabled: return not a.is_disabled
		return a.name.nocasecmp_to(b.name) < 0
	items.sort_custom(sort_func)
	return items


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
	var weapon = RPGSYSTEM.get_data("weapons", weapon_id)
	if weapon:
		return _get_weapon_or_armor_parameter(weapon, parameter_id, weapon_level)
		
	return 0


func get_armor_parameter(armor_id: int, parameter_id: String, armor_level: int) -> int:
	## Retrieves a stat parameter from a specific armor at a given level.
	var armor = RPGSYSTEM.get_data("armors", armor_id)
	if armor:
		return _get_weapon_or_armor_parameter(armor, parameter_id, armor_level)
		
	return 0


func is_actor_in_group(id: int) -> bool:
	## Checks if a specific actor ID is currently in the active party.
	if GameManager.game_state:
		var uid = RPGSYSTEM.id_to_uid("actors", id)
		for actor_id in GameManager.game_state.current_party:
			if actor_id == id or actor_id == uid:
				return true
	
	return false


func get_actor(id: int) -> GameActor:
	## Retrieves the GameActor instance from the active game state.
	if GameManager.game_state:
		var uid = RPGSYSTEM.id_to_uid("actors", id)

		if id in GameManager.game_state.actors:
			return GameManager.game_state.actors[id]
		elif uid in GameManager.game_state.actors:
			return GameManager.game_state.actors[uid]
	
	return null


func get_actor_weapon(id: int) -> GameWeapon:
	## Retrieves the currently equipped weapon object for a given actor.
	var actor: GameActor = get_actor(id)
	if actor:
		if actor.current_gear.size() > 0:
			return actor.current_gear[0]
	
	return null


func get_actor_weapon_db(id: int) -> RPGWeapon:
	## Retrieves the database entry for the currently equipped weapon of an actor.
	var actor: GameActor = get_actor(id)
	if actor.current_gear.size() > 0:
		var weapon: GameWeapon = actor.current_gear[0]
		var real_weapon = RPGSYSTEM.get_data("weapons", weapon.id)
		return real_weapon
	
	return null


func get_real_actor(id: int) -> RPGActor:
	## Retrieves the base actor data directly from the system database.
	var actor: RPGActor = RPGSYSTEM.get_data("actors", id)
	return actor


func add_party_member(actor_id: int, initialize: bool) -> void:
	## Adds an actor to the party safely. Instantiates them if they don't exist yet.
	if GameManager.game_state and not is_actor_in_group(actor_id):
		var actor: GameActor = get_actor(actor_id)
		
		if not actor:
			var uid = RPGSYSTEM.id_to_uid("actors", actor_id)
			var real_actor = RPGSYSTEM.get_data("actors", uid)
			if real_actor:
				actor = GameActor.new(uid)
				GameManager.game_state.actors[uid] = actor
				
		if actor:
			GameManager.game_state.current_party.append(actor.id)
				
			if initialize:
				actor.initialize()


func remove_party_member(actor_id: int) -> void:
	## Removes an actor from the active party array.
	if GameManager.game_state and is_actor_in_group(actor_id):
		var uid = RPGSYSTEM.id_to_uid("actors", actor_id)
		for i in range(GameManager.game_state.current_party.size()):
			if GameManager.game_state.current_party[i] == actor_id or \
				GameManager.game_state.current_party[i] == uid:
				GameManager.game_state.current_party.remove_at(i)
				break


func change_formation(actor_id1: int, actor_id2: int) -> void:
	## Swaps the position of two actors within the active party.
	if GameManager.game_state and is_actor_in_group(actor_id1) and is_actor_in_group(actor_id2):
		if is_party_member_locked(actor_id1) or is_party_member_locked(actor_id2):
			return
			
		var p1 = GameManager.game_state.current_party.find(actor_id1)
		if p1 == -1:
			var uid = RPGSYSTEM.id_to_uid("actors", actor_id1)
			p1 = GameManager.game_state.current_party.find(uid)
		var p2 = GameManager.game_state.current_party.find(actor_id2)
		if p2 == -1:
			var uid = RPGSYSTEM.id_to_uid("actors", actor_id2)
			p2 = GameManager.game_state.current_party.find(uid)
		
		if p1 == -1 or p2 == -1: return
		
		var temp = GameManager.game_state.current_party[p1]
		GameManager.game_state.current_party[p1] = GameManager.game_state.current_party[p2]
		GameManager.game_state.current_party[p2] = temp
		
		if GameManager.main_scene:
			GameManager.main_scene.update_party_visuals()


func is_party_member_locked(actor_id: int) -> bool:
	## Checks if a specific actor is locked in the party formation.
	if GameManager.game_state:
		var uid = RPGSYSTEM.id_to_uid("actors", actor_id)
		return actor_id in GameManager.game_state.party_member_locked or uid in GameManager.game_state.party_member_locked
		
	return false


func change_leader(leader_id: int, is_locked: bool) -> void:
	## Forces a specific actor to become the party leader and optionally locks them.
	var leader_uid = RPGSYSTEM.id_to_uid("actors", leader_id)
	if GameManager.game_state:
		for i in range(GameManager.game_state.current_party.size()):
			var uid = RPGSYSTEM.id_to_uid("actors", GameManager.game_state.current_party[i])
			if GameManager.game_state.current_party[i] == leader_uid or uid == leader_uid:
				GameManager.game_state.current_party.remove_at(i)
				break
				
		GameManager.game_state.current_party.insert(0, leader_uid)

		while GameManager.game_state.current_party.size() > RPGSYSTEM.database.system.party_active_members:
			GameManager.game_state.current_party.resize(GameManager.game_state.current_party.size() - 1)

		if is_locked:
			GameManager.game_state.party_member_locked.append(leader_uid)
		else:
			for i in range(GameManager.game_state.party_member_locked.size()):
				if GameManager.game_state.party_member_locked[i] == leader_uid:
					GameManager.game_state.party_member_locked.remove_at(i)
					break
