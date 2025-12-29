@tool
extends CommandBaseDialog


var current_data: Dictionary


var cache_data: Dictionary = {
	"item_selected": 0,
	"variable_item_selected": 0,
	"actor_item_selected": 0,
	"enemy_item_selected": 0,
	"switch_selected": 1,
	"switch_value": 0,
	"variable_selected": 1,
	"variable_condition": 0,
	"variable_constant": 0,
	"variable_variable_selected": 1,
	"self_switch_selected": 0,
	"self_switch_value": 0,
	"timer_condition": 0,
	"timer_minutes": 0,
	"timer_seconds": 0,
	"timer_id": 0,
	"actor_selected": 1,
	"actor_name": "",
	"actor_class_selected": 1,
	"actor_skill_selected": 1,
	"actor_weapon_selected": 1,
	"actor_armor_selected": 1,
	"actor_state_selected": 1,
	"enemy_selected": 0,
	"enemy_state_selected": 1,
	"character_selected": 0,
	"character_direction": 0,
	"vehicle_selected": 0,
	"gold_condition": 0,
	"gold_value": 0,
	"has_item_selected": 1,
	"has_weapon_selected": 1,
	"has_weapon_equipped": false,
	"has_armor_selected": 1,
	"has_armor_equipped": false,
	"button_selected": 0,
	"button_action": 0,
	"script": "",
	"create_else_branch": false,
	"text_variable_selected": 1,
	"text_variable_condition": 0,
	"text_variable_item_selected": 0,
	"text_variable_constant": "",
	"text_variable_variable": 1,
	"profession_selected": 1,
	"profession_condition": 0,
	"profession_value": 0,
	"relationship_condition": 0,
	"relationship_value": 0,
	"actor_parameter_selected": false,
	"actor_parameter_id": 0,
	"actor_parameter_condition": 0,
	"actor_parameter_value": 0,
	"global_user_parameter_selected": false,
	"global_user_parameter_id": 0,
	"global_user_parameter_condition": 0,
	"global_user_parameter_item_selected": 0,
	"global_user_parameter_constant": 0.0,
	"global_user_parameter_variable": 0,
	
	"global_user_parameter_value": 0,
}


var insert_commands: Dictionary

var filter_update_timer: float = 0.0
var filter_nodes: Array = []
var last_filter_used: String


func _ready() -> void:
	super()
	parameter_code = 21
	fill_characters()
	set_tabs()


func _process(delta: float) -> void:
	if filter_update_timer > 0.0:
		filter_update_timer -= delta
		if filter_update_timer <= 0:
			filter_update_timer = 0.0
			_update_filter()


func set_tabs():
	var node = %TabsContainer
	for i in 4:
		node.add_tab(str(i+1))


func fill_characters() -> void:
	var node: EditEventEditor = get_tree().get_first_node_in_group("event_editor")
	var list = %CharacterID
	list.clear()
	
	list.add_item("Player")
	
	if node:
		list.add_item("This Event")
		for ev: RPGEvent in node.events.get_events():
			list.add_item("%s: %s" % [ev.id, ev.name])


func set_data() -> void:
	var config = parameters[0].parameters
	insert_commands = {}
	var i = "parameters"
	insert_commands[i] = []
	var else_branch = false
	var indent = parameters[0].indent
	for j in range(1, parameters.size()):
		var current_command = parameters[j]
		if current_command.code == 22 and current_command.indent == indent: # Else
			i = "else"
			insert_commands[i] = []
			else_branch = true
		elif current_command.code != 23 or (current_command.code == 23 and current_command.indent != indent):
			insert_commands[i].append(current_command)
			
	var item_selected = config.get("item_selected", 0)
	var value1 = config.get("value1", 1)
	var value2 = config.get("value2", 0)
	var value3 = config.get("value3", null)
	var value4 = config.get("value4", null)
	var value5 = config.get("value5", null)
	var value6 = config.get("value6", null)

	cache_data.item_selected = item_selected

	match item_selected:
		0:
			cache_data.switch_selected = value1
			cache_data.switch_value = value2
		1:
			cache_data.variable_selected = value1
			cache_data.variable_condition = value2
			cache_data.variable_item_selected = value3
			if value3 == 0:
				cache_data.variable_constant = value4
			else:
				cache_data.variable_variable_selected = value4
		2:
			cache_data.self_switch_selected = value1
			cache_data.self_switch_value = value2
		3:
			cache_data.timer_condition = value1
			cache_data.timer_minutes = value2
			cache_data.timer_seconds = value3
		4:
			cache_data.actor_selected = value1
			cache_data.actor_item_selected = value2
			match value2:
				1: cache_data.actor_name = value3
				2: cache_data.actor_class_selected = value3
				3: cache_data.actor_skill_selected = value3
				4: cache_data.actor_weapon_selected = value3
				5: cache_data.actor_armor_selected = value3
				6: cache_data.actor_state_selected = value3
				7:
					cache_data.actor_parameter_selected = value3
					cache_data.actor_parameter_id = value4
					cache_data.actor_parameter_condition = value5
					cache_data.actor_parameter_value = value6
		5:
			cache_data.enemy_selected = value1
			cache_data.enemy_item_selected = value2
			if value2 == 1:
				cache_data.enemy_state_selected = value3
		6:
			cache_data.character_selected = value1
			cache_data.character_direction = value2
		7:
			cache_data.vehicle_selected = value1
		8:
			cache_data.gold_condition = value1
			cache_data.gold_value = value2
		9:
			cache_data.has_item_selected = value1
		10:
			cache_data.has_weapon_selected = value1
			cache_data.has_weapon_equipped = value2
		11:
			cache_data.has_armor_selected = value1
			cache_data.has_armor_equipped = value2
		12:
			cache_data.button_selected = value1
			cache_data.button_action = value2
		13:
			cache_data.script = value1
		14:
			cache_data.text_variable_selected = value1
			cache_data.text_variable_condition = value2
			cache_data.text_variable_item_selected = value3
			if value3 == 0:
				cache_data.text_variable_constant = value4
			else:
				cache_data.text_variable_variable = value4
		15:
			cache_data.profession_selected = value1
			cache_data.profession_condition = value2
			cache_data.profession_value = value3
		16:
			cache_data.relationship_condition = value2
			cache_data.relationship_value = value3
		17:
			cache_data.global_user_parameter_selected = value1
			cache_data.global_user_parameter_condition = value2
			cache_data.global_user_parameter_item_selected = value3
			if value3 == 0:
				cache_data.global_user_parameter_constant = value4
			else:
				cache_data.global_user_parameter_variable = value4
	
	cache_data.create_else_branch = else_branch

	update_controls()


