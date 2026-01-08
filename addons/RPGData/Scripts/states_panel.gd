@tool
extends BasePanelData

var traits_need_refresh_timer: float = 0.0


func _ready() -> void:
	super()
	default_data_element = RPGState.new()
	%MessageList.set_lock_items(PackedInt32Array([0, 1, 2, 3]))


func get_data() -> RPGState:
	if not data: return null
	current_selected_index = max(1, min(current_selected_index, data.size() - 1))
	return data[current_selected_index]


func initialize_data(item) -> void:
	var messages = [
		"If an actor is affected by a state...",
		"If an enemy is affected by a state...",
		"If the state persists...",
		"If the state is removed..."
	]
	for message in messages:
		var msg = RPGMessage.new()
		msg.id = message
		item.messages.append(msg)


func _update_data_fields() -> void:
	busy = true
	
	if current_selected_index != -1:
		disable_all(false)
		var current_data = get_data()
		%NameLineEdit.text = current_data.name
		%DescriptionTextEdit.text = current_data.description
		%RestrictionOptions.select(current_data.restriction)
		%MotionOptions.select(current_data.motion_animation)
		%OverlayAnimationOptions.select(current_data.overlay_animation)
		%PrioritySpinBox.value = current_data.priority
		%RemoveAtBattleEndCheckBox.set_pressed(current_data.remove_at_battle_end)
		%RemoveByRestrictionCheckBox.set_pressed(current_data.remove_by_restriction)
		%RemoveByDamageCheckBox.set_pressed(current_data.remove_by_damage)
		%DamageAmount.value = current_data.chance_by_damage
		%DamageAmount.set_disabled(!current_data.remove_by_damage)
		%RemoveByWalkingCheckBox.set_pressed(current_data.remove_by_walking)
		%WalkingAmount.value = current_data.steps_to_remove
		%WalkingAmount.set_disabled(!current_data.remove_by_walking)
		%AutoRemovalOptions.select(current_data.auto_removal_timing)
		%MinTurnsSpinBox.value = current_data.min_turns
		%MinTurnsSpinBox.set_disabled(current_data.auto_removal_timing == 0)
		%MaxTurnsSpinBox.value = current_data.max_turns
		%MaxTurnsSpinBox.set_disabled(current_data.auto_removal_timing == 0)
		%NoteTextEdit.text = current_data.notes
		%IconPicker.set_icon(current_data.icon.path, current_data.icon.region)
		%TraitsPanel.set_data(database, current_data.traits)
		
		%RemoveByTime.set_pressed(current_data.remove_by_time)
		%Time.value = current_data.max_time
		%IsCumulative.set_pressed(current_data.is_cumulative)
		%TickInterval.value = current_data.tick_interval
		fill_messages(-1)
	else:
		disable_all(true)
	
	busy = false


func _on_name_line_edit_text_changed(new_text: String) -> void:
	super(new_text)
	%TraitsPanel.set_need_refresh()


func _on_description_text_edit_text_changed() -> void:
	get_data().description = %DescriptionTextEdit.text


func _on_restriction_options_item_selected(index: int) -> void:
	get_data().restriction = index


func _on_motion_options_item_selected(index: int) -> void:
	get_data().motion_animation = index


func _on_overlay_animation_options_item_selected(index: int) -> void:
	get_data().overlay_animation = index


func _on_priority_spin_box_value_changed(value: float) -> void:
	get_data().priority = value


func _on_remove_at_battle_end_check_box_toggled(toggled_on: bool) -> void:
	get_data().remove_at_battle_end = toggled_on


func _on_remove_by_restriction_check_box_toggled(toggled_on: bool) -> void:
	get_data().remove_by_restriction = toggled_on


func _on_remove_by_damage_check_box_toggled(toggled_on: bool) -> void:
	get_data().remove_by_damage = toggled_on
	%DamageAmount.set_disabled(!toggled_on)


func _on_damage_amount_value_changed(value: float) -> void:
	get_data().chance_by_damage = value


func _on_remove_by_walking_check_box_toggled(toggled_on: bool) -> void:
	get_data().remove_by_walking = toggled_on
	%WalkingAmount.set_disabled(!toggled_on)


func _on_walking_amount_value_changed(value: float) -> void:
	get_data().steps_to_remove = value


func _on_auto_removal_options_item_selected(index: int) -> void:
	get_data().auto_removal_timing = index
	%MinTurnsSpinBox.set_disabled(index == 0)
	%MaxTurnsSpinBox.set_disabled(index == 0)

func _on_min_turns_spin_box_value_changed(value: float) -> void:
	if not get_data(): return
	get_data().min_turns = value


func _on_max_turns_spin_box_value_changed(value: float) -> void:
	if not get_data(): return
	get_data().max_turns = value


func _on_note_text_edit_text_changed() -> void:
	get_data().notes = %NoteTextEdit.text


func _on_icon_picker_remove_requested() -> void:
	get_data().icon.clear()
	%IconPicker.set_icon("")


func _on_icon_picker_clicked() -> void:
	var path = "res://addons/CustomControls/Dialogs/select_icon_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	dialog.set_data(get_data().icon)
	
	dialog.icon_changed.connect(update_icon)


