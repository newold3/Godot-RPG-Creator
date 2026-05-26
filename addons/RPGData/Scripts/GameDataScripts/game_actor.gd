class_name GameActor
extends GameBattler

## Represents a playable character instance within the game.
##
## Inherits from GameBattler for combat logic but handles its own specific
## mechanics like classes, experience, level progression, and inventory management.

#region Variables
## ID of the actor’s class from the database (-1 = invalid).
@export var current_class: int = -1

## Array of currently equipped gear (index 0 = weapon, others = armor slots).
@export var current_gear: Array = []

## Current set or costume applied to the actor.
@export var current_set: Variant = null

## Actor’s nickname or title.
@export var current_nickname: String = ""

## Actor’s biography or profile description.
@export var current_profile: String = ""

## Actor’s total experience points.
@export var current_experience: int = 0

## Actor’s current level.
@export var current_level: int = 0

## Actor’s current facing direction.
@export var current_direction: LPCCharacter.DIRECTIONS = LPCCharacter.DIRECTIONS.DOWN

var is_comparation_enabled: bool = false
#endregion



#region Initialization
func _init(_id: int = 1) -> void:
	if GameManager.cancel_actors_initialize:
		return
	
	var actor_data: RPGActor = RPGSYSTEM.get_data("actors", _id)
	
	if actor_data:
		id = _id
		current_name = actor_data.name
		current_nickname = actor_data.nickname
		current_profile = actor_data.profile
		current_class = actor_data.class_id
		current_level = max(1, min(actor_data.initial_level, actor_data.max_level))
		
		if user_params.size() != RPGSYSTEM.database.types.user_parameters.size():
			user_params.resize(RPGSYSTEM.database.types.user_parameters.size())
		
		for i in RPGSYSTEM.database.types.user_parameters.size():
			user_params[i] = RPGSYSTEM.database.types.user_parameters[i].default_value
			
		_change_class(actor_data.class_id, false, true)
		_init_equipment(actor_data)
		_validate_equipment()
		recover_all()


## Initializes the actor using its ID and loads its base data.
func initialize(_id: int = 1) -> void:
	_init(_id)


## Refreshes the actor data against the current database version.
func refresh_actor_data() -> void:
	var actor_data: RPGActor = get_real_actor()
	
	if not actor_data:
		is_valid = false
		return
	
	var db_params_size = RPGSYSTEM.database.types.user_parameters.size()

	if user_params.size() != db_params_size:
		var old_size = user_params.size()
		user_params.resize(db_params_size)
		for i in range(old_size, db_params_size):
			user_params[i] = RPGSYSTEM.database.types.user_parameters[i].default_value

	trait_list.clear()
	
	for tr: RPGTrait in actor_data.traits:
		trait_list.append(tr.clone(true))

	current_states = current_states.filter(func(state): return state and not state.is_permanent())
	
	_validate_equipment()
	restore_permanent_states_after_battle()
	parameter_changed.emit()
#endregion



#region Parameters And Traits
## Internal: Implementation of base parameter retrieval for actors.
func _get_base_parameter(search_param: String) -> float:
	var value = super._get_base_parameter(search_param)
	var class_data = get_real_class()
	
	if class_data:
		if search_param in RPGActor.BaseParamType.keys():
			var p_id = RPGActor.BaseParamType[search_param]
			
			if class_data.params[p_id].data.size() > current_level:
				value = float(class_data.params[p_id].data[current_level])
				
			for gear in current_gear:
				if gear and gear.id > 0:
					var real_data = gear.get_real_data() 
					if real_data and real_data.has_method("get_parameter"):
						value += real_data.get_parameter(search_param, gear.current_level)
						
			if current_set:
				var real_data = current_set.get_real_data()
				if real_data and real_data.has_method("get_parameter"):
					value += real_data.get_parameter(search_param, 1)
		
		elif search_param == "LEVEL":
			value = float(current_level)
		
		elif search_param == "EXPERIENCE":
			value = float(current_experience)
		
		elif search_param.begins_with("USER_PARAMETER_"):
			var u_id = search_param.replace("USER_PARAMETER_", "").to_int()
			if user_params.size() > u_id and u_id >= 0:
				value = float(user_params[u_id])
				
	return value


## Internal: Implementation of extra traits from gear and class.
func _get_extra_traits() -> Array:
	var extra = []
	var class_data = get_real_class()
	
	if class_data:
		extra.append_array(class_data.traits)
		
	for gear in current_gear:
		if gear:
			var real_data = gear.get_real_data()
			if real_data:
				extra.append_array(real_data.traits)
				
	if current_set:
		var real_data = current_set.get_real_data()
		if real_data:
			extra.append_array(real_data.traits)
				
	return extra


