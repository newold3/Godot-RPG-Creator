@tool
class_name UserParametersControls
extends PanelContainer

var data: Array
var default_data_element: Variant
var current_selected_index: int = -1


func get_data() -> Variant:
	if not data: return null
	current_selected_index = max(1, min(current_selected_index, data.size() - 1))
	if data.size() > current_selected_index:
		return data[current_selected_index]
	else:
		return default_data_element


func fill_user_parameters(selected_index: int = 0) -> void:
	var current_data = get_data()
	if not current_data: return
	
	var node = %UserParameters
	node.clear()
	
	var user_parameters = current_data.user_parameters
	var user_parameter_data = RPGSYSTEM.database.types.user_parameters
	if user_parameters.size() != user_parameter_data.size():
		user_parameters.resize(user_parameter_data.size())

	for i in user_parameter_data.size():
		var column = []
		column.append(user_parameter_data[i].name)
		column.append("%.2f" % user_parameters[i])
		node.add_column(column)
	
	await node.columns_setted
	if selected_index >= 0 and node.get_item_count() > selected_index:
		node.select(selected_index)
	
	_check_for_disabled_controls()



func _check_for_disabled_controls() -> void:
	var user_parameter_disabled = RPGSYSTEM.database.types.user_parameters.size() == 0
	%UserParameters.set_disabled(user_parameter_disabled)
	%CopyUserParameters.set_disabled(user_parameter_disabled)
	%PasteUserParameters.set_disabled(user_parameter_disabled or !StaticEditorVars.CLIPBOARD.get("items_user_parameters", false))


## Copies user parameters list to clipboard
func _on_copy_user_parameters_pressed() -> void:
	StaticEditorVars.CLIPBOARD.items_user_parameters = get_data().user_parameters.duplicate()
	%PasteUserParameters.set_disabled(false)
	RPGEditorToast.show_message("User parameter list copied to Clipboard")



## Pastes user parameters list from clipboard
func _on_paste_user_parameters_pressed() -> void:
	if "items_user_parameters" in StaticEditorVars.CLIPBOARD:
		for i in get_data().user_parameters.size():
			if StaticEditorVars.CLIPBOARD.items_user_parameters.size() > i:
				get_data().user_parameters[i] = StaticEditorVars.CLIPBOARD.items_user_parameters[i]
		fill_user_parameters()



## Resets user parameters to global defaults
func _on_reset_user_parameters_pressed() -> void:
	var user_parameters: PackedFloat32Array = get_data().user_parameters
	var database = RPGSYSTEM.database
	if user_parameters.size() < database.types.user_parameters.size():
		user_parameters.resize(database.types.user_parameters.size())
	for i in database.types.user_parameters.size():
		if user_parameters.size() > i:
			user_parameters[i] = database.types.user_parameters[i].default_value
	fill_user_parameters()
	RPGEditorToast.show_message("User parameter list reset to default values")


func clear() -> void:
	var node = %UserParameters
	node.clear()
	%CopyUserParameters.set_disabled(true)
	%PasteUserParameters.set_disabled(true)
	%ResetUserParameters.set_disabled(true)
	%UserParameters.set_disabled(true)
	

## Opens dialog to set custom user parameter value
func _on_user_parameters_item_activated(index: int) -> void:
	var database = RPGSYSTEM.database
	if database.types.user_parameters.size() > index and index >= 0:
		var path = "res://addons/CustomControls/Dialogs/select_number_value_dialog.tscn"
		var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
		var user_param_name = database.types.user_parameters[index].name
		var user_param_value = get_data().user_parameters[index]
		
		dialog.set_min_max_values(0, 0, 0.01)
		dialog.set_title_and_contents(tr("Set Parameter value"), user_param_name)
		dialog.set_value(user_param_value)
		dialog.selected_value.connect(
			func(value: float):
				get_data().user_parameters[index] = value
				fill_user_parameters(index)
		)


func _on_random_user_parameters_pressed() -> void:
	var user_parameters: PackedFloat32Array = get_data().user_parameters
	
	if user_parameters.size() > 0:
		
		for i in user_parameters.size():
			if not %ToggleDecimal.is_pressed():
				user_parameters[i] = randi_range(
					%MinValue.value,
					%MaxValue.value
				)
			else:
				user_parameters[i] = randf_range(
					%MinValue.value,
					%MaxValue.value
				)
		
		fill_user_parameters(0)


func _on_min_value_value_changed(value: float) -> void:
	if %MaxValue.value < value:
		%MaxValue.set_value_no_signal(value)


func _on_max_value_value_changed(value: float) -> void:
	if %MinValue.value > value:
		%MinValue.set_value_no_signal(value)


func _on_check_box_toggled(toggled_on: bool) -> void:
	if toggled_on:
		%MinValue.step = 0.001
		%MaxValue.step = 0.001
		%MinValue.rounded = false
		%MaxValue.rounded = false
	else:
		%MinValue.step = 1
		%MaxValue.step = 1
		%MinValue.rounded = true
		%MaxValue.rounded = true