func update_controls() -> void:
	_fill_actor_parameters()
	_fill_global_user_parameters()
	
	var node = %SelfSwitchID
	node.clear()

	for switch_name in RPGSYSTEM.system.self_switches.keys:
		node.add_item(switch_name)

	_set_switch_name(cache_data.switch_selected, %SwitchID)

	%SwitchValue.select(cache_data.switch_value)

	_set_variable_name(cache_data.variable_selected, %VariableID)

	%VariableCondition.select(cache_data.variable_condition)

	%VariableConstantValue.value = cache_data.variable_constant

	_set_variable_name(cache_data.variable_variable_selected, %VariableVariableValue)
	
	_set_data_name(null, cache_data.text_variable_selected, %TextVariableID)
	

	%TextVariableCondition.select(cache_data.text_variable_condition)
	
	%TextVariableConstantValue.set_deferred("text", cache_data.text_variable_constant)
	
	_set_data_name(null, cache_data.text_variable_variable, %TextVariableVariableValue)
	
	_set_data_name("professions", cache_data.profession_selected, %ProfessionID)
	
	%ProfessionCondition.select(cache_data.profession_condition)
	
	%ProfessionValue.value = cache_data.profession_value
	
	%RelationshipCondition.select(cache_data.relationship_condition)
	
	%RelationshipValue.value = cache_data.relationship_value
	
	if %ActorParameters.get_item_count() > cache_data.actor_parameter_id and cache_data.actor_parameter_id >= 0:
		%ActorParameters.select(cache_data.actor_parameter_id)
	else:
		%ActorParameters.select(0)
		cache_data.actor_parameter_id = 0
	
	%ActorParametersCondition.select(cache_data.actor_parameter_condition)
	
	%ActorParametersValue.value =  cache_data.actor_parameter_value
	
	var var_buttons = [%VariableConstantSelection, %VariableVariableSelection]
	var_buttons[cache_data.variable_item_selected].set_pressed(false)
	var_buttons[cache_data.variable_item_selected].set_pressed(true)
	
	var text_buttons = [%TextVariableConstantSelection, %TextVariableVariableSelection]
	text_buttons[cache_data.text_variable_item_selected].set_pressed(false)
	text_buttons[cache_data.text_variable_item_selected].set_pressed(true)
	
	var global_user_parameter_buttons = [%GlobalParameterConstantSelection, %GlobalParameterVariableSelection]
	global_user_parameter_buttons[cache_data.global_user_parameter_item_selected].set_pressed(false)
	global_user_parameter_buttons[cache_data.global_user_parameter_item_selected].set_pressed(true)
	
	var main_buttons = [
		%SwitchSelection, %VariableSelection, %SelfSwitchSelection, %TimerSelection,
		%ActorSelection, %EnemySelection, %CharacterSelection, %VehicleSelection,
		%GoldSelection, %ItemSelection, %WeaponSelection, %HasArmorEquipment,
		%ButtonSelection, %ScriptSelection, %VariableTextSelection,
		%ProfessionSelection, %RelationshipSelection, %GlobalUserParametersSelection
	]

	%SelfSwitchID.select(cache_data.self_switch_selected)
	%SelfSwitchValue.select(cache_data.self_switch_value)

	%TimerCondition.select(cache_data.timer_condition)
	%TimerMin.value = cache_data.timer_minutes
	%TimerSec.value = cache_data.timer_seconds
	%TimerID.value = cache_data.timer_id
	_set_data_name("actors", cache_data.actor_selected, %ActorID)
	%ActorNameValue.text = cache_data.actor_name
	_set_data_name("classes", cache_data.actor_class_selected, %ActorClassID)
	_set_data_name("skills", cache_data.actor_skill_selected, %ActorSkillID)
	_set_data_name("weapons", cache_data.actor_weapon_selected, %ActorWeaponID)
	_set_data_name("armors", cache_data.actor_armor_selected, %ActorArmorID)
	_set_data_name("states", cache_data.actor_state_selected, %ActorStateID)
	var buttons = %ActorIsInPartySelection.button_group.get_buttons()
	buttons[cache_data.actor_item_selected].set_pressed(false)
	buttons[cache_data.actor_item_selected].set_pressed(true)
	
	%EnemyID.select(cache_data.enemy_selected)
	_set_data_name("states", cache_data.enemy_state_selected, %EnemyStateID)
	buttons = %EnemyAppearedSelection.button_group.get_buttons()
	buttons[cache_data.enemy_item_selected].set_pressed(false)
	buttons[cache_data.enemy_item_selected].set_pressed(true)

	var character_id = cache_data.character_selected
	if %CharacterID.get_item_count() > character_id:
		%CharacterID.select(character_id)
	else:
		cache_data.character_selected = 0
		%CharacterID.select(0)
	%CharacterState.select(cache_data.character_direction)
	%CharacterState.set_item_disabled(-1, %CharacterID.get_selected_id() != 0)
	%VehicleID.select(cache_data.vehicle_selected)
	
	%GoldCondition.select(cache_data.gold_condition)
	%GoldValue.value = cache_data.gold_value

	_set_data_name("items", cache_data.has_item_selected, %ItemID)
	
	_set_data_name("weapons", cache_data.has_weapon_selected, %WeaponID)
	%WeaponIncludeEquipment.set_pressed(cache_data.has_weapon_equipped)
	
	_set_data_name("armors", cache_data.has_armor_selected, %ArmorID)
	%ArmorIncludeEquipment.set_pressed(cache_data.has_armor_equipped)

	%ButtonID.select(cache_data.button_selected)
	%ButtonAction.select(cache_data.button_action)
	
	%ScriptContents.text = cache_data.script

	%CreateElseBranch.set_pressed(cache_data.create_else_branch)
	
	if %GlobalUserParameters.get_item_count() > cache_data.global_user_parameter_id:
		%GlobalUserParameters.select(cache_data.global_user_parameter_id)
	elif %GlobalUserParameters.get_item_count() > 0:
		%GlobalUserParameters.select(0)
	
	%GlobalUserParametersCondition.select(cache_data.global_user_parameter_condition)
	
	%GlobalParameterConstantValue.value = cache_data.global_user_parameter_constant
	
	if %GlobalParameterVariableValue.get_item_count() > cache_data.global_user_parameter_variable:
		%GlobalParameterVariableValue.select(cache_data.global_user_parameter_variable)
	elif %GlobalParameterVariableValue.get_item_count() > 0:
		%GlobalParameterVariableValue.select(0)

	match cache_data.item_selected:
		0, 1, 2, 3, 14, 17: %TabsContainer.select(0, true)
		4: %TabsContainer.select(1, true)
		5, 6, 7, 15, 16: %TabsContainer.select(2, true)
		_: %TabsContainer.select(3, true)

	main_buttons[cache_data.item_selected].set_pressed(false)
	main_buttons[cache_data.item_selected].set_pressed(true)