## Re-evaluates and applies all permanent states from gear and class.
func restore_permanent_states_after_battle() -> void:
	var states_to_erase = current_states.filter(func(s: GameState): return s != null and s.is_permanent())
	
	for state in states_to_erase:
		current_states.erase(state)
	
	var actor_data = get_real_actor()
	var class_data = get_real_class()
	
	if actor_data:
		for t in actor_data.traits:
			if t.code == TraitCode.ADD_STATE: add_trait_state(t)
			
	if class_data:
		for t in class_data.traits:
			if t.code == TraitCode.ADD_STATE: add_trait_state(t)
			
	for gear in current_gear:
		if gear:
			var real_data = gear.get_real_data()
			if real_data:
				for t in real_data.traits:
					if t.code == TraitCode.ADD_STATE: add_trait_state(t)
					
	if current_set:
		var real_data = current_set.get_real_data()
		if real_data:
			for t in real_data.traits:
				if t.code == TraitCode.ADD_STATE: add_trait_state(t)
	
	parameter_changed.emit()
	emit_changed()

#endregion



#region Class And Core Lookups
## Changes the actor’s class and reinitializes stats and level.
func _change_class(class_id: int, keep_level: bool = false, clear_traits: bool = true) -> void:
	var actor_data = get_real_actor()
	
	if not actor_data: 
		return
	
	if clear_traits:
		trait_list.clear()
		for tr: RPGTrait in actor_data.traits:
			trait_list.append(tr.clone(true))
			
	var class_data: RPGClass = RPGSYSTEM.get_data("classes", class_id)
	
	if class_data:
		current_class = class_id
		
		if not keep_level:
			current_level = max(1, min(actor_data.initial_level, class_data.max_level))
			current_experience = max(class_data.get_parameter("experience", current_level), current_experience)
		else:
			current_level = max(1, min(current_level, class_data.max_level))
			current_experience = class_data.get_parameter("experience", current_level)
		
		restore_permanent_states_after_battle()
		recover_all()


## Sets the actor’s class by calling _change_class.
func set_class(class_id: int, keep_level: bool) -> void:
	_change_class(class_id, keep_level)


## Returns the real RPGClass data from database.
func get_real_class() -> RPGClass:
	return RPGSYSTEM.get_data("classes", current_class)


## Returns the real RPGActor data from database.
func get_real_actor() -> RPGActor:
	return RPGSYSTEM.get_data("actors", id)


## Returns the real RPGSkill data from database.
func get_real_skill(skill_id: int) -> RPGSkill:
	return RPGSYSTEM.get_data("skills", skill_id)
#endregion



#region Equipment
## Initializes the actor’s equipment based on database loadout.
func _init_equipment(actor_data: RPGActor) -> void:
	if not GameManager.game_state: 
		return

	current_gear.clear()
	current_gear.resize(RPGSYSTEM.database.types.equipment_types.size())
	
	var weapon_id = actor_data.equipment[0] if actor_data.equipment.size() > 0 else -1
	var weapon_level = actor_data.equipment_level[0] if actor_data.equipment_level.size() > 0 else -1
	var weapon: RPGWeapon = RPGSYSTEM.get_data("weapons", weapon_id)
	
	if weapon:
		var new_weapon = GameWeapon.new(weapon_id, 1, 1)
		new_weapon.current_level = weapon_level
		new_weapon.equipped = true
		new_weapon.total_equipped += 1
		current_gear[0] = new_weapon
		
		if not GameManager.game_state.weapons.has(weapon_id):
			GameManager.game_state.weapons[weapon_id] = []
			
		GameManager.game_state.weapons[weapon_id].append(new_weapon)
	
	for i in range(1, actor_data.equipment.size()):
		var armor_id = actor_data.equipment[i]
		var armor_level = actor_data.equipment_level[i]
		var armor: RPGArmor = RPGSYSTEM.get_data("armors", armor_id)
		
		if armor:
			var new_armor = GameArmor.new(armor_id, 1, 2)
			new_armor.current_level = armor_level
			new_armor.equipped = true
			new_armor.total_equipped += 1
			current_gear[i] = new_armor
			
			if not GameManager.game_state.armors.has(armor_id):
				GameManager.game_state.armors[armor_id] = []
				
			GameManager.game_state.armors[armor_id].append(new_armor)


