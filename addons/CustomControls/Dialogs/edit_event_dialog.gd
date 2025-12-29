@tool
class_name EditEventEditor
extends Window

var resource_previewer: EditorResourcePreview
var original_event: RPGEvent
var current_event: RPGEvent
var events: RPGEvents
var current_page: RPGEventPage
var rpg_system

var undo_redo: EditorUndoRedoManager
var current_object: Object
var plugin: RPGMapPlugin

var busy: bool


signal changed()


func _ready() -> void:
	close_requested.connect(confirm_changes)
	%EditEventPage.current_event = current_event
	if current_event:
		%QuestManagerPanel.set_data(current_event.quests)
		%RelationshipManagerPanel.set_data(current_event.relationship)
	%QuestManagerPanel.visible = false
	%RelationshipManagerPanel.visible = false
	%EditEventPage.visible = true


func setup() -> void:
	var node = Engine.get_main_loop().root.get_node_or_null("RPGSYSTEM")
	if node:
		rpg_system = node
	var edit_event_page = %EditEventPage
	if rpg_system:
		edit_event_page.system = rpg_system.system
	set_event_name()
	#await get_tree().process_frame
	var tab_selected = %EventPageContainer.selected_tab
	if current_event:
		tab_selected = current_event._editor_last_page_used
		tab_selected = clamp(tab_selected, 0, current_event.pages.size() - 1)
		original_event = current_event.clone()
		%QuestManagerPanel.pages = current_event.pages
		%QuestManagerPanel.relationship_levels = current_event.relationship.levels
		%QuestManagerPanel.set_data(current_event.quests)
		%RelationshipManagerPanel.set_data(current_event.relationship)
	fill_pages()
	
	%EventPageContainer.select(tab_selected, true)
	#setup_current_page(tab_selected)
	%ApplyButton.set_disabled(true)


func set_event(event: RPGEvent) -> void:
	var new_event = event.clone(true)
	current_event = new_event
	%QuestManagerPanel.quests = current_event.quests
	%RelationshipManagerPanel.relationship = current_event.relationship


func set_events(_events: RPGEvents) -> void:
	events = _events


func set_event_name() -> void:
	if current_event:
		title = TranslationManager.tr("Edit event - ID:") + str(current_event.id).pad_zeros(4)
		%EventName.text = current_event.name
		%EventName.editable = true
	else:
		title = TranslationManager.tr("Edit Event")
		%EventName.editable = false


func fill_pages(selected_tab_index: int = 0) -> void:
	busy = true
	
	if !current_event:
		var nodes = [%NewPageButton, %CopyPageButton, %PastePageButton, %RemovePageButton, %CleanPageButton]
		for node in nodes:
			node.set_disabled(true)
		return
	
	%EventPageContainer.update_tabs(current_event.pages.size(), selected_tab_index, true)
	
	%NewPageButton.set_disabled(false)
	%CopyPageButton.set_disabled(false)
	%PastePageButton.set_disabled(not "event_page" in StaticEditorVars.CLIPBOARD)
	%RemovePageButton.set_disabled(%EventPageContainer.selected_tab == 0)
	%CleanPageButton.set_disabled(false)
	
	busy = false


func create_event_page(index) -> void:
	var edit_event_page = %EditEventPage
	if rpg_system:
		edit_event_page.system = rpg_system.system
	edit_event_page.name = "Page %s" % (index+1)


func setup_current_page(index: int) -> void:
	if index == -1:
		return
		
	if current_event and events:
		var page: RPGEventPage = current_event.pages[index]
		var edit_event_page = %EditEventPage
		edit_event_page.fill_page(page)
		current_page = page


func _on_event_page_container_tab_changed(tab: int) -> void:
	setup_current_page(tab)
	%RemovePageButton.set_disabled(tab == 0)
	original_event._editor_last_page_used = tab
	current_event._editor_last_page_used = tab


func _on_ok_button_pressed() -> void:
	_create_undo_redo_action()
	changed.emit()
	queue_free()


func _create_undo_redo_action() -> void:
	propagate_call("apply")
	
	if not current_event or not events or not original_event or not undo_redo or not current_object:
		push_error("Faltan datos para crear la acción de undo/redo")
		return
	
	# Crear copias de los eventos
	var modified_event = current_event.clone(true)
	var original_copy = original_event.clone(true)
	
	undo_redo.create_action("Edit Event", UndoRedo.MERGE_DISABLE, current_object)
	
	# DO - aplicar los cambios nuevos
	undo_redo.add_do_method(plugin, "_force_mode_switch", plugin.current_edit_mode)
	undo_redo.add_do_method(events, "replace_event", modified_event)
	undo_redo.add_do_method(EditorInterface, "mark_scene_as_unsaved")
	
	# UNDO - restaurar el evento original
	undo_redo.add_undo_method(plugin, "_force_mode_switch", plugin.current_edit_mode)
	undo_redo.add_undo_method(events, "replace_event", original_copy)
	undo_redo.add_undo_method(EditorInterface, "mark_scene_as_unsaved")
	
	undo_redo.commit_action()


func _on_cancel_button_pressed() -> void:
	confirm_changes()


