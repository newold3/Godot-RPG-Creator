@tool
extends "res://addons/tile_bit_tools/controls/tbt_plugin_control/popups/template_dialog.gd"





func _setup_connections() -> void:
	var _err := tbt.save_template_requested.connect(_on_save_template_requested)


func _setup_save_dialog() -> void:
	template_bit_data = TBTPlugin.TemplateBitData.new()

	var result := template_bit_data.load_editor_bit_data(tbt.context.bit_data)
	if result != OK:
		tbt.output.user("Cannot create template from editor data", result)
		# TODO: message_box_requested not implemented
#		tbt.message_box_requested.emit("Cannot create template from editor data (ERR %s)" % result)
		hide()

	show_dialog()





# overriden
func _setup_initial_values() -> void:
	name_edit.text = DEFAULT_TEMPLATE_NAME
	description_edit.text = DEFAULT_TEMPLATE_DESCRIPTION
	tags_edit.text = DEFAULT_TEMPLATE_TAGS



# overriden
func _get_save_path(_valid_only := true) -> String:
	var dir := _get_save_dir()
	var file_name := _get_file_name(dir)
	var path : String = dir.get_current_dir() + "/" + file_name

	if !path.is_absolute_path():
		tbt.output.error("Unable to get valid save path: %s" % path)
		return ""

	return path


func _get_save_dir() -> DirAccess:
	var folder_id := folder_option_button.get_selected_id()
	var path : String = tbt.template_manager.template_folder_paths[folder_id].path
	return DirAccess.open(path)


func _get_file_name(dir : DirAccess) -> String:
	var template_name := name_edit.text
	if template_name == "":
		template_name = DEFAULT_TEMPLATE_NAME

	var s := template_name.to_lower().replace(" ", "_").validate_filename()
	var extension := ".tres"
	var file_name := s + extension

	var suffix := 0

	while dir.file_exists(file_name):
		suffix += 1
		file_name = s + str(suffix).pad_zeros(2) + extension

	return file_name



func _on_save_template_requested() -> void:
	_setup_save_dialog()
