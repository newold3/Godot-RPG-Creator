@tool
extends CommandBaseDialog

func _ready() -> void:
	super()
	parameter_code = 60

func set_data() -> void:
	%ExpereinceMode.select(parameters[0].parameters.get("type", 0))

func build_command_list() -> Array[RPGEventCommand]:
	var commands = super()
	commands[-1].parameters.type = %ExpereinceMode.get_selected_id()
	return commands
