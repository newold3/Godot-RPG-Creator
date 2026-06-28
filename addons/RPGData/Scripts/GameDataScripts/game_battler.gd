class_name GameBattler
extends Resource

## Base class for all combatants in the game (Actors and Enemies).
##
## Handles all shared mathematical logic, parameters, states, buffs, debuffs,
## and trait calculations. Designed to be extended by GameActor and GameEnemy.

#region VariablesAndConstants
## Battler's unique ID in the database.
@export var id: int = -1

## Current name of the battler.
@export var current_name: String = ""

## List of active GameState instances currently affecting the battler.
@export var current_states: Array[GameState] = []

## Full list of inherent traits applied to the battler.
@export var trait_list: Array[RPGTrait] = []

## Stores all vital parameters (HP, MP, modifiers).
@export var params: GameParams = GameParams.new()

## Stores all user parameters defined in database.
@export var user_params: PackedInt32Array = []

enum TraitCode {
	PARAM_BASE = 5,
	ADD_STATE = 28,
	PERMANENT_STATE = 28,
	EQUIP_WEAPON = 17,
	EQUIP_ARMOR = 18,
	LOCK_EQUIP = 19,
	SEAL_EQUIP = 20,
	ADD_SKILL_TYPE = 13,
	SEAL_SKILL_TYPE = 14,
	ADD_SKILL = 15,
	SEAL_SKILL = 16,
	ELEMENT_ATTACK = 1,
	ELEMENT_DEFENSE = 27,
	USER_PARAMETER = 101,
	DEBUFF_RATE = 2,
	STATE_RATE = 3,
	STATE_RESIST = 4
}

const DEFAULT_EXTRA_PARAMS = {
	RPGActor.ExtraParamType.HIT: 1.0,
	RPGActor.ExtraParamType.EVA: 0.05,
	RPGActor.ExtraParamType.CRI: 0.04,
	RPGActor.ExtraParamType.CEV: 0.01,
	RPGActor.ExtraParamType.MEV: 0.0,
	RPGActor.ExtraParamType.MRF: 0.0,
	RPGActor.ExtraParamType.CNT: 0.0,
	RPGActor.ExtraParamType.HRG: 0.0,
	RPGActor.ExtraParamType.MRG: 0.0,
	RPGActor.ExtraParamType.TRG: 0.0
}

const DEFAULT_SPECIAL_PARAMS = {
	RPGActor.SpecialParamType.TGR: 1.0,
	RPGActor.SpecialParamType.GRD: 1.0,
	RPGActor.SpecialParamType.REC: 1.0,
	RPGActor.SpecialParamType.HM: 1.0,
	RPGActor.SpecialParamType.MCR: 1.0,
	RPGActor.SpecialParamType.TCR: 1.0,
	RPGActor.SpecialParamType.PDR: 1.0,
	RPGActor.SpecialParamType.MDR: 1.0,
	RPGActor.SpecialParamType.FDR: 1.0,
	RPGActor.SpecialParamType.EXR: 1.0,
	RPGActor.SpecialParamType.GDR: 1.0
}

const TICKS_ENABLED = {
	CODE = 5,
	DATA_IDS = [17, 18, 19]
}

var MAX_MULTIPLIER = 10000.0
var MAX_RESULT     = 1_000_000_000.0

var temp_buffs: Array = []
var temp_debuff: Array = []

var _param_offsets_cache: Array[int] = []
var _temp_trait_cache: Array = []

var is_valid: bool = true

## Emitted whenever a change in parameters occurs.
signal parameter_changed()
#endregion



#region CoreLogicAndTraits
## Fully restores the battler's HP and MP and removes non-permanent states.
func recover_all() -> void:
	params.hp = get_parameter("hp")
	params.mp = get_parameter("mp")
	
	current_states = current_states.filter(
		func(t: GameState):
			return t != null and t.is_permanent()
	)
	
	if is_dead():
		params.hp = 0
	
	parameter_changed.emit()
	emit_changed()



## Adds a [RPGTrait] to the battler.
func add_trait(tr: RPGTrait) -> void:
	if !tr: return
	
	trait_list.append(tr)
	
	if tr.code == TraitCode.ADD_STATE:
		add_trait_state(tr)
		
	parameter_changed.emit()