func _fill_actor_parameters() -> void:
	var items = PackedStringArray(["Level", "Experience"]) + RPGSYSTEM.database.types.main_parameters
	
	var node = %ActorParameters
	node.clear()
	
	for item in items:
		node.add_item(item)
	
	var user_parameters = RPGSYSTEM.database.types.user_parameters
	
	if user_parameters.size() > 0:
		node.add_separator()
		
		for param in user_parameters:
			node.add_item("User Parameter: " + param.name)


func _fill_global_user_parameters() -> void:
	var node1 = %GlobalUserParameters
	node1.clear()
	var node2 = %GlobalParameterVariableValue
	node2.clear()
	
	var user_parameters = RPGSYSTEM.database.types.user_parameters
	
	if user_parameters.size() > 0:
		for param in user_parameters:
			node1.add_item("User Parameter: " + param.name)
			node2.add_item("User Parameter: " + param.name)
	else:
		node1.add_item("No User parameters")
		node2.add_item("No User parameters")


func _set_variable_name(id: int, target: Node) -> void:
	var variables = RPGSYSTEM.system.variables
	var index = id
	var variable_name = "%s:%s" % [
		str(index).pad_zeros(4),
		variables.get_item_name(index)
	]
	target.text = variable_name


func _set_switch_name(id: int, target: Node) -> void:
	var variables = RPGSYSTEM.system.switches
	var index = id
	var variable_name = "%s:%s" % [
		str(index).pad_zeros(4),
		variables.get_item_name(index)
	]
	target.text = variable_name


