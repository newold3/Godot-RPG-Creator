@tool
extends Window


@onready var main_control: EditableRectControl = %MainControl

static var _last_config: Dictionary

signal rect_changed(rect: Rect2, horizontal_flip: bool, vertical_flip: bool, aspect_ratio: bool)


func _ready() -> void:
	close_requested.connect(_exit)
	_fill_preset_list()
	if _last_config:
		_restore_last_config()


func hide_top_container() -> void:
	%TopContainer.visible = false
	size.y = 0


func _fill_preset_list(selected_id: int = 0) -> void:
	var list := %Presets
	list.clear()

	# --- Default presets ---
	var default_items = [
		"Top Left", "Top Center", "Top Right",
		"Mid Left", "Mid Center", "Mid Right",
		"Bottom Left", "Bottom Mid", "Bottom Right"
	]

	for item in default_items:
		list.add_item(tr(item))

	# --- Separator ---
	list.add_separator(tr("Custom Presets"))

	# --- User presets ---
	var documents_path := OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	var presets_folder := documents_path.path_join(
		"GodotRPGCreatorPresets/FitRectInScreenPresets/"
	)

	if DirAccess.dir_exists_absolute(presets_folder):
		var dir := DirAccess.open(presets_folder)
		if dir:
			dir.list_dir_begin()
			var file_name := dir.get_next()

			while file_name != "":
				if not dir.current_is_dir() and file_name.ends_with(".res"):
					var file_path := presets_folder.path_join(file_name)
					var preset_res := FileAccess.open(file_path, FileAccess.READ).get_var(true)
					if preset_res is FitRectInScreenPreset:
						var item_index = list.get_item_count()
						list.add_item(preset_res.name)
						list.set_item_metadata(item_index, {"path": file_path, "preset": preset_res.preset})

				file_name = dir.get_next()

			dir.list_dir_end()

	if selected_id < 0:
		selected_id = list.get_item_count() + selected_id
	
	selected_id = max(0, min(selected_id, list.get_item_count() - 1))
	
	if selected_id == 9:
		selected_id = 8

	if selected_id >= 0 and selected_id < list.get_item_count():
		list.select(selected_id)
	
	%RemovePreset.set_disabled(selected_id < 9)



func set_rect(rect: Rect2) -> void:
	main_control.set_final_rect(rect)


func set_image(tex: Texture) -> void:
	main_control.set_target_image(tex)


func set_aspect_ratio(value: bool) -> void:
	%EnableAspectRatio.set_pressed_no_signal(value)
	_on_enable_aspect_ratio_toggled(value)


func set_flips(horizontal: bool, vertical: bool) -> void:
	%FlipHorizontal.set_pressed_no_signal(horizontal)
	%FlipVertical.set_pressed_no_signal(vertical)
	main_control.flip_horizontal = horizontal
	main_control.flip_vertical = vertical


func _on_ok_button_pressed() -> void:
	var flips = main_control.get_flips()
	var rect = main_control.get_final_rect()
	var aspect_ratio = %EnableAspectRatio.is_pressed()
	rect_changed.emit(rect, flips.horizontal, flips.vertical, aspect_ratio)
	_exit()


func _on_cancel_button_pressed() -> void:
	_exit()


func _exit() -> void:
	_save_last_config()
	queue_free()


func _on_enable_aspect_ratio_toggled(value: bool) -> void:
	main_control.set_keep_aspect_ratio(value)


func _on_flip_horizontal_toggled(value: bool) -> void:
	main_control.flip_horizontal = value


func _on_flip_vertical_toggled(value: bool) -> void:
	main_control.flip_vertical = value


func _on_apply_preset_pressed() -> void:
	propagate_call("apply")
	var rect_size = %MainControl.size
	var index = %Presets.get_selected_id()
	
	var preset = {
		x = 0,
		y = 0,
		width = 0,
		height = 0,
		flip_horizontal = false,
		flip_vertical = false,
		enable_aspect_ratio = false,
		margins = {"left": 0, "right": 0, "top": 0, "bottom": 0},
	}
	
	if index < 9:
		preset.width = %Width.value
		preset.height = %Height.value
		preset.margins.left = %MarginLeft.value
		preset.margins.right = %MarginRight.value
		preset.margins.top = %MarginTop.value
		preset.margins.bottom = %MarginBottom.value
		preset.flip_horizontal = %FlipHorizontal.is_pressed()
		preset.flip_vertical = %FlipVertical.is_pressed()
		preset.enable_aspect_ratio = %EnableAspectRatio.is_pressed()

		match index:
			0: # Top Left
				preset.x = preset.margins.left
				preset.y = preset.margins.top

			1: # Top Center
				preset.x = (rect_size.x - preset.width) / 2
				preset.y = preset.margins.top

			2: # Top Right
				preset.x = rect_size.x - preset.width - preset.margins.right
				preset.y = preset.margins.top

			3: # Middle Left
				preset.x = preset.margins.left
				preset.y = (rect_size.y - preset.height) / 2

			4: # Middle Center
				preset.x = (rect_size.x - preset.width) / 2
				preset.y = (rect_size.y - preset.height) / 2

			5: # Middle Right
				preset.x = rect_size.x - preset.width - preset.margins.right
				preset.y = (rect_size.y - preset.height) / 2

			6: # Bottom Left
				preset.x = preset.margins.left
				preset.y = rect_size.y - preset.height - preset.margins.bottom

			7: # Bottom Center
				preset.x = (rect_size.x - preset.width) / 2
				preset.y = rect_size.y - preset.height - preset.margins.bottom

			8: # Bottom Right
				preset.x = rect_size.x - preset.width - preset.margins.right
				preset.y = rect_size.y - preset.height - preset.margins.bottom
	
	else:
		# get values from dictionary
		var data = %Presets.get_item_metadata(index)
		if data:
			preset = data.preset
	
	main_control.set_preset(preset)


