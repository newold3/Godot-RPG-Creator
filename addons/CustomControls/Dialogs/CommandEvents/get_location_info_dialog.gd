@tool
extends CommandBaseDialog


var current_data: Dictionary

var current_numeric_variable_id: int = 1
var current_text_variable_id: int = 1
var current_numeric_info: int = 0
var current_text_info: int = 0

var current_location: Vector2 = Vector2.ZERO
var current_location_variable: Vector2 = Vector2.ONE


func _ready() -> void:
	super()
	parameter_code = 106
	create_button_groups()


func create_button_groups() -> void:
	var b = ButtonGroup.new()
	for button in [%SelectNumberVariable, %SelectTextVariable]: button.button_group = b
	b = ButtonGroup.new()
	for button in [%ManualAdjustment, %VariableAdjustment]: button.button_group = b


func set_data() -> void:
	var data: Dictionary = parameters[0].parameters
	current_data = data.duplicate()
	var variable_type = current_data.get("variable_type", 0)
	if variable_type == 0:
		current_numeric_variable_id = current_data.get("variable_id", 1)
		%SelectNumberVariable.set_pressed(true)
	else:
		current_text_variable_id = current_data.get("variable_id", 1)
		%SelectTextVariable.set_pressed(true)
	
	var info_selected = current_data.get("info_selected", 0)
	if %InfoType.get_item_count() > info_selected and info_selected >= 0:
		%InfoType.select(info_selected)
	
	var location_type = current_data.get("location_type", 0)
	if location_type == 0:
		current_numeric_info = info_selected
		current_location = current_data.get("cell", Vector2.ZERO)
		%ManualAdjustment.set_pressed(true)
	else:
		current_text_info = info_selected
		current_location_variable = current_data.get("cell", Vector2.ONE)
		%VariableAdjustment.set_pressed(true)
	


func fill_info(options: PackedStringArray, index_selected: int) -> void:
	var node = %InfoType
	node.clear()
	
	for option in options:
		node.add_item(tr(option))
	
	if options.size() > index_selected:
		node.select(index_selected)



func fill_numeric_info() -> void:
	var options: PackedStringArray = [
		"Is Flipped Horizontally", "Is Flipped Vertically", "Terrain ID",
		"Terrain Set ID", "Y Sort Origin", "Z-Index", "Is Transpose"
	]
	
	fill_info(options, current_numeric_info)


func fill_text_info() -> void:
	var options: PackedStringArray = [
		"Terrain Name", "Texture Name"
		
	]
	
	var edited_scene = RPGSYSTEM.editor_interface.get_edited_scene_root()
	if edited_scene and edited_scene is RPGMap:
		var custom_layers: PackedStringArray = edited_scene.get_custom_data_layer_names()
		for layer in custom_layers:
			options.append("Get data from custom data layer < %s >" % layer)
	
	fill_info(options, current_text_info)


func build_command_list() -> Array[RPGEventCommand]:
	var commands: Array[RPGEventCommand] = super()
	
	if %SelectNumberVariable.is_pressed():
		commands[-1].parameters.variable_type = 0
		commands[-1].parameters.variable_id = current_numeric_variable_id
	else:
		commands[-1].parameters.variable_type = 1
		commands[-1].parameters.variable_id = current_text_variable_id

	commands[-1].parameters.info_selected = %InfoType.get_selected_id()
	
	if %ManualAdjustment.is_pressed():
		commands[-1].parameters.location_type = 0
		commands[-1].parameters.cell = current_location
	else:
		commands[-1].parameters.location_type = 1
		commands[-1].parameters.cell = current_location_variable
	
	return commands


func _set_variable_name() -> void:
	var variables = RPGSYSTEM.system.variables
	var index = current_numeric_variable_id
	var variable_name = "%s:%s" % [
		str(index).pad_zeros(4),
		variables.get_item_name(index)
	]
	%NumberVariable.text = variable_name


