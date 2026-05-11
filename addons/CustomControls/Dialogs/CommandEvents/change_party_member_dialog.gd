@tool
extends CommandBaseDialog

#region Variables
var current_data: Dictionary
#endregion



#region Lifecycle & Setup
## Initializes the base configuration for the Party command
func _ready() -> void:
	super()
	parameter_code = 16
	fill_actor_list()



## Populates the actor dropdown linking classic IDs to UIDs
func fill_actor_list() -> void:
	var items = RPGSYSTEM.database.actors
	var list = %ActorID
	list.clear()
	
	for i in range(1, items.size(), 1):
		var actor = items[i]
		var item_name = "%s: %s" % [
			str(i).pad_zeros(str(items.size() - 1).length()),
			actor.name
		]
		list.add_item(item_name)
		list.set_item_metadata(list.get_item_count() - 1, RPGSYSTEM.id_to_uid("actors", i))



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

	var uid = data.get("actor_id", 1)
	uid = RPGSYSTEM.id_to_uid("actors", uid) if uid > 0 else 1
	current_data.actor_id = uid
	
	var classic_id = RPGSYSTEM.uid_to_id("actors", uid)
	
	if classic_id > 0 and classic_id < RPGSYSTEM.database.actors.size():
		%ActorID.select(classic_id - 1)
	else:
		%ActorID.select(0)
		current_data.actor_id = RPGSYSTEM.id_to_uid("actors", 1)

	%Initialize.set_pressed(data.get("initialize", false))
	current_data.initialize = %Initialize.is_pressed()



## Compiles the UI state back into an Event Command array
func build_command_list() -> Array[RPGEventCommand]:
	var commands = super()
	commands[-1].parameters = current_data
	return commands
#endregion



#region Toggles & Interaction
## Sets the operation to Increase and enables Initialize option
func _on_operation_increase_toggled(toggled_on: bool, type: int) -> void:
	current_data.operation_type = type
	if toggled_on:
		%Initialize.set_disabled(false)



## Sets the operation to Decrease and disables Initialize option
func _on_operation_decrease_toggled(toggled_on: bool, type: int) -> void:
	current_data.operation_type = type
	if toggled_on:
		%Initialize.set_disabled(true)



## Submits the selected actor UID from the metadata
func _on_actor_id_item_selected(index: int) -> void:
	current_data.actor_id = %ActorID.get_item_metadata(index)



## Submits the initialize flag state
func _on_initialize_toggled(toggled_on: bool) -> void:
	current_data.initialize = toggled_on
#endregion