## Removes a [RPGTrait] from the battler.
func remove_trait(tr: RPGTrait) -> void:
	if !tr: return
	
	var ids_to_remove = []
	
	for i in range(trait_list.size() - 1, -1, -1):
		if trait_list[i].code == tr.code and trait_list[i].data_id == tr.data_id:
			ids_to_remove.append(i)

	for i in range(ids_to_remove.size()):
		var removed_trait = trait_list[ids_to_remove[i]]
		trait_list.remove_at(ids_to_remove[i])
		
		if removed_trait.code == TraitCode.ADD_STATE:
			_remove_permanent_state_usage(removed_trait.data_id)
	
	if ids_to_remove.size() > 0: 
		parameter_changed.emit()



## Adds a [GameState] based on a trait definition.
func add_trait_state(state: RPGTrait) -> void:
	if state.data_id > 0:
		var real_state = RPGSYSTEM.get_data("states", state.data_id)
		if real_state:
			add_state(real_state, true, true)
#endregion



#region StateManagement
## Determines if the battler is completely immune to a specific state.
func is_inmune_to_state(state: RPGState) -> bool:
	var traits = _get_trait_list()
	
	var is_inmune = traits.filter(
		func(t: RPGTrait):
			return t.code == TraitCode.STATE_RESIST and t.data_id == state.id
	)
	
	return not is_inmune.is_empty()


func has_state(state_id: int) -> bool:
	for state in current_states:
		if state and state.id == state_id:
			return true
	return false


func is_dead() -> bool:
	return has_state(1)



## Attempts to apply a state to the battler considering resistance and base chance.
func apply_state_effect(state_id: int, base_chance: float) -> bool:
	var real_state = RPGSYSTEM.get_data("states", state_id)
	
	if not real_state:
		return false

	var state_rate = get_state_rate(state_id)

	if randf() < (base_chance / 100.0) * state_rate:
		return add_state(real_state)

	return false



## Attempts to remove a state from the battler based on a probability chance.
func remove_state_effect(state_id: int, base_chance: float) -> bool:
	var has_removable_state = current_states.any(func(s): return s != null and s.id == state_id and not s.is_permanent())
	if not has_removable_state:
		return false

	if randf() < (base_chance / 100.0):
		execute_state_removal(state_id)
		return true

	return false



## Forcefully applies the removal logic of a state, decrementing stacks or removing it.
func execute_state_removal(state_id: int) -> void:
	var states_to_remove = current_states.filter(func(s): return s != null and s.id == state_id and not s.is_permanent())
	
	for s in states_to_remove:
		var real_state = s.get_real_state()
		
		if real_state and real_state.is_cumulative and real_state.remove_by_stacks and s.cumulative_effect > 1:
			s.cumulative_effect -= 1
			s.emit_changed()
			parameter_changed.emit()
		else:
			_remove_state(s)




