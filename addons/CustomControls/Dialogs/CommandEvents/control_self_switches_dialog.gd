@tool
extends CommandBaseDialog

var current_data: Dictionary


func _ready() -> void:
	super()
	parameter_code = 19


func set_data() -> void:
	var data = parameters[0].parameters
	current_data = data.duplicate()
	var operation = data.get("operation_type", 0)
	current_data.operation_type = operation
	%SelfSwitch.select(data.get("switch_id", 0))
	current_data.switch_id = %SelfSwitch.get_selected_id()
	if operation == 0:
		%OperationON.set_pressed(false)
		%OperationON.set_pressed(true)
	else:
		%OperationOFF.set_pressed(true)


func build_command_list() -> Array[RPGEventCommand]:
	var commands = super()
	commands[-1].parameters = current_data
	return commands


func _on_operation_on_toggled(toggled_on: bool, operation_type: int) -> void:
	if toggled_on: current_data.operation_type = operation_type


func _on_operation_off_toggled(toggled_on: bool, operation_type: int) -> void:
	if toggled_on: current_data.operation_type = operation_type


func _on_self_switch_item_selected(index: int) -> void:
	current_data.switch_id = index