func _save_last_config() -> void:
	var preset = {}
	preset.preset_type = %Presets.get_selected_id()
	preset.width = %Width.value
	preset.height = %Height.value
	preset.margins_left = %MarginLeft.value
	preset.margins_right = %MarginRight.value
	preset.margins_top = %MarginTop.value
	preset.margins_bottom = %MarginBottom.value
	preset.flip_horizontal = %FlipHorizontal.is_pressed()
	preset.flip_vertical = %FlipVertical.is_pressed()
	preset.enable_aspect_ratio = %EnableAspectRatio.is_pressed()
	_last_config = preset


func _restore_last_config() -> void:
	if _last_config:
		%Presets.select(_last_config.preset_type)
		%Width.value = _last_config.width
		%Height.value = _last_config.height
		%MarginLeft.value = _last_config.margins_left
		%MarginRight.value = _last_config.margins_right
		%MarginTop.value = _last_config.margins_top
		%MarginBottom.value = _last_config.margins_bottom
		%FlipHorizontal.set_pressed_no_signal(_last_config.flip_horizontal)
		%FlipVertical.set_pressed_no_signal(_last_config.flip_vertical)
		%EnableAspectRatio.set_pressed_no_signal(_last_config.enable_aspect_ratio)

func _on_add_preset_pressed() -> void:
	var path = "res://addons/CustomControls/Dialogs/select_text_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	dialog.title = TranslationManager.tr("Set Preset Name")
	dialog.text_selected.connect(_save_preset, CONNECT_DEFERRED)


# Saves the current event as a preset with the given name
func _save_preset(preset_name: String) -> void:
	await get_tree().process_frame
	
	# Get the Documents folder path and create presets folder if it doesn't exist
	var documents_path = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	var presets_folder = documents_path.path_join("GodotRPGCreatorPresets/FitRectInScreenPresets/")
	if not DirAccess.dir_exists_absolute(presets_folder):
		DirAccess.make_dir_recursive_absolute(presets_folder)
	var current_preset = main_control.get_preset()
	
	# Create and configure the preset resource
	var preset = FitRectInScreenPreset.new()
	preset.name = preset_name
	preset.preset = current_preset
	# Generate the file name from the preset name
	var preset_file = preset_name.to_snake_case().to_lower().trim_prefix("_")
	var preset_file_path: String = presets_folder + preset_file + ".res"
	
	# Check if preset already exists and ask for confirmation
	if FileAccess.file_exists(preset_file_path):
		var path = "res://addons/CustomControls/Dialogs/confirm_dialog.tscn"
		var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
		dialog.set_text(tr("There is already a preset with that name. Do you want to overwrite it?"))
		dialog.title = TranslationManager.tr("Override Preset")
		await dialog.tree_exiting
		if dialog.result == false: return
	
	# Save the preset file
	FileAccess.open(preset_file_path, FileAccess.WRITE).store_var(preset, true)
	_fill_preset_list(-1)


func _on_remove_preset_pressed() -> void:
	var index = %Presets.get_selected_id()
	if index > 9:
		var data = %Presets.get_item_metadata(index)
		var path = "res://addons/CustomControls/Dialogs/confirm_dialog.tscn"
		var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
		var preset_name = %Presets.get_item_text(index)
		dialog.set_text(tr("Do you want to permanently delete the preset %s?") % preset_name)
		dialog.title = TranslationManager.tr("Remove Preset")
		await dialog.tree_exiting
		if dialog.result == false: return
		DirAccess.remove_absolute(data.path)
		_fill_preset_list(index)
	
	# remove preset


func _on_presets_item_selected(index: int) -> void:
	%RemovePreset.set_disabled(index < 9)
