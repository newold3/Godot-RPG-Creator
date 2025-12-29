@tool
extends CommandBaseDialog


func _ready() -> void:

	super()
	parameter_code = 55


func set_data() -> void:
	var type = clamp(parameters[0].parameters.get("type", 0), 0, 1)
	%Type.select(type)


func build_command_list() -> Array[RPGEventCommand]:
	var commands = super()
	commands[-1].parameters.type = %Type.get_selected_id()
	return commands
