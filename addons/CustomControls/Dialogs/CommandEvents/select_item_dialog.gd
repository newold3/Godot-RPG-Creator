@tool
extends CommandBaseDialog


var current_variable_id = 1


func _ready() -> void:
	super()
	parameter_code = 9
	set_data()


func set_data() -> void:
	var variable_id: int
	var item_type: int
	if parameters:
		variable_id = parameters[0].parameters.get("variable_id", current_variable_id)
		item_type = parameters[0].parameters.get("item_type", 1)
	else:
		variable_id = 1
		item_type = 1
	current_variable_id = variable_id
	_set_variable_name()
	item_type = max(0, min(item_type, %ItemType.get_item_count()))
	%ItemType.select(item_type)


func build_command_list() -> Array[RPGEventCommand]:
	var commands: Array[RPGEventCommand] = super()

	commands[-1].parameters.variable_id = current_variable_id
	commands[-1].parameters.item_type = %ItemType.get_selected_id()
	
	return commands


func _on_variable_id_pressed() -> void:
	var path = "res://addons/CustomControls/Dialogs/switch_variable_dialog.tscn"
	var callable = _on_variable_changed
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	dialog.data_type = 0
	dialog.target = %VariableID
	dialog.selected.connect(callable)
	dialog.variable_or_switch_name_changed.connect(_set_variable_name)
	dialog.setup(current_variable_id)


func _on_variable_changed(index: int, target: Node) -> void:
	current_variable_id = index
	_set_variable_name()


func _set_variable_name() -> void:
	var variables = RPGSYSTEM.system.variables
	var index = current_variable_id
	var variable_name = "%s:%s" % [
		str(index).pad_zeros(4),
		variables.get_item_name(index)
	]
	%VariableID.text = variable_name