## Adds a full [GameState] instance to the battler. Returns true if applied, false if blocked.
func add_state(state: RPGState, is_permanent: bool = false, usage_count: bool = false) -> bool:
	if is_inmune_to_state(state):
		return false

	if not is_permanent and get_state_rate(state.id) <= 0.0:
		return false


	var enable_ticks = state.traits.filter(
		func(t: RPGTrait):
			return t.code == TICKS_ENABLED.CODE and TICKS_ENABLED.DATA_IDS.has(t.data_id)
	)

	var state_mode: GameState.STATE_MODE = GameState.STATE_MODE.STATE_CONTEXT_GLOBAL

	if is_permanent:
		state_mode |= GameState.STATE_MODE.STATE_DURATION_PERMANENT

	if enable_ticks:
		state_mode |= GameState.STATE_MODE.STATE_TICKS_ENABLED

	if state.is_damage_tick:
		state_mode |= GameState.STATE_MODE.STATE_TICKS_DAMAGE

	if state.remove_at_battle_end:
		state_mode |= GameState.STATE_MODE.STATE_CONTEXT_BATTLE_ONLY

	if state.remove_by_time:
		state_mode |= GameState.STATE_MODE.STATE_DURATION_SECONDS
	elif state.auto_removal_timing > 0:
		state_mode |= GameState.STATE_MODE.STATE_DURATION_TURNS

	if state.remove_by_walking:
		state_mode |= GameState.STATE_MODE.STATE_REMOVE_BY_WALKING

	if state.remove_by_damage:
		state_mode |= GameState.STATE_MODE.STATE_REMOVE_BY_DAMAGE

	if state.remove_by_restriction:
		state_mode |= GameState.STATE_MODE.STATE_REMOVE_BY_RESTRICTION

	var duration_value = state.max_time if state.remove_by_time else randi_range(state.min_turns, state.max_turns)
	var is_new_state = true
	var game_state: GameState
	var search_state = current_states.filter(func(t: GameState): return t != null and t.id == state.id)

	if search_state:
		game_state = search_state[0]
		is_new_state = false

		if state.is_cumulative:
			game_state.cumulative_effect += 1
			game_state.duration += duration_value
		else:
			game_state.duration = duration_value

		if is_permanent:
			game_state.state_mode |= GameState.STATE_MODE.STATE_DURATION_PERMANENT

		if usage_count:
			game_state.usage_count += 1

		game_state.emit_changed()
	else:
		game_state = GameState.new(state.id, duration_value, state.tick_interval, state_mode)

		if usage_count:
			game_state.usage_count = 1

		current_states.append(game_state)

	if is_new_state:
		game_state.state_ended.connect(_remove_state)
		game_state.state_tick.connect(_on_state_tick)

	if state.id == 1:
		params.hp = 0

	parameter_changed.emit()
	emit_changed()

	return true



## Removes a specific state from the battler. Will not remove permanent states unless forced.
func remove_state(state_id: int, force_permanent: bool = false) -> void:
	var states_to_remove = current_states.filter(
		func(s: GameState) -> bool:
			return s != null and s.id == state_id and (force_permanent or not s.is_permanent())
	)
	
	var changed = false
	
	for state in states_to_remove:
		current_states.erase(state)
		changed = true
		
	if changed:
		parameter_changed.emit()
		emit_changed()



## Decreases the usage count of a permanent state and removes it if the count reaches 0.
func _remove_permanent_state_usage(state_id: int) -> void:
	var states_to_remove = current_states.filter(
		func(s: GameState) -> bool:
			return s != null and s.id == state_id and s.is_permanent()
	)
	
	var changed = false
	
	for state in states_to_remove:
		state.usage_count -= 1
		
		var real_state = state.get_real_state()
		if real_state and real_state.is_cumulative:
			state.cumulative_effect = max(1, state.cumulative_effect - 1)
		
		if state.usage_count <= 0:
			current_states.erase(state)
			
		changed = true
			
	if changed:
		parameter_changed.emit()
		emit_changed()



## Removes a state directly from the list.
func _remove_state(state: GameState) -> void:
	if state in current_states:
		current_states.erase(state)
		if state.id == 1 and params.hp <= 0:
			params.hp = 1
		parameter_changed.emit()
		emit_changed()



## Updates all statuses added to this battler (Lifetime).
func update_states(delta: float) -> void:
	for state in current_states:
		if state:
			state.update_lifetime(delta)



## Out of battle tick callback.
func _on_state_tick(state: GameState) -> void:
	pass
#endregion



#region BuffsAndDebuffs
## Adds a percentage buff to a specific parameter.
func add_buff(param_index: int, value: float, duration: int = 0) -> void:
	var param_list = RPGActor.get_parameter_list(true)
	
	if param_index < 0 or param_index >= param_list.size():
		return
		
	var param_id = param_list[param_index].to_upper()
	if param_id == "": return
		
	temp_buffs.append({"param_id": param_id, "value": value, "duration": duration})
	parameter_changed.emit()



## Adds a percentage debuff to a specific parameter.
func add_debuff(param_index: int, value: float, duration: int = 0) -> void:
	var param_list = RPGActor.get_parameter_list(true)
	
	if param_index < 0 or param_index >= param_list.size():
		return
		
	var param_id = param_list[param_index].to_upper()
	if param_id == "": return
		
	temp_debuff.append({"param_id": param_id, "value": value, "duration": duration})
	parameter_changed.emit()



