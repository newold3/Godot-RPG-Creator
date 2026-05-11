@tool
extends BasePanelData

#region Variables
var parameters_cache: Array[Dictionary]
var params_need_resize: float
#endregion



#region Lifecycle
## Initializes the panel with default data and locks the first level
func _ready() -> void:
	super()
	default_data_element = RPGProfession.new()
	%ProfessionLevels.set_lock_items([0])



## Retrieves the currently selected Profession data
func get_data() -> RPGProfession:
	current_selected_index = max(1, min(current_selected_index, data.size() - 1))
	return data[current_selected_index]



## Updates all the visual fields based on the selected profession
func _update_data_fields() -> void:
	busy = true

	if current_selected_index != -1:
		var current_data = get_data()
		disable_all(false)
		%IconPicker.set_icon(current_data.icon.path, current_data.icon.region)
		%NameLineEdit.text = current_data.name
		%DescriptionText.text = current_data.description
		_fill_colors()
		_fill_levels()
		_update_common_event_name()
		%CallGlobalEvent.set_pressed_no_signal(current_data.call_global_event_on_level_up)
		_on_call_global_event_toggled(current_data.call_global_event_on_level_up)
		%NoteTextEdit.text = current_data.notes
		%AutoUpgradeLevel.set_pressed(current_data.auto_upgrade_level)
	else:
		disable_all(true)
	
	%PasteLevels.set_disabled(not "profession_levels" in StaticEditorVars.CLIPBOARD)
	
	busy = false



## Fills the color pickers with the profession's color range
func _fill_colors() -> void:
	var current_data = get_data()
	%LevelTooLow.set_pick_color(current_data.name_color_far_below)
	%LevelLow.set_pick_color(current_data.name_color_below)
	%EqualLevel.set_pick_color(current_data.name_color_equal)
	%LevelTooHigh.set_pick_color(current_data.name_color_far_above)
	%LevelHigh.set_pick_color(current_data.name_color_above)
	%Unavailable.set_pick_color(current_data.name_color_requirement_not_met)



## Populates the levels list in the UI
func _fill_levels(selected_index: int = -1) -> void:
	var levels = get_data().levels
	
	var node = %ProfessionLevels
	node.clear()
	
	var i = 1
	for level: RPGExtractionLevelComponent in levels:
		var l = tr("levels") if level.max_levels > 1 else tr("level")
		var level_name = "%s (%s %s)" % [level.name, level.max_levels, l]
		node.add_column([i, level_name, level.experience_to_complete])
		i += 1
	
	await node.columns_setted
	
	if selected_index != -1:
		node.select(selected_index)



## Updates notes when text is modified
func _on_note_text_edit_text_changed() -> void:
	get_data().notes = %NoteTextEdit.text



## Handles visibility changes
func _on_visibility_changed() -> void:
	super()



## Clears the currently assigned icon
func _on_icon_picker_remove_requested() -> void:
	get_data().icon.clear()
	%IconPicker.set_icon("")



## Opens the icon selection dialog
func _on_icon_picker_clicked() -> void:
	var path = "res://addons/CustomControls/Dialogs/select_icon_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	dialog.set_data(get_data().icon)
	
	dialog.icon_changed.connect(update_icon)



## Refreshes the icon UI with the new data
func update_icon() -> void:
	var icon = get_data().icon
	%IconPicker.set_icon(icon.path, icon.region)



## Updates the description when the text is modified
func _on_description_text_edit_text_changed() -> void:
	get_data().description = %DescriptionText.text



## Switches the visibility of the configuration tabs
func _on_config_data_tabs_tab_changed(index: int) -> void:
	var node_path = "%%Tab%s" % (index + 1)
	var node = get_node_or_null(node_path)
	if node:
		for child in node.get_parent().get_children():
			child.visible = false
		node.visible = true



## Updates the base name color
func _on_name_color_color_changed(color: Color) -> void:
	get_data().name_color = color



## Deletes selected levels from the profession
func _on_profession_levels_delete_pressed(indexes: PackedInt32Array) -> void:
	var items_to_removed = []
	var current_data = get_data()
	for index in indexes:
		if index == 0: continue # lock first level
		items_to_removed.append(current_data.levels[index])
		
	while items_to_removed.size() > 0:
		var item = items_to_removed.pop_back()
		for i in current_data.levels.size():
			if current_data.levels[i] == item:
				current_data.levels.remove_at(i)
				break
	
	if current_data.levels.size() > indexes[0]:
		_fill_levels(indexes[0])
	else:
		_fill_levels()



## Opens the level editor dialog
func _on_profession_levels_item_activated(index: int) -> void:
	var path = "res://addons/CustomControls/Dialogs/select_profession_level_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	
	var current_data = get_data()
	
	if current_data.levels.size() > index:
		dialog.set_data(current_data.levels[index])
	else:
		var level = RPGExtractionLevelComponent.new()
		dialog.set_data(level)
	
	dialog.data_changed.connect(_on_level_changed.bind(index))



