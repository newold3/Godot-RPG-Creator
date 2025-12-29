@tool
extends CommandBaseDialog


var current_data: Dictionary
var current_variable_id: int = 1
var operand_variable_id: int = 1
var busy: bool = false

var cache_data = {
	"constant": 8,
	"variable": 1,
	"random": [1, 1],
	"game_data": [8, 0, 0],
	"script": ""
}


func _ready() -> void:
	super()
	parameter_code = 18


func set_data() -> void:
	var data: Dictionary = parameters[0].parameters
	current_data = data.duplicate()
	busy = true
	var from = data.get("from", 1)
	var to = data.get("to", 1)
	if from != to:
		%Random.set_pressed(true)
		%From.value = from
		%To.value = to
	else:
		%Single.set_pressed(false)
		%Single.set_pressed(true)
		%From.value = from
		%To.value = from
	current_data.from = %From.value
	current_data.to = %To.value
	var operation_id = data.get("operation_type", 0)
	current_data.operation_type = operation_id
	var operators = [%OperationSet, %OperationAdd, %OperationSub, %OperationMul, %OperationDiv, %OperationMod]
	operators[operation_id].set_pressed(false)
	operators[operation_id].set_pressed(true)
	var operand_type = data.get("operand_type", 0)
	current_data.operand_type = operand_type
	var node1
	var node2
	var operands = [%Constant, %Variable, %OperandRandom, %GameData, %Script]
	operands[operand_type].set_pressed(false)
	operands[operand_type].set_pressed(true)
	match operand_type:
		0:
			node1 = %OperandConstant
			cache_data.constant = int(data.get("value1", 0))
			current_data.value1 = cache_data.constant
		1:
			operand_variable_id = data.get("value1", 1)
			cache_data.variable = operand_variable_id
			current_data.value1 = operand_variable_id
		2:
			node1 = %OperandFrom
			node2 = %OperandTo
			cache_data.random = [data.get("value1", 1), data.get("value2", 1)]
			current_data.value1 = cache_data.random[0]
			current_data.value2 = cache_data.random[1]
		3:
			_set_game_data_text()
			cache_data.game_data = [
				data.get("value1", cache_data.game_data[0]),
				data.get("value2", cache_data.game_data[1]),
				data.get("value3", cache_data.game_data[2])
			]
			current_data.value1 = cache_data.game_data[0]
			current_data.value2 = cache_data.game_data[1]
			current_data.value3 = cache_data.game_data[2]
		4:
			node1 = %OperandScript
			cache_data.script = data.get("value2", "")
			current_data.value2 = cache_data.script
	
	if node1:
		if node1 is SpinBox:
			node1.value = int(data.get("value1", 0))
			current_data.value1 = node1.value
		elif node1 is LineEdit:
			node1.text = data.get("value1", "")
			current_data.value1 = node1.text
	if node2:
		if node2 is SpinBox:
			node2.value = data.get("value2", 0)
			current_data.value2 = node2.value
		elif node2 is LineEdit:
			node2.text = data.get("value2", "")
			current_data.value2 = node2.text
	
	current_variable_id = current_data.from
		
	_set_variable_name()
	_set_operand_variable_name()
	if operand_type == 3:
		_set_game_data_text()
	else:
		var bak = [
			current_data.get("value1", 8),
			current_data.get("value2", 0),
			current_data.get("value3", 0)
		]
		current_data.value1 = cache_data.game_data[0]
		current_data.value2 = cache_data.game_data[1]
		current_data.value3 = cache_data.game_data[2]
		_set_game_data_text()
		current_data.value1 = bak[0]
		current_data.value2 = bak[1]
		current_data.value3 = bak[2]
	busy = false


func _on_item_id_pressed() -> void:
	var path = "res://addons/CustomControls/Dialogs/switch_variable_dialog.tscn"
	var callable = _on_variable_changed
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	dialog.data_type = 0
	dialog.target = null
	dialog.selected.connect(callable)
	dialog.variable_or_switch_name_changed.connect(_set_variable_name)
	dialog.setup(current_data.from)


func _on_variable_changed(index: int, target: Node) -> void:
	current_data.from = index
	current_data.to = index
	current_variable_id = index
	_set_variable_name()