func _set_data_name(data_key: Variant, id: int, target: Node) -> void:
	var data: Variant
	if target == %TextVariableID or target == %TextVariableVariableValue:
		data = RPGSYSTEM.system.text_variables.data
	else:
		data = RPGSYSTEM.database[data_key]

	var data_name = "%s:%s" % [
		str(id).pad_zeros(4),
		data[id].name if data.size() > id else "⚠ Invalid Data"
	]
	target.text = data_name


func build_command_list() -> Array[RPGEventCommand]:
	var commands: Array[RPGEventCommand] = []
	
	var item_selected = cache_data.item_selected
	var value1; var value2; var value3; var value4; var value5; var value6;
	match item_selected:
		0: # Switch
			value1 = cache_data.switch_selected
			value2 = cache_data.switch_value
		1: # Variable
			value1 = cache_data.variable_selected
			value2 = cache_data.variable_condition
			value3 = cache_data.variable_item_selected
			if value3 == 0:
				value4 = cache_data.variable_constant
			else:
				value4 = cache_data.variable_variable_selected
		2: # Self Switch
			value1 = cache_data.self_switch_selected
			value2 = cache_data.self_switch_value
		3: # Timer
			value1 = cache_data.timer_condition
			value2 = cache_data.timer_minutes
			value3 = cache_data.timer_seconds
			value4 = cache_data.timer_id
		4: # Actor
			value1 = cache_data.actor_selected
			value2 = cache_data.actor_item_selected
			match value2:
				1: value3 = cache_data.actor_name
				2: value3 = cache_data.actor_class_selected
				3: value3 = cache_data.actor_skill_selected
				4: value3 = cache_data.actor_weapon_selected
				5: value3 = cache_data.actor_armor_selected
				6: value3 = cache_data.actor_state_selected
				7:
					value3 = cache_data.actor_parameter_selected
					value4 = cache_data.actor_parameter_id
					value5 = cache_data.actor_parameter_condition
					value6 = cache_data.actor_parameter_value
		5: # Enemy
			value1 = cache_data.enemy_selected
			value2 = cache_data.enemy_item_selected
			if value2 == 1:
				value3 = cache_data.enemy_state_selected
		6: # Character
			value1 = cache_data.character_selected
			value2 = cache_data.character_direction
		7: # Vehicle
			value1 = cache_data.vehicle_selected
		8: # gold
			value1 = cache_data.gold_condition
			value2 = cache_data.gold_value
		9: # Has Item
			value1 = cache_data.has_item_selected
		10: # Has Weapon
			value1 = cache_data.has_weapon_selected
			value2 = cache_data.has_weapon_equipped
		11: # Has Armor
			value1 = cache_data.has_armor_selected
			value2 = cache_data.has_armor_equipped
		12: # Is Button Pressed
			value1 = cache_data.button_selected
			value2 = cache_data.button_action
		13: # Script
			value1 = cache_data.script
		14: # Text var
			value1 = cache_data.text_variable_selected
			value2 = cache_data.text_variable_condition
			value3 = cache_data.text_variable_item_selected
			if value3 == 0:
				value4 = cache_data.text_variable_constant
			else:
				value4 = cache_data.text_variable_variable
		15: # Profession
			value1 = cache_data.profession_selected
			value2 = cache_data.profession_condition
			value3 = cache_data.profession_value
		16: # Relationship
			value2 = cache_data.relationship_condition
			value3 = cache_data.relationship_value
		17: # Global User Parameter
			value1 = cache_data.global_user_parameter_id
			value2 = cache_data.global_user_parameter_condition
			value3 = cache_data.global_user_parameter_item_selected
			if value3 == 0:
				value4 = cache_data.global_user_parameter_constant
			else:
				value4 = cache_data.global_user_parameter_variable


	var config = {
		"item_selected": item_selected,
		"value1": value1,
		"value2": value2,
		"value3": value3,
		"value4": value4,
		"value5": value5,
		"value6": value6,
		"else_branch": %CreateElseBranch.is_pressed()
	}
	
	var current_indent = parameters[0].indent
	
	# Conditional Branch End command
	var command = RPGEventCommand.new()
	command.code = 23
	command.indent = current_indent
	commands.append(command)
	# Conditional Branch Else command
	if config.else_branch: # using Else
		# First insert all commands found in else (in reverse) or command 0
		var index = "else"
		var extra_commands = insert_commands.get(index, [])
		if extra_commands.size() > 0:
			for i in range(extra_commands.size() - 1, -1, -1):
				command = extra_commands[i]
				commands.append(command)
		else:
			# Insert command 0
			command = RPGEventCommand.new()
			command.code = 0
			command.indent = current_indent + 1
			commands.append(command)
		# Next Create Else command
		command = RPGEventCommand.new()
		command.code = 22
		command.indent = current_indent
		commands.append(command)
	# Next insert all controls in extra_commands.parameters (in reverse) or command 0
	var index = "parameters"
	var extra_commands = insert_commands.get(index, [])
	if extra_commands.size() > 0:
		for i in range(extra_commands.size() - 1, -1, -1):
			command = extra_commands[i]
			commands.append(command)
	else:
		# Insert command 0
		command = RPGEventCommand.new()
		command.code = 0
		command.indent = current_indent + 1
		commands.append(command)
	
	# Last insert Conditional Branch Command
	config.erase("else_branch")
	var command_parent = super()
	command_parent[-1].parameters = config
	commands.append(command_parent[-1])
	
	return commands


