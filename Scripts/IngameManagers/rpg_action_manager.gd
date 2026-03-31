class_name RPGActionManager
extends Node


enum Ocassion {
	ALWAYS = 0,
	BATTLE_SCREEN = 1,
	MENU_SCREEN = 2,
	NEVER = 3
}

enum ScopeSide {
	NONE = 0,
	ENEMY = 1,
	ALLY = 2,
	ENEMY_AND_ALLY = 3,
	USER = 4
}

enum ScopeTarget {
	ONE = 0,
	ALL = 1,
	RANDOM = 2
}

enum ScopeStatus {
	ALIVE = 0,
	DEAD = 1,
	UNCONDITIONAL = 2
}

enum EffectCode {
	NONE = 0,
	RECOVER_HP = 1,
	RECOVER_MP = 2,
	GAIN_TP = 3,
	ADD_STATE = 4,
	REMOVE_STATE = 5,
	ADD_BUFF = 6,
	ADD_DEBUFF = 7,
	REMOVE_BUFF = 8,
	REMOVE_DEBUFF = 9,
	SPECIAL_EFFECT = 10,
	GROW = 11,
	LEARN_SKILL = 12
}


signal action_success(target: Variant, changes: Dictionary)


signal action_failure(target: Variant)


signal action_canceled(target: Variant)


func _get_default_simulate_data() -> Dictionary:
	var result_data = {
		"success": false,
		"hp_change": 0,
		"mp_change": 0,
		"tp_change": 0,
		"added_states": [],
		"removed_states": [],
		"added_buffs": [],
		"removed_buffs": [],
		"added_debuffs": [],
		"removed_debuffs": [],
		"special_effects": [],
		"growth": [],
		"learned_skills": [],
		"common_event": -1,
		"callables": []
	}
	
	return result_data


func _parse_formula(formula: String, user: Variant, target: Variant) -> int:
	if formula.is_empty():
		return 0
		
	var regex = RegEx.new()
	regex.compile("\\b([ab])\\.([a-zA-Z_]+)\\b")
	
	var parsed_formula = formula
	var matches = regex.search_all(formula)
	var replacements = {}
	
	for m in matches:
		var full_match = m.get_string()
		if replacements.has(full_match):
			continue
			
		var obj_str = m.get_string(1).to_lower()
		var param = m.get_string(2).to_upper()
		var obj = user if obj_str == "a" else target
		var val: float = 0.0
		
		if obj != null and obj.has_method("get_parameter"):
			val = obj.get_parameter(param)
			
		replacements[full_match] = str(val)
		
	for key in replacements:
		parsed_formula = parsed_formula.replace(key, replacements[key])

	var expression = Expression.new()
	var error = expression.parse(parsed_formula)
	
	if error != OK:
		return 0
		
	var result = expression.execute()
	
	if expression.has_execute_failed() or result == null:
		return 0
		
	return int(result)