func _set_text_variable_name() -> void:
	var variables = RPGSYSTEM.system.text_variables
	var index = current_text_variable_id
	var variable_name = "%s:%s" % [
		str(index).pad_zeros(4),
		variables.get_item_name(index)
	]
	%TextVariable.text = variable_name


func _fill_manual_location() -> void:
	%MapCell.text = "x: %s, y: %s" % [current_location.x, current_location.y]


func _fill_variable_location() -> void:
	var variables = RPGSYSTEM.system.variables
	var index1 = current_location_variable.x
	var index2 = current_location_variable.y
	var variable1_name = "%s:%s" % [
		str(index1).pad_zeros(4),
		variables.get_item_name(index1)
	]
	var variable2_name = "%s:%s" % [
		str(index2).pad_zeros(4),
		variables.get_item_name(index2)
	]
	%X.text = variable1_name
	%Y.text = variable2_name


func _show_variable_dialog(button: Button, type: int, current_variable_id: int, real_type: int) -> void:
	var path = "res://addons/CustomControls/Dialogs/switch_variable_dialog.tscn"
	var callable = _on_variable_changed.bind(real_type)
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	dialog.data_type = type
	dialog.target = button
	dialog.selected.connect(callable)
	dialog.variable_or_switch_name_changed.connect(_set_variable_name)
	dialog.setup(current_variable_id)


func _on_variable_changed(index: int, button: Node, type: int) -> void:
	if type == 0:
		current_numeric_variable_id = index
		_set_variable_name()
	elif type == 1:
		current_text_variable_id = index
		_set_text_variable_name()
	elif type == 2:
		current_location_variable.x = index
		_fill_variable_location()
	elif type == 3:
		current_location_variable.y = index
		_fill_variable_location()


func _on_number_variable_pressed() -> void:
	_show_variable_dialog(%NumberVariable, 0, current_numeric_variable_id, 0)


func _on_text_variable_pressed() -> void:
	_show_variable_dialog(%TextVariable, 2, current_text_variable_id, 1)


func _on_select_number_variable_toggled(toggled_on: bool) -> void:
	%NumberVariable.set_disabled(!toggled_on)
	if toggled_on:
		_set_variable_name()
		fill_numeric_info()


func _on_select_text_variable_toggled(toggled_on: bool) -> void:
	%TextVariable.set_disabled(!toggled_on)
	if toggled_on:
		fill_text_info()
		_set_text_variable_name()


func _on_manual_adjustment_toggled(toggled_on: bool) -> void:
	%MapCell.set_disabled(!toggled_on)
	_fill_manual_location()


func _on_variable_adjustment_toggled(toggled_on: bool) -> void:
	%X.set_disabled(!toggled_on)
	%Y.set_disabled(!toggled_on)
	_fill_variable_location()


func _on_map_cell_pressed() -> void:
	var edited_scene = RPGSYSTEM.editor_interface.get_edited_scene_root()
	if edited_scene and edited_scene is RPGMap:
		var map_path = edited_scene.scene_file_path
		if ResourceLoader.exists(map_path):
			var path = "res://addons/CustomControls/Dialogs/CommandEvents/select_map_position_dialog.tscn"
			var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
			dialog.set_start_map(map_path, current_location)
			dialog.hide_map_list()
			dialog.cell_selected.connect(_on_manual_map_position_selected)


func _on_manual_map_position_selected(_map_id: int, start_position: Vector2i) -> void:
	current_location = start_position
	_fill_manual_location()


func _on_x_pressed() -> void:
	_show_variable_dialog(%X, 0, current_location_variable.x, 2)


func _on_y_pressed() -> void:
	_show_variable_dialog(%Y, 0, current_location_variable.y, 3)


func _on_info_type_item_selected(index: int) -> void:
	if %SelectNumberVariable.is_pressed():
		current_numeric_info = index
	else:
		current_text_info = index
