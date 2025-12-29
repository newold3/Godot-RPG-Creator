@tool
extends CommandBaseDialog

var filter: PackedStringArray
var default_path: String


func set_info(_window_title: String, _image_title: String, _parameter_code: int, _file_filter: PackedStringArray) -> void:
	title = _window_title
	%Title.text = _image_title
	parameter_code = _parameter_code
	filter = _file_filter


func set_data() -> void:
	default_path = parameters[0].parameters.get("path", "")
	%Picker.set_icon(default_path)


func build_command_list() -> Array[RPGEventCommand]:
	var commands: Array[RPGEventCommand] = super()
	commands[-1].parameters.path = default_path
	return commands


func _on_picker_clicked() -> void:
	var path = "res://addons/CustomControls/Dialogs/select_file_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	await get_tree().process_frame
	
	dialog.destroy_on_hide = true
	dialog.set_dialog_mode(0)
	dialog.target_callable = _on_obj_selected
	dialog.set_file_selected(default_path)
	dialog.fill_mix_files(filter)


func _on_obj_selected(path: String) -> void:
	default_path = path
	%Picker.set_icon(default_path)
