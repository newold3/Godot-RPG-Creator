@tool
extends CommandBaseDialog

#region Variables
var current_data : Dictionary
var char_variable_id: int = 1
#endregion



#region Lifecycle & Setup
## Initializes base parameters and populates default UI state
func _ready() -> void:
	super()
	parameter_code = 40
	fill_fixed_values()
	set_initial_values()
	_set_variable_name()



## Restores default toggles when no data is loaded
func set_initial_values() -> void:
	%Fixed.set_pressed(true)
	%Add.set_pressed(true)
	%StateSelected.set_disabled(false)



## Populates the Fixed Actor dropdown associating safe classic IDs to internal secure UIDs
func fill_fixed_values() -> void:
	var node : OptionButton = %FixedValue
	node.clear()
	
	node.add_item("Entire Party")
	node.set_item_metadata(0, 0)
	
	for i in range(1, RPGSYSTEM.database.actors.size()):
		var text = "%s: %s" % [i, RPGSYSTEM.database.actors[i].name]
		node.add_item(text)
		node.set_item_metadata(i, RPGSYSTEM.id_to_uid("actors", i))



## Reads and parses initial parameters into the dialog UI controls
func set_data() -> void:
	var data = parameters[0].parameters
	current_data = data.duplicate()
	
	var actor_type = data.get("actor_type", 0)
	current_data.actor_type = actor_type
	
	var uid_actor = data.get("actor_id", 0) if actor_type == 0 else data.get("actor_id", 1)
	current_data.actor_id = uid_actor
	
	var operation = data.get("operand", 0)
	current_data.operand = operation
	
	var uid_state = data.get("state_id", 1)
	current_data.state_id = uid_state

	if actor_type == 0:
		%Fixed.set_pressed(true)
		var classic_actor_id = RPGSYSTEM.uid_to_id("actors", uid_actor) if uid_actor > 0 else 0
		if classic_actor_id <= RPGSYSTEM.database.actors.size() and classic_actor_id >= 0:
			%FixedValue.select(classic_actor_id)
		else:
			%FixedValue.select(0)
		char_variable_id = 1
	else:
		%Variable.set_pressed(true)
		char_variable_id = uid_actor

	if operation == 0:
		%Add.set_pressed(true)
	else:
		%Remove.set_pressed(true)

	var classic_state_id = RPGSYSTEM.uid_to_id("states", uid_state) if uid_state > 0 else 1
	if classic_state_id > 0 and classic_state_id < RPGSYSTEM.database.states.size():
		%StateSelected.text = "%s: %s" % [classic_state_id, RPGSYSTEM.database.states[classic_state_id].name]
	else:
		%StateSelected.text = "⚠ Invalid State"

	_set_variable_name()



## Restructures current memory variables back into an Event Command
func build_command_list() -> Array[RPGEventCommand]:
	var commands = super()
	commands[-1].parameters = current_data
	return commands
#endregion



#region Target Actor Logic
## Handles UI shift and maps selected actor UID directly from the Dropdown Metadata
func _on_fixed_toggled(toggled_on: bool) -> void:
	current_data.actor_type = 0
	var idx = %FixedValue.get_selected_id()
	current_data.actor_id = %FixedValue.get_item_metadata(idx) if idx >= 0 else 0
	%FixedValue.set_disabled(!toggled_on)
	%VariableValue.set_disabled(toggled_on)



## Captures selection switch over Variable mode
func _on_variable_toggled(toggled_on: bool) -> void:
	current_data.actor_type = 1
	current_data.actor_id = char_variable_id
	%VariableValue.set_disabled(!toggled_on)
	%FixedValue.set_disabled(toggled_on)



## Syncs selected actor UID internally based on dropdown changes
func _on_fixed_value_item_selected(index: int) -> void:
	current_data.actor_id = %FixedValue.get_item_metadata(index)
#endregion



#region Variable Selection
## Common spawn logic for picking an existing System Variable
func show_select_variable_dialog(callable: Callable, variable_selected_id: int = -1) -> void:
	var path = "res://addons/CustomControls/Dialogs/switch_variable_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	dialog.data_type = 0
	dialog.target = null
	dialog.selected.connect(callable)
	dialog.variable_or_switch_name_changed.connect(_set_variable_name)
	dialog.setup(variable_selected_id)



## Handles click event targeting Actor Variable picker
func _on_variable_value_pressed() -> void:
	var callable = _on_actor_variable_changed
	show_select_variable_dialog(callable, char_variable_id)



## Internal callback processing Actor Variable change
func _on_actor_variable_changed(index: int, target) -> void:
	current_data.actor_id = index
	char_variable_id = index
	_set_variable_name()



## Refreshes the display text of all selected Variables
func _set_variable_name() -> void:
	var variables = RPGSYSTEM.system.variables
	var variable_name = "%s: %s" % [char_variable_id, variables.get_item_name(char_variable_id)]
	%VariableValue.text = variable_name
#endregion



#region Operation & State Logic
## Sets the operation mode to Add
func _on_add_toggled(toggled_on: bool) -> void:
	if toggled_on: current_data.operand = 0



## Sets the operation mode to Remove
func _on_remove_toggled(toggled_on: bool) -> void:
	if toggled_on: current_data.operand = 1



## Spawns the dialog to select a State resolving classic ID
func _on_state_selected_pressed() -> void:
	var path = "res://addons/CustomControls/Dialogs/select_any_data_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	dialog.database = RPGSYSTEM.database
	dialog.destroy_on_hide = true
	dialog.selected.connect(_on_state_selected, CONNECT_ONE_SHOT)
	
	var uid = current_data.get("state_id", 1)
	var classic_id = RPGSYSTEM.uid_to_id("states", uid) if uid > 0 else 1
	
	dialog.setup(RPGSYSTEM.database.states, classic_id, "States", null)



## Receives the classic ID from the dialog and stores it as a secure UID
func _on_state_selected(state_id: int, target) -> void:
	var uid = RPGSYSTEM.id_to_uid("states", state_id)
	current_data.state_id = uid
	%StateSelected.text = "%s: %s" % [state_id, RPGSYSTEM.database.states[state_id].name]
#endregion