func _set_variable_name() -> void:
	var variables = RPGSYSTEM.system.variables
	var index = current_variable_id
	var variable_name = "%s: %s" % [
		str(index).pad_zeros(4),
		variables.get_item_name(index)
	]
	%ItemID.text = variable_name


func _on_from_value_changed(value: float) -> void:
	if busy: return
	if value > current_data.to:
		%To.value = value
	current_data.from = value


func _on_to_value_changed(value: float) -> void:
	if busy: return
	if value < current_data.from:
		%From.value = current_data.to
	current_data.to = value


func build_command_list() -> Array[RPGEventCommand]:
	var commands: Array[RPGEventCommand] = super()
	if %Single.is_pressed():
		current_data.to = current_data.from
	commands[-1].parameters = current_data
	return commands


func _on_single_toggled(toggled_on: bool) -> void:
	if toggled_on:
		%From.set_disabled(true)
		%To.set_disabled(true)
		%ItemID.set_disabled(false)


func _on_random_toggled(toggled_on: bool) -> void:
	if toggled_on:
		%From.set_disabled(false)
		%To.set_disabled(false)
		%ItemID.set_disabled(true)


func _on_operand_toggled(toggled_on: bool, command_id: int) -> void:
	current_data.operand_type = command_id
	cache_data.constant = command_id
	var node = [%Constant, %Variable, %OperandRandom, %GameData, %Script][command_id]
	if toggled_on:
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
	else:
		node.get_parent().propagate_call("set_disabled", [true])
		node.set_disabled(false)
	propagate_call("release_focus")


func _on_operation_changed(toggled_on: bool, command_type: int) -> void:
	current_data.operation_type = command_type


func _on_operand_constant_value_changed(value: float) -> void:
	current_data.value1 = value


func _on_operand_from_value_changed(value: float) -> void:
	if busy: return
	if value > current_data.value2:
		%OperandTo.value = value
	current_data.value1 = value
	cache_data.random[0] = value


func _on_operand_to_value_changed(value: float) -> void:
	if busy: return
	if value < current_data.value1:
		%OperandFrom.value = value
	current_data.value2 = value
	cache_data.random[1] = value
	


func _on_operand_script_text_changed(new_text: String) -> void:
	current_data.value1 = new_text
	cache_data.script = new_text


func _on_operand_variable_id_pressed() -> void:
	var path = "res://addons/CustomControls/Dialogs/switch_variable_dialog.tscn"
	var callable = _on_operand_variable_changed
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	dialog.data_type = 0
	dialog.target = null
	dialog.selected.connect(callable)
	dialog.variable_or_switch_name_changed.connect(_set_operand_variable_name)
	dialog.setup(current_data.from)


func _on_operand_variable_changed(index: int, target: Node) -> void:
	current_data.value1 = index
	operand_variable_id = index
	cache_data.variable = index
	_set_operand_variable_name()


func _set_operand_variable_name() -> void:
	var variables = RPGSYSTEM.system.variables
	var index = operand_variable_id
	var variable_name = "%s:%s" % [
		str(index).pad_zeros(4),
		variables.get_item_name(index)
	]
	%OperandVariableID.text = variable_name


func _on_operand_game_data_pressed() -> void:
	var path = "res://addons/CustomControls/Dialogs/CommandEvents/control_variable_sub_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)

	dialog.option_selected.connect(game_data_selected)
	dialog.set_data(current_data.value1, current_data.value2, current_data.value3)


func game_data_selected(value1: int, value2: int, value3: int) -> void:
	current_data.value1 = value1
	current_data.value2 = value2
	current_data.value3 = value3
	cache_data.game_data = [value1, value2, value3]
	_set_game_data_text()


