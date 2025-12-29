@tool
extends CommandBaseDialog


var type_selected: int = 0
var variable_selected: int = 1
var troop_selected: int = 1

var insert_commands: Dictionary


func _ready() -> void:
	super()
	parameter_code = 500
	set_button_group_and_connections()
	fill_troops()
	fill_variables()


func set_button_group_and_connections() -> void:
	var buttons = [%SelectTroop, %SelectWithVariable, %SelectRandomEnemy]
	var button_group = ButtonGroup.new()
	for i in buttons.size():
		var button = buttons[i]
		button.button_group = button_group
		button.toggled.connect(_on_type_toggled.bind(button, i))


func fill_troops() -> void:
	var node = %TroopList
	node.clear()
	for troop in RPGSYSTEM.database.troops:
		if not troop: continue
		node.add_item("%s: %s" % [troop.id, troop.name])


func fill_variables() -> void:
	var node = %VariableList
	node.clear()
	for i in range(1, RPGSYSTEM.system.variables.size() + 1):
		node.add_item("%s: %s" % [i, RPGSYSTEM.system.variables.get_item_name(i)])


func set_data() -> void:
	var type = parameters[0].parameters.get("type", 0)
	var value = parameters[0].parameters.get("value", 1)
	var win_condition = parameters[0].parameters.get("win_condition", false)
	var lost_condition = parameters[0].parameters.get("lost_condition", false)
	var retreat_condition = parameters[0].parameters.get("retreat_condition", false)
	
	if type == 0:
		%SelectTroop.set_pressed(true)
		type_selected = 0
		troop_selected = value
		if %TroopList.get_item_count() > troop_selected - 1:
			%TroopList.select( troop_selected - 1)
		else:
			%TroopList.select(0)
			troop_selected = 1
			
	elif type == 1:
		%SelectWithVariable.set_pressed(true)
		type_selected = 1
		variable_selected = value
		if %VariableList.get_item_count() > variable_selected - 1:
			%VariableList.select( variable_selected - 1)
		else:
			%VariableList.select(0)
			variable_selected = 1
	else:
		%SelectRandomEnemy.set_pressed(true)
		type_selected = 2
	
	%EnableWinCondition.set_pressed(win_condition)
	%EnableLostCondition.set_pressed(lost_condition)
	%EnableRetreatCondition.set_pressed(retreat_condition)
	
	insert_commands = {}
	var last_key: String
	var indent = parameters[0].indent
	for j in range(1, parameters.size()):
		var current_command = parameters[j]
		if current_command.code == 501 and current_command.indent == indent: # When Win
			last_key = "win"
			insert_commands[last_key] = []
		elif current_command.code == 502 and current_command.indent == indent: # When Win
			last_key = "lost"
			insert_commands[last_key] = []
		elif current_command.code == 503 and current_command.indent == indent: # When Win
			last_key = "retreat"
			insert_commands[last_key] = []
		elif current_command.code == 504 and current_command.indent == indent: # End command
			break
		elif last_key:
			insert_commands[last_key].append(current_command)


func _on_type_toggled(toggled: bool, button: CheckBox, index: int) -> void:
	if toggled:
		type_selected = index
		
	if index != 2:
		button.get_parent().get_child(1).set_disabled(!toggled)


func build_command_list() -> Array[RPGEventCommand]:
	var commands: Array[RPGEventCommand] = []
	
	if %EnableWinCondition.is_pressed() or %EnableLostCondition.is_pressed() or %EnableRetreatCondition.is_pressed():
		commands.append(RPGEventCommand.new(504, parameters[0].indent))
		
		if %EnableRetreatCondition.is_pressed():
			var index = "retreat"
			var extra_commands = insert_commands.get(index, [])
			if extra_commands:
				for i in range(extra_commands.size() - 1, -1, -1): # add commands in reverse
					var command = extra_commands[i]
					commands.append(command)
			else:
				commands.append(RPGEventCommand.new(0, parameters[0].indent + 1))
			commands.append(RPGEventCommand.new(503, parameters[0].indent))
		
		if %EnableLostCondition.is_pressed():
			var index = "lost"
			var extra_commands = insert_commands.get(index, [])
			if extra_commands:
				for i in range(extra_commands.size() - 1, -1, -1): # add commands in reverse
					var command = extra_commands[i]
					commands.append(command)
			else:
				commands.append(RPGEventCommand.new(0, parameters[0].indent + 1))
			commands.append(RPGEventCommand.new(502, parameters[0].indent))
		
		if %EnableWinCondition.is_pressed():
			var index = "win"
			var extra_commands = insert_commands.get(index, [])
			if extra_commands:
				for i in range(extra_commands.size() - 1, -1, -1): # add commands in reverse
					var command = extra_commands[i]
					commands.append(command)
			else:
				commands.append(RPGEventCommand.new(0, parameters[0].indent + 1))
			commands.append(RPGEventCommand.new(501, parameters[0].indent))
	
	var parent_command = super()
	parent_command[-1].parameters.type = type_selected
	parent_command[-1].parameters.value = troop_selected if type_selected == 0 else variable_selected if type_selected == 1 else -1
	parent_command[-1].parameters.win_condition = %EnableWinCondition.is_pressed()
	parent_command[-1].parameters.lost_condition = %EnableLostCondition.is_pressed()
	parent_command[-1].parameters.retreat_condition = %EnableRetreatCondition.is_pressed()
	commands.append(parent_command[-1])
	
	return commands


func _on_variable_list_item_selected(index: int) -> void:
	variable_selected = index + 1


func _on_troop_list_item_selected(index: int) -> void:
	troop_selected = index + 1