## Attempts to change an equipment slot to a new item (used to preview equipment, avoid using directly).
func _set_equip(equipment_type_id: int, item_id: int, item_level: int) -> void:
	if item_id != -1:
		var is_weapon = equipment_type_id == 0
		var new_equipment = _create_new_equipment(equipment_type_id, item_id, item_level, is_weapon)
		current_gear[equipment_type_id] = new_equipment
	else:
		current_gear[equipment_type_id] = null
		
	restore_permanent_states_after_battle()
	parameter_changed.emit()


## Attempts to change an equipment slot to a new item.
func change_equipment(equipment_type_id: int, item_id: int, item_level: int, is_new_item: bool = true) -> void:
	if not can_equip(equipment_type_id, item_id):
		return
	
	var is_weapon = equipment_type_id == 0
	var database_key = "weapons" if is_weapon else "armors"
	var game_state_items = GameManager.game_state.weapons if is_weapon else GameManager.game_state.armors
	var real_item = RPGSYSTEM.get_data(database_key, item_id)
	
	if item_id <= 0 or not real_item:
		return
	
	remove_current_equipment(equipment_type_id)
	
	var new_equipment = _create_new_equipment(equipment_type_id, item_id, item_level, is_weapon)
	current_gear[equipment_type_id] = new_equipment
	
	if is_new_item:
		_add_equipment_to_inventory(item_id, new_equipment, real_item, game_state_items)
	
	_validate_equipment()
	restore_permanent_states_after_battle()
	parameter_changed.emit()


## Attempts to change an equipment slot to a item in the inventory.
func equip_equipment_from_inventory(slot_id: int, item: Variant) -> void:
	var equipment_type_id = slot_id
	var item_id = item.id
	
	if not can_equip(equipment_type_id, item_id):
		return
	
	var is_weapon = equipment_type_id == 0
	var database_key = "weapons" if is_weapon else "armors"
	var real_item = RPGSYSTEM.get_data(database_key, item_id)
	
	if item_id <= 0 or not real_item:
		return
	
	remove_current_equipment(equipment_type_id)
	
	var new_equipment = item
	
	if not is_comparation_enabled:
		new_equipment.total_equipped += 1
		new_equipment.equipped = true
		
	current_gear[equipment_type_id] = new_equipment
	
	_validate_equipment()
	restore_permanent_states_after_battle()
	parameter_changed.emit()


## Return the equip (GameWeapon or GameArmor) in the slot selected or null if not exists.
func get_equip_in_slot(slot_id: int) -> Variant:
	if current_gear.size() > slot_id:
		return current_gear[slot_id]
		
	return null


## Removes the currently equipped item from the specified equipment slot.
func remove_current_equipment(equipment_type_id: int) -> void:
	var current_equipment = current_gear[equipment_type_id]
	
	if not current_equipment:
		return
	
	if not is_comparation_enabled:
		current_equipment.total_equipped = max(0, current_equipment.total_equipped - 1)
		current_equipment.equipped = current_equipment.total_equipped > 0
	
	current_gear[equipment_type_id] = null
	
	restore_permanent_states_after_battle()
	parameter_changed.emit()


## Creates a new GameWeapon or GameArmor instance from the given item ID.
func _create_new_equipment(equipment_type_id: int, item_id: int, level: int, is_weapon: bool):
	var new_equipment
	
	if is_weapon:
		new_equipment = GameWeapon.new(item_id, 1, 1)
	else:
		new_equipment = GameArmor.new(item_id, 1, 2)
	
	new_equipment.type = equipment_type_id
	new_equipment.id = item_id
	new_equipment.quantity = 1
	new_equipment.equipped = true
	new_equipment.total_equipped += 1
	new_equipment.current_level = level
	
	return new_equipment


## Adds a given item back into the inventory.
func _add_equipment_to_inventory(item_id: int, new_equipment, real_item, game_state_items: Dictionary) -> void:
	if not game_state_items.has(item_id):
		game_state_items[item_id] = []
	
	var item_array = game_state_items[item_id]
	
	if real_item.upgrades.max_levels > 1 or item_array.is_empty():
		item_array.append(new_equipment)
	elif real_item.upgrades.max_levels == 1:
		item_array[0].quantity += 1


## Check if there is new equipment in the inventory that can be equipped by this actor.
func _has_new_equipment_available() -> bool:
	_temp_trait_cache = _get_trait_list()
	var has_new = false
	
	for slot_id in range(0, 8, 1):
		if _has_new_items_in_slot(slot_id):
			has_new = true
			break
	
	_temp_trait_cache.clear()
	
	return has_new


