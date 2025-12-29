@tool
extends CommandBaseDialog

func _ready() -> void:
	super()
	parameter_code = 71

func set_data() -> void:
	var enabled = parameters[0].parameters.get("value", true)
	if enabled:
		%Enabled.set_pressed(true)
	else:
		%Disabled.set_pressed(true)

func build_command_list() -> Array[RPGEventCommand]:
	var commands = super()
	commands[-1].parameters.value = true if %Enabled.is_pressed() else false
	return commands
