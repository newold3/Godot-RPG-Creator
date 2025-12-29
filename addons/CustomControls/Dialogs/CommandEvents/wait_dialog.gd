@tool
extends CommandBaseDialog

var default_min_value = 1.0


func _ready() -> void:
	super()
	parameter_code = 33


func show_local_container(value: bool = true) -> void:
	%LocalContainer.visible = value
	size.y = 0


func set_data() -> void:
	var duration = parameters[0].parameters.get("duration", default_min_value)
	%Duration.value = duration
	%Duration.get_line_edit().grab_focus()
	
	if %LocalContainer.visible:
		var is_local_wait = parameters[0].parameters.get("is_local", false)
		%MakeLocalEvent.set_pressed(is_local_wait)


func build_command_list() -> Array[RPGEventCommand]:
	var commands: Array[RPGEventCommand] = super()
	commands[-1].parameters.duration = %Duration.value 
	if %LocalContainer.visible:
		commands[-1].parameters.is_local = %MakeLocalEvent.is_pressed()
	return commands


func set_parameter_name(_name: String, _tooltip: String = "") -> void:
	%ParameterName.text = _name
	if _tooltip:
		%Duration.tooltip_text = _tooltip
		CustomTooltipManager.replace_all_tooltips_with_custom(%Duration)


func set_min_value(value: float, default: bool = true) -> void:
	%Duration.min_value = value
	if default:
		default_min_value = value
