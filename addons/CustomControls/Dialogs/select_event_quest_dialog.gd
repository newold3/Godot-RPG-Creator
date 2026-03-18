@tool
extends Window


var data: RPGEventPQuest
var pages: Array[RPGEventPage]
var relationship_levels: Array[RPGRelationshipLevel]

signal data_changed(data: RPGEventPQuest)


func _ready() -> void:
	close_requested.connect(queue_free)
	_fill_page_list([0])
	_fill_relationship_level_list(0)


func _fill_page_list(indexes: Array = []) -> void:
	var node = %PageList
	node.clear()
	
	if pages:
		for i in pages.size():
			node.add_item("Page %s" % (i+1))
	
	if not indexes.is_empty():
		for id in indexes:
			node.set_item_selected(id, true)
	elif pages.size() > 0:
		node.select(0)
		


func _fill_relationship_level_list(index: int) -> void:
	var node = %RelationshipLevel
	node.clear()
	
	node.add_item(tr("No level needed"))
	if relationship_levels:
		for i in relationship_levels.size():
			node.add_item("Level %s" % (i+1))
	
	if index >= 0 and relationship_levels.size() > index - 1:
		node.select(index)


func set_data(p_data: RPGEventPQuest) -> void:
	data = p_data.clone(true)
	_update_texts()
	_on_quest_id_selected(data.id, null)
	%CustomTimer.value = data.custom_timer
	%UseCustomTimer.set_pressed(data.use_custom_timer)
	_fill_page_list(data.required_pages)
	_fill_relationship_level_list(data.relationship_requeriment_level)
	%UseConfirm.set_pressed(data.use_confirm_message)
	%ConfirmOK.text = data.confirm_ok_option
	%ConfirmCancel.text = data.confirm_cancel_option


func _update_texts() -> void:
	%StartMessage.text = data.dialogue_on_start.replace("\n", "\\n")
	%SuccessMessage.text = data.dialogue_on_finish.replace("\n", "\\n")
	%FailureMessage.text = data.dialogue_on_failure.replace("\n", "\\n")


func _on_cancel_button_pressed() -> void:
	queue_free()


func _on_ok_button_pressed() -> void:
	if %UseCustomTimer.is_pressed():
		%CustomTimer.apply()
	data_changed.emit(data)
	queue_free()


func _show_text_message(id: int) -> void:
	var path = "res://addons/CustomControls/Dialogs/CommandEvents/advanced_text_editor_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	var text: String
	match id:
		0: text = data.dialogue_on_start
		1: text = data.dialogue_on_finish
		2: text = data.dialogue_on_failure
	dialog.set_fast_edit_text(text)
	dialog.fast_text_changed.connect(
		func(new_text: String):
			match id:
				0: data.dialogue_on_start = new_text
				1: data.dialogue_on_finish = new_text
				2: data.dialogue_on_failure = new_text
			_update_texts()
	)


func _on_start_message_pressed() -> void:
	_show_text_message(0)


func _on_success_message_pressed() -> void:
	_show_text_message(1)


func _on_failure_message_pressed() -> void:
	_show_text_message(2)


func _on_quest_id_pressed() -> void:
	var path = "res://addons/CustomControls/Dialogs/select_any_data_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	dialog.database = RPGSYSTEM.database
	
	dialog.destroy_on_hide = true
	dialog.selected.connect(_on_quest_id_selected)
	
	dialog.setup(RPGSYSTEM.database.quests, data.id, "Quest", null)


func _on_quest_id_selected(id: int, target: Variant) -> void:
	data.id = id
	if id > 0 and RPGSYSTEM.database.quests.size() > id:
		%QuestID.text = "%s: %s" % [id, RPGSYSTEM.database.quests[id].name]
	else:
		%QuestID.text = "⚠ Invalid Data"
	


func _on_use_custom_timer_toggled(toggled_on: bool) -> void:
	%CustomTimer.set_disabled(!toggled_on)


func _on_page_list_multi_selection_changed(selected_ids: PackedInt32Array) -> void:
	data.required_pages = selected_ids


func _on_relationship_level_item_selected(index: int) -> void:
	data.relationship_requeriment_level = index


func _on_use_confirm_toggled(toggled_on: bool) -> void:
	data.use_confirm_message = toggled_on
	%ConfirmOK.set_disabled(!toggled_on)
	%ConfirmCancel.set_disabled(!toggled_on)


func _on_confirm_ok_text_changed(new_text: String) -> void:
	data.confirm_ok_option = new_text


func _on_confirm_cancel_text_changed(new_text: String) -> void:
	data.confirm_cancel_option = new_text


func _select_event(data_id: String, event: RPGMapEventID, is_single: bool) -> void:
	var path = "res://addons/CustomControls/Dialogs/select_event_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	
	if is_single:
		var w = get_tree().get_first_node_in_group("event_editor")
		print([w.current_object, w.current_event])
		dialog.setup_single_event_mode(w.current_object.internal_id, w.current_event._uniq_id, true, true)
	else:
		dialog.setup_quest_mode(true, true)
	
	dialog.set_selection(event.map_id, event.event_id, event.event_page_id)

	#
	dialog.event_selected.connect(
		func(map_id: int, event_id: int, page_id: int):
			var ev = RPGMapEventID.new(map_id, event_id, page_id)
			data.set(data_id, ev)
			set_control_name(data_id, ev)
	)


func set_control_name(data_id: String, event_id: RPGMapEventID) -> void:
	var target_node = %StartPage if data_id == "start_page" else %TargetEventPage
	
	var event_name: String = ""
	var map_name: String = ""
	var page_name: String = ""
	var ev = event_id
	if ev and ev.map_id != -1 and ev.event_id != -1:
		map_name = RPGSYSTEM.map_infos.get_map_name_from_id(ev.map_id)
		map_name = (map_name if not map_name.is_empty() else str(ev.map_id))
		var event: Dictionary = RPGSYSTEM.map_infos.get_event(ev.map_id, ev.event_id)
		event_name = "%s: %s" % [event.get("id", 0), event.get("name", "")]
		page_name = RPGSYSTEM.map_infos.get_event_page_name(ev.map_id, ev.event_id, ev.event_page_id)
	
	if not event_name.is_empty():
		target_node.text = "Map < %s > event %s - %s" % [map_name, event_name, page_name]
	else:
		target_node.text = tr("Select Event")


func _on_start_page_pressed() -> void:
	_select_event("start_page", data.start_page, true)


func _on_target_event_page_pressed() -> void:
	_select_event("target_page", data.target_page, false)


func _on_start_page_middle_click_pressed() -> void:
	data.start_page.clear()
	set_control_name("start_page", data.start_page)


func _on_target_event_page_middle_click_pressed() -> void:
	data.target_page.clear()
	set_control_name("target_page", data.target_page)
