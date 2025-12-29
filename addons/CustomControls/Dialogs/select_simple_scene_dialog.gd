@tool
extends Window

var current_scene_path: String
var index: int

signal selected(index: int, path: String)


func _ready() -> void:
	close_requested.connect(queue_free)


func setup(p_index: int, p_current_scene_path: String) -> void:
	current_scene_path = p_current_scene_path
	index = p_index
	if not current_scene_path.is_empty():
		%Scene.text = current_scene_path.get_file()
	else:
		%Scene.text = tr("Select Scene")


func _on_scene_pressed() -> void:
	var path = "res://addons/CustomControls/Dialogs/select_file_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	await get_tree().process_frame
	
	dialog.destroy_on_hide = true
	dialog.set_dialog_mode(0)
	dialog.target_callable = _on_scene_selected
	
	var scene_path = current_scene_path if not current_scene_path.is_empty() else "res://"
	dialog.fill_files_by_extension(scene_path, ["tscn"])


func _on_scene_selected(path: String) -> void:
	current_scene_path = path
	%Scene.text = path.get_file()


func _on_ok_button_pressed() -> void:
	if not current_scene_path.is_empty():
		selected.emit(index, current_scene_path)
	queue_free()


func _on_cancel_button_pressed() -> void:
	queue_free()