func _on_custom_tab_container_tab_changed(index: int) -> void:
	var node = %TargetContainer
	for child in node.get_children():
		child.visible = false
	if node.get_child_count() > index:
		node.get_child(index).visible = true


func _on_item_selected_toggled(toggled_on: bool, index: int) -> void:
	if toggled_on:
		cache_data.item_selected = index
		disable_all()
	
	var nodes: Array
	match index:
		0:
			nodes = [%SwitchID, %SwitchValue]
		1:
			nodes = [%VariableID, %VariableCondition, %VariableConstantSelection, %VariableVariableSelection]
		2:
			nodes = [%SelfSwitchID, %SelfSwitchValue]
		3:
			nodes = [%TimerCondition, %TimerMin, %TimerSec, %TimerID]
		4:
			nodes = [%ActorID, %ActorIsInPartySelection, %ActorNameSelection, %ActorClassSelection, %ActorSkillSelection, %ActorWeaponSelection, %ActorArmorSelection, %ActorStateSelection, %ActorParametersSelection]
		5:
			nodes = [%EnemyID, %EnemyAppearedSelection, %EnemyStateSelection]
		6:
			nodes = [%CharacterID, %CharacterState]
		7:
			nodes = [%VehicleID]
		8:
			nodes = [%GoldCondition, %GoldValue]
		9:
			nodes = [%ItemID]
		10:
			nodes = [%WeaponID, %WeaponIncludeEquipment]
		11:
			nodes = [%ArmorID, %ArmorIncludeEquipment]
		12:
			nodes = [%ButtonID, %ButtonAction]
		13:
			nodes = [%ScriptContents]
		14:
			nodes = [%TextVariableID, %TextVariableCondition, %TextVariableConstantSelection, %TextVariableVariableSelection]
		15:
			nodes = [%ProfessionID, %ProfessionCondition, %ProfessionValue]
		16:
			nodes = [%RelationshipCondition, %RelationshipValue]
		17:
			nodes = [%GlobalUserParameters, %GlobalUserParametersCondition, %GlobalParameterConstantSelection, %GlobalParameterVariableSelection]
	
	for node in nodes:
		node.set_disabled(false)
	
	
	var button
	if index == 1:
		button = %VariableConstantSelection.button_group.get_pressed_button()
	elif index == 3:
		%TimerMin.get_line_edit().call_deferred("grab_focus")
	elif index == 4:
		button = %ActorIsInPartySelection.button_group.get_pressed_button()
	elif index == 5:
		button = %EnemyAppearedSelection.button_group.get_pressed_button()
	elif index == 8:
		%GoldValue.get_line_edit().call_deferred("grab_focus")
	elif index == 13:
		%ScriptContents.call_deferred("grab_focus")
	elif index == 14:
		button = %TextVariableConstantSelection.button_group.get_pressed_button()
	elif index == 15:
		%ProfessionValue.get_line_edit().call_deferred("grab_focus")
	elif index == 16:
		%RelationshipValue.get_line_edit().call_deferred("grab_focus")
	elif index == 17:
		button = %GlobalParameterConstantSelection.button_group.get_pressed_button()
		
	if button:
		button.set_pressed(false)
		button.set_pressed(true)


func disable_all() -> void:
	propagate_call("set_disabled", [true])
	%Filter.set_disabled(false)
	var buttons = %SwitchSelection.button_group.get_buttons()
	for button in buttons:
		button.set_disabled(false)
	
	%CreateElseBranch.set_disabled(false)
	%OKButton.set_disabled(false)
	%CancelButton.set_disabled(false)


func _on_actor_item_selected(toggled_on: bool, index: int) -> void:
	if toggled_on:
		cache_data.actor_item_selected = index
	if index != 0:
		var buttons = %ActorIsInPartySelection.button_group.get_buttons()
		#buttons[index].get_parent().get_child(2).set_disabled(!toggled_on)
		buttons[index].get_parent().propagate_call("set_disabled", [!toggled_on])
		buttons[index].set_disabled(false)
		
	
	if index == 1:
		%ActorNameValue.grab_focus()


