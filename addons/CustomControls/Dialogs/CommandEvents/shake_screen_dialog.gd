@tool
extends CommandBaseDialog


func _ready() -> void:
	super()
	parameter_code = 67


func set_data() -> void:
	var current_power = parameters[0].parameters.get("power", 4500)
	%Power.value = current_power
	var current_duration = parameters[0].parameters.get("duration", 0.5)
	%Duration.value = current_duration


func build_command_list() -> Array[RPGEventCommand]:
	var commands: Array[RPGEventCommand] = super()

	commands[-1].parameters.power = %Power.value
	commands[-1].parameters.duration = %Duration.value
	
	return commands
