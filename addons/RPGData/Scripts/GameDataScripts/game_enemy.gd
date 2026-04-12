class_name GameEnemy
extends GameBattler

## Represents a hostile monster or adversary in combat.
##
## Inherits all core combat logic from GameBattler. Handles enemy-specific
## data such as static database parameters, experience/gold rewards, and loot drops.


## Returns the real RPGEnemy data from the database.
func get_real_enemy() -> RPGEnemy:
	if id > 0 and RPGSYSTEM.database.enemies.size() > id:
		return RPGSYSTEM.database.enemies[id]
	return null


## Initializes the enemy using its ID and loads its base data from the database.
func initialize(_id: int) -> void:
	if RPGSYSTEM.database.enemies.size() > _id:
		id = _id
		var enemy_data = RPGSYSTEM.database.enemies[_id]
		
		current_name = enemy_data.name
		
		trait_list.clear()
		for tr: RPGTrait in enemy_data.traits:
			trait_list.append(tr.clone(true))
			
		recover_all()
		
		var static_traits = enemy_data.traits.filter(func(t: RPGTrait): return t.code == TraitCode.ADD_STATE)
		for state_trait in static_traits:
			add_trait_state(state_trait)


## Internal: Implementation of base parameter retrieval for enemies.
func _get_base_parameter(search_param: String) -> float:
	var value = super._get_base_parameter(search_param)
	var enemy_data = get_real_enemy()
	
	if enemy_data:
		if search_param in RPGActor.BaseParamType.keys():
			var p_id = RPGActor.BaseParamType[search_param]
			if enemy_data.params.size() > p_id:
				value = float(enemy_data.params[p_id])
				
	return value


## Internal: Enemies typically do not have extra equipment traits.
func _get_extra_traits() -> Array:
	return []


## Re-evaluates and applies all permanent states from inherent traits.
func restore_permanent_states_after_battle() -> void:
	var states_to_erase = current_states.filter(func(s: GameState): return s != null and s.is_permanent())
	for state in states_to_erase:
		current_states.erase(state)
	
	var enemy_data = get_real_enemy()
	
	if enemy_data:
		for t in enemy_data.traits:
			if t.code == TraitCode.ADD_STATE: add_trait_state(t)
			
	parameter_changed.emit()
	emit_changed()


## Returns the experience reward for defeating this enemy.
func get_exp_reward() -> int:
	var enemy_data = get_real_enemy()
	
	if enemy_data:
		return enemy_data.experience_reward
		
	return 0


## Returns the gold reward for defeating this enemy, calculating a random value within its range.
func get_gold_reward() -> int:
	var enemy_data = get_real_enemy()
	
	if enemy_data:
		return randi_range(enemy_data.gold_reward_from, enemy_data.gold_reward_to)
		
	return 0


## Returns an array of dictionaries representing the generated drops based on probabilities and quantity ranges.
func make_drop_items() -> Array:
	var drops = []
	var enemy_data = get_real_enemy()
	
	if enemy_data:
		for drop: RPGItemDrop in enemy_data.drop_items:
			if drop.percent > 0.0 and randf() * 100.0 <= drop.percent:
				var generated_drop = {
					"data_id": drop.item.data_id,
					"item_id": drop.item.item_id,
					"quantity": randi_range(drop.quantity, drop.quantity2),
					"level": randi_range(drop.min_level, drop.max_level)
				}
				drops.append(generated_drop)
				
	return drops
