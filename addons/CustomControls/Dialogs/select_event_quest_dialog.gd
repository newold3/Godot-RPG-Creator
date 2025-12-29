@tool
extends Window


var data: RPGEventPQuest
var pages: Array[RPGEventPage]
var relationship_levels: Array[RPGRelationshipLevel]

signal data_changed(data: RPGEventPQuest)


func _ready() -> void:
	close_requested.connect(queue_free)
	_fill_local_switches()
	_fill_page_list([0])
	_fill_relationship_level_list(0)


func _fill_local_switches() -> void:
	var node = %EnableSelfSwitch
	node.clear()
	
	node.add_item(tr("Do not activate any switch."))
	for key in RPGSYSTEM.system.self_switches.get_switch_names():
		node.add_item("Switch %s" % key)


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
	var self_switch_id = data.self_switch_enabled + 1
	if %EnableSelfSwitch.get_item_count() > self_switch_id:
		%EnableSelfSwitch.select(self_switch_id)
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
	%EndMessage.text = data.dialogue_in_progress.replace("\n", "\\n")
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
		1: text = data.dialogue_in_progress
		2: text = data.dialogue_on_finish
		3: text = data.dialogue_on_failure
	dialog.set_fast_edit_text(text)
	dialog.fast_text_changed.connect(
		func(new_text: String):
			match id:
				0: data.dialogue_on_start = new_text
				1: data.dialogue_in_progress = new_text
				2: data.dialogue_on_finish = new_text
				3: data.dialogue_on_failure = new_text
			_update_texts()
	)


func _on_start_message_pressed() -> void:
	_show_text_message(0)


func _on_end_message_pressed() -> void:
	_show_text_message(1)


func _on_success_message_pressed() -> void:
	_show_text_message(2)


func _on_failure_message_pressed() -> void:
	_show_text_message(3)


func _on_enable_self_switch_item_selected(index: int) -> void:
	data.self_switch_enabled = index - 1


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