## Applies the changes from the level editor
func _on_level_changed(level: RPGExtractionLevelComponent, index: int) -> void:
	var current_data = get_data()
	if current_data.levels.size() <= index:
		current_data.levels.append(level)
		index = current_data.levels.size() - 1
	else:
		current_data.levels[index] = level
	
	_fill_levels(index)



## Updates the color for far below level items
func _on_level_too_low_color_changed(color: Color) -> void:
	get_data().name_color_far_below = color



## Updates the color for below level items
func _on_level_low_color_changed(color: Color) -> void:
	get_data().name_color_below = color



## Updates the color for equal level items
func _on_equal_level_color_changed(color: Color) -> void:
	get_data().name_color_equal = color



## Updates the color for far above level items
func _on_level_too_high_color_changed(color: Color) -> void:
	get_data().name_color_far_above = color



## Updates the color for above level items
func _on_level_high_color_changed(color: Color) -> void:
	get_data().name_color_above = color



## Updates the color for unavailable items
func _on_unavailable_color_changed(color: Color) -> void:
	get_data().name_color_requirement_not_met = color



## Resets all colors to their default values
func _on_reset_colors_pressed() -> void:
	get_data().set_default_colors()
	get_data().changed.emit()
	_fill_colors()
	RPGEditorToast.show_message("Profession range color reset")



## Copies the parameters to the clipboard
func _on_copy_weights_pressed() -> void:
	var current_data = get_data()
	var params: Array[RPGCurveParams] = []
	for param: RPGCurveParams in current_data.params:
		params.append(param.clone(true))
	StaticEditorVars.CLIPBOARD.class_parameters = {
		"params": params,
		"experience": current_data.experience.clone(true)
	}
	%PasteParameters.set_disabled(false)



## Copies all levels to the clipboard
func _on_copy_levels_pressed() -> void:
	var current_data = get_data()
	var levels: Array[RPGExtractionLevelComponent] = []
	for level: RPGExtractionLevelComponent in current_data.levels:
		levels.append(level.clone(true))
	StaticEditorVars.CLIPBOARD.profession_levels = levels
	%PasteLevels.set_disabled(false)
	RPGEditorToast.show_message("Profession levels copied into Clipboard")



## Pastes levels from the clipboard
func _on_paste_levels_pressed() -> void:
	var current_data = get_data()
	var levels = StaticEditorVars.CLIPBOARD.get("profession_levels", null)
	if levels:
		var new_levels: Array[RPGExtractionLevelComponent] = []
		for level: RPGExtractionLevelComponent in levels:
			new_levels.append(level.clone(true))
		current_data.levels = levels
		_fill_levels()



## Toggles the global event call on level up
func _on_call_global_event_toggled(toggled_on: bool) -> void:
	get_data().call_global_event_on_level_up = toggled_on
	%SelectCommonEvent.set_disabled(!toggled_on)



## Opens the selection dialog to choose a Common Event
func _on_select_common_event_pressed() -> void:
	var path = "res://addons/CustomControls/Dialogs/select_any_data_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	dialog.database = RPGSYSTEM.database
	dialog.destroy_on_hide = true
	
	dialog.selected.connect(_on_global_event_selected, CONNECT_ONE_SHOT)
	
	var uid = get_data().target_global_event
	var classic_id = RPGSYSTEM.uid_to_id("common_events", uid)
	classic_id = max(1, min(classic_id, RPGSYSTEM.database.common_events.size() - 1))
	
	var title = tr("Global Events")
	dialog.setup(RPGSYSTEM.database.common_events, classic_id, title, null)



## Receives the classic ID from the sub-dialog, converts it to UID, and updates the data
func _on_global_event_selected(id: int, target: Variant) -> void:
	var uid = RPGSYSTEM.id_to_uid("common_events", id)
	get_data().target_global_event = uid
	_update_common_event_name()



## Updates the button text displaying the target common event
func _update_common_event_name() -> void:
	var uid = get_data().target_global_event
	var event_data = RPGSYSTEM.get_data("common_events", uid)
	
	if event_data:
		var classic_id = RPGSYSTEM.uid_to_id("common_events", uid)
		var id_padded = str(classic_id).pad_zeros(str(RPGSYSTEM.database.common_events.size()).length())
		%SelectCommonEvent.text = "%s: %s" % [id_padded, event_data.name]
	else:
		%SelectCommonEvent.text = tr("None")



## Toggles automatic level up
func _on_auto_upgrade_level_toggled(toggled_on: bool) -> void:
	get_data().auto_upgrade_level = toggled_on



## Handles pasting an icon from the clipboard
func _on_icon_picker_paste_requested(icon: String, region: Rect2) -> void:
	var data_icon = get_data().icon
	data_icon.path = icon
	data_icon.region = region
	%IconPicker.set_icon(data_icon.path, data_icon.region)
#endregion
