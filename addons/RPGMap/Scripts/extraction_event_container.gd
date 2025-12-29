@tool
extends MarginContainer

var extraction_events: Array[RPGExtractionItem]

var real_indexes: Dictionary
var filter_update_timer: float = 0.0


signal requested_edit_event(index: int)
signal requested_remove_event(index: int)
signal item_selected(index: int)
signal detach_panel(panel: MarginContainer)


func _ready() -> void:
	pass


func enable_plugin() -> void:
	CustomTooltipManager.replace_all_tooltips_with_custom(self)


func hide_detach_button(value: bool) -> void:
	%DetachButton.visible = !value


func _process(delta: float) -> void:
	if filter_update_timer > 0:
		filter_update_timer -= delta
		if filter_update_timer <= 0.0:
			filter_update_timer = 0.0
			refresh()


func refresh(clear_filter: bool = false) -> void:
	if clear_filter:
		%Filter.text = ""
		_on_filter_text_changed("")
		filter_update_timer = 0.0
		
	var node: ItemList = %EventList
	var items_selected = node.get_selected_items()
	var item_selected = items_selected[0] if items_selected.size() > 0 else -1
	if real_indexes.has(item_selected):
		item_selected = real_indexes[item_selected]
	
	node.clear()
	
	real_indexes.clear()
	var real_index = 0
	var current_index = 0
	var filter = %Filter.text.to_lower()
	
	for event: RPGExtractionItem in extraction_events:
		if !filter or event.name.to_lower().find(filter) != -1:
			node.add_item(event.name)
			real_indexes[current_index] = real_index
			if item_selected == real_index:
				item_selected = current_index
			current_index += 1
		real_index += 1
	
	var event_count = node.get_item_count()
	if event_count > item_selected and item_selected != -1:
		node.select(item_selected)
		node.item_selected.emit(real_indexes[item_selected])
			
	elif event_count > 0:
		node.select(0)
		node.item_selected.emit(real_indexes[0])
	else:
		node.item_selected.emit(-1)
	
	%RemoveEventButton.set_disabled(event_count == 0)
	%EditEventButton.set_disabled(event_count == 0)


func _on_event_list_item_selected(index: int) -> void:
	if index >= 0 and extraction_events.size() > index:
		var event: RPGExtractionItem = extraction_events[index]
		
		if event:
			%EventID.text = str(event.id)
			%EventName.text = str(event.name)
			%EventPosition.text = "x: %s, y: %s" % [event.x, event.y]
			
			item_selected.emit(index)
		else:
			%EventID.text = ""
			%EventName.text = ""
			%EventPosition.text = ""
	else:
		%EventID.text = ""
		%EventName.text = ""
		%EventPosition.text = ""


func select(id: int, emit_signal: bool = false, clear_filter: bool = false) -> void:
	if clear_filter and %Filter.text.length() > 0:
		%EventList.deselect_all()
		refresh(true)
		emit_signal = true
		
	var node: ItemList = %EventList
	var index = -1
	var current_event: RPGExtractionItem
	
	for i in extraction_events.size():
		current_event = extraction_events[i]
		if current_event and current_event.id == id:
			index = i
			break
			
	if node.get_item_count() > index and index != -1:
		var filtered_index = -1
		for key in real_indexes.keys():
			if real_indexes[key] == index:
				filtered_index = key
				break
				
		if filtered_index != -1:
			node.select(filtered_index)
			node.ensure_current_is_visible()
			if !emit_signal:
				%EventID.text = str(current_event.id)
				%EventName.text = str(current_event.name)
				%EventPosition.text = "x: %s, y: %s" % [current_event.x, current_event.y]
			else:
				node.item_selected.emit(real_indexes[filtered_index])


func _on_remove_event_button_pressed() -> void:
	var node: ItemList = %EventList
	var items_selected = node.get_selected_items()
	var item_selected = items_selected[0] if items_selected.size() > 0 else -1
	
	if item_selected != -1:
		requested_remove_event.emit(real_indexes[item_selected])


func _on_event_list_item_activated(index: int) -> void:
	requested_edit_event.emit(real_indexes[index])


func _on_edit_event_button_pressed() -> void:
	var node: ItemList = %EventList
	var items_selected = node.get_selected_items()
	var item_selected = items_selected[0] if items_selected.size() > 0 else -1
	
	if item_selected != -1:
		requested_edit_event.emit(real_indexes[item_selected])


func _on_filter_text_changed(new_text: String) -> void:
	if new_text.length() != 0:
		%Filter.right_icon = ResourceLoader.load("res://addons/CustomControls/Images/filter_reset.png")
	else:
		%Filter.right_icon = ResourceLoader.load("res://addons/CustomControls/Images/magnifying_glass.png")
	filter_update_timer = 0.25


func _on_filter_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.is_pressed():
			if event.button_index == MOUSE_BUTTON_LEFT:
				if %Filter.text.length() > 0:
					if event.position.x >= %Filter.size.x - 22:
						%Filter.text = ""
						_on_filter_text_changed("")
	elif event is InputEventMouseMotion:
		if event.position.x >= %Filter.size.x - 22:
			%Filter.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		else:
			%Filter.mouse_default_cursor_shape = Control.CURSOR_IBEAM


func _on_detach_button_pressed() -> void:
	detach_panel.emit(self)
