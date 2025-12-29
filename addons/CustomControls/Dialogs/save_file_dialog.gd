@tool
extends Window

static var last_path_used: String


var extension = "ext"

signal path_selected(path: String)


func _ready() -> void:
	close_requested.connect(queue_free)


func set_data(_folder: String = "res://", _extension: String = "") -> void:
	%Folder.text = _folder
	if _extension.begins_with("."):
		_extension = _extension.trim_prefix(".")
	extension = _extension
	%ExtensionLabel.text = "." + extension


func fill_data(_folder: String = "", _extension: String = "") -> void:
	var folder: String
	var ext: String
	if not _folder.is_empty():
		folder = _folder
	if not _extension.is_empty():
		ext = _extension
	if not last_path_used.is_empty():
		if folder.is_empty():
			folder = last_path_used.get_base_dir()
		if  ext.is_empty():
			ext = last_path_used.get_extension()
	
	if folder.is_empty():
		folder = "res://"
		
	set_data(folder, ext)


func _on_folder_button_down() -> void:
	var path = "res://addons/CustomControls/Dialogs/select_file_dialog.tscn"
	
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	await get_tree().process_frame
	
	dialog.target_callable = _set_folder
	dialog.set_dialog_mode(1)
	dialog.hide_directory_extra_controls2()
	dialog.destroy_on_hide = true
	
	var default_path = %Folder.text
	dialog.navigate_to_directory(default_path)


func _set_folder(path: String) -> void:
	%Folder.text = path


func _get_full_path() -> String:
	var folder = %Folder.text
	var file = %FileName.text
	var ext = "." + extension if not extension.is_empty() else ""
	if not folder.ends_with("/"):
		folder += "/"
	var path = folder + file + ext
	return path


func _on_ok_button_pressed() -> void:
	last_path_used = _get_full_path()
	path_selected.emit(last_path_used)
	queue_free()


func _on_cancel_button_pressed() -> void:
	last_path_used = _get_full_path()
	queue_free()
