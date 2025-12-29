@tool
extends CommandBaseDialog


var current_variable_id: int = 1


func _ready() -> void:
	super()
	parameter_code = 61


func set_data() -> void:
	%Value.text = parameters[0].parameters.get("value", "")
	current_variable_id = parameters[0].parameters.get("id", 1)
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
