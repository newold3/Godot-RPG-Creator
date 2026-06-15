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


@warning_ignore("unused_signal")
signal action_success(target: Variant, changes: Dictionary)


@warning_ignore("unused_signal")
signal action_failure(target: Variant)


@warning_ignore("unused_signal")
signal action_canceled(target: Variant)


var is_simulating: bool = false


## Returns a default dictionary structure for simulation results.
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



## Parses and evaluates a damage formula string using the user and target parameters.
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


## Simulates the effects of an action on a target to determine success and collect callables.
func _simulate_generic(user: Variant, target: GameActor, data: Variant) -> Dictionary:
	var result_data = _get_default_simulate_data()
	var state = GameManager.game_state
	
	var snap_items = _take_inventory_snapshot(state.items) if state else {}
	var snap_weapons = _take_inventory_snapshot(state.weapons) if state else {}
	var snap_armors = _take_inventory_snapshot(state.armors) if state else {}
	var snap_sets = _take_inventory_snapshot(state.sets) if state else {}
	
	var clone = target.clone() if target.has_method("clone") else target.duplicate(true)
	
	_mute_node_recursively(clone)
	
	if state:
		_restore_inventory_snapshot(state.items, snap_items)
		_restore_inventory_snapshot(state.weapons, snap_weapons)
		_restore_inventory_snapshot(state.armors, snap_armors)
		_restore_inventory_snapshot(state.sets, snap_sets)
	
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
		var _val3 = effect.value3 if "value3" in effect else 0.0
		
		match effect.code:
			EffectCode.RECOVER_HP:
				if clone.has_method("apply_recovery_effect"):
					clone.apply_recovery_effect("hp", effect.value1, effect.value2)
					result_data["callables"].append(target.apply_recovery_effect.bind("hp", effect.value1, effect.value2))
					
			EffectCode.RECOVER_MP:
				if clone.has_method("apply_recovery_effect"):
					clone.apply_recovery_effect("mp", effect.value1, effect.value2)
					result_data["callables"].append(target.apply_recovery_effect.bind("mp", effect.value1, effect.value2))
					
			EffectCode.GAIN_TP:
				var tp_val = effect.value1 if effect.value1 != 0 else effect.value2
				var op = 0 if tp_val > 0 else 1
				if clone.has_method("set_parameter"):
					clone.set_parameter("TP", abs(tp_val), op)
					result_data["callables"].append(target.set_parameter.bind("TP", abs(tp_val), op))
					
			EffectCode.ADD_STATE:
				var state_id = effect.data_id
				if clone.has_method("apply_state_effect"):
					if clone.apply_state_effect(state_id, effect.value2):
						var state_res = RPGSYSTEM.database.states[state_id]
						result_data["callables"].append(target.add_state.bind(state_res))
						
			EffectCode.REMOVE_STATE:
				var state_id = effect.data_id
				if clone.has_method("remove_state_effect"):
					if clone.remove_state_effect(state_id, effect.value2):
						result_data["callables"].append(target.execute_state_removal.bind(state_id))
							
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
				var before_count = clone.temp_buffs.size()
				if clone.has_method("remove_buff"):
					clone.remove_buff(effect.data_id, val2)
					if clone.temp_buffs.size() < before_count:
						result_data["callables"].append(target.remove_buff.bind(effect.data_id, val2))
						
			EffectCode.REMOVE_DEBUFF:
				var before_count = clone.temp_debuff.size()
				if clone.has_method("remove_debuff"):
					clone.remove_debuff(effect.data_id, val2)
					if clone.temp_debuff.size() < before_count:
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
	
	result_data["success"] = false
	if result_data.get("hp_change", 0) != 0: result_data["success"] = true
	elif result_data.get("mp_change", 0) != 0: result_data["success"] = true
	elif result_data.get("tp_change", 0) != 0: result_data["success"] = true
	elif not result_data.get("added_states", []).is_empty(): result_data["success"] = true
	elif not result_data.get("removed_states", []).is_empty(): result_data["success"] = true
	elif not result_data.get("added_buffs", []).is_empty(): result_data["success"] = true
	elif not result_data.get("removed_buffs", []).is_empty(): result_data["success"] = true
	elif not result_data.get("added_debuffs", []).is_empty(): result_data["success"] = true
	elif not result_data.get("removed_debuffs", []).is_empty(): result_data["success"] = true
	elif not result_data.get("special_effects", []).is_empty(): result_data["success"] = true
	elif not result_data.get("growth", []).is_empty(): result_data["success"] = true
	elif not result_data.get("learned_skills", []).is_empty(): result_data["success"] = true
	elif result_data.get("common_event", 0) > 0: result_data["success"] = true

	if clone is Object and clone != target and not clone is RefCounted:
		if clone is Node and clone.is_inside_tree():
			var parent = clone.get_parent()
			if parent:
				parent.remove_child(clone)
		clone.free()
	
	clone = null 
	
	if state:
		_restore_inventory_snapshot(state.items, snap_items)
		_restore_inventory_snapshot(state.weapons, snap_weapons)
		_restore_inventory_snapshot(state.armors, snap_armors)
		_restore_inventory_snapshot(state.sets, snap_sets)
	
	return result_data


## Recursively blocks all signals from an object and its children to prevent ghost events during simulation
func _mute_node_recursively(obj: Object) -> void:
	if obj:
		obj.set_block_signals(true)
		if obj is Node:
			for child in obj.get_children():
				_mute_node_recursively(child)


## Takes a shallow copy snapshot of a dictionary containing arrays
func _take_inventory_snapshot(collection: Dictionary) -> Dictionary:
	var snap = {}
	for k in collection:
		if typeof(collection[k]) == TYPE_ARRAY:
			snap[k] = collection[k].duplicate()
	return snap


## Restores a dictionary containing arrays to its snapshot state
func _restore_inventory_snapshot(collection: Dictionary, snapshot: Dictionary) -> void:
	var to_remove = []
	for k in collection:
		if not snapshot.has(k):
			to_remove.append(k)
		else:
			collection[k] = snapshot[k].duplicate()
	for k in to_remove:
		collection.erase(k)


#endregion


## Simulates using an item on a target to evaluate success and potential parameter changes.
func simulate_use_item(user: Variant, target: Variant, item: GameItem) -> Dictionary:
	var real_item: RPGItem = item.get_real_data()
	
	if not real_item:
		return _get_default_simulate_data()
		
	return _simulate_generic(user, target, real_item)



## Simulates using a skill on a target to evaluate success and potential parameter changes.
func simulate_use_skill(user: Variant, target: Variant, skill_id: int) -> Dictionary:
	var real_skill = RPGSYSTEM.get_data("skills", skill_id)
		
	if not real_skill:
		return _get_default_simulate_data()
		
	return _simulate_generic(user, target, real_skill)
