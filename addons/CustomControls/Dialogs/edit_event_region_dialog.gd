@tool
extends Window

var real_region: EventRegion
var current_region: EventRegion
var current_events: Array

var undo_redo: EditorUndoRedoManager
var current_object: Object
var plugin: RPGMapPlugin

signal region_changed(region: EventRegion)


func _ready() -> void:
	close_requested.connect(queue_free)
	%ApplyButton.set_disabled(true)
	%Name.grab_focus()
	var b = ButtonGroup.new()
	%UseCommonEvent.button_group = b
	%UseCallerEvent.button_group = b
	CustomTooltipManager.replace_all_tooltips_with_custom.call_deferred(self)


func set_region(region: EventRegion) -> void:
	real_region = region
	current_region = region.clone(true)
	title = TranslationManager.tr("Edit Region | %s: %s") % [region.id, region.name]
	%Name.text = region.name
	%PositionX.value = region.rect.position.x
	%PositionY.value = region.rect.position.y
	%SizeX.value = region.rect.size.x
	%SizeY.value = region.rect.size.y
	%ColorButton.set_color(region.color)
	%DamageAmount.value = region.damage_amount
	%DamageFrequency.value = region.damage_frequency
	%ActivationMode.select(clamp(region.activation_mode, 0, 1))
	update_switch()
	%SwitchID.set_disabled(%ActivationMode.get_selected_id() == 0)
	
	%TriggerMode.select(current_region.trigger_mode)
	
	if region.always_passable:
		%CanPass.set_pressed(region.always_passable)
	elif not region.can_entry:
		%CanEntry.set_pressed(!region.can_entry)

	fill_common_events(region.entry_common_event, region.exit_common_event)
	fill_events(region.trigger_caller_event_on_entry, region.trigger_caller_event_on_exit)
	set_triggers(region.triggers)
	
	if current_region.event_mode == current_region.EventMode.COMMON_EVENTS:
		%UseCommonEvent.set_pressed(true)
	else:
		%UseCallerEvent.set_pressed(true)
	
	%ApplyButton.set_disabled(true)


func fill_common_events(selected_index1: int, selected_index2: int) -> void:
	var events: Array[RPGCommonEvent] = RPGSYSTEM.database.common_events
	var list1 = %EntryCommonEvent
	var list2 = %ExitCommonEvent
	
	list1.clear()
	list1.add_item(tr("none"))
	list2.clear()
	list2.add_item(tr("none"))
	
	for ev: RPGCommonEvent in events:
		if not ev:
			continue
			
		var text = "Event #%s: %s" % [ev.id, ev.name]
		list1.add_item(text)
		list2.add_item(text)
	
	if list1.get_item_count() > selected_index1 and selected_index1 >= 0:
		list1.select(selected_index1)
	else:
		list1.select(0)
	
	if list2.get_item_count() > selected_index2 and selected_index2 >= 0:
		list2.select(selected_index2)
	else:
		list2.select(0)


func fill_events(selected_index1: int, selected_index2: int) -> void:
	var list1 = %EntryCallerEvent
	var list2 = %ExitCallerEvent
	
	list1.clear()
	list1.add_item(tr("none"))
	list1.set_item_metadata(-1, -1)
	list2.clear()
	list2.add_item(tr("none"))
	list2.set_item_metadata(-1, -1)
	
	for ev: RPGEvent in current_events:
		var text = "Event #%s: %s" % [ev.id, ev.name]
		list1.add_item(text)
		list1.set_item_metadata(-1, ev._uniq_id)
		list2.add_item(text)
		list2.set_item_metadata(-1, ev._uniq_id)
	
	list1.select(0)
	for i in list1.get_item_count():
		var real_item_index = list1.get_item_metadata(i)
		if real_item_index == selected_index1:
			list1.select(i)
			break
	
	list2.select(0)
	for i in list2.get_item_count():
		var real_item_index = list2.get_item_metadata(i)
		if real_item_index == selected_index2:
			list2.select(i)
			break


func set_triggers(selected_indexes: PackedInt32Array) -> void:
	var list = %TriggerList
	var total_items = list.get_item_count()
	
	for i in list.get_item_count():
		var real_item_index = list.get_item_metadata(i)
		if real_item_index in selected_indexes:
			list.select(i, false)


func set_events(events: Array) -> void:
	var list = %TriggerList
	list.clear()
	
	list.add_item("Player")
	list.set_item_metadata(-1, -1)
	
	for ev: RPGEvent in events:
		var text = "Event #%s: %s" % [ev.id, ev.name]
		list.add_item(text)
		list.set_item_metadata(-1, ev._uniq_id)
	
	current_events = events


func _on_ok_button_pressed() -> void:
	_create_undo_redo_action()
	queue_free()


