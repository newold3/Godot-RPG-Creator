@tool
extends CommandBaseDialog


var current_variables: Vector2i = Vector2i.ONE


func _ready() -> void:
	super()
	parameter_code = 76


func set_data() -> void:
	var image_id = parameters[0].parameters.get("index", 1)
	var position_type = parameters[0].parameters.get("position_type", 0)
	var pos: Vector2
	if position_type == 0:
		pos = parameters[0].parameters.get("position", Vector2.ZERO)
	else:
		pos = parameters[0].parameters.get("position", Vector2.ONE)
	var duration = parameters[0].parameters.get("duration", 0)
	var wait = parameters[0].parameters.get("wait", true)
	var relative_movement = parameters[0].parameters.get("relative_movement", true)
	
	%ImageID.value = image_id
	if position_type == 0:
		%ManualSettings.set_pressed(true)
		%PositionX.value = pos.x
		%PositionY.value = pos.y
	else:
		%VariableSettings.set_pressed(true)
		current_variables = Vector2i(pos)
	%Duration.value = duration
	%Wait.set_pressed(wait)
	%RelativeMovement.set_pressed(relative_movement)
	
	update_variable_names()


func build_command_list() -> Array[RPGEventCommand]:
	var commands: Array[RPGEventCommand] = super()
	

	commands[-1].parameters.index = %ImageID.value
	commands[-1].parameters.position_type = 0 if %ManualSettings.is_pressed() else 1
	if commands[-1].parameters.position_type == 0:
		commands[-1].parameters.position = Vector2(%PositionX.value, %PositionY.value)
	else:
		commands[-1].parameters.position = current_variables
	commands[-1].parameters.duration = %Duration.value
	commands[-1].parameters.wait = %Wait.is_pressed()
	commands[-1].parameters.relative_movement = %RelativeMovement.is_pressed()
	
	return commands


func _on_manual_settings_toggled(toggled_on: bool) -> void:
	%ManualPositionContainer.propagate_call("set_disabled", [!toggled_on])


func _on_variable_settings_toggled(toggled_on: bool) -> void:
	%VariablePositionContainer.propagate_call("set_disabled", [!toggled_on])


func select_variable_dialog(target: String) -> void:
	var path = "res://addons/CustomControls/Dialogs/switch_variable_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	dialog.data_type = 0
	dialog.target = target
	dialog.selected.connect(select_variable)
	dialog.variable_or_switch_name_changed.connect(update_variable_names)
	var id_selected: int = current_variables.x if target == "x" else current_variables.y
	dialog.setup(id_selected)


func select_variable(id: int, target: String) -> void:
	if target == "x":
		current_variables.x = id
	else:
		current_variables.y = id
	update_variable_names()


func update_variable_names() -> void:
	var variable_x_name = "%s:%s" % [
		str(current_variables.x).pad_zeros(4),
		RPGSYSTEM.system.variables.get_item_name(current_variables.x)
	]
	var variable_y_name = "%s:%s" % [
		str(current_variables.y).pad_zeros(4),
		RPGSYSTEM.system.variables.get_item_name(current_variables.y)
	]
	%VariableX.text = variable_x_name
	%VariableY.text = variable_y_name


func _on_variable_x_pressed() -> void:
	select_variable_dialog("x")


func _on_variable_y_pressed() -> void:
	select_variable_dialog("y")
