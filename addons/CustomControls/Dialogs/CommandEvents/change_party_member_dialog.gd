@tool
extends CommandBaseDialog

var current_data: Dictionary

func _ready() -> void:
	super()
	parameter_code = 16
	fill_actor_list()

func fill_actor_list() -> void:
	var items = RPGSYSTEM.database.actors
	var list = %ActorID
	list.clear()
	for i in range(1, items.size(), 1):
		var actor = items[i]
		var item_name = "%s: %s" % [
			str(i).pad_zeros(str(items.size()).length()),
			actor.name
		]
		list.add_item(item_name)

func set_data() -> void:
	var data = parameters[0].parameters
	current_data = data.duplicate()
	var operation = data.get("operation_type", 0)
	current_data.operation_type = operation
	if operation == 0:
		%OperationIncrease.set_pressed(true)
	else:
		%OperationDecrease.set_pressed(true)

	var id = data.get("actor_id", 1)
	current_data.actor_id = id
	if RPGSYSTEM.database.actors.size() > id and id > 0:
		%ActorID.select(id - 1)
	else:
		%ActorID.select(0)
		current_data.actor_id = 1

	%Initialize.set_pressed(data.get("initialize", false))
	current_data.initialize = %Initialize.is_pressed()

func build_command_list() -> Array[RPGEventCommand]:
	var commands = super()
	commands[-1].parameters = current_data
	return commands

func _on_operation_increase_toggled(toggled_on: bool, type: int) -> void:
	current_data.operation_type = type
	if toggled_on:
		%Initialize.set_disabled(false)

func _on_operation_decrease_toggled(toggled_on: bool, type: int) -> void:
	current_data.operation_type = type
	if toggled_on:
		%Initialize.set_disabled(true)

func _on_actor_id_item_selected(index: int) -> void:
	current_data.actor_id = index + 1

func _on_initialize_toggled(toggled_on: bool) -> void:
	current_data.initialize = toggled_on
