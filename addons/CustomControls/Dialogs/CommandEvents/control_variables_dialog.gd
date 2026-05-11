@tool
extends CommandBaseDialog

#region Variables
var current_data: Dictionary
var current_variable_id: int = 1
var operand_variable_id: int = 1
var busy: bool = false

var cache_data = {
	"constant": 0,
	"variable": 1,
	"random": [1, 1],
	"game_data": [8, 0, 0],
	"script": ""
}
#endregion



#region Initialization
## Called when the node enters the scene tree for the first time
func _ready() -> void:
	super()
	parameter_code = 18



## Sets up the dialog data from the command parameters safely without triggering signals
func set_data() -> void:
	var data: Dictionary = parameters[0].parameters
	current_data = data.duplicate()
	busy = true
	var from = data.get("from", 1)
	var to = data.get("to", 1)
	
	if from != to:
		%Random.set_pressed_no_signal(true)
		%Single.set_pressed_no_signal(false)
		%From.value = from
		%To.value = to
	else:
		%Random.set_pressed_no_signal(false)
		%Single.set_pressed_no_signal(true)
		%From.value = from
		%To.value = from
		
	current_data.from = %From.value
	current_data.to = %To.value
	
	var operation_id = data.get("operation_type", 0)
	current_data.operation_type = operation_id
	var operators = [%OperationSet, %OperationAdd, %OperationSub, %OperationMul, %OperationDiv, %OperationMod]
	for op in operators:
		op.set_pressed_no_signal(false)
	operators[operation_id].set_pressed_no_signal(true)
	
	var operand_type = data.get("operand_type", 0)
	current_data.operand_type = operand_type
	var operands = [%Constant, %Variable, %OperandRandom, %GameData, %Script]
	for op in operands:
		op.set_pressed_no_signal(false)
	operands[operand_type].set_pressed_no_signal(true)
	
	# Load cache data safely
	match operand_type:
		0:
			cache_data.constant = int(data.get("value1", 0))
		1:
			operand_variable_id = data.get("value1", 1)
			cache_data.variable = operand_variable_id
		2:
			cache_data.random = [data.get("value1", 1), data.get("value2", 1)]
		3:
			cache_data.game_data = [
				data.get("value1", 8),
				data.get("value2", 0),
				data.get("value3", 0)
			]
		4:
			cache_data.script = data.get("value1", "")
	
	# Update UI nodes silently
	%OperandConstant.value = cache_data.constant
	%OperandFrom.value = cache_data.random[0]
	%OperandTo.value = cache_data.random[1]
	%OperandScript.text = cache_data.script
	
	current_variable_id = current_data.from
	_set_variable_name()
	_set_operand_variable_name()
	
	# Enable/Disable operand sections
	for i in range(5):
		var node = operands[i]
		if i == operand_type:
			node.get_parent().propagate_call("set_disabled", [false])
		else:
			node.get_parent().propagate_call("set_disabled", [true])
			node.set_disabled(false)
	
	# Compute text for GameData button
	var bak = [
		current_data.get("value1", 8),
		current_data.get("value2", 0),
		current_data.get("value3", 0)
	]
	
	current_data.value1 = cache_data.game_data[0]
	current_data.value2 = cache_data.game_data[1]
	current_data.value3 = cache_data.game_data[2]
	_set_game_data_text()
	
	# Restore actual parameters
	current_data.value1 = bak[0]
	current_data.value2 = bak[1]
	current_data.value3 = bak[2]
		
	busy = false
#endregion



#region UI_Handlers
## Opens the variable selection dialog for the target
func _on_item_id_pressed() -> void:
	var path = "res://addons/CustomControls/Dialogs/switch_variable_dialog.tscn"
	var callable = _on_variable_changed
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	dialog.data_type = 0
	dialog.target = null
	dialog.selected.connect(callable)
	dialog.variable_or_switch_name_changed.connect(_set_variable_name)
	dialog.setup(current_data.from)



## Callback when a target variable is selected
func _on_variable_changed(index: int, target: Node) -> void:
	current_data.from = index
	current_data.to = index
	current_variable_id = index
	_set_variable_name()



## Updates the button text for the selected target variable
func _set_variable_name() -> void:
	var variables = RPGSYSTEM.system.variables
	var index = current_variable_id
	var variable_name = "%s: %s" % [
		str(index).pad_zeros(4),
		variables.get_item_name(index)
	]
	%ItemID.text = variable_name