func update_icon() -> void:
	var icon = get_data().icon
	%IconPicker.set_icon(icon.path, icon.region)


func _on_message_list_item_activated(index: int) -> void:
	var mode: int
	if get_data().messages.size() > index:
		mode = 0
	else:
		mode = 1
	
	var path = "res://addons/CustomControls/Dialogs/edit_message_dialog.tscn"
	var parent = get_tree().get_nodes_in_group("main_database")[0]
	var dialog
	var main_panel = parent.get_child(0)
	if main_panel.cache_dialog.has(path) and is_instance_valid(main_panel.cache_dialog[path]):
		dialog = main_panel.cache_dialog[path]
		RPGDialogFunctions.show_dialog(dialog, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	else:
		dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
		main_panel.cache_dialog[path] = dialog
	
	if mode == 0:
		dialog.target_callable = update_message.bind(index)
		dialog.edit_message(get_data().messages[index])
	else:
		dialog.target_callable = update_message.bind(-1)
		dialog.new_message()
	
	dialog.lock_id(index != -1 and index <= 3)


func update_message(message: RPGMessage, target_index) -> void:
	if target_index != -1:
		get_data().messages[target_index] = message
		fill_messages(target_index)
	else:
		get_data().messages.append(message)
		fill_messages(get_data().messages.size() - 1)


func fill_messages(item_selected: int) -> void:
	var node = %MessageList
	node.clear()
	for item in get_data().messages:
		node.add_column([item.id, item.message])
	
	if get_data().messages.size() > 0:
		await node.columns_setted
		if node.items.size() + 1 > item_selected and item_selected != -1:
			node.select(item_selected)
		else:
			node.deselect_all()
	else:
		node.deselect_all()



func _on_message_list_copy_requested(indexes: PackedInt32Array) -> void:
	var copy_items: Array[RPGMessage]
	var obj_data = get_data().messages
	for index in indexes:
		if index > obj_data.size() - 1:
			continue
		copy_items.append(obj_data[index].clone(true))
		
	StaticEditorVars.CLIPBOARD["state_messages"] = copy_items


func _on_message_list_cut_requested(indexes: PackedInt32Array) -> void:
	var copy_items: Array[RPGMessage]
	var remove_items: Array[RPGMessage]
	var obj_data = get_data().messages
	for index in indexes:
		if index > obj_data.size() - 1:
			continue
		copy_items.append(obj_data[index].clone(true))
		if index > 3:
			remove_items.append(obj_data[index])
	for item in remove_items:
		obj_data.erase(item)

	StaticEditorVars.CLIPBOARD["state_messages"] = copy_items
	
	var item_selected = max(-1, indexes[0])
	fill_messages(item_selected)


func _on_message_list_paste_requested(index: int) -> void:
	var obj_data = get_data().messages
	
	if index < 4:
		index = 4
	
	if StaticEditorVars.CLIPBOARD.has("state_messages"):
		for i in StaticEditorVars.CLIPBOARD["state_messages"].size():
			var real_index = index + i + 1
			var current_trait = StaticEditorVars.CLIPBOARD["state_messages"][i].clone()
			if real_index < obj_data.size():
				obj_data.insert(real_index, current_trait)
			else:
				obj_data.append(current_trait)
	
	fill_messages(index + 1)
	
	var list = %MessageList
	await list.columns_setted
	await get_tree().process_frame
	await get_tree().process_frame
	for i in range(index + 1, index + StaticEditorVars.CLIPBOARD["state_messages"].size() + 1):
		if i == obj_data.size():
			i = index
		list.select(i, false)


func _on_message_list_delete_pressed(indexes: PackedInt32Array) -> void:
	var remove_items: Array[RPGMessage] = []
	var obj_data = get_data().messages
	
	for index in indexes:
		if index > 3 and obj_data.size() > index:
			remove_items.append(obj_data[index])
	for obj in remove_items:
		obj_data.erase(obj)
		
	fill_messages(indexes[0])


func _on_visibility_changed() -> void:
	super()
	if visible:
		busy = true
		if current_selected_index != -1:
			%TraitsPanel.set_data(database, get_data().traits)
		else:
			%TraitsPanel.clear()
		busy = false


func _on_is_cumulative_toggled(toggled_on: bool) -> void:
	get_data().is_cumulative = toggled_on


func _on_remove_by_time_toggled(toggled_on: bool) -> void:
	get_data().remove_by_time = toggled_on
	%Time.set_disabled(!toggled_on)


func _on_time_value_changed(value: float) -> void:
	get_data().max_time = value


func _on_tick_interval_value_changed(value: float) -> void:
	get_data().tick_interval = value


func _on_config_data_tabs_tab_changed(index: int) -> void:
	var node_path = "%%Tab%s" % (index + 1)
	var node = get_node_or_null(node_path)
	if node:
		for child in node.get_parent().get_children():
			child.visible = false
		node.visible = true


func _on_icon_picker_paste_requested(icon: String, region: Rect2) -> void:
	var data_icon = get_data().icon
	data_icon.path = icon
	data_icon.region = region
	%IconPicker.set_icon(data_icon.path, data_icon.region)
