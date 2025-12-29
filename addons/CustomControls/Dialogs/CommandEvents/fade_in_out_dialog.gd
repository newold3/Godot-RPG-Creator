@tool
extends CommandBaseDialog


func _ready() -> void:
	super()
	parameter_code = 63 # 63: Fade Out, 64: Fade In


func set_data() -> void:
	var current_duration = parameters[0].parameters.get("duration", 0.5)
	%Duration.value = current_duration


func build_command_list() -> Array[RPGEventCommand]:
	var commands: Array[RPGEventCommand] = super()
	commands[-1].parameters.duration = %Duration.value
	return commands