## Handles the change of the starting variable index
func _on_from_value_changed(value: float) -> void:
	if busy or not current_data: return
	if value > current_data.to:
		%To.value = value
	current_data.from = value



## Handles the change of the ending variable index
func _on_to_value_changed(value: float) -> void:
	if busy or not current_data: return
	if value < current_data.from:
		%From.value = current_data.to
	current_data.to = value



## Builds the final command list with the updated parameters
func build_command_list() -> Array[RPGEventCommand]:
	var commands: Array[RPGEventCommand] = super()
	if %Single.is_pressed():
		current_data.to = current_data.from
	commands[-1].parameters = current_data
	return commands



## Toggles the UI for a single variable selection
func _on_single_toggled(toggled_on: bool) -> void:
	if toggled_on:
		%From.set_disabled(true)
		%To.set_disabled(true)
		%ItemID.set_disabled(false)



## Toggles the UI for a range of variables selection
func _on_random_toggled(toggled_on: bool) -> void:
	if toggled_on:
		%From.set_disabled(false)
		%To.set_disabled(false)
		%ItemID.set_disabled(true)



## Handles the change of the operand type safely avoiding data corruption
func _on_operand_toggled(toggled_on: bool, command_id: int) -> void:
	if busy or not toggled_on: return
	current_data.operand_type = command_id
	
	var node = [%Constant, %Variable, %OperandRandom, %GameData, %Script][command_id]
	node.get_parent().propagate_call("set_disabled", [false])
	
	match command_id:
		0: current_data.value1 = cache_data.constant
		1: current_data.value1 = cache_data.variable
		2:
			current_data.value1 = cache_data.random[0]
			current_data.value2 = cache_data.random[1]
		3:
			current_data.value1 = cache_data.game_data[0]
			current_data.value2 = cache_data.game_data[1]
			current_data.value3 = cache_data.game_data[2]
		4: current_data.value1 = cache_data.script
			
	propagate_call("release_focus")
	
	for i in range(5):
		if i != command_id:
			[%Constant, %Variable, %OperandRandom, %GameData, %Script][i].get_parent().propagate_call("set_disabled", [true])
			[%Constant, %Variable, %OperandRandom, %GameData, %Script][i].set_disabled(false)



## Handles the change of the mathematical operation type
func _on_operation_changed(toggled_on: bool, command_type: int) -> void:
	if toggled_on:
		current_data.operation_type = command_type



## Handles the change of a constant operand value
func _on_operand_constant_value_changed(value: float) -> void:
	if busy: return
	cache_data.constant = int(value)
	if current_data.operand_type == 0:
		current_data.value1 = cache_data.constant



## Handles the change of the starting random value
func _on_operand_from_value_changed(value: float) -> void:
	if busy or not current_data: return
	if "value2" in current_data and value > current_data.get("value2", -INF):
		%OperandTo.value = value
	cache_data.random[0] = value
	if current_data.operand_type == 2:
		current_data.value1 = value



## Handles the change of the ending random value
func _on_operand_to_value_changed(value: float) -> void:
	if busy or not current_data: return
	if value < current_data.value1:
		%OperandFrom.value = value
	cache_data.random[1] = value
	if current_data.operand_type == 2:
		current_data.value2 = value
	


## Handles script text changes
func _on_operand_script_text_changed(new_text: String) -> void:
	if busy: return
	cache_data.script = new_text
	if current_data.operand_type == 4:
		current_data.value1 = new_text



## Opens the variable selection dialog for the operand
func _on_operand_variable_id_pressed() -> void:
	var path = "res://addons/CustomControls/Dialogs/switch_variable_dialog.tscn"
	var callable = _on_operand_variable_changed
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	dialog.data_type = 0
	dialog.target = null
	dialog.selected.connect(callable)
	dialog.variable_or_switch_name_changed.connect(_set_operand_variable_name)
	dialog.setup(operand_variable_id)



## Callback when an operand variable is selected
func _on_operand_variable_changed(index: int, target: Node) -> void:
	operand_variable_id = index
	cache_data.variable = index
	if current_data.operand_type == 1:
		current_data.value1 = index
	_set_operand_variable_name()