## Clears all active buffs from the battler.
func clear_buffs() -> void:
	temp_buffs.clear()
	parameter_changed.emit()



## Clears all active debuffs from the battler.
func clear_debuffs() -> void:
	temp_debuff.clear()
	parameter_changed.emit()



## Removes a specific number of buff stacks for a parameter.
func remove_buff(param_index: int, stacks: int = 0) -> void:
	var param_list = RPGActor.get_parameter_list(true)
	
	if param_index < 0 or param_index >= param_list.size():
		return
		
	var param_id = param_list[param_index].to_upper()
	var removed_count = 0
	
	for i in range(temp_buffs.size() - 1, -1, -1):
		if temp_buffs[i]["param_id"] == param_id:
			temp_buffs.remove_at(i)
			removed_count += 1
			
			if stacks > 0 and removed_count >= stacks:
				break
				
	if removed_count > 0:
		parameter_changed.emit()



## Removes a specific number of debuff stacks for a parameter.
func remove_debuff(param_index: int, stacks: int = 0) -> void:
	var param_list = RPGActor.get_parameter_list(true)
	
	if param_index < 0 or param_index >= param_list.size():
		return
		
	var param_id = param_list[param_index].to_upper()
	var removed_count = 0
	
	for i in range(temp_debuff.size() - 1, -1, -1):
		if temp_debuff[i]["param_id"] == param_id:
			temp_debuff.remove_at(i)
			removed_count += 1
			
			if stacks > 0 and removed_count >= stacks:
				break
				
	if removed_count > 0:
		parameter_changed.emit()



## Decrements the duration of all active buffs and debuffs.
func update_buffs_duration() -> void:
	var has_changes = false
	
	for i in range(temp_buffs.size() - 1, -1, -1):
		if temp_buffs[i]["duration"] > 0:
			temp_buffs[i]["duration"] -= 1
			
			if temp_buffs[i]["duration"] <= 0:
				temp_buffs.remove_at(i)
				has_changes = true
				
	for i in range(temp_debuff.size() - 1, -1, -1):
		if temp_debuff[i]["duration"] > 0:
			temp_debuff[i]["duration"] -= 1
			
			if temp_debuff[i]["duration"] <= 0:
				temp_debuff.remove_at(i)
				has_changes = true
				
	if has_changes:
		parameter_changed.emit()
#endregion



#region CombatMathAndModifiers
## Applies damage or healing to the battler.
func apply_damage(raw_amount: float, damage_type: int, element_id: int) -> void:
	var element_rate = 1.0
	
	if damage_type in [1, 2, 5, 6] and element_id != 1:
		var rate = get_element_defense_rate(element_id)
		element_rate = rate / 100.0
		
	var final_amount = int(raw_amount * element_rate)
	var max_hp = get_parameter("HP")
	var max_mp = get_parameter("MP")
	
	if max_hp <= 0: max_hp = 999999
	if max_mp <= 0: max_mp = 999999
		
	match damage_type:
		1, 3, 5:
			params.hp = clamp(params.hp + final_amount, 0, max_hp)
			if params.hp == 0:
				var dead_state = RPGSYSTEM.get_data("states", 1)
				if dead_state:
					add_state(dead_state)
		2, 4, 6:
			params.mp = clamp(params.mp + final_amount, 0, max_mp)



## Applies a recovery effect based on a percentage of the max parameter plus a flat amount.
func apply_recovery_effect(param: String, percent: float, flat: int) -> void:
	param = param.to_upper()
	var max_val = get_parameter(param)
	
	if max_val <= 0:
		max_val = 999999
		
	var heal_amount = int((max_val * (percent / 100.0)) + flat)
	
	if param == "HP":
		params.hp = clamp(params.hp + heal_amount, 0, max_val)
	elif param == "MP":
		params.mp = clamp(params.mp + heal_amount, 0, max_val)
	elif param == "TP":
		params.tp = clamp(params.tp + heal_amount, 0, max_val)