func _on_variable_item_selected(toggled_on: bool, index: int) -> void:
	if toggled_on:
		cache_data.variable_item_selected = index

	if index == 0:
		%VariableConstantValue.set_disabled(false)
		%VariableVariableValue.set_disabled(true)
	else:
		%VariableConstantValue.set_disabled(true)
		%VariableVariableValue.set_disabled(false)


func _on_enemy_item_selected(toggled_on: bool, index: int) -> void:
	if toggled_on:
		cache_data.enemy_item_selected = index
	if index != 0:
		var buttons = %EnemyAppearedSelection.button_group.get_buttons()
		buttons[index].get_parent().get_child(2).set_disabled(!toggled_on)


func open_switch_variable(type: int, id: int, target: Node, selected: Callable, name_changed: Callable) -> void:
	var path = "res://addons/CustomControls/Dialogs/switch_variable_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	dialog.data_type = type
	dialog.target = target
	dialog.selected.connect(selected)
	dialog.variable_or_switch_name_changed.connect(name_changed)
	dialog.setup(id)


func _on_switch_id_pressed() -> void:
	open_switch_variable(1, cache_data.switch_selected, %SwitchID, _on_switch_changed, _on_switch_name_changed)


func _on_switch_changed(index: int, target: Node) -> void:
	cache_data.switch_selected = index
	_set_switch_name(index, target)


func _on_switch_name_changed() -> void:
	_set_switch_name(cache_data.switch_selected, %SwitchID)


func _on_switch_value_item_selected(index: int) -> void:
	cache_data.switch_value = index


func _on_variable_id_pressed() -> void:
	open_switch_variable(0, cache_data.variable_selected, %VariableID, _on_variable_changed, _on_variable_name_changed)


func _on_variable_changed(index: int, target: Node) -> void:
	cache_data.variable_selected = index
	_set_variable_name(index, target)


func _on_variable_name_changed() -> void:
	_set_variable_name(cache_data.variable_selected, %VariableID)
	_set_variable_name(cache_data.variable_variable_selected, %VariableVariableValue)


func _on_variable_condition_item_selected(index: int) -> void:
	cache_data.variable_condition = index


func _on_variable_constant_value_value_changed(value: float) -> void:
	cache_data.variable_constant = value


func _on_variable_variable_value_pressed() -> void:
	open_switch_variable(0, cache_data.variable_variable_selected, %VariableVariableValue, _on_variable_variable_changed, _on_variable_name_changed)


func _on_variable_variable_changed(index: int, target: Node) -> void:
	cache_data.variable_variable_selected = index
	_set_variable_name(index, target)


func _on_self_switch_id_item_selected(index: int) -> void:
	cache_data.self_switch_selected = index


func _on_self_switch_value_item_selected(index: int) -> void:
	cache_data.self_switch_value = index


func _on_timer_condition_item_selected(index: int) -> void:
	cache_data.timer_condition = index


func _on_timer_min_value_changed(value: float) -> void:
	cache_data.timer_minutes = value


func _on_timer_sec_value_changed(value: float) -> void:
	cache_data.timer_seconds = value


func _open_select_any_data_dialog(key: String, id_selected: int, title: String, target: int) -> void:
	var path = "res://addons/CustomControls/Dialogs/select_any_data_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	dialog.database = RPGSYSTEM.database
	
	var data: Variant
	if target == 14 or target == 141:
		data = RPGSYSTEM.system.text_variables.data
	else:
		data = RPGSYSTEM.database[key]
	
	dialog.destroy_on_hide = true
	dialog.selected.connect(_on_any_data_selected.bind(key))
	
	dialog.setup(data, id_selected, title, target)


func _on_any_data_selected(id: int, target: int, key: String) -> void:
	match target:
		0:
			cache_data.actor_selected = id
			_set_data_name(key, id, %ActorID)
		1:
			cache_data.actor_class_selected = id
			_set_data_name(key, id, %ActorClassID)
		2:
			cache_data.actor_skill_selected = id
			_set_data_name(key, id, %ActorSkillID)
		3:
			cache_data.actor_weapon_selected = id
			_set_data_name(key, id, %ActorWeaponID)
		4:
			cache_data.actor_armor_selected = id
			_set_data_name(key, id, %ActorArmorID)
		5:
			cache_data.actor_state_selected = id
			_set_data_name(key, id, %ActorStateID)
		6:
			cache_data.enemy_state_selected = id
			_set_data_name(key, id, %EnemyStateID)
		7:
			cache_data.has_item_selected = id
			_set_data_name(key, id, %ItemID)
		8:
			cache_data.has_weapon_selected = id
			_set_data_name(key, id, %WeaponID)
		9:
			cache_data.has_armor_selected = id
			_set_data_name(key, id, %ArmorID)
		14:
			cache_data.text_variable_selected = id
			_set_data_name(key, id, %TextVariableID)
		141:
			cache_data.text_variable_variable = id
			_set_data_name(key, id, %TextVariableVariableValue)
		15:
			cache_data.profession_selected = id
			_set_data_name(key, id, %ProfessionID)