## Updates the button text for the selected operand variable
func _set_operand_variable_name() -> void:
	var variables = RPGSYSTEM.system.variables
	var index = operand_variable_id
	var variable_name = "%s:%s" % [
		str(index).pad_zeros(4),
		variables.get_item_name(index)
	]
	%OperandVariableID.text = variable_name



## Opens the sub-dialog to pick specific game data
func _on_operand_game_data_pressed() -> void:
	var path = "res://addons/CustomControls/Dialogs/CommandEvents/control_variable_sub_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)

	dialog.option_selected.connect(game_data_selected)
	var v1 = cache_data.game_data[0] if current_data.operand_type != 3 else current_data.value1
	var v2 = cache_data.game_data[1] if current_data.operand_type != 3 else current_data.value2
	var v3 = cache_data.game_data[2] if current_data.operand_type != 3 else current_data.value3
	dialog.set_data(v1, v2, v3)



## Callback from the game data sub-dialog
func game_data_selected(value1: int, value2: int, value3: int) -> void:
	cache_data.game_data = [value1, value2, value3]
	if current_data.operand_type == 3:
		current_data.value1 = value1
		current_data.value2 = value2
		current_data.value3 = value3
		_set_game_data_text()



## Opens the advanced script editor dialog
func _on_open_advanced_script_editor_pressed() -> void:
	var path = "res://addons/CustomControls/Dialogs/script_text_editor.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	dialog.set_text(%OperandScript.text)
	dialog.text_changed.connect(
		func(new_text: String):
			%OperandScript.text = new_text
			%OperandScript.text_changed.emit(new_text)
	)
#endregion



