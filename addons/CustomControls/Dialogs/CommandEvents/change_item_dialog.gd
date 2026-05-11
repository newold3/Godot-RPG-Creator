@tool
extends CommandBaseDialog

#region Variables
var current_data: Dictionary
var current_variable_id: int = 1
#endregion



#region Lifecycle & Setup
## Initializes the base configuration for the Items command
func _ready() -> void:
	super()
	parameter_code = 13



## Parses the initial command data and configures the UI state
func set_data() -> void:
	var data = parameters[0].parameters
	current_data = data.duplicate()
	
	var operation = data.get("operation_type", 0)
	current_data.operation_type = operation
	
	if operation == 0:
		%OperationIncrease.set_pressed(true)
	else:
		%OperationDecrease.set_pressed(true)
		
	var operand = data.get("value_type", 0)
	current_data.value_type = operand
	
	if operand == 0:
		%OperandConstant.set_pressed(true)
		%OperandValue.value = data.get("value", 1)
		current_data.value = %OperandValue.value
	else:
		%OperandVariable.set_pressed(true)
		current_variable_id = data.get("value", 1)
		current_data.value = current_variable_id
		_set_variable_name()
		
	_set_item_name()



## Compiles the UI state back into an Event Command array
func build_command_list() -> Array[RPGEventCommand]:
	var commands = super()
	if %OperandVariable.is_pressed():
		current_data.value = current_variable_id
	commands[-1].parameters = current_data
	return commands
#endregion



#region Operation & Operand Toggles
## Sets the operation to Increase
func _on_operation_increase_toggled(toggled_on: bool, type: int) -> void:
	current_data.operation_type = type



## Sets the operation to Decrease
func _on_operation_decrease_toggled(toggled_on: bool, type: int) -> void:
	current_data.operation_type = type



## Toggles the constant operand value mode
func _on_operand_constant_toggled(toggled_on: bool, value_type: int) -> void:
	propagate_call("apply")
	current_data.value_type = value_type
	if toggled_on:
		%OperandVariable.get_parent().propagate_call("set_disabled", [true])
		%OperandVariable.set_disabled(false)
		%OperandConstant.get_parent().propagate_call("set_disabled", [false])



## Toggles the variable operand mode
func _on_operand_variable_toggled(toggled_on: bool, value_type: int) -> void:
	propagate_call("apply")
	current_data.value_type = value_type
	if toggled_on:
		%OperandConstant.get_parent().propagate_call("set_disabled", [true])
		%OperandConstant.set_disabled(false)
		%OperandVariable.get_parent().propagate_call("set_disabled", [false])
		_set_variable_name()



## Updates the numeric value parameter
func _on_operand_value_value_changed(value: float) -> void:
	current_data.value = value
#endregion



#region Variable & Item Selection
## Opens the Variable selection sub-dialog
func _on_operand_variable_id_pressed() -> void:
	var path = "res://addons/CustomControls/Dialogs/switch_variable_dialog.tscn"
	var callable = _on_variable_changed
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	dialog.data_type = 0
	dialog.target = null
	dialog.selected.connect(callable)
	dialog.variable_or_switch_name_changed.connect(_set_variable_name)
	dialog.setup(current_variable_id)



## Processes the selected variable from the sub-dialog
func _on_variable_changed(index: int, target: Node) -> void:
	current_variable_id = index
	current_data.value = index
	_set_variable_name()



## Refreshes the variable label visually
func _set_variable_name() -> void:
	var variables = RPGSYSTEM.system.variables
	var index = current_variable_id
	var variable_name = "%s:%s" % [
		str(index).pad_zeros(4),
		variables.get_item_name(index)
	]
	%OperandVariableID.text = variable_name



## Renders the selected Item resolving the UID properly
func _set_item_name() -> void:
	var uid = current_data.get("item_id", 1)
	
	if uid > 0 and uid < 1000000:
		uid = RPGSYSTEM.id_to_uid("items", uid)
		current_data.item_id = uid
		
	var item_data = RPGSYSTEM.get_data("items", uid) if uid > 0 else null
	
	if item_data:
		var classic_id = RPGSYSTEM.uid_to_id("items", uid)
		var size_pad = str(RPGSYSTEM.database.items.size()).length()
		var item_name = "%s:%s" % [
			str(classic_id).pad_zeros(size_pad),
			item_data.name
		]
		%ItemID.text = item_name
	else:
		%ItemID.text = "⚠ Invalid Item"



## Opens the selection dialog converting UID to classic ID dynamically
func _on_item_id_pressed() -> void:
	var path = "res://addons/CustomControls/Dialogs/select_any_data_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	dialog.database = RPGSYSTEM.database
	dialog.destroy_on_hide = true
	dialog.selected.connect(_on_item_selected)
	
	var uid = current_data.get("item_id", 1)
	var classic_id = RPGSYSTEM.uid_to_id("items", uid) if uid > 0 else 1
	
	dialog.setup(RPGSYSTEM.database.items, classic_id, title, null)



## Converts classic ID returned from dialog back to secure UID
func _on_item_selected(id: int, target: Variant) -> void:
	var uid = RPGSYSTEM.id_to_uid("items", id)
	current_data.item_id = uid
	_set_item_name()
#endregion