## Modifies a given parameter by adding or subtracting a value.
func set_parameter(param_id: String, value: float, operation: int) -> void:
	var search_param = _get_unified_param_key(param_id)
	var real_param_id = _find_real_param(search_param)
	
	if real_param_id != "":
		var current_value = params.mods.get(real_param_id, 0)
		
		if operation == 0:
			params.mods[real_param_id] = current_value + value
		else:
			params.mods[real_param_id] = current_value - value
		
		if "base" in real_param_id:
			match int(real_param_id):
				0: params.hp = params.hp + (value if operation == 0 else -value)
				1: params.mp = params.mp + (value if operation == 0 else -value)

		parameter_changed.emit()



## Permanently increases a parameter (Grow effect).
func apply_grow_effect(param_id: int, amount: int) -> void:
	var param_list = RPGActor.get_parameter_list(true)
	
	if param_id >= 0 and param_id < param_list.size():
		var stat_name = param_list[param_id]
		set_parameter(stat_name, amount, 0)
#endregion



#region ParameterGetters
## Retrieves the current value of vital parameters like HP, MP, or TP.
func get_current_parameter(param_id: String) -> float:
	var search_param = param_id.strip_edges().to_upper()
	match search_param:
		"HP": return params.hp
		"MP": return params.mp
		"TP": return params.tp if "tp" in params else 0.0
		_: return get_parameter(param_id)


## Safely modifies the current vital parameters without exceeding their maximum values.
func set_current_parameter(param_id: String, value: float) -> void:
	var search_param = param_id.strip_edges().to_upper()
	match search_param:
		"HP":
			if is_dead():
				params.hp = 0
			else:
				var clamped_val = clamp(value, 0, get_parameter("HP"))
				params.hp = clamped_val
				if clamped_val == 0:
					var dead_state = RPGSYSTEM.get_data("states", 1)
					if dead_state:
						add_state(dead_state)
		"MP": params.mp = clamp(value, 0, get_parameter("MP"))
		"TP":
			if "tp" in params:
				params.tp = clamp(value, 0, get_parameter("TP"))
	parameter_changed.emit()


## Calculates a specific parameter value by combining base stats, traits, gear, and state effects.
func get_parameter(param_id: String) -> float:
	var search_param = _get_unified_param_key(param_id)
	var is_rate = _is_rate_parameter(search_param)
	
	var value: float = _get_base_parameter(search_param)
	var real_param_id = _find_real_param(search_param)

	if real_param_id != "" and params.mods.has(real_param_id):
		value += params.mods[real_param_id]

	var trait_code = _get_trait_code(search_param)

	if trait_code > 0:
		var traits = _get_trait_list()
		var trait_data_id = _get_param_type_id(search_param)
		
		if trait_code == TraitCode.USER_PARAMETER:
			trait_data_id = search_param.replace("USER_PARAMETER_", "").to_int()

		value = _add_traits_to_value(
			traits,
			value,
			trait_code,
			trait_data_id,
			is_rate
		)

	var total_buff_percent = 0.0
	for b in temp_buffs:
		if b["param_id"] == search_param:
			total_buff_percent += b["value"]

	var total_debuff_percent = 0.0
	for d in temp_debuff:
		if d["param_id"] == search_param:
			total_debuff_percent += d["value"]

	if total_buff_percent > 0.0 or total_debuff_percent > 0.0:
		value += value * ((total_buff_percent - total_debuff_percent) / 100.0)
		
	return clamp(value, -MAX_RESULT, MAX_RESULT)



## Returns the probability multiplier for receiving a specific state.
func get_state_rate(state_id: int) -> float:
	var value: float = 100.0
	var traits: Array = _get_trait_list()
	
	value = _add_traits_to_value(traits, value, TraitCode.STATE_RATE, state_id, true)
	
	return value / 100.0



func get_buff_rate(param_id: int) -> float:
	return 1.0



func get_debuff_rate(param_id: int) -> float:
	var value: float = 100.0
	var traits: Array = _get_trait_list()
	
	value = _add_traits_to_value(traits, value, TraitCode.DEBUFF_RATE, param_id, true)
	
	return value / 100.0



