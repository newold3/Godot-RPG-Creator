@tool
extends CommandBaseDialog


var default_value: float = 0


func _ready() -> void:
	super()
	await get_tree().process_frame
	%ValueSpinBox.get_line_edit().select_all()
	%ValueSpinBox.get_line_edit().grab_focus()


func set_data() -> void:
	%ValueSpinBox.value = parameters[0].parameters.get("value", default_value)


func set_min_max_values(min_value: float, max_value: float, step: float = 1) -> void:
	%ValueSpinBox.step = step
	%ValueSpinBox.rounded = (step == 1)
	%ValueSpinBox.max_value = max_value
	%ValueSpinBox.min_value = min_value


func set_suffix(text: String) -> void:
	%Suffix.text = text


func set_value(value: int) -> void:
	%ValueSpinBox.value = value
	%ValueSpinBox.get_line_edit().select_all()


func build_command_list() -> Array[RPGEventCommand]:
	var commands: Array[RPGEventCommand] = super()
	commands[-1].parameters.value = %ValueSpinBox.value
	return commands
