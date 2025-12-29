@tool
extends CommandBaseDialog


var option_type: int = 0


func _ready() -> void:
	super()
	parameter_code = 59
	set_option_connections()


func set_option_connections() -> void:
	var nodes = [%GetInOption, %GetOutOption]
	var button_group = ButtonGroup.new()
	for i in nodes.size():
		var node: CheckBox = nodes[i]
		node.button_group = button_group
		node.toggled.connect(
			func(toggled_on: bool):
				if i == 0:
					node.get_parent().propagate_call("set_disabled", [!toggled_on])
					node.set_disabled(false)
				
				if toggled_on:
					option_type = i
				
		)
	
	nodes[0].set_pressed(true)


func set_data() -> void:
	option_type = parameters[0].parameters.get("type", 0)
	if option_type == 0:
		%GetInOption.set_pressed(true)
		var transport_id = clamp(
			parameters[0].parameters.get("transport_id", 0), 0, %TransportType.get_item_count() - 1
		)
		%TransportType.select(transport_id)
	else:
		%GetOutOption.set_pressed(true)


func build_command_list() -> Array[RPGEventCommand]:
	var commands: Array[RPGEventCommand] = super()
	commands[-1].parameters.type = option_type
	if option_type == 0:
		commands[-1].parameters.transport_id = %TransportType.get_selected_id()
	return commands