## Check if there are items in the inventory that can be equipped in the selected slot.
func _has_new_items_in_slot(slot_id: int) -> bool:
	var data = GameManager.game_state.weapons if slot_id == 0 else GameManager.game_state.armors
	
	for item_arr: Array in data.values():
		var item = item_arr[0]
		
		if item is GameArmor:
			var real_armor = RPGSYSTEM.get_data("armors", item.id)
			if item.id <= 0 or not real_armor:
				continue
			if real_armor.equipment_type != 0 and real_armor.equipment_type != slot_id:
				continue
				
		else:
			var real_weapon = RPGSYSTEM.get_data("weapons", item.id)
			if item.id <= 0 or not real_weapon:
				continue
			
		if not can_equip(slot_id, item.id):
			continue
			
		for obj in item_arr:
			if obj.newly_added:
				return true
				
	return false


## Helper function to check if any trait with given codes affects a slot.
func _has_trait_affecting_slot(codes: Array, slot_id: int) -> bool:
	var traits = _get_trait_list()
	
	return traits.any(func(t): return t.code in codes and t.data_id == slot_id)


## Determines whether an equipment slot is sealed.
func is_slot_sealed(slot_id: int) -> bool:
	return _has_trait_affecting_slot([TraitCode.SEAL_EQUIP], slot_id)


## Determines whether an equipment slot is locked.
func is_slot_locked(slot_id: int) -> bool:
	return _has_trait_affecting_slot([TraitCode.LOCK_EQUIP], slot_id)


## Determines whether an equipment slot is available.
func is_slot_available(slot_id: int) -> bool:
	return not _has_trait_affecting_slot([TraitCode.SEAL_EQUIP, TraitCode.LOCK_EQUIP], slot_id)


## Determines whether the actor can equip the item with the given ID in the specified slot.
func can_equip(equipment_type_id: int, item_id: int) -> bool:
	if not is_slot_available(equipment_type_id):
		return false

	var is_weapon := equipment_type_id == 0
	var database_key = "weapons" if is_weapon else "armors"
	var trait_code = TraitCode.EQUIP_WEAPON if is_weapon else TraitCode.EQUIP_ARMOR
	var item_data = RPGSYSTEM.get_data(database_key, item_id)

	if not item_data:
		return false
	
	if equipment_type_id > 0:
		if item_data.equipment_type != 0 and item_data.equipment_type != equipment_type_id:
			return false
	
	var restrictions: RPGEquipRestrictions = \
		item_data.equipment_restriction if "equipment_restriction" in item_data \
		else RPGEquipRestrictions.new()
	
	if restrictions.level_restriction > 0 and \
		restrictions.level_restriction > current_level:
		return false
	
	if restrictions.class_restriction > 0 and \
		current_class != restrictions.class_restriction:
			return false
	
	if restrictions.gender_restriction > 0:
		var real_actor = get_real_actor()
		if real_actor and real_actor.gender != restrictions.gender_restriction:
			return false

	var type_id = item_data.weapon_type if is_weapon else item_data.armor_type
	var general_type_id = item_data.weapon_type if is_weapon else item_data.armor_type

	if type_id == 0:
		return true

	var allowed_traits = trait_list.filter(
		func(t: RPGTrait) -> bool:
			return t.code == trait_code and (t.data_id == general_type_id or t.data_id == 0)
	)

	if not allowed_traits.is_empty():
		return true

	for gear in current_gear:
		if gear == null:
			continue

		var gdata = gear.get_real_data()
		if gdata == null:
			continue
		
		if gear is GameWeapon and is_weapon:
			for t in gdata.traits:
				if t.code == TraitCode.EQUIP_WEAPON and (t.data_id == gdata.weapon_type or t.data_id == 0):
					return true

		elif gear is GameArmor and not is_weapon:
			for t in gdata.traits:
				if t.code == TraitCode.EQUIP_ARMOR and (t.data_id == gdata.armor_type or t.data_id == 0):
					return true
	
	return false


## Validates all equipped gear, removing any that are now sealed or invalid.
func _validate_equipment() -> void:
	for i in range(current_gear.size()):
		if is_slot_sealed(i):
			remove_current_equipment(i)
			continue
			
		if current_gear[i] and current_gear[i].id > 0:
			if not can_equip(i, current_gear[i].id):
				remove_current_equipment(i)
#endregion