func _get_user_parameters_from_data(param_id: int) -> float:
	var _real_data: Variant
	if "current_class" in self:
		_real_data = RPGSYSTEM.get_data("classes", get("current_class"))
	elif has_method("get_real_enemy"):
		_real_data = call("get_real_enemy")
		
	var _current_user_parameters: PackedFloat32Array
	
	if _real_data:
		_current_user_parameters = _real_data.user_parameters
		if _current_user_parameters.size() < RPGSYSTEM.database.types.user_parameters.size():
			var min_index = _current_user_parameters.size()
			_current_user_parameters.resize(RPGSYSTEM.database.types.user_parameters.size())
			for i in range(min_index, RPGSYSTEM.database.types.user_parameters.size()):
				_current_user_parameters[i] = RPGSYSTEM.database.types.user_parameters[i].default_value
	else:
		_current_user_parameters.resize(RPGSYSTEM.database.types.user_parameters.size())
		for i in RPGSYSTEM.database.types.user_parameters.size():
			_current_user_parameters[i] = RPGSYSTEM.database.types.user_parameters[i].default_value
	
	if _current_user_parameters.size() > param_id:
		return _current_user_parameters[param_id]
	
	return 0.0
	
	


## Calculates a specific parameter value by combining base stats + gear.
func get_user_parameter(param_id: int) -> float:
	return get_parameter("USER_PARAMETER_" + str(param_id))


func get_element_attack_rate(element_id: Variant) -> float:
	return _get_element_rate(TraitCode.ELEMENT_ATTACK, element_id)



func get_element_defense_rate(element_id: Variant) -> float:
	return _get_element_rate(TraitCode.ELEMENT_DEFENSE, element_id)



func _get_element_rate(trait_code: int, element_id: Variant) -> float:
	var elements = RPGSYSTEM.database.types.element_types
	var data_id: int = 0
	
	if element_id is int and elements.size() > element_id:
		data_id = element_id
	elif element_id is String:
		var search_element = element_id.to_lower()
		for i in elements.size():
			if elements[i].to_lower() == search_element:
				data_id = i
				break
				
	var value: float = 100.0
	var traits: Array = _get_trait_list()
	
	value = _add_traits_to_value(traits, value, trait_code, data_id, true)
	
	return value
#endregion



#region TraitCalculations
## Collects all active traits from states, inherent traits, and child sources.
func _get_trait_list() -> Array:
	if _temp_trait_cache:
		return _temp_trait_cache
	
	var traits: Array = []
	
	for state in current_states:
		if state and state.id > 0:
			var real_state = RPGSYSTEM.get_data("states", state.id)
			if real_state:
				if state.cumulative_effect <= 1:
					traits.append_array(real_state.traits)
				else:
					var new_traits = []
					for old_trait in real_state.traits:
						var new_trait = old_trait.clone(true)
						new_trait.value *= state.cumulative_effect
						new_traits.append(new_trait)

					if new_traits:
						traits.append_array(new_traits)
					
	traits.append_array(trait_list)
	traits.append_array(_get_extra_traits())

	return traits



## Applies RPGTrait modifiers to a parameter value using multiplicative scaling.
func _add_traits_to_value(traits: Array, current_value: float, code_id: int, data_id: int, is_rate: bool = false) -> float:
	var multiplier := 1.0
	
	for traits_data in traits:
		if traits_data is Array:
			for t in traits_data:
				if t is RPGTrait and t.code == code_id and t.data_id == data_id:
					multiplier *= t.value / 100.0
		elif traits_data is RPGTrait and traits_data.code == code_id and traits_data.data_id == data_id:
			multiplier *= traits_data.value / 100.0
	
	multiplier = clamp(multiplier, -MAX_RESULT, MAX_RESULT)
	
	var result: int
	if current_value == 0.0 and is_rate:
		result = multiplier * 100.0
	else:
		result = current_value * multiplier
	
	return clamp(result, -MAX_RESULT, MAX_RESULT)



func _get_unified_param_key(param: String) -> String:
	var search_param = param.strip_edges().to_upper()
	var type_id = _get_param_type_id(search_param)
	
	if type_id >= 0:
		var param_list = RPGActor.get_parameter_list(true)
		if type_id < param_list.size():
			return param_list[type_id]
			
	return search_param