#region Logic
## Updates the text to display the current game data selection utilizing UIDs
func _set_game_data_text() -> void:
	var node = %OperandGameData
	match current_data.value1:
		0:
			var item = RPGSYSTEM.get_data("items", current_data.value2)
			if item:
				var classic_id = RPGSYSTEM.uid_to_id("items", current_data.value2)
				var items_size = RPGSYSTEM.database.items.size()
				var item_name = "%s: %s" % [str(classic_id).pad_zeros(str(items_size).length()), item.name]
				node.text = TranslationManager.tr("Number of the < %s >") % item_name
			else:
				node.text = TranslationManager.tr("Number of the ?")
		1:
			var item = RPGSYSTEM.get_data("weapons", current_data.value2)
			if item:
				var classic_id = RPGSYSTEM.uid_to_id("weapons", current_data.value2)
				var items_size = RPGSYSTEM.database.weapons.size()
				var item_name = "%s: %s" % [str(classic_id).pad_zeros(str(items_size).length()), item.name]
				node.text = TranslationManager.tr("Number of the < %s >") % item_name
			else:
				node.text = TranslationManager.tr("Number of the ?")
		2:
			var item = RPGSYSTEM.get_data("armors", current_data.value2)
			if item:
				var classic_id = RPGSYSTEM.uid_to_id("armors", current_data.value2)
				var items_size = RPGSYSTEM.database.armors.size()
				var item_name = "%s: %s" % [str(classic_id).pad_zeros(str(items_size).length()), item.name]
				node.text = TranslationManager.tr("Number of the < %s >") % item_name
			else:
				node.text = TranslationManager.tr("Number of the ?")
		3:
			var parameters = PackedStringArray(["Level", "Experience"]) + RPGSYSTEM.database.types.main_parameters
			var target_value: String
			if current_data.value3 >= 0 and current_data.value3 < parameters.size():
				target_value = parameters[current_data.value3]
			elif current_data.value3 >= parameters.size():
				var user_parameter_id = current_data.value3 - parameters.size() - 1
				var user_parameters = RPGSYSTEM.database.types.user_parameters
				if user_parameters.size() > user_parameter_id and user_parameter_id >= 0:
					target_value = "User Parameter " + user_parameters[user_parameter_id].name
				else:
					target_value = "User Parameter ?"
			
			var actor = RPGSYSTEM.get_data("actors", current_data.value2)
			if actor:
				var classic_id = RPGSYSTEM.uid_to_id("actors", current_data.value2)
				var items_size = RPGSYSTEM.database.actors.size()
				var item_name = "%s: %s" % [str(classic_id).pad_zeros(str(items_size).length()), actor.name]
				node.text = TranslationManager.tr("%s of < %s >") % [target_value, item_name]
			else:
				node.text = TranslationManager.tr("%s of ?") % target_value
		4:
			var parameter = [
				"HP", "MP", "Max HP", "Max MP", "Attack", "Defense",
				"Magic Attack", "Magic Defense", "Agility", "Luck", "TP"
			][current_data.value3]
			var item_name = ["#1", "#2", "#3", "#4", "#5", "#6", "#7", "#8"][current_data.value2]
			node.text = TranslationManager.tr("%s of < %s >") % [parameter, item_name]
		5:
			var parameter = ["Map X", "Map Y", "Direction", "Screen X", "Screen Y", "Global Position X", "Global Position Y", "Z-Index"][current_data.value3]
			var item_name = ["Player", "This Event"][current_data.value2]
			node.text = TranslationManager.tr("%s of < %s >") % [parameter, item_name]
		6:
			node.text = TranslationManager.tr("Actor ID of party member #%s") % (current_data.value2 + 1)
		7:
			var option = [
				"Last Used Skill ID", "Last Used Item ID", "Last Actor ID To Act",
				"Last Enemy Index To Act", "Last Target Actor ID", "Last Target Enemy Index"
			][current_data.value2]
			node.text = option
		8:
			var index = current_data.value2
			var option = [
				"Map ID", "Party size", "Amount of gold", "Steps Count", "Play Time",
				"Timer", "Save Count", "Battle Count", "Win Count", "Escape Count",
				"Quests Failed", "Quests in Progress", "Total Completed Quests",
				"Total Enemy Kills", "Total Money Earned", "Total Quest Found",
				"Total Relationships Started", "Total Relationships Maximized",
				"Total Achievements Unlocked", "Global User Parameter"
			][index]
			var text:  String
			if index == 19:
				var user_parameters = RPGSYSTEM.database.types.user_parameters
				var param_id = current_data.value3
				if param_id >= 0 and user_parameters.size() > param_id:
					text = option + " < %s >" % user_parameters[param_id].name
				else:
					text = option + " < ? >"
			else:
				text = option
			node.text = text
		9:
			var profession = RPGSYSTEM.get_data("professions", current_data.value2)
			if profession:
				var classic_id = RPGSYSTEM.uid_to_id("professions", current_data.value2)
				var items_size = RPGSYSTEM.database.professions.size()
				var item_name = "%s: %s" % [str(classic_id).pad_zeros(str(items_size).length()), profession.name]
				node.text = TranslationManager.tr("Level of the < %s >") % item_name
			else:
				node.text = TranslationManager.tr("Level of the ?")
		10:
			var option: String
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
			if current_data.value2 < base_options.size():
				option = base_options[current_data.value2]
			else:
				var user_stat_id =  current_data.value2 - base_options.size() - 1
				if user_stat_id >= 0 and RPGSYSTEM.database.types.user_stats.size() > user_stat_id:
					option = RPGSYSTEM.database.types.user_stats[user_stat_id]
				else:
					option = "⚠ Invalid Stat"
				
			var extra = ""
			var target_uid = current_data.value3
			var db_key = ""
			var prefix = ""
			
			if current_data.value2 in [4, 5, 6]:
				db_key = "items"
				prefix = tr("Item")
			elif current_data.value2 in [7, 8, 9]:
				db_key = "weapons"
				prefix = tr("Weapon")
			elif current_data.value2 in [10, 11, 12]:
				db_key = "armors"
				prefix = tr("Armor")
			elif current_data.value2 in [31]:
				db_key = "professions"
				prefix = tr("Profession")
			elif current_data.value2 == 2:
				db_key = "enemies"
				prefix = tr("Enemy")
			elif current_data.value2 == 3:
				db_key = "skills"
				prefix = tr("Skill")
				
			if not db_key.is_empty():
				var item = RPGSYSTEM.get_data(db_key, target_uid)
				if item:
					var classic_id = RPGSYSTEM.uid_to_id(db_key, target_uid)
					var id_padded = str(classic_id).pad_zeros(str(RPGSYSTEM.database[db_key].size()).length())
					extra = " (%s: %s: %s)" % [prefix, id_padded, item.name]
				else:
					extra = " (%s: ⚠ Invalid Data)" % prefix
					
			node.text = option + extra
#endregion