#region Progression
## Returns the remaining experience points needed to reach the next level.
func get_remaining_exp_to_level() -> String:
	var class_data: RPGClass = get_real_class()
	
	if class_data:
		var current_level_experience = class_data.get_parameter("experience", current_level)
		var next_level_experience = class_data.get_parameter("experience", current_level + 1)
		
		if next_level_experience != 0:
			return str(next_level_experience - current_level_experience)
	
	return "0"


## Returns the current experience points of the actor at the current level.
func get_current_level_experience() -> int:
	var class_data: RPGClass = get_real_class()
	
	if class_data:
		return class_data.get_parameter("experience", current_level)
	
	return 0


## Changes the actor's level and adjusts experience accordingly.
func change_level(level: int) -> void:
	if level <= 0:
		return
	
	current_level = level
	current_experience = 0
	
	var class_data: RPGClass = get_real_class()
	
	if class_data:
		current_experience = class_data.get_parameter("experience", current_level)


## Adds experience points and levels up the actor if needed.
func add_experience(amount: int) -> void:
	if amount <= 0:
		return
	
	current_experience += amount
	
	while true:
		var class_data: RPGClass = get_real_class()
		
		if not class_data:
			break
			
		var next_level_experience = class_data.get_parameter("experience", current_level + 1)
		
		if next_level_experience > 0 and current_experience >= next_level_experience:
			current_experience -= next_level_experience
			current_level += 1
		else:
			break
#endregion



#region Skills
## Returns true if a given skill ID is currently sealed by traits, gear, or states.
func is_skill_sealed(skill_id: int) -> bool:
	var trait_code = TraitCode.SEAL_SKILL
	
	var has_sealed_trait = func(_trait_array: Array) -> bool:
		for t: RPGTrait in _trait_array:
			if t.code == trait_code and t.data_id == skill_id:
				return true
		return false
	
	if has_sealed_trait.call(trait_list):
		return true
	
	for gear in current_gear:
		if not gear or gear.id <= 0 or gear.type < 0:
			continue

		var is_weapon = gear.type == 0
		var database_key = "weapons" if is_weapon else "armors"
		var real_item = RPGSYSTEM.get_data(database_key, gear.id)

		if real_item:
			if has_sealed_trait.call(real_item.traits):
				return true
	
	for state in current_states:
		if state and state.id > 0:
			var real_state = RPGSYSTEM.get_data("states", state.id)
			if real_state:
				if has_sealed_trait.call(real_state.traits):
					return true
	
	return false


## Returns a dictionary of all available skills for this actor, indicating if they are sealed.
func get_skills() -> Dictionary:
	var skill_traits = _get_trait_list()
	var skill_add_traits = skill_traits.filter(func(t: RPGTrait): return t.code == TraitCode.ADD_SKILL)
	var current_skill_types = skill_traits.filter(func(t: RPGTrait): return t.code == TraitCode.ADD_SKILL_TYPE)
	var skill_types_sealed = skill_traits.filter(func(t: RPGTrait): return t.code == TraitCode.SEAL_SKILL_TYPE)
	
	var current_types_added = current_skill_types.map(func(t: RPGTrait): return t.data_id + 1)
	var current_types_sealed = skill_types_sealed.map(func(t: RPGTrait): return t.data_id + 1)
	var all_skill_ids: Array[int] = []
	
	for t: RPGTrait in skill_add_traits:
		if not all_skill_ids.has(t.data_id):
			all_skill_ids.append(t.data_id)
	
	var real_class: RPGClass = get_real_class()
	
	if real_class:
		for skill_data: RPGLearnableSkill in real_class.learnable_skills:
			if skill_data.level <= current_level and not all_skill_ids.has(skill_data.skill_id):
				all_skill_ids.append(skill_data.skill_id)
	
	var skills: Dictionary = {}
	
	for skill_id: int in all_skill_ids:
		var skill = get_real_skill(skill_id)
		
		if skill:
			if skill.skill_type == 0 or skill.skill_type in current_types_added:
				var is_sealed = (
					(skill.skill_type != 0 and skill.skill_type in current_types_sealed) or
					is_skill_sealed(skill._uniq_id)
				)
				skills[skill._uniq_id] = {"id": skill._uniq_id, "name": skill.name, "sealed": is_sealed, "icon": skill.icon, "description": skill.description}
				
	return skills
#endregion



#region Utility
## Returns the string representation of the object.
func _to_string() -> String:
	return "<GameActor name=%s id=%s>" % [current_name, id]
#endregion