func _find_real_param(param: String) -> String:
	if param in RPGActor.BaseParamType.keys():
		return "base" + str(RPGActor.BaseParamType[param])
	elif param in RPGActor.ExtraParamType.keys():
		return "extra" + str(RPGActor.ExtraParamType[param])
	elif param in RPGActor.SpecialParamType.keys():
		return "special" + str(RPGActor.SpecialParamType[param])
	elif param.begins_with("USER_PARAMETER_"):
		var u_id = param.replace("USER_PARAMETER_", "").to_int()
		return "USER_PARAM_" + str(u_id)
	elif param == "LEVEL": return "level"
	elif param == "EXPERIENCE": return "experience"
	elif param == "TP": return "tp"
	return ""



func _get_trait_code(param: String) -> int:
	if param in RPGActor.BaseParamType.keys() or param in RPGActor.ExtraParamType.keys() or param in RPGActor.SpecialParamType.keys():
		return TraitCode.PARAM_BASE

	if param.begins_with("USER_PARAMETER_"):
		return TraitCode.USER_PARAMETER

	return 0



func _get_param_type_id(param: String) -> int:
	if _param_offsets_cache.is_empty():
		var all_params = RPGActor.get_parameter_list(false)
		for i in all_params.size():
			if all_params[i] == "":
				_param_offsets_cache.append(i + 1)

	if param in RPGActor.BaseParamType.keys():
		return RPGActor.BaseParamType[param] + (_param_offsets_cache[0] if _param_offsets_cache.size() > 0 else 0)
	elif param in RPGActor.ExtraParamType.keys():
		return RPGActor.ExtraParamType[param] + (_param_offsets_cache[1] if _param_offsets_cache.size() > 1 else 0)
	elif param in RPGActor.SpecialParamType.keys():
		return RPGActor.SpecialParamType[param] + (_param_offsets_cache[2] if _param_offsets_cache.size() > 2 else 0)
	elif param.begins_with("USER_PARAMETER_"):
		var u_id = param.replace("USER_PARAMETER_", "").to_int()
		return u_id + (_param_offsets_cache[3] if _param_offsets_cache.size() > 3 else 0)

	return -1



func _is_rate_parameter(param: String) -> bool:
	if param in RPGActor.BaseParamType.keys(): return false
	if param.begins_with("USER_PARAMETER_"): return false
	if param in ["LEVEL", "EXPERIENCE", "TP"]: return false
	return true
#endregion



#region VirtualMethods
## VIRTUAL: Override this to provide the raw base value of a parameter before traits/buffs.
func _get_base_parameter(search_param: String) -> float:
	if search_param in RPGActor.ExtraParamType.keys():
		return DEFAULT_EXTRA_PARAMS[RPGActor.ExtraParamType[search_param]] * 100.0
	elif search_param in RPGActor.SpecialParamType.keys():
		return DEFAULT_SPECIAL_PARAMS[RPGActor.SpecialParamType[search_param]] * 100.0
	return 0.0



## VIRTUAL: Override this to provide traits from equipment, classes, or database profiles.
func _get_extra_traits() -> Array:
	return []



## VIRTUAL: Override this to wipe and re-apply all permanent states from gear/classes/profiles.
func restore_permanent_states_after_battle() -> void:
	pass



func clone() -> GameBattler:
	var last_gamemanager_simulation = GameManager.is_simulation
	GameManager.is_simulation = true
	var new_battler = duplicate(true)
	
	new_battler.id = id
	new_battler.current_name = current_name
	
	if params:
		new_battler.params = params.duplicate(true)
		
	new_battler.current_states.clear()
	for s in current_states:
		new_battler.current_states.append(s.clone())
			
	new_battler.trait_list.clear()
	for t in trait_list:
		new_battler.trait_list.append(t.clone())
			
	new_battler.temp_buffs = temp_buffs.duplicate(true)
	new_battler.temp_debuff = temp_debuff.duplicate(true)
	
	GameManager.is_simulation = last_gamemanager_simulation
	
	return new_battler
#endregion