func _create_undo_redo_action() -> void:
	propagate_call("apply")
	
	if not current_region or not real_region or not undo_redo or not current_object:
		push_error("Faltan datos para crear la acción de undo/redo")
		return
	
	# Crear copia del estado modificado
	var modified_region = current_region.clone(true)
	var original_copy = real_region.clone(true)
	
	# Encontrar el índice de la región
	var region_index: int = -1
	for i in current_object.event_regions.size():
		if current_object.event_regions[i].id == real_region.id:
			region_index = i
			break
	
	if region_index == -1:
		push_error("No se encontró la región en la lista")
		return
	
	undo_redo.create_action("Edit Event Region", UndoRedo.MERGE_DISABLE, current_object)
	
	# DO - aplicar los cambios
	undo_redo.add_do_method(plugin, "_force_mode_switch", plugin.current_edit_mode)
	undo_redo.add_do_method(current_object, "_update_event_region", region_index, modified_region)
	undo_redo.add_do_method(EditorInterface, "mark_scene_as_unsaved")
	
	# UNDO - restaurar la región original
	undo_redo.add_undo_method(plugin, "_force_mode_switch", plugin.current_edit_mode)
	undo_redo.add_undo_method(current_object, "_update_event_region", region_index, original_copy)
	undo_redo.add_undo_method(EditorInterface, "mark_scene_as_unsaved")
	
	undo_redo.commit_action()
	
	region_changed.emit(modified_region)
	%ApplyButton.set_disabled(true)


func _on_cancel_button_pressed() -> void:
	queue_free()


func _on_apply_button_pressed() -> void:
	_create_undo_redo_action()
	%ApplyButton.set_disabled(true)


func _on_name_text_changed(new_text: String) -> void:
	if current_region:
		%ApplyButton.set_disabled(false)
		current_region.name = new_text
		title = TranslationManager.tr("Edit Region | %s: %s") % [current_region.id, current_region.name]


func _on_position_x_value_changed(value: float) -> void:
	if current_region:
		%ApplyButton.set_disabled(false)
		current_region.rect.position.x = value


func _on_position_y_value_changed(value: float) -> void:
	if current_region:
		%ApplyButton.set_disabled(false)
		current_region.rect.position.y = value


func _on_size_x_value_changed(value: float) -> void:
	if current_region:
		%ApplyButton.set_disabled(false)
		current_region.rect.size.x = value


func _on_size_y_value_changed(value: float) -> void:
	if current_region:
		%ApplyButton.set_disabled(false)
		current_region.rect.size.y = value


func _on_color_button_pressed() -> void:
	if not current_region: return
	var path = "res://addons/CustomControls/Dialogs/select_color.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	
	dialog.title = TranslationManager.tr("Select Region Color")
	dialog.color_selected.connect(_on_color_selected)
	dialog.set_color(current_region.color)


func _on_color_selected(color: Color) -> void:
	if not current_region: return
	%ApplyButton.set_disabled(false)
	current_region.color = color
	%ColorButton.set_color(color)


func _on_entry_common_event_item_selected(index: int) -> void:
	if not current_region: return
	%ApplyButton.set_disabled(false)
	current_region.entry_common_event = index


func _on_exit_common_event_item_selected(index: int) -> void:
	if not current_region: return
	%ApplyButton.set_disabled(false)
	current_region.exit_common_event = index


func _on_entry_caller_event_item_selected(index: int) -> void:
	if not current_region: return
	current_region.trigger_caller_event_on_entry = %EntryCallerEvent.get_item_metadata(index)
	%ApplyButton.set_disabled(false)


func _on_exit_caller_event_item_selected(index: int) -> void:
	if not current_region: return
	current_region.trigger_caller_event_on_exit = %ExitCallerEvent.get_item_metadata(index)
	%ApplyButton.set_disabled(false)


func _on_can_entry_toggled(toggled_on: bool) -> void:
	%ApplyButton.set_disabled(false)
	current_region.can_entry = !toggled_on
	
	_update_trigger_controls()


