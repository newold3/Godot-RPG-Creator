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

## Signal emitted when an action is successfully executed.
signal action_success(target: Variant, changes: Dictionary)
## Signal emitted when an action fails.
signal action_failure(target: Variant)
## Signal emitted when an action is canceled.
signal action_canceled(target: Variant)



## Parses and evaluates a damage or healing formula using the Expression class.
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
	print("fornula = ", parsed_formula, "result = ", result)
	return int(result)


## Simulates the use of a GameItem on a target, calculating damage, healing, and processing all RPGEffects.
func simulate_use_item(user: Variant, target: Variant, item: GameItem) -> Dictionary:
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
		"removed_debuffs": []
	}
	var real_item = item.get_real_data() as RPGItem

	if not real_item:
		return result_data

	var base_value = _parse_formula(real_item.damage.formula, user, target)

	if base_value != 0:
		var variance_val = base_value * (real_item.damage.variance / 100.0)
		var final_value = base_value + randf_range(-variance_val, variance_val)

		if real_item.damage.type == 1 or real_item.damage.type == 3 or real_item.damage.type == 5:
			final_value = -final_value

		if real_item.damage.critical and randf() < user.get_parameter("CRI"):
			final_value *= 3.0

		var final_int = int(final_value)

		match real_item.damage.type:
			1, 2:
				result_data["hp_change"] += final_int
			3, 4:
				result_data["mp_change"] += final_int
			5, 6:
				result_data["hp_change"] += final_int
				result_data["mp_change"] += final_int

	for effect in real_item.effects:
		match effect.code:
			EffectCode.RECOVER_HP:
				var max_hp = target.get_parameter("HP") if target.has_method("get_parameter") else 0
				result_data["hp_change"] += int((max_hp * (effect.value1 / 100.0)) + effect.value2)
			EffectCode.RECOVER_MP:
				var max_mp = target.get_parameter("MP") if target.has_method("get_parameter") else 0
				result_data["mp_change"] += int((max_mp * (effect.value1 / 100.0)) + effect.value2)
			EffectCode.GAIN_TP:
				result_data["tp_change"] += effect.value1
			EffectCode.ADD_STATE:
				result_data["added_states"].append({"id": effect.data_id, "chance": effect.value1})
			EffectCode.REMOVE_STATE:
				result_data["removed_states"].append({"id": effect.data_id, "chance": effect.value1})
			EffectCode.ADD_BUFF:
				result_data["added_buffs"].append({"param_id": effect.data_id, "turns": effect.value1})
			EffectCode.ADD_DEBUFF:
				result_data["added_debuffs"].append({"param_id": effect.data_id, "turns": effect.value1})
			EffectCode.REMOVE_BUFF:
				result_data["removed_buffs"].append({"param_id": effect.data_id})
			EffectCode.REMOVE_DEBUFF:
				result_data["removed_debuffs"].append({"param_id": effect.data_id})

	if result_data["hp_change"] != 0 or result_data["mp_change"] != 0 or result_data["tp_change"] != 0 or result_data["added_states"].size() > 0 or result_data["added_buffs"].size() > 0 or result_data["added_debuffs"].size() > 0 or result_data["removed_states"].size() > 0 or result_data["removed_buffs"].size() > 0 or result_data["removed_debuffs"].size() > 0:
		result_data["success"] = true

	return result_data


## Simulates the use of a skill on a target.
func simulate_use_skill(user: Variant, target: Variant, skill_id: int) -> Dictionary:
	return {}