func _set_game_data_text() -> void:
	var node = %OperandGameData
	match current_data.value1:
		0: # Item
			var items = RPGSYSTEM.database.items
			var index = max(1, current_data.value2)
			if items.size() > index:
				var item_name = "%s:%s" % [
					str(index).pad_zeros(str(items.size()).length()),
					items[index].name
				]
				node.text = TranslationManager.tr("Number of the < %s >") % item_name
			else:
				node.text = TranslationManager.tr("Number of the ?")
		1: # Weapon
			var items = RPGSYSTEM.database.weapons
			var index = max(1, current_data.value2)
			if items.size() > index:
				var item_name = "%s:%s" % [
					str(index).pad_zeros(str(items.size()).length()),
					items[index].name
				]
				node.text = TranslationManager.tr("Number of the < %s >") % item_name
			else:
				node.text = TranslationManager.tr("Number of the ?")
		2: # Armor
			var items = RPGSYSTEM.database.armors
			var index = max(1, current_data.value2)
			if items.size() > index:
				var item_name = "%s:%s" % [
					str(index).pad_zeros(str(items.size()).length()),
					items[index].name
				]
				node.text = TranslationManager.tr("Number of the < %s >") % item_name
			else:
				node.text = TranslationManager.tr("Number of the ?")
		3: # Actor
			var parameters = PackedStringArray(["Level", "Experience"]) + RPGSYSTEM.database.types.main_parameters
			var target_value: String
			if current_data.value3 >= 0 and current_data.value3 < parameters.size():
				target_value = parameters[current_data.value3]
			elif current_data.value3 > parameters.size(): # user paramater
				var user_parameter_id = current_data.value3 - parameters.size() - 1
				var user_parameters = RPGSYSTEM.database.types.user_parameters
				if user_parameters.size() > user_parameter_id:
					target_value = "User Parameter " + user_parameters[user_parameter_id].name
				else:
					target_value = "User Parameter ?"
			
			var index = max(1, current_data.value2)
			var items = RPGSYSTEM.database.actors
			if items.size() > index:
				var item_name = "%s:%s" % [
					str(index).pad_zeros(str(items.size()).length()),
					items[index].name
				]
				node.text = TranslationManager.tr("%s of < %s >") % [target_value, item_name]
			else:
				node.text = TranslationManager.tr("%s of ?") % target_value
		4: # Enemy
			var parameter = [
				"HP", "MP", "Max HP", "Max MP", "Attack", "Defense",
				"Magic Attack", "Magic Defense", "Agility", "Luck", "TP"
			][current_data.value3]
			var item_name = ["#1", "#2", "#3", "#4", "#5", "#6", "#7", "#8"][current_data.value2]
			node.text = TranslationManager.tr("%s of < %s >") % [parameter, item_name]
		5: # Character
			var parameter = ["Map X", "Map Y", "Direction", "Screen X", "Screen Y", "Global Position X", "Global Position Y", "Z-Index"][current_data.value3]
			var item_name = ["Player", "This Event"][current_data.value2]
			node.text = TranslationManager.tr("%s of < %s >") % [parameter, item_name]
		6: # Party
			node.text = TranslationManager.tr("Actor ID of party member #%s") % (current_data.value2 + 1)
		7: # Last
			var option = [
				"Last Used Skill ID", "Last Used Item ID", "Last Actor ID To Act",
				"Last Enemy Index To Act", "Last Target Actor ID", "Last Target Enemy Index"
			][current_data.value2]
			node.text = option
		8: # Other
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
				if param_id > 0 and user_parameters.size() > param_id:
					text = option + " < %s >" % user_parameters[param_id].name
				else:
					text = option + " < ? >"
			else:
				text = option
			node.text = text
		9: # Profession
			var items = RPGSYSTEM.database.professions
			var index = max(1, current_data.value2)
			if items.size() > index:
				var item_name = "%s:%s" % [
					str(index).pad_zeros(str(items.size()).length()),
					items[index].name
				]
				node.text = TranslationManager.tr("Level of the < %s >") % item_name
			else:
				node.text = TranslationManager.tr("Level of the ?")
		10: # Stat
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
				
			var extra = " (ID = %s)" % current_data.value3 if current_data.value2 in [2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 31] else  ""
			node.text = option + extra


func _on_open_advanced_script_editor_pressed() -> void:
	var path = "res://addons/CustomControls/Dialogs/script_text_editor.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	dialog.set_text(%OperandScript.text)
	dialog.text_changed.connect(
		func(new_text: String):
			%OperandScript.text = new_text
			%OperandScript.text_changed.emit(new_text)
	)
