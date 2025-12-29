@tool
extends CommandBaseDialog

var current_data: Dictionary
var current_variable_id: int = 1
var max_level: int = 1

func _ready() -> void:
	super()
	parameter_code = 14

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
	%IncludeEquipment.set_pressed(data.get("include_equipment", false))
	current_data.include_equipment = %IncludeEquipment.is_pressed()
	%ItemLevel.value = current_data.get("level", 1)
	_set_item_name()

func build_command_list() -> Array[RPGEventCommand]:
	var commands = super()
	if %OperandVariable.is_pressed():
		current_data.value = current_variable_id
	commands[-1].parameters = current_data
	return commands

func _on_operation_increase_toggled(toggled_on: bool, type: int) -> void:
	current_data.operation_type = type
	if toggled_on:
		%IncludeEquipment.set_disabled(true)

func _on_operation_decrease_toggled(toggled_on: bool, type: int) -> void:
	current_data.operation_type = type
	if toggled_on:
		%IncludeEquipment.set_disabled(false)

func _on_operand_constant_toggled(toggled_on: bool, value_type: int) -> void:
	current_data.value_type = value_type
	if toggled_on:
		%OperandVariable.get_parent().propagate_call("set_disabled", [true])
		%OperandVariable.set_disabled(false)
		%OperandConstant.get_parent().propagate_call("set_disabled", [false])

func _on_operand_variable_toggled(toggled_on: bool, value_type: int) -> void:
	current_data.value_type = value_type
	if toggled_on:
		%OperandConstant.get_parent().propagate_call("set_disabled", [true])
		%OperandConstant.set_disabled(false)
		%OperandVariable.get_parent().propagate_call("set_disabled", [false])
		_set_variable_name()

func _on_operand_value_value_changed(value: float) -> void:
	current_data.value = value

func _on_operand_variable_id_pressed() -> void:
	var path = "res://addons/CustomControls/Dialogs/switch_variable_dialog.tscn"
	var callable = _on_variable_changed
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	dialog.data_type = 0
	dialog.target = null
	dialog.selected.connect(callable)
	dialog.variable_or_switch_name_changed.connect(_set_variable_name)
	dialog.setup(current_variable_id)

func _on_variable_changed(index: int, target: Node) -> void:
	current_variable_id = index
	current_data.value = index
	_set_variable_name()

func _set_variable_name() -> void:
	var variables = RPGSYSTEM.system.variables
	var index = current_variable_id
	var variable_name = "%s:%s" % [
		str(index).pad_zeros(4),
		variables.get_item_name(index)
	]
	%OperandVariableID.text = variable_name

func _set_item_name() -> void:
	var items = RPGSYSTEM.database.weapons
	var index = current_data.get("item_id", 1)
	current_data.item_id = index
	if items.size() > index:
		var item_name = "%s:%s" % [
			str(index).pad_zeros(str(items.size()).length()),
			items[index].name
		]
		%ItemID.text = item_name
		max_level = items[index].upgrades.max_levels
		current_data.level = max(1, min(max_level, current_data.get("level", 1)))
	else:
		%ItemID.text = "⚠ Invalid Item"
		current_data.level = 1
		max_level = 1
	
	%ItemLevel.max_value = max_level
	%ItemLevel.value = current_data.level
	%MaxLevels.text = " / %s" % max_level

func _on_item_id_pressed() -> void:
	var path = "res://addons/CustomControls/Dialogs/select_any_data_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	dialog.database = RPGSYSTEM.database
	dialog.destroy_on_hide = true
	dialog.selected.connect(_on_item_selected)
	var item_id = current_data.get("item_id", 1)
	dialog.setup(RPGSYSTEM.database.weapons, item_id, title, null)

func _on_item_selected(id: int, target: Variant) -> void:
	current_data.item_id = id
	_set_item_name()

func _on_include_equipment_toggled(toggled_on: bool) -> void:
	current_data.include_equipment = toggled_on


func _on_item_level_value_changed(value: float) -> void:
	current_data.level = value