func _simulate_generic(user: Variant, target: Variant, data: Variant) -> Dictionary:
	var result_data = _get_default_simulate_data()
	
	var clone = target.duplicate_deep() if target.has_method("duplicate_deep") else target.duplicate(true)
	
	if "temp_buffs" in target and "temp_buffs" in clone:
		clone.temp_buffs = target.temp_buffs.duplicate(true)
		
	if "temp_debuff" in target and "temp_debuff" in clone:
		clone.temp_debuff = target.temp_debuff.duplicate(true)
		
	var initial_hp = clone.params.hp if "params" in clone else 0
	var initial_mp = clone.params.mp if "params" in clone else 0
	var initial_tp = clone.get_parameter("TP") if clone.has_method("get_parameter") else 0
	
	var initial_states = []
	if "current_states" in clone:
		for s in clone.current_states:
			initial_states.append(s.id)
			
	var initial_buffs = clone.temp_buffs.duplicate() if "temp_buffs" in clone else []
	var initial_debuffs = clone.temp_debuff.duplicate() if "temp_debuff" in clone else []
	
	var base_value = _parse_formula(data.damage.formula, user, clone)
	var final_value = float(base_value)
	
	if base_value != 0 and data.damage.type != 0:
		var variance_val = final_value * (data.damage.variance / 100.0)
		final_value = final_value + randf_range(-variance_val, variance_val)
		
		if data.damage.type in [1, 2, 5, 6]:
			final_value = -final_value
			
		if user != null and data.damage.critical and randf() < user.get_parameter("CRI"):
			final_value *= 3.0
			
		if clone.has_method("apply_damage"):
			clone.apply_damage(final_value, data.damage.type, data.damage.element_id)
			result_data["callables"].append(target.apply_damage.bind(final_value, data.damage.type, data.damage.element_id))
	
	for effect in data.effects:
		var val2 = int(effect.value2)
		var val3 = effect.value3 if "value3" in effect else 0.0
		
		match effect.code:
			EffectCode.RECOVER_HP:
				if clone.has_method("apply_recovery_effect"):
					clone.apply_recovery_effect(true, effect.value1, effect.value2)
					result_data["callables"].append(target.apply_recovery_effect.bind(true, effect.value1, effect.value2))
			EffectCode.RECOVER_MP:
				if clone.has_method("apply_recovery_effect"):
					clone.apply_recovery_effect(false, effect.value1, effect.value2)
					result_data["callables"].append(target.apply_recovery_effect.bind(false, effect.value1, effect.value2))
			EffectCode.GAIN_TP:
				var tp_val = effect.value1 if effect.value1 != 0 else effect.value2
				var op = 0 if tp_val > 0 else 1
				if clone.has_method("set_parameter"):
					clone.set_parameter("TP", abs(tp_val), op)
					result_data["callables"].append(target.set_parameter.bind("TP", abs(tp_val), op))
			EffectCode.ADD_STATE:
				var before_count = clone.current_states.size()
				if clone.has_method("apply_state_effect"):
					clone.apply_state_effect(effect.data_id, effect.value2)
					if clone.current_states.size() > before_count:
						var state_res = RPGSYSTEM.database.states[effect.data_id]
						result_data["callables"].append(target.add_state.bind(state_res))
			EffectCode.REMOVE_STATE:
				var before_count = clone.current_states.size()
				if clone.has_method("remove_state_effect"):
					clone.remove_state_effect(effect.data_id, effect.value2)
					if clone.current_states.size() < before_count:
						var states_to_remove = target.current_states.filter(func(s): return s.id == effect.data_id)
						for s in states_to_remove:
							result_data["callables"].append(target._remove_state.bind(s))
			EffectCode.ADD_BUFF:
				var before_count = clone.temp_buffs.size()
				if clone.has_method("apply_buff_effect"):
					var potency = effect.value3 if "value3" in effect else 25.0
					clone.apply_buff_effect(effect.data_id, potency, val2)
					if clone.temp_buffs.size() > before_count:
						result_data["callables"].append(target.add_buff.bind(effect.data_id, potency, val2))
			EffectCode.ADD_DEBUFF:
				var before_count = clone.temp_debuff.size()
				if clone.has_method("apply_debuff_effect"):
					var potency = effect.value3 if "value3" in effect else 25.0
					clone.apply_debuff_effect(effect.data_id, potency, val2)
					if clone.temp_debuff.size() > before_count:
						result_data["callables"].append(target.add_debuff.bind(effect.data_id, potency, val2))
			EffectCode.REMOVE_BUFF:
				if clone.has_method("remove_buff"):
					clone.remove_buff(effect.data_id, val2)
					result_data["callables"].append(target.remove_buff.bind(effect.data_id, val2))
			EffectCode.REMOVE_DEBUFF:
				if clone.has_method("remove_debuff"):
					clone.remove_debuff(effect.data_id, val2)
					result_data["callables"].append(target.remove_debuff.bind(effect.data_id, val2))
			EffectCode.SPECIAL_EFFECT:
				result_data["special_effects"].append(effect.data_id)
			EffectCode.GROW:
				if clone.has_method("apply_grow_effect"):
					clone.apply_grow_effect(effect.data_id, val2)
					result_data["growth"].append({"param_id": effect.data_id, "amount": val2})
					result_data["callables"].append(target.apply_grow_effect.bind(effect.data_id, val2))
			EffectCode.LEARN_SKILL:
				result_data["learned_skills"].append(effect.data_id)
			13:
				result_data["common_event"] = effect.data_id
					
	var final_hp = clone.params.hp if "params" in clone else 0
	var final_mp = clone.params.mp if "params" in clone else 0
	var final_tp = clone.get_parameter("TP") if clone.has_method("get_parameter") else 0
	
	if "params" in clone:
		result_data["hp_change"] = final_hp - initial_hp
		result_data["mp_change"] = final_mp - initial_mp
		
	if clone.has_method("get_parameter"):
		result_data["tp_change"] = final_tp - initial_tp
		
	var final_states = []
	if "current_states" in clone:
		for s in clone.current_states:
			final_states.append(s.id)
			
	var states_to_check_added = final_states.duplicate()
	var states_to_check_removed = initial_states.duplicate()
	
	for s in initial_states:
		var idx = states_to_check_added.find(s)
		if idx != -1:
			states_to_check_added.remove_at(idx)
			
	for s in final_states:
		var idx = states_to_check_removed.find(s)
		if idx != -1:
			states_to_check_removed.remove_at(idx)
			
	result_data["added_states"] = states_to_check_added
	result_data["removed_states"] = states_to_check_removed
	
	var final_buffs = clone.temp_buffs if "temp_buffs" in clone else []
	var buffs_to_check_added = final_buffs.duplicate()
	var buffs_to_check_removed = initial_buffs.duplicate()
	
	for b in initial_buffs:
		var idx = buffs_to_check_added.find(b)
		if idx != -1:
			buffs_to_check_added.remove_at(idx)
			
	for b in final_buffs:
		var idx = buffs_to_check_removed.find(b)
		if idx != -1:
			buffs_to_check_removed.remove_at(idx)
			
	result_data["added_buffs"] = buffs_to_check_added
	result_data["removed_buffs"] = buffs_to_check_removed
	
	var final_debuffs = clone.temp_debuff if "temp_debuff" in clone else []
	var debuffs_to_check_added = final_debuffs.duplicate()
	var debuffs_to_check_removed = initial_debuffs.duplicate()
	
	for d in initial_debuffs:
		var idx = debuffs_to_check_added.find(d)
		if idx != -1:
			debuffs_to_check_added.remove_at(idx)
			
	for d in final_debuffs:
		var idx = debuffs_to_check_removed.find(d)
		if idx != -1:
			debuffs_to_check_removed.remove_at(idx)
			
	result_data["added_debuffs"] = debuffs_to_check_added
	result_data["removed_debuffs"] = debuffs_to_check_removed
	
	for key in result_data:
		match typeof(result_data[key]):
			TYPE_ARRAY:
				if not result_data[key].is_empty():
					result_data["success"] = true
					break
			TYPE_INT, TYPE_FLOAT:
				if result_data[key] != 0:
					result_data["success"] = true
					break
			TYPE_CALLABLE:
				result_data["success"] = true
				break

	if clone is Node and clone != target:
		clone.queue_free()
	elif clone is Object and not clone is RefCounted and clone != target:
		clone.free()
	
	print(result_data)
	
	return result_data


func simulate_use_item(user: Variant, target: Variant, item: GameItem) -> Dictionary:
	var real_item: RPGItem = item.get_real_data()
	
	if not real_item:
		return _get_default_simulate_data()
		
	return _simulate_generic(user, target, real_item)


func simulate_use_skill(user: Variant, target: Variant, skill_id: int) -> Dictionary:
	var real_skill: RPGSkill = RPGSYSTEM.database.skills[skill_id] \
		if skill_id > 0 and RPGSYSTEM.database.skills.size() > skill_id else null
		
	if not real_skill:
		return _get_default_simulate_data()
		
	return _simulate_generic(user, target, real_skill)
