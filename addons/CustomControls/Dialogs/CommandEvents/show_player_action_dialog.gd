@tool
extends CommandBaseDialog


@export var action_names: PackedStringArray


func _ready() -> void:
	super()
	parameter_code = 74
	fill_actions()


func fill_actions() -> void:
	var node = %ActionsList
	node.clear()
	
	for item: String in action_names:
		node.add_item(item)
	
	if node.get_item_count() == 0:
		node.add_item("items...")
	
	node.select(0)


func set_data() -> void:
	var action_selected = parameters[0].parameters.get("index", 0)
	%ActionsList.select(action_selected if %ActionsList.get_item_count() > action_selected else 0)


func build_command_list() -> Array[RPGEventCommand]:
	var commands: Array[RPGEventCommand] = super()
	commands[-1].parameters.index = %ActionsList.get_selected_id()
	return commands
