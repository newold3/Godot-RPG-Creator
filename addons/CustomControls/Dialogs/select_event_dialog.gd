@tool
extends Window


const QUEST_ICON = preload("uid://bhdctf1b0orp7")

# When the value is true, it disables any page that is not a quest page.
var _quest_mode: bool = false
# When the value is true, Only the selected map and event and any of its pages can be chosen..
var _single_event_mode: bool = false
var _target_map_id: int = -1
var _target_event_id: int = -1

var _ok_disabled: bool = false


signal event_selected(map_id: int, event_id: int, page_id: int)


func _ready() -> void:
	close_requested.connect(queue_free)
	fill_maps()


func _process(delta: float) -> void:
	%OKButton.set_disabled(_ok_disabled == true)


func setup_quest_mode(value: bool, fill: bool = true) -> void:
	_quest_mode = value
	
	if is_inside_tree() and fill: fill_maps()


func setup_single_event_mode(map_id: int, event_id: int, quest_mode: bool = false, fill: bool = true) -> void:
	if quest_mode:
		setup_quest_mode(true, false)
		
	_single_event_mode = true
	_target_map_id = map_id
	_target_event_id = event_id
	
	if is_inside_tree() and fill: fill_maps()


func set_selection(map_id: int, event_id: int, page_id: int) -> void:
	var node = %MapList
	for i in node.get_item_count():
		var id = node.get_item_metadata(i)
		if id and id == map_id:
			node.select(i)
			node.item_selected.emit(i)
			break
	
	node = %EventList
	var items = node.get_item_count()
	if items > 0:
		node.select(0)
		for i in items:
			var real_index = node.get_item_metadata(i)
			if real_index == event_id:
				node.select(i)
				break
	
	fill_pages(page_id)


func fill_maps() -> void:
	var node = %MapList
	node.clear()
	var map_list = RPGSYSTEM.map_infos.map_infos.maps
	
	if _single_event_mode:
		var map_name = RPGSYSTEM.map_infos.get_map_name_from_id(_target_map_id)
		node.add_item(map_name if not map_name.is_empty() else "Map #%s" % _target_map_id)
		node.set_item_metadata(0, _target_map_id)
		
		node.select(0)
		
		var map_exists = false
		for map in map_list:
			if RPGSYSTEM.map_infos.get_map_id(map) == _target_map_id:
				map_exists = true
				break
				
		if map_exists:
			node.item_selected.emit(0)
		
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
	else:
		node.mouse_filter = Control.MOUSE_FILTER_STOP
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
	
	if _single_event_mode:
		var target_event_found: Dictionary = {}
		
		for ev: Dictionary in events:
			if ev.uid == _target_event_id:
				target_event_found = ev
				break
		
		if not target_event_found.is_empty():
			node.add_item("%s: %s" % [target_event_found.id, target_event_found.name])
			node.set_item_metadata(0, target_event_found.uid)
			node.select(0)
			
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
	else:
		node.mouse_filter = Control.MOUSE_FILTER_STOP
		for ev: Dictionary in events:
			node.add_item("%s: %s" % [ev.id, ev.name])
			node.set_item_metadata(-1, ev.uid)

		if events.size() > 0:
			node.select(0)
		
	fill_pages()


func fill_pages(page_selected: int = 0) -> void:
	var node = %PageList
	node.clear()
	
	if %MapList.is_anything_selected() and %EventList.is_anything_selected():
		var id = %MapList.get_selected_items()[0]
		var map_id = %MapList.get_item_metadata(id)
		id = %EventList.get_selected_items()[0]
		var event_id = %EventList.get_item_metadata(id)
		var events = RPGSYSTEM.map_infos.get_events(map_id)
		for ev: Dictionary in events:
			if ev.uid == event_id:
				for i in ev.pages.size():
					var page_name = "Page %s" % (i + 1) + (" (" + ev.pages[i].name + ")" if not ev.pages[i].name.is_empty() else "")
					node.add_item(page_name)
					node.set_item_metadata(-1, ev.pages[i].uid)
					if i in ev.quest_pages:
						node.set_item_icon(-1, QUEST_ICON)
					if i in ev.quest_pages:
						node.set_item_disabled(i, not _quest_mode)
					elif _quest_mode:
						node.set_item_disabled(i, true)

				break
	
	node = %PageList
	var items = node.get_item_count()
	if items > 0:
		for i in items:
			if not node.is_item_disabled(i):
				node.select(i)
				break
		for i in items:
			var real_index = node.get_item_metadata(i)
			if real_index == page_selected:
				if not node.is_item_disabled(i):
					node.select(i)
				break
	
	_ok_disabled = not node.is_anything_selected()


func _on_ok_button_pressed() -> void:
	if %MapList.is_anything_selected() and %EventList.is_anything_selected() and %PageList.is_anything_selected():
		var map_id = %MapList.get_item_metadata(%MapList.get_selected_items()[0])
		var event_id = %EventList.get_item_metadata(%EventList.get_selected_items()[0])
		var page_id = %PageList.get_item_metadata(%PageList.get_selected_items()[0]) if %PageList.is_anything_selected() else -1

		event_selected.emit(map_id, event_id, page_id)
		
	queue_free()


func _on_cancel_button_pressed() -> void:
	queue_free()


func _on_page_list_item_activated(index: int) -> void:
	_on_ok_button_pressed()


func _on_event_list_item_selected(index: int) -> void:
	fill_pages()