func confirm_changes() -> void:
	if current_event and not current_event.is_equal_to(original_event):
		var path = "res://addons/CustomControls/Dialogs/confirm_dialog.tscn"
		var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
		dialog.set_text("Discard the changes and exit?")
		dialog.title = TranslationManager.tr("Override File")
		dialog.OK.connect(queue_free)
	else:
		queue_free()


func _on_apply_button_pressed() -> void:
	_create_undo_redo_action()
	%ApplyButton.set_disabled(true)


func _on_event_name_text_changed(new_text: String) -> void:
	current_event.name = new_text
	%ApplyButton.set_disabled(false)


func _on_new_page_button_pressed() -> void:
	if busy:
		return
		
	var index = %EventPageContainer.selected_tab + 1
	current_event.add_new_page(index)
	fill_pages(index)
	
	%ApplyButton.set_disabled(false)


func _on_copy_page_button_pressed() -> void:
	if busy:
		return
		
	StaticEditorVars.CLIPBOARD["event_page"] = current_page.clone(true)
	%PastePageButton.set_disabled(false)


func _on_paste_page_button_pressed() -> void:
	if busy:
		return
		
	if StaticEditorVars.CLIPBOARD.has("event_page"):
		var index = %EventPageContainer.selected_tab + 1
		current_event.insert_page(StaticEditorVars.CLIPBOARD["event_page"].clone(true), index)
		fill_pages(index)
	
	%ApplyButton.set_disabled(false)


func _on_remove_page_button_pressed() -> void:
	if busy:
		return
		
	var index = %EventPageContainer.selected_tab
	if index > 0:
		current_event.remove_page(index)
		index = max(0, min(index, current_event.pages.size() - 1))
		fill_pages(index)
	
	%ApplyButton.set_disabled(false)


func _on_clean_page_button_pressed() -> void:
	if busy:
		return
	
	var index = %EventPageContainer.selected_tab
	var page: RPGEventPage = RPGEventPage.new()
	current_event.replace_page(index, page)
	setup_current_page(index)

	%ApplyButton.set_disabled(false)


func _on_edit_event_page_changed() -> void:
	%ApplyButton.set_disabled(false)


func _on_quest_manager_button_toggled(toggled_on: bool) -> void:
	if %RelationshipManagerButton.is_pressed():
		%RelationshipManagerButton.set_pressed(false)
	%EditEventPage.visible = !toggled_on
	%EventPageContainer.visible = !toggled_on
	%NewPageButton.visible = !toggled_on
	%CopyPageButton.visible = !toggled_on
	%PastePageButton.visible = !toggled_on
	%RemovePageButton.visible = !toggled_on
	%RelationshipManagerButton.visible = !toggled_on
	%CleanPageButton.visible = !toggled_on
	%QuestManagerPanel.visible = toggled_on
	%BackToPagesButton.visible = toggled_on


func _on_back_to_pages_button_pressed() -> void:
	if %QuestManagerPanel.visible:
		%QuestManagerButton.set_pressed(false)
	elif %RelationshipManagerPanel.visible:
		%RelationshipManagerButton.set_pressed(false)


func _on_relationship_manager_button_toggled(toggled_on: bool) -> void:
	if %QuestManagerButton.is_pressed():
		%QuestManagerButton.set_pressed(false)
	%EditEventPage.visible = !toggled_on
	%EventPageContainer.visible = !toggled_on
	%NewPageButton.visible = !toggled_on
	%CopyPageButton.visible = !toggled_on
	%PastePageButton.visible = !toggled_on
	%RemovePageButton.visible = !toggled_on
	%QuestManagerButton.visible = !toggled_on
	%CleanPageButton.visible = !toggled_on
	%RelationshipManagerPanel.visible = toggled_on
	%BackToPagesButton.visible = toggled_on


func _on_save_as_preset_button_pressed() -> void:
	var path = "res://addons/CustomControls/Dialogs/select_text_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	dialog.title = TranslationManager.tr("Set Preset Name")
	dialog.text_selected.connect(_save_preset, CONNECT_DEFERRED)


# Saves the current event as a preset with the given name
func _save_preset(preset_name: String) -> void:
	await get_tree().process_frame
	
	# Get the Documents folder path and create presets folder if it doesn't exist
	var documents_path = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	var presets_folder = documents_path.path_join("GodotRPGCreatorPresets/EventPresets/")
	if not DirAccess.dir_exists_absolute(presets_folder):
		DirAccess.make_dir_recursive_absolute(presets_folder)
	
	# Create and configure the preset resource
	var preset = EventPreset.new()
	preset.name = preset_name
	preset.preset = current_event
	
	# Generate the file name from the preset name
	var event_file = preset_name.to_snake_case().to_lower().trim_prefix("_")
	var preset_file_path: String = presets_folder + event_file + ".res"
	
	# Check if preset already exists and ask for confirmation
	if FileAccess.file_exists(preset_file_path):
		var path = "res://addons/CustomControls/Dialogs/confirm_dialog.tscn"
		var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
		dialog.set_text(tr("There is already a preset with that name. Do you want to overwrite it?"))
		dialog.title = TranslationManager.tr("Override File")
		await dialog.tree_exiting
		if dialog.result == false: return
	
	# Save the preset file
	FileAccess.open(preset_file_path, FileAccess.WRITE).store_var(preset, true)
