@tool
extends CommandBaseDialog


func _ready() -> void:
	super()
	parameter_code = 78


func set_data() -> void:
	var image_id = parameters[0].parameters.get("index", 1)
	var image_scale = parameters[0].parameters.get("scale", Vector2.ONE) * 100
	var duration = parameters[0].parameters.get("duration", 0)
	var wait = parameters[0].parameters.get("wait", true)
	
	%ImageID.value = image_id
	%SizeX.value = image_scale.x
	%SizeY.value = image_scale.y
	%Duration.value = duration
	%Wait.set_pressed(wait)


func build_command_list() -> Array[RPGEventCommand]:
	var commands: Array[RPGEventCommand] = super()

	commands[-1].parameters.index = %ImageID.value
	commands[-1].parameters.scale = Vector2(%SizeX.value, %SizeY.value) / 100.0
	commands[-1].parameters.duration = %Duration.value
	commands[-1].parameters.wait = %Wait.is_pressed()
	
	return commands