func _update_trigger_controls() -> void:
	var is_common = current_region.event_mode == current_region.EventMode.COMMON_EVENTS
	
	%CommonEventContainer.propagate_call("set_disabled", [!is_common])
	%CallerEventContainer.propagate_call("set_disabled", [is_common])
	%ExitCommonEventContainer.propagate_call("set_disabled", [!is_common])
	%ExitCallerEventContainer.propagate_call("set_disabled", [is_common])
	
	if current_region.can_entry:
		%TriggerModeContainer.visible = false
		%ExitCommonEventContainer.visible = true
		%ExitCallerEventContainer.visible = true
		%EntryCommonEventLabel.text = tr("Entry common event") + ":"
		%EntryCallerEventLabel.text = tr("Entry caller event") + ":"
		%EntryCommonEvent.tooltip_text = "[title]Entry Common Event[/title]\n" + \
			tr("Select the common event that will play when a trigger enters this area.")
		%EntryCallerEvent.tooltip_text = "[title]Entry Caller Event[/title]\n" + \
			tr("Select the event that will be initialized when entering this area.\n\n[Note]: If the current page of the selected event does not have its trigger set to \"Caller\", the event initialization will be ignored.")
		%UseCommonEvent.set_disabled(false)
		%UseCallerEvent.set_disabled(false)
	else:
		%TriggerModeContainer.visible = true
		%ExitCommonEventContainer.visible = false
		%ExitCallerEventContainer.visible = false
		%EntryCommonEventLabel.text = tr("Trigger common event") + ":"
		%EntryCallerEventLabel.text = tr("Trigger caller event") + ":"
		%EntryCommonEvent.tooltip_text = "[title]Trigger Common Event[/title]\n" + \
			tr("Select the common event that will play when trigger this area.")
		%EntryCallerEvent.tooltip_text = "[title]Trigger Caller Event[/title]\n" + \
			tr("Select the event that will be initialized when trigger this area.\n\n[Note]: If the current page of the selected event does not have its trigger set to \"Caller\", the event initialization will be ignored.")
		
		match current_region.trigger_mode:
			0:
				%EntryCommonEvent.set_disabled(true)
				%EntryCallerEvent.set_disabled(true)
				%UseCommonEvent.set_disabled(true)
				%UseCallerEvent.set_disabled(true)
			_:
				%UseCommonEvent.set_disabled(false)
				%UseCallerEvent.set_disabled(false)


func _on_trigger_list_multi_selected(index: int, selected: bool) -> void:
	%ApplyButton.set_disabled(false)
	
	var real_id = %TriggerList.get_item_metadata(index)
	if selected and not real_id in current_region.triggers:
		current_region.triggers.append(real_id)
	elif not selected and real_id in current_region.triggers:
		current_region.triggers.erase(real_id)
	


func _on_use_common_event_toggled(toggled_on: bool) -> void:
	if not current_region: return
	if toggled_on:
		current_region.event_mode = current_region.EventMode.COMMON_EVENTS
		_update_trigger_controls()


func _on_use_caller_event_toggled(toggled_on: bool) -> void:
	if not current_region: return
	if toggled_on:
		current_region.event_mode = current_region.EventMode.CALLER_EVENTS
		_update_trigger_controls()


func _on_player_damage_value_changed(value: float) -> void:
	if not current_region: return
	current_region.damage_amount = value
	%ApplyButton.set_disabled(false)


func _on_damage_amount_value_changed(value: float) -> void:
	if not current_region: return
	current_region.damage_amount = value
	%ApplyButton.set_disabled(false)


func _on_damage_frequency_value_changed(value: float) -> void:
	if not current_region: return
	current_region.damage_frequency = value
	%ApplyButton.set_disabled(false)


func _on_activation_mode_item_selected(index: int) -> void:
	if current_region:
		%ApplyButton.set_disabled(false)
		current_region.activation_mode = index
		%SwitchID.set_disabled(index == 0)


func select_variable_or_switch(data_type: int, target: String, id_selected: int, callable: Callable) -> void:
	var path = "res://addons/CustomControls/Dialogs/switch_variable_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	dialog.data_type = data_type
	dialog.target = target
	dialog.selected.connect(callable)
	dialog.variable_or_switch_name_changed.connect(update_switch)
	dialog.setup(id_selected)


func _on_switch_id_pressed() -> void:
	if current_region:
		var id = max(1, current_region.activation_switch_id)
		select_variable_or_switch(1, "activation_switch_id", id, change_condition_value)


func update_switch() -> void:
	if current_region:
		var id = max(1, current_region.activation_switch_id)
		change_condition_value(id, "activation_switch_id")


func change_condition_value(id: int, target: String) -> void:
	if current_region:
		var text: String = ""
		current_region.set(target, id)
		if RPGSYSTEM.system:
			var real_data = RPGSYSTEM.system.variables if target == "variable_id" else RPGSYSTEM.system.switches
			var data_name = "%s:%s" % [
				str(id).pad_zeros(4),
				real_data.get_item_name(id)
			]
			text = data_name
		else:
			text = str(id).pad_zeros(4) + ":"
		
		%SwitchID.text = text


func _on_can_pass_toggled(toggled_on: bool) -> void:
	%ApplyButton.set_disabled(false)
	if current_region:
		current_region.always_passable = toggled_on


func _on_trigger_mode_item_selected(index: int) -> void:
	current_region.trigger_mode = index
	_update_trigger_controls()
