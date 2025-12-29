@tool
extends CommandBaseDialog


func _ready() -> void:
	super()
	parameter_code = 80


func set_data() -> void:
	var image_id = parameters[0].parameters.get("index", 1)
	
	%ImageID.value = image_id


func build_command_list() -> Array[RPGEventCommand]:
	var commands: Array[RPGEventCommand] = super()
	commands[-1].parameters.index = %ImageID.value
	return commands
