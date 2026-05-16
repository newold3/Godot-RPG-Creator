@tool
extends Window


#region VARIABLES
var current_data: MapGeneratorEvents
var current_event_selected: MapGeneratorEvent
var busy: bool = false
#endregion


func _ready() -> void:
	close_requested.connect(_on_exit)
	%RightColumn.propagate_call("set_disabled", [true])
	if not current_data:
		set_data(MapGeneratorEvents.new())


func set_data(data: MapGeneratorEvents) -> void:
	current_data = data
	_fill_list()


func _fill_parameters(data_selected: MapGeneratorEvent) -> void:
	if data_selected:
		%RemoveFromStack.set_pressed_no_signal(data_selected.locked)
		%ProbabilityOfAppearance.set_value_no_signal(data_selected.probability)
		%Quantity.set_value_no_signal(data_selected.max_quantity)
		%PlacementMode.select(data_selected.placement)
		%RightColumn.propagate_call("set_disabled", [false])
		%Width.set_value_no_signal(data_selected.width)
		%Height.set_value_no_signal(data_selected.height)
		%FootprintHeight.set_value_no_signal(data_selected.footprint_height)
		%MarginLeft.set_value_no_signal(data_selected.wall_margins.x)
		%MarginRight.set_value_no_signal(data_selected.wall_margins.z)
		%MarginTop.set_value_no_signal(data_selected.wall_margins.y)
		%MarginBottom.set_value_no_signal(data_selected.wall_margins.w)
	else:
		%RightColumn.propagate_call("set_disabled", [true])


func _fill_list() -> void:
	var node = %EventList
	node.clear()
	
	if not current_data: 
		_fill_parameters(null)
		return
	
	var selected_index = -1
	
	for i in current_data.events.size():
		var obj: MapGeneratorEvent = current_data.events[i]
		node.add_column(["%s: %s" % [obj.event.id, obj.event.name]])
		
		if current_event_selected and obj == current_event_selected:
			selected_index = i
		
		if obj.locked:
			node.add_row_color(i, Color(0.8, 0.2, 0.2, 0.3))
		else:
			node.restore_row_color(i)
	
	await node.columns_setted
	
	if selected_index == -1 and current_data.events.size() > 0:
		selected_index = 0
	
	if selected_index != -1:
		current_event_selected = current_data.events[selected_index]
		node.select(selected_index)
		_fill_parameters(current_event_selected)
	else:
		current_event_selected = null
		_fill_parameters(null)


func _on_remove_from_stack_toggled(toggled_on: bool) -> void:
	if current_event_selected:
		current_event_selected.locked = toggled_on
		var idxs: PackedInt32Array = %EventList.get_selected_ids()
		if not idxs.is_empty():
			var idx = idxs[0]
			if current_event_selected.locked:
				%EventList.add_row_color(idx, Color(0.8, 0.2, 0.2, 0.3))
			else:
				%EventList.restore_row_color(idx)


func _on_probability_of_appearance_value_changed(value: float) -> void:
	if current_event_selected: current_event_selected.probability = value


func _on_quantity_value_changed(value: float) -> void:
	if current_event_selected: current_event_selected.max_quantity = value


func _on_placement_mode_item_selected(index: int) -> void:
	if current_event_selected: current_event_selected.placement = index


func _on_event_list_item_activated(index: int) -> void:
	if not current_data: return
	
	var event: RPGEvent
	if current_data.events.size() > index:
		event = current_data.events[index].event
	else:
		event = RPGEvent.new()
		if event.pages.is_empty():
			event.pages.append(RPGEventPage.new())
	
	var path = "res://addons/CustomControls/Dialogs/edit_event_dialog.tscn"
	var dialog: Window = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	
	dialog.resource_previewer = EditorInterface.get_resource_previewer()
	
	dialog.event_updated.connect(_on_event_updated.bind(index))
	dialog.set_event(event)
	dialog.setup()

	var state = FileCache.options.get("edit_event_dialog", null)
	if !state:
		var s = Vector2i(DisplayServer.screen_get_size() * 0.85)
		dialog.size = s
		dialog.position = DisplayServer.screen_get_size() / 2 - dialog.size / 2
	else:
		dialog.size = state.size
		dialog.position = state.position


func _on_event_updated(event: RPGEvent, index: int) -> void:
	if current_data.events.size() > index:
		current_data.events[index].event = event
		current_event_selected = current_data.events[index]
	else:
		var new_event = MapGeneratorEvent.new()
		new_event.event = event
		current_data.events.append(new_event)
		current_event_selected = current_data.events[-1]
	
	_fill_list()


func _on_cancel_button_pressed() -> void:
	_on_exit()


func _on_exit() -> void:
	propagate_call("apply")
	queue_free()


func _on_event_list_multi_selected(index: int, _selected: bool) -> void:
	if current_data.events.size() > index:
		current_event_selected = current_data.events[index]
		_fill_parameters(current_event_selected)
	else:
		current_event_selected = null
		_fill_parameters(null)


func _on_delete_event_pressed() -> void:
	if not current_data or not current_event_selected:
		return
		
	var path = "res://addons/CustomControls/Dialogs/confirm_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	
	dialog.set_text(TranslationManager.tr("Are you sure you want to delete this event template? This action cannot be undone."))
	dialog.title = TranslationManager.tr("Delete Event")
	
	dialog.tree_exiting.connect(
		func():
			if dialog.result:
				var index: int = current_data.events.find(current_event_selected)
				if index != -1:
					current_data.events.remove_at(index)
					
					if current_data.events.is_empty():
						current_event_selected = null
					else:
						var new_index = min(index, current_data.events.size() - 1)
						current_event_selected = current_data.events[new_index]
					
					_fill_list()
	)


func _on_footprint_height_value_changed(value: float) -> void:
	if current_event_selected: current_event_selected.footprint_height = value


func _on_margin_left_value_changed(value: float) -> void:
	if current_event_selected: current_event_selected.wall_margins.x = value


func _on_margin_right_value_changed(value: float) -> void:
	if current_event_selected: current_event_selected.wall_margins.z = value


func _on_margin_top_value_changed(value: float) -> void:
	if current_event_selected: current_event_selected.wall_margins.y = value


func _on_margin_bottom_value_changed(value: float) -> void:
	if current_event_selected: current_event_selected.wall_margins.w = value


func _on_width_value_changed(value: float) -> void:
	if current_event_selected: current_event_selected.width = value


func _on_height_value_changed(value: float) -> void:
	if current_event_selected: current_event_selected.height = value
