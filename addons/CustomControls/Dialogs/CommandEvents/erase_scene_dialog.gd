@tool
extends CommandBaseDialog


func _ready() -> void:
	super()
	parameter_code = 82


func set_data() -> void:
	var image_id = parameters[0].parameters.get("index", 1)
	
	%SceneID.value = image_id


func build_command_list() -> Array[RPGEventCommand]:
	var commands: Array[RPGEventCommand] = super()
	commands[-1].parameters.index = %SceneID.value
	return commands
