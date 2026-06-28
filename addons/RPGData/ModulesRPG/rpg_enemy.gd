@tool
class_name RPGEnemy
extends  Resource


func get_class(): return "RPGEnemy"


## Unique identifier used for internal referencing and persistence.
@export var _uniq_id: int = -1 :
	get():
		if _uniq_id < 0: _uniq_id = RPGSYSTEM.generate_16_digit_id()
		return _uniq_id

@export var id: int = 0
@export var name: String = ""
@export var description: String = ""
@export var unknown_description: String = ""
## Rarity type of the enemy.
@export var rarity_type: int = 0
@export var icon: RPGIcon = RPGIcon.new()
@export var battler: String = ""
@export var enemy_scene: String = ""
@export var params: PackedInt32Array = [0, 0, 0, 0, 0, 0, 0, 0]
## list of user-defined parameters in [Database/Types/User Parameters]
@export var user_parameters: PackedFloat32Array = []
@export var experience_reward: int = 0
@export var gold_reward_from: int = 0
@export var gold_reward_to: int = 0
@export var drop_items: Array[RPGItemDrop] = []
@export var action_patterns: Array[RPGEnemyAction] = []
@export var traits: Array[RPGTrait] = []
@export var notes: String = ""
@export var battle_actions: Array[RPGActorBattleAction] = []


func clear() -> void:
	for v in ["name", "description", "battler", "enemy_scene", "notes"]: set(v, "")
	for v in [drop_items, action_patterns, traits, battle_actions]: v.clear()
	params = PackedInt32Array([0, 0, 0, 0, 0, 0, 0, 0])
	experience_reward = 0
	gold_reward_from = 0
	gold_reward_to = 0
	rarity_type = 0
	icon.clear()
	
	var database = RPGSYSTEM.database
	if database:
		user_parameters.resize(database.types.user_parameters.size())
		for i in database.types.user_parameters.size():
			user_parameters[i] = database.types.user_parameters[i].default_value


## Gets the parameter value for a specific level.
## @param parameter String - The parameter to get.
## @param level int - The level to get the parameter for.
## @return int - The parameter value.
func get_parameter(parameter: String) -> float:
	if parameter.begins_with("USER_PARAMETER_"):
		var param_id = parameter.replace("USER_PARAMETER_", "").to_int()
		return get_user_parameter(param_id, 1)

	var param_index: int = -1

	if RPGActor.BaseParamType.keys().has(parameter):
		param_index = RPGActor.BaseParamType[parameter]

	if param_index == -1:
		return 0.0

	return float(params[param_index])


## Gets the user parameter value for a specific level.
func get_user_parameter(param_id: int, level_id: int) -> float:
	var current_value = 0
	
	if user_parameters.size() > param_id and param_id >= 0:
		current_value += user_parameters[param_id]
	
	return current_value


func clone(value: bool = true) -> RPGEnemy:
	var new_enemy = duplicate(value)
	
	for i in new_enemy.drop_items.size():
		new_enemy.drop_items[i] = new_enemy.drop_items[i].clone(value)
	for i in new_enemy.action_patterns.size():
		new_enemy.action_patterns[i] = new_enemy.action_patterns[i].clone(value)
	for i in new_enemy.traits.size():
		new_enemy.traits[i] = new_enemy.traits[i].clone(value)
	for i in new_enemy.battle_actions.size():
		new_enemy.battle_actions[i] = new_enemy.battle_actions[i].clone(value)
	
	new_enemy.icon = icon.clone(value)
	
	return new_enemy


## Returns a formatted list of reward items for this enemy.
## Each item in the list is a dictionary with the following structure:
## {
##     "item_type": int,      # 0 = items, 1 = weapons, 2 = armors, 3 = costumes
##     "item_id": int,        # Item ID / UID
##     "name": String,        # Item name
##     "icon": Texture2D,     # Icon texture (or null)
##     "min_quantity": int,   # Minimum quantity
##     "max_quantity": int,   # Maximum quantity
##     "min_level": int,      # Minimum level
##     "max_level": int,      # Maximum level
##     "percent": float       # Drop chance percentage
## }
func get_rewards() -> Array[Dictionary]:
	var formatted_list: Array[Dictionary] = []
	
	for drop: RPGItemDrop in drop_items:
		if not drop or not drop.item:
			continue
			
		var item_comp: RPGComponent = drop.item
		var item_type: int = item_comp.data_id
		var item_id: int = item_comp.item_id
		
		var db_key := ""
		match item_type:
			0: db_key = "items"
			1: db_key = "weapons"
			2: db_key = "armors"
			3: db_key = "costumes"
			
		var name_str := ""
		var icon_tex: Texture2D = null
		
		var resolved_id := item_id
		if db_key != "":
			if resolved_id > 0 and resolved_id < 1000000 and is_instance_valid(RPGSYSTEM):
				resolved_id = RPGSYSTEM.id_to_uid(db_key, resolved_id)
				
			var res_data = RPGSYSTEM.get_data(db_key, resolved_id) if is_instance_valid(RPGSYSTEM) else null
			if res_data:
				name_str = res_data.name
				if res_data.icon:
					icon_tex = res_data.icon.get_texture()
					
		var min_q = min(drop.quantity, drop.quantity2)
		var max_q = max(drop.quantity, drop.quantity2)
		
		formatted_list.append({
			"item_type": item_type,
			"item_id": item_id,
			"name": name_str,
			"icon": icon_tex,
			"min_quantity": min_q,
			"max_quantity": max_q,
			"percent": drop.percent,
			"min_level": drop.min_level,
			"max_level": drop.max_level,
		})
		
	return formatted_list
