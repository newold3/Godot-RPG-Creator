@tool
extends CommandBaseDialog


func _ready() -> void:
	super()
	parameter_code = 77


func set_data() -> void:
	var image_id = parameters[0].parameters.get("index", 1)
	var image_rotation = parameters[0].parameters.get("rotation", 0)
	var duration = parameters[0].parameters.get("duration", 0)
	var wait = parameters[0].parameters.get("wait", true)
	
	%ImageID.value = image_id
	%Rotation.value = image_rotation
	%Duration.value = duration
	%Wait.set_pressed(wait)


func build_command_list() -> Array[RPGEventCommand]:
	var commands: Array[RPGEventCommand] = super()

	commands[-1].parameters.index = %ImageID.value
	commands[-1].parameters.rotation = %Rotation.value
	commands[-1].parameters.duration = %Duration.value
	commands[-1].parameters.wait = %Wait.is_pressed()
	
	return commands
