@tool
extends CommandBaseDialog

var is_selected: bool = false

func _ready() -> void:
	super()
	var button_group = ButtonGroup.new()
	%Option1.button_group = button_group
	%Option2.button_group = button_group
	%Option1.grab_focus()


func select(value: bool) -> void:
	%Option1.set_pressed(value)


func set_info(_title: String, _contents: String, _option1 : String = "Enabled", _option2 : String = "Disabled") -> void:
	title = _title
	%Content.text = _contents
	%Option1.text = _option1
	%Option2.text = _option2


func set_data() -> void:
	var selected = parameters[0].parameters.get("selected", is_selected)
	if selected:
		%Option1.set_pressed(true)
	else:
		%Option2.set_pressed(true)


func build_command_list() -> Array[RPGEventCommand]:
	var commands: Array[RPGEventCommand] = super()
	commands[-1].parameters.selected = is_selected
	return commands


func _on_option_1_toggled(toggled_on: bool) -> void:
	if toggled_on:
		is_selected = true


func _on_option_2_toggled(toggled_on: bool) -> void:
	if toggled_on:
		is_selected = false
