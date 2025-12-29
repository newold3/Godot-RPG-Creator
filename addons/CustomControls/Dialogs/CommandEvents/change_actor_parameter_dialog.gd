@tool
extends CommandBaseDialog

var current_data : Dictionary
var char_variable_id: int = 1
var operand_variable_id: int = 1


func _ready() -> void:
	super()
	fill_fixed_values()
	set_initial_values()
	_set_variable_name()


func set_initial_values() -> void:
	propagate_call("set_pressed", [false])
	%Fixed.set_pressed(true)
	%Increase.set_pressed(true)
	%Constant.set_pressed(true)


func fill_fixed_values() -> void:
	var node : OptionButton = %FixedValue
	node.clear()
	node.add_item("Entire Party")
	for i in range(1, RPGSYSTEM.database.actors.size()):
		var text = "%s: %s" % [i, RPGSYSTEM.database.actors[i].name]
		node.add_item(text)


func set_data() -> void:
	var data = parameters[0].parameters
	current_data = data.duplicate()
	
	var actor_type = data.get("actor_type", 0)
	current_data.actor_type = actor_type
	var actor_id = data.get("actor_id", 0) if actor_type == 0 else data.get("actor_id", 1)
	current_data.actor_id = actor_id
	var operation = data.get("operand", 0)
	current_data.operand = operation
	var operand_type = data.get("operand_type", 0)
	current_data.operand_type = operand_type
	var operand_value = data.get("operand_value", 1)
	current_data.operand_value = operand_value
	
	if actor_type == 0:
		%Fixed.set_pressed(true)
		if actor_id <= RPGSYSTEM.database.actors.size():
			%FixedValue.select(actor_id)
		else:
			%FixedValue.select(0)
		char_variable_id = 1
	else:
		%Variable.set_pressed(true)
		char_variable_id = actor_id
	
	if operation == 0:
		%Increase.set_pressed(true)
	else:
		%Decrease.set_pressed(true)
	
	if operand_type == 0:
		%Constant.set_pressed(true)
		%ConstantValue.value = operand_value
		operand_variable_id = 1
	else:
		%OperandVariable.set_pressed(true)
		operand_variable_id = operand_value
	
	%LevelUp.set_pressed(data.get("show_level_up", false))
	current_data.show_level_up = %LevelUp.is_pressed()
	%ParameterSelected.select(data.get("parameter_id", 0))
	current_data.parameter_id = %ParameterSelected.get_selected_id()
	
	_set_variable_name()


func build_command_list() -> Array[RPGEventCommand]:
	var commands = super()
	commands[-1].parameters = current_data
	return commands


func _on_fixed_toggled(toggled_on: bool) -> void:
	current_data.actor_type = 0
	current_data.actor_id = %FixedValue.get_selected_id()
	%FixedValue.set_disabled(!toggled_on)
	%VariableValue.set_disabled(toggled_on)


func _on_variable_toggled(toggled_on: bool) -> void:
	current_data.actor_type = 1
	current_data.actor_id = char_variable_id
	%VariableValue.set_disabled(!toggled_on)
	%FixedValue.set_disabled(toggled_on)


func _on_fixed_value_item_selected(index: int) -> void:
	current_data.actor_id = index


func show_select_variable_dialog(callable: Callable, variable_selected_id: int = -1) -> void:
	var path = "res://addons/CustomControls/Dialogs/switch_variable_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	dialog.data_type = 0
	dialog.target = null
	dialog.selected.connect(callable)
	dialog.variable_or_switch_name_changed.connect(_set_variable_name)
	dialog.setup(variable_selected_id)


func _on_variable_value_pressed() -> void:
	var callable = _on_actor_variable_changed
	show_select_variable_dialog(callable, char_variable_id)


func _on_actor_variable_changed(index: int, target) -> void:
	current_data.actor_id = index
	char_variable_id = index
	_set_variable_name()


func _set_variable_name() -> void:
	var variables = RPGSYSTEM.system.variables
	var variable_name = "%s: %s" % [char_variable_id, variables.get_item_name(char_variable_id)]
	%VariableValue.text = variable_name
	variable_name = "%s: %s" % [operand_variable_id, variables.get_item_name(operand_variable_id)]
	%OperandVariableValue.text = variable_name


func _on_increase_toggled(toggled_on: bool) -> void:
	if toggled_on: current_data.operand = 0


func _on_decrease_toggled(toggled_on: bool) -> void:
	if toggled_on: current_data.operand = 1


func _on_constant_toggled(toggled_on: bool) -> void:
	current_data.operand_type = 0
	current_data.operand_value = %ConstantValue.value
	%ConstantValue.set_disabled(!toggled_on)
	%OperandVariableValue.set_disabled(toggled_on)


func _on_operand_variable_toggled(toggled_on: bool) -> void:
	current_data.operand_type = 1
	current_data.operand_value = operand_variable_id
	%OperandVariableValue.set_disabled(!toggled_on)
	%ConstantValue.set_disabled(toggled_on)


func _on_constant_value_value_changed(value: float) -> void:
	current_data.operand_value = value


func _on_operand_variable_value_pressed() -> void:
	var callable = _on_operand_variable_changed
	show_select_variable_dialog(callable, operand_variable_id)


func _on_operand_variable_changed(index: int, target) -> void:
	current_data.operand_value = index
	operand_variable_id = index
	_set_variable_name()


func show_level_control(value: bool = true) -> void:
	var control_size = 53
	if value and !%ContentsPanel4.visible:
		%ContentsPanel4.visible = true
		size.y += control_size
	elif !value and %ContentsPanel4.visible:
		%ContentsPanel4.visible = false
		size.y -= control_size


func show_parameter_control(value: bool = true) -> void:
	var control_size = 90
	if value and !%ContentsPanel5.visible:
		%ContentsPanel5.visible = true
		size.y += control_size
	elif !value and %ContentsPanel5.visible:
		%ContentsPanel5.visible = false
		size.y -= control_size


func _on_level_up_toggled(toggled_on: bool) -> void:
	current_data.show_level_up = toggled_on


func _on_parameter_selected_item_selected(parameter_id: int) -> void:
	current_data.parameter_id = parameter_id