func _on_actor_id_pressed() -> void:
	_open_select_any_data_dialog("actors", cache_data.actor_selected, "Actors", 0)


func _on_actor_name_value_text_changed(new_text: String) -> void:
	cache_data.actor_name = new_text


func _on_actor_class_id_pressed() -> void:
	_open_select_any_data_dialog("classes", cache_data.actor_class_selected, "Classes", 1)


func _on_actor_skill_id_pressed() -> void:
	_open_select_any_data_dialog("skills", cache_data.actor_skill_selected, "Skills", 2)


func _on_actor_weapon_id_pressed() -> void:
	_open_select_any_data_dialog("weapons", cache_data.actor_weapon_selected, "Weapons", 3)


func _on_actor_armor_id_pressed() -> void:
	_open_select_any_data_dialog("armors", cache_data.actor_armor_selected, "Armors", 4)


func _on_actor_state_id_pressed() -> void:
	_open_select_any_data_dialog("states", cache_data.actor_state_selected, "States", 5)


func _on_enemy_id_item_selected(index: int) -> void:
	cache_data.enemy_selected = index


func _on_enemy_state_pressed() -> void:
	_open_select_any_data_dialog("states", cache_data.enemy_state_selected, "States", 6)


func _on_character_id_item_selected(index: int) -> void:
	cache_data.character_selected = index
	%CharacterState.set_item_disabled(-1, index != 0)


func _on_character_direction_item_selected(index: int) -> void:
	cache_data.character_direction = index


func _on_vehicle_id_item_selected(index: int) -> void:
	cache_data.vehicle_selected = index


func _on_gold_condition_item_selected(index: int) -> void:
	cache_data.gold_condition = index


func _on_gold_value_value_changed(value: float) -> void:
	cache_data.gold_value = value


func _on_item_id_pressed() -> void:
	_open_select_any_data_dialog("items", cache_data.has_item_selected, "Items", 7)


func _on_weapon_id_pressed() -> void:
	_open_select_any_data_dialog("weapons", cache_data.has_weapon_selected, "Weapons", 8)


func _on_weapon_include_equipment_toggled(toggled_on: bool) -> void:
	cache_data.has_weapon_equipped = toggled_on


func _on_armor_id_pressed() -> void:
	_open_select_any_data_dialog("armors", cache_data.has_armor_selected, "Armors", 9)


func _on_armor_include_equipment_toggled(toggled_on: bool) -> void:
	cache_data.has_armor_equipped = toggled_on


func _on_button_id_item_selected(index: int) -> void:
	cache_data.button_selected = index


func _on_button_action_item_selected(index: int) -> void:
	cache_data.button_action = index


func _on_custom_line_edit_text_changed(new_text: String) -> void:
	cache_data.script = new_text


func _on_create_else_branch_toggled(toggled_on: bool) -> void:
	cache_data.create_else_branch = toggled_on


func _on_timer_id_value_changed(value: float) -> void:
	cache_data.timer_id = value


func _on_filter_text_changed(new_text: String) -> void:
	if new_text.length() != 0:
		%Filter.right_icon = ResourceLoader.load("res://addons/CustomControls/Images/filter_reset.png")
	else:
		%Filter.right_icon = ResourceLoader.load("res://addons/CustomControls/Images/magnifying_glass.png")
	filter_update_timer = 0.25


func _on_filter_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.is_pressed():
			if event.button_index == MOUSE_BUTTON_LEFT:
				if %Filter.text.length() > 0:
					if event.position.x >= %Filter.size.x - 22:
						%Filter.text = ""
						_on_filter_text_changed("")
	elif event is InputEventMouseMotion:
		if event.position.x >= %Filter.size.x - 22:
			%Filter.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		else:
			%Filter.mouse_default_cursor_shape = Control.CURSOR_IBEAM


func _update_filter() -> void:
	if last_filter_used != %Filter.text.to_lower():
		_restore_node_parents()
		var filter = %Filter.text.to_lower()
		last_filter_used = filter
		if filter.length() > 0:
			var nodes = _get_filter_controls(%TargetContainer, filter)
			if not nodes.is_empty():
				_filter_controls(nodes)
			else:
				_restore_node_parents()
		else:
			%TargetContainer.visible = true
			%FilterContainer.visible = false
			%TabsContainer.visible = true
			size.y = 0


