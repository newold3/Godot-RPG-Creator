@tool
extends PanelContainer

var current_type: int = 0
var param_title: String
var current_switch: int = 1
var current_numeric_variable: int = 1
var current_text_variable: int = 1

const CUSTOM_BUTTON = preload("res://addons/CustomControls/custom_button_2.tscn")

signal value_changed(param_index: int, value: Variant)
signal remove_param_requested(param_index: int)


func set_data(title: String, type: int, current_value: Variant = null) -> void:
	param_title = title
	%Name.text = title + ": "
	current_type = type
	create_main_control(current_value)


func get_data() -> Dictionary:
	var data = {"name": param_title, "index": get_index(), "type": current_type, "value": null}
	match current_type:
		0: # Number:
			propagate_call("apply")
			data.value = %ParamContainer.get_child(0).get_value()
		1: # String:
			data.value = %ParamContainer.get_child(0).get_text()
		2: # Bool:
			data.value = %ParamContainer.get_child(0).is_pressed()
		3: # Switch:
			data.value = current_switch
		4: # Numeric Variable:
			data.value = current_numeric_variable
		5: # Text Variable:
			data.value = current_text_variable
			
	return data


func create_main_control(current_value: Variant) -> void:
	match current_type:
		0: # Number:
			var scn: SpinBox = preload("res://addons/CustomControls/custom_spin_box.tscn").instantiate()
			scn.allow_greater = true
			scn.allow_lesser = true
			scn.step = 0.01
			if typeof(current_value) == TYPE_INT or typeof(current_value) == TYPE_FLOAT:
				scn.value = current_value
			scn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			%ParamContainer.add_child(scn)
			scn.value_changed.connect(func(value): value_changed.emit(get_index(), value))
		1: # String:
			var scn: LineEdit = preload("res://addons/CustomControls/custom_line_edit.tscn").instantiate()
			if typeof(current_value) == TYPE_STRING:
				scn.text = current_value
			scn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			%ParamContainer.add_child(scn)
			scn.text_changed.connect(func(value): value_changed.emit(get_index(), value))
		2: # Bool:
			var scn = CheckBox.new()
			scn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			if typeof(current_value) == TYPE_BOOL:
				scn.set_pressed(current_value)
			scn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			%ParamContainer.add_child(scn)
			scn.toggled.connect(func(value): value_changed.emit(get_index(), value))
		3: # Switch:
			var scn = CUSTOM_BUTTON.instantiate()
			scn.pressed.connect(_select_switch.bind(scn))
			scn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			%ParamContainer.add_child(scn)
			if current_value: current_switch = current_value
			_set_text(scn, "Switch #%s" % str(current_switch))
		4: # Numeric Variable:
			var scn = CUSTOM_BUTTON.instantiate()
			scn.pressed.connect(_select_numeric_variable.bind(scn))
			scn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			%ParamContainer.add_child(scn)
			if current_value: current_numeric_variable = current_value
			_set_text(scn, "Variable #%s" % str(current_numeric_variable))
		5: # Text Variable:
			var scn = CUSTOM_BUTTON.instantiate()
			scn.pressed.connect(_select_text_variable.bind(scn))
			scn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			%ParamContainer.add_child(scn)
			if current_value: current_text_variable = current_value
			_set_text(scn, "Text Variable #%s" % str(current_text_variable))


func _set_text(button: Button, text: String) -> void:
	button.text = text


func _on_remove_parameter_pressed() -> void:
	remove_param_requested.emit(get_index())


func _on_move_up_pressed() -> void:
	if get_index() > 0:
		get_parent().move_child(self, get_index() - 1)


func _on_move_down_pressed() -> void:
	if get_index() < get_parent().get_child_count() - 1:
		get_parent().move_child(self, get_index() + 1)


func _select_variable_or_switch(data_type: int, target: Button, id_selected: int, callable: Callable) -> void:
	var path = "res://addons/CustomControls/Dialogs/switch_variable_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	dialog.data_type = data_type
	dialog.target = target
	dialog.selected.connect(callable)
	dialog.setup(id_selected)


func _select_switch(button: Button) -> void:
	_select_variable_or_switch(1, button, current_switch, _change_switch)


func _change_switch(value: int, button: Button) -> void:
	current_switch = value
	_set_text(button, "Switch #%s" % str(current_switch))


func _select_numeric_variable(button: Button) -> void:
	_select_variable_or_switch(0, button, current_numeric_variable, _change_numeric_variable)


func _change_numeric_variable(value: int, button: Button) -> void:
	current_numeric_variable = value
	_set_text(button, "Variable #%s" % str(current_numeric_variable))


func _select_text_variable(button: Button) -> void:
	_select_variable_or_switch(2, button, current_text_variable, _change_text_variable)


func _change_text_variable(value: int, button: Button) -> void:
	current_text_variable = value
	_set_text(button, "Text Variable #%s" % str(current_text_variable))
