@tool
extends CommandBaseDialog


var current_variable_id: int = 1


func _ready() -> void:
	super()
	parameter_code = 61


func set_data() -> void:
	%Value.text = parameters[0].parameters.get("value", "")
	current_variable_id = parameters[0].parameters.get("id", 1)
	var operation = parameters[0].parameters.get("operation", 0)
	%OperationType.select(max(0, min(%OperationType.get_item_count() - 1, operation)))
	%NewValue.text = parameters[0].parameters.get("replace_text", "")
	_set_extra_value_visible()
	_set_variable_name()


func _set_variable_name() -> void:
	var variables = RPGSYSTEM.system.text_variables
	
	var variable_name = "%s:%s" % [
		str(current_variable_id).pad_zeros(4),
		variables.get_item_name(current_variable_id)
	]
	%Variable.text = variable_name


func build_command_list() -> Array[RPGEventCommand]:
	var commands: Array[RPGEventCommand] = super()

	commands[-1].parameters.id = current_variable_id
	var operation = %OperationType.get_selected_id()
	commands[-1].parameters.operation = operation
	if operation == 2:
		commands[-1].parameters.replace_text = %NewValue.text
	commands[-1].parameters.value = %Value.text
	
	return commands


func _on_variable_pressed() -> void:
	var path = "res://addons/CustomControls/Dialogs/switch_variable_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	dialog.data_type = 2
	dialog.selected.connect(_on_variable_selected)
	dialog.variable_or_switch_name_changed.connect(_set_variable_name)
	dialog.setup(current_variable_id)


func _on_variable_selected(id: int, target) -> void:
	current_variable_id = id
	_set_variable_name()


func _set_extra_value_visible() -> void:
	var id = %OperationType.get_selected_id()
	%NewValueContainer.visible = id == 2
	size.y = get_contents_minimum_size().y


func _on_operation_type_item_selected(index: int) -> void:
	_set_extra_value_visible()
