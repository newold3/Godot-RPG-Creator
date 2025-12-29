@tool
extends CommandBaseDialog

var current_data : Dictionary
var char_variable_id: int = 1

func _ready() -> void:
	super()
	parameter_code = 40
	fill_fixed_values()
	set_initial_values()
	_set_variable_name()

func set_initial_values() -> void:
	%Fixed.set_pressed(true)
	%Add.set_pressed(true)
	%StateSelected.set_disabled(false)

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
	var state_id = data.get("state_id", 1)
	current_data.state_id = state_id

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
		%Add.set_pressed(true)
	else:
		%Remove.set_pressed(true)

	if state_id <= RPGSYSTEM.database.states.size():
		%StateSelected.text = "%s: %s" % [state_id, RPGSYSTEM.database.states[state_id].name]
	else:
		%StateSelected.text = "%s: " % state_id

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

func _on_add_toggled(toggled_on: bool) -> void:
	if toggled_on: current_data.operand = 0

func _on_remove_toggled(toggled_on: bool) -> void:
	if toggled_on: current_data.operand = 1

func _on_state_selected_pressed() -> void:
	var path = "res://addons/CustomControls/Dialogs/select_any_data_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	dialog.database = RPGSYSTEM.database
	dialog.destroy_on_hide = true
	dialog.selected.connect(_on_state_selected, CONNECT_ONE_SHOT)
	dialog.setup(RPGSYSTEM.database.states, current_data.state_id, "States", null)

func _on_state_selected(state_id: int, target) -> void:
	current_data.state_id = state_id
	%StateSelected.text = "%s: %s" % [state_id, RPGSYSTEM.database.states[state_id].name]
