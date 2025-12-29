@tool
extends Window


signal event_selected(map_id: int, event_id: int, page_id: int)


func _ready() -> void:
	close_requested.connect(queue_free)
	fill_maps()


func set_selection(map_id: int, event_id: int, page_id: int) -> void:
	var node = %MapList
	for i in node.get_item_count():
		var id = node.get_item_metadata(i)
		if id and id == map_id:
			node.select(i)
			node.item_selected.emit(i)
			break
	
	node = %EventList
	for i in node.get_item_count():
		var id = node.get_item_metadata(i)
		if id and id == event_id:
			node.select(i)
			break
	
	fill_pages(page_id)


func fill_maps() -> void:
	var node = %MapList
	node.clear()
	var map_list = RPGSYSTEM.map_infos.map_infos.maps
	for map in map_list:
		var map_id = RPGSYSTEM.map_infos.get_map_id(map)
		var map_name = RPGSYSTEM.map_infos.get_map_name_from_id(map_id)
		node.add_item(map_name if not map_name.is_empty() else "Map #%s" % map_id)
		node.set_item_metadata(-1, map_id)
		
	if map_list.size() > 0:
		node.select(0)
		node.item_selected.emit(0)


func _on_map_list_item_selected(index: int) -> void:
	var map_id = %MapList.get_item_metadata(index)
	var events = RPGSYSTEM.map_infos.get_events(map_id)
	fill_events(events)


func fill_events(events: Array) -> void:
	var node = %EventList
	node.clear()
	
	for ev: Dictionary in events:
		node.add_item("%s: %s" % [ev.id, ev.name])
		node.set_item_metadata(-1, ev.id)

	if events.size() > 0:
		node.select(0)
		
	fill_pages()


func fill_pages(index_selected: int = 0) -> void:
	var node = %PageList
	node.clear()
	
	if %MapList.is_anything_selected() and %EventList.is_anything_selected():
		var id = %MapList.get_selected_items()[0]
		var map_id = %MapList.get_item_metadata(id)
		id = %EventList.get_selected_items()[0]
		var event_id = %EventList.get_item_metadata(id)
		var events = RPGSYSTEM.map_infos.get_events(map_id)
		for ev: Dictionary in events:
			if ev.id == event_id:
				for i in ev.pages.size():
					var page_name = "Page %s" % (i + 1) + (" (" + ev.pages[i] + ")" if not ev.pages[i].is_empty() else "")
					node.add_item(page_name)
				break
	
	if index_selected >= 0 and %PageList.get_item_count() > index_selected:
		%PageList.select(index_selected)
	elif %PageList.get_item_count() > 0:
		%PageList.select(0)


func _on_ok_button_pressed() -> void:
	if %MapList.is_anything_selected() and %EventList.is_anything_selected() and %PageList.is_anything_selected():
		var map_id = %MapList.get_item_metadata(%MapList.get_selected_items()[0])
		var event_id = %EventList.get_item_metadata(%EventList.get_selected_items()[0])
		var page_id = %PageList.get_selected_items()[0]

		event_selected.emit(map_id, event_id, page_id)
		
	queue_free()


func _on_cancel_button_pressed() -> void:
	queue_free()


func _on_page_list_item_activated(index: int) -> void:
	_on_ok_button_pressed()


func _on_event_list_item_selected(index: int) -> void:
	fill_pages()
