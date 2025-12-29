@tool
extends CommandBaseDialog


func _ready() -> void:
	super()


func set_data() -> void:
	var zoom = parameters[0].parameters.get("zoom", 2)
	%Zoom.value = zoom
	var duration = parameters[0].parameters.get("duration", 0.5)
	%Duration.value = duration


func build_command_list() -> Array[RPGEventCommand]:
	var commands: Array[RPGEventCommand] = super()
	commands[-1].parameters.duration = %Duration.value
	commands[-1].parameters.zoom = %Zoom.value
	return commands
