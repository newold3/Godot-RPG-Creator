@tool
extends "res://addons/tile_bit_tools/controls/tbt_plugin_control/popups/template_dialog.gd"


var save_path : String

@onready var folder_label: Label = %FolderLabel



func _setup_connections() -> void:
	var _err := tbt.edit_template_requested.connect(_on_edit_template_requested)



func _setup_edit_dialog(p_template_bit_data : TBTPlugin.TemplateBitData) -> void:
	template_bit_data = p_template_bit_data
	save_path = template_bit_data.resource_path

	show_dialog()



# overriden
func _setup_initial_values() -> void:
	name_edit.text = template_bit_data.template_name
	description_edit.text = template_bit_data.template_description
	tags_edit.text = _custom_tags_to_string()
	_update_folder_label()


# unable to get selecting option button item to work...
# using label instead
func _update_folder_label() -> void:
	var path = save_path.rsplit("/", true, 1)[0] + "/"
	for i in range(tbt.template_manager.template_folder_paths.size()):
		var folder_path : Dictionary = tbt.template_manager.template_folder_paths[i]
		if path == folder_path.path:
			folder_label.text = folder_path.name
			folder_label.tooltip_text = folder_path.tooltip + "\n" + folder_path.path
			return
	folder_label.text = path # if cannot find saved path, list path itself
	folder_label.tooltip_text = ""



func _custom_tags_to_string() -> String:
	return ", ".join(template_bit_data._custom_tags)


# overriden
func _get_save_path(_valid_only := true) -> String:
	return save_path




func _on_edit_template_requested(p_template_bit_data : TBTPlugin.TemplateBitData) -> void:
	if p_template_bit_data != null:
		_setup_edit_dialog(p_template_bit_data)
	else:
		tbt.output.warning("Edit requested without bit data")