func _get_filter_controls(root: Node, filter: String) -> Array:
	var controls := []

	if "text" in root and root.text.to_lower().find(filter) != -1 and not root is OptionButton:
		var main_container = root.get_parent()
		while main_container and not main_container.is_in_group("main_trait_filter_tab"):
			main_container = main_container.get_parent()

		if main_container and not main_container in controls:
			controls.append(main_container)
			
	elif root is OptionButton:
		var matching_items = []
		# Primero recopilar todos los items que coinciden
		for i in root.get_item_count():
			var text = root.get_item_text(i)
			if text.to_lower().find(filter) != -1:
				matching_items.append(i)
		
		# Si hay items que coinciden, procesar el container
		if not matching_items.is_empty():
			var main_container = root.get_parent()
			while main_container and not main_container.is_in_group("main_trait_filter_tab"):
				main_container = main_container.get_parent()
			
			if main_container:
				# Buscar el checkbox asociado a este OptionButton
				var parent_checkbox_selected = _find_checkbox_in_container(main_container)
				
				# Si el checkbox padre NO está seleccionado, seleccionar el primer item que coincide
				if not parent_checkbox_selected:
					root.select(matching_items[0])
					root.item_selected.emit(matching_items[0])
				
				# Agregar el container a los controles (solo una vez)
				if not main_container in controls:
					controls.append(main_container)
	
	for child in root.get_children():
		controls += _get_filter_controls(child, filter)
	
	return controls

func _find_checkbox_in_container(container: Node) -> bool:
	# Hacer un recorrido en profundidad para encontrar EL PRIMER checkbox
	return _find_first_checkbox_recursive(container)

func _find_first_checkbox_recursive(node: Node) -> bool:
	# Si este nodo es un CheckBox, retornar su estado
	if node is CheckBox:
		return node.is_pressed()
	
	# Recorrer los hijos en orden
	for child in node.get_children():
		var result = _find_first_checkbox_recursive(child)
		# Si encontramos un CheckBox en este hijo, retornar su estado
		if child is CheckBox or _contains_checkbox(child):
			return result
	
	return false

func _contains_checkbox(node: Node) -> bool:
	if node is CheckBox:
		return true
	for child in node.get_children():
		if _contains_checkbox(child):
			return true
	return false


func _filter_controls(controls: Array) -> void:
	_restore_node_parents()
	%TargetContainer.visible = false
	%FilterContainer.visible = true
	%TabsContainer.visible = false
	var container = %FlowContainer
	for c: Control in controls:
		if c.get_parent() != container and c.get_child_count() == 1:
			var child = c.get_child(0)
			child.set_meta("original_parent", c)
			child.reparent(container)
			child.size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _restore_node_parents() -> void:
	var container = %FlowContainer
	for node in container.get_children():
		if node.has_meta("original_parent"):
			var original_parent = node.get_meta("original_parent")
			if original_parent != node.get_parent():
				node.reparent(original_parent)
		node.remove_meta("original_parent")


func _on_text_variable_id_pressed() -> void:
	_open_select_any_data_dialog("text_variable", cache_data.text_variable_selected, "Variable", 14)


func _on_text_variable_condition_item_selected(index: int) -> void:
	cache_data.text_variable_condition = index


func _on_text_variable_item_selected(toggled_on: bool, index: int) -> void:
	if toggled_on:
		cache_data.text_variable_item_selected = index
	
	if index == 0:
		%TextVariableConstantValue.set_disabled(false)
		%TextVariableVariableValue.set_disabled(true)
	else:
		%TextVariableConstantValue.set_disabled(true)
		%TextVariableVariableValue.set_disabled(false)


func _on_text_variable_variable_value_pressed() -> void:
	_open_select_any_data_dialog("text_variable", cache_data.text_variable_variable, "Variable", 141)


func _on_text_variable_constant_value_text_changed(new_text: String) -> void:
	cache_data.text_variable_constant = new_text


func _on_profession_id_pressed() -> void:
	_open_select_any_data_dialog("professions", cache_data.profession_selected, "Profession", 15)


func _on_profession_condition_item_selected(index: int) -> void:
	cache_data.profession_condition = index


func _on_profession_value_value_changed(value: float) -> void:
	cache_data.profession_value = value


func _on_relationship_condition_item_selected(index: int) -> void:
	cache_data.relationship_condition = index


func _on_relationship_value_value_changed(value: float) -> void:
	cache_data.relationship_value = value


func _on_actor_parameters_item_selected(index: int) -> void:
	cache_data.actor_parameter_id = index


func _on_actor_parameters_condition_item_selected(index: int) -> void:
	cache_data.actor_parameter_condition = index


func _on_actor_parameters_value_value_changed(value: float) -> void:
		cache_data.actor_parameter_value = value


func _on_global_user_parameters_item_selected(index: int) -> void:
	cache_data.global_user_parameter_id = index


func _on_global_user_parameters_condition_item_selected(index: int) -> void:
	cache_data.global_user_parameter_condition = index


func _on_global_parameter_item_selected(toggled_on: bool, index: int) -> void:
	if toggled_on:
		cache_data.global_user_parameter_item_selected = index
	
	if index == 0:
		%GlobalParameterConstantValue.set_disabled(false)
		%GlobalParameterVariableValue.set_disabled(true)
	else:
		%GlobalParameterConstantValue.set_disabled(true)
		%GlobalParameterVariableValue.set_disabled(false)


func _on_global_parameter_constant_value_value_changed(value: float) -> void:
	cache_data.global_user_parameter_constant = value


func _on_global_parameter_variable_value_item_selected(index: int) -> void:
	cache_data.global_user_parameter_variable = index
