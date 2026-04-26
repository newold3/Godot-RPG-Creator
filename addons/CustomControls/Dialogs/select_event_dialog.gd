@tool
extends Window


const QUEST_ICON = preload("uid://bhdctf1b0orp7")
const LIST_QUEST_ICON = preload("uid://caoj7tt8yvikv")

var _quest_mode: bool = false
var _single_event_mode: bool = false
var _disable_non_quest_events: bool = false
var _target_map_id: int = -1
var _target_event_id: int = -1

var _ok_disabled: bool = false

var is_multi_events_mode: bool = false
var _selection_data: Dictionary

var busy: bool = false

var preview_window: Window
var _loading_map_path: String = ""
var _hovered_map_id: int = -1
var _hovered_event_uid: int = -1
var _hovered_page_index: int = -1
var _is_hovering_page: bool = false
var _last_hovered_idx: int = -1

signal event_selected(map_id: int, event_id: int, page_id: int)
signal events_selected(selection_data: Dictionary)


func _ready() -> void:
	close_requested.connect(_on_close_requested_safe)
	
	var preview_scene = load("res://addons/CustomControls/Dialogs/preview_event_commands_window.tscn")
	preview_window = preview_scene.instantiate()
	
	add_child(preview_window)
	
	%PageList.gui_input.connect(_on_page_list_gui_input)
	
	fill_maps()



func _exit_tree() -> void:
	if is_instance_valid(preview_window):
		preview_window.transient = false
		preview_window.queue_free()


func _on_close_requested_safe() -> void:
	_hide_preview()
	queue_free()



func _process(_delta: float) -> void:
	%OKButton.set_disabled(_ok_disabled == true)
	
	if not _loading_map_path.is_empty():
		var status = ResourceLoader.load_threaded_get_status(_loading_map_path)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			if _is_hovering_page: _extract_and_show_preview()
			_loading_map_path = ""

	if is_instance_valid(preview_window) and preview_window.visible:
		var mouse_pos = DisplayServer.mouse_get_position()
		var parent_rect = Rect2i(position, size)
		var preview_rect = Rect2i(preview_window.position, preview_window.size)
		
		if preview_rect.has_point(mouse_pos):
			preview_window.unfocusable = false
			#if not preview_window.has_focus():
				#preview_window.grab_focus()
			return
		
		if parent_rect.has_point(mouse_pos):
			if not has_focus():
				grab_focus()
			if not preview_window.unfocusable:
				preview_window.unfocusable = true
				
			var map_list_rect = Rect2i(Vector2i(%MapList.get_screen_position()), Vector2i(%MapList.size))
			var event_list_rect = Rect2i(Vector2i(%EventList.get_screen_position()), Vector2i(%EventList.size))
			
			if map_list_rect.has_point(mouse_pos) or event_list_rect.has_point(mouse_pos):
				_hide_preview()
				return
		
		var bridge_rect = parent_rect.merge(preview_rect).grow(20)
		if not bridge_rect.has_point(mouse_pos):
			_hide_preview()



## Manages hovering logic and preserves the window position if it's already open
func _on_page_list_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var idx = %PageList.get_item_at_position(event.position, true)
		
		if idx != -1:
			if idx == _last_hovered_idx and _is_hovering_page and preview_window.visible:
				return
				
			_last_hovered_idx = idx
			_is_hovering_page = true
			
			if %MapList.is_anything_selected() and %EventList.is_anything_selected():
				_hovered_map_id = %MapList.get_item_metadata(%MapList.get_selected_items()[0])
				_hovered_event_uid = %EventList.get_item_metadata(%EventList.get_selected_items()[0])
				_hovered_page_index = idx 
				
				var map_file = "res://data/MapEvents/Map_%s_events.tres" % _hovered_map_id
				
				if FileAccess.file_exists(map_file):
					_loading_map_path = map_file
					if ResourceLoader.has_cached(map_file):
						_extract_and_show_preview()
					else:
						ResourceLoader.load_threaded_request(map_file)



## Extracts data from the RPGEvents resource and sets the dynamic title
func _extract_and_show_preview() -> void:
	if not _is_hovering_page or _hovered_map_id == -1:
		return
		
	var map_resource = ResourceLoader.load(_loading_map_path)
	if not map_resource or not "events" in map_resource: return
		
	var target_event = null
	for ev in map_resource.events:
		if ev._uniq_id == _hovered_event_uid or ev.id == _hovered_event_uid:
			target_event = ev
			break
			
	if target_event and _hovered_page_index < target_event.pages.size():
		var page_data = target_event.pages[_hovered_page_index]
		
		var ev_name = target_event.name if not target_event.name.is_empty() else "EV%03d" % target_event.id
		var pg_name = "Page %s" % (_hovered_page_index + 1)
		if not page_data.name.is_empty(): pg_name += " (%s)" % page_data.name
		
		preview_window.title = ev_name + " - " + pg_name
		
		var target_pos: Vector2i
		if preview_window.visible:
			target_pos = preview_window.position
		else:
			target_pos = position + Vector2i(size.x + 10, 0)
		
		var theme = RPGSYSTEM.color_theme if "color_theme" in RPGSYSTEM else {}
		preview_window.show_preview(page_data.list, target_pos, {"color_theme": theme})



## Hides the window and cleans up variables
func _hide_preview() -> void:
	_is_hovering_page = false
	_last_hovered_idx = -1
	if is_instance_valid(preview_window):
		preview_window.hide()



func setup_quest_mode(value: bool, fill: bool = true) -> void:
	_quest_mode = value
	if is_inside_tree() and fill: fill_maps()



func setup_single_event_mode(map_id: int, event_id: int, quest_mode: bool = false, fill: bool = true) -> void:
	if quest_mode: setup_quest_mode(true, false)
	_single_event_mode = true
	_target_map_id = map_id
	_target_event_id = event_id
	if is_inside_tree() and fill: fill_maps()


func setup_single_event_quest_mode(map_id: int, event_id: int, fill: bool = true) -> void:
	%PageNameLabel.visible = false
	%PageList.visible = false
	_single_event_mode = true
	_disable_non_quest_events = true
	_target_map_id = map_id
	_target_event_id = event_id
	if is_inside_tree() and fill: fill_maps()



func setup_multi_events_mode(selection_data: Dictionary) -> void:
	%PageNameLabel.visible = false
	%PageList.visible = false
	%EventList.select_mode = ItemList.SelectMode.SELECT_TOGGLE
	size.x = 544
	is_multi_events_mode = true
	_selection_data = selection_data.duplicate_deep()
	set_multi_selection()



func set_multi_selection() -> void:
	if busy: return
	busy = true
	var node1 = %MapList
	var events = []
	if node1.is_anything_selected():
			var id = node1.get_selected_items()[0]
			var map_id = node1.get_item_metadata(id)
			if map_id in _selection_data: events = _selection_data[map_id]
	elif node1.get_item_count() > 0:
		node1.select(0)
		node1.item_selected.emit(0)
		var map_id = node1.get_item_metadata(0)
		if map_id in _selection_data: events = _selection_data[map_id]
	var node2 = %EventList
	node2.deselect_all()
	for i in node2.get_item_count():
		var id = node2.get_item_metadata(i)
		if id in events: node2.select(i, false)
	busy = false



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
	if _single_event_mode and not _disable_non_quest_events:
		var map_name = RPGSYSTEM.map_infos.get_map_name_from_id(_target_map_id)
		node.add_item(map_name if not map_name.is_empty() else "Map #%s" % _target_map_id)
		node.set_item_metadata(0, _target_map_id)
		node.select(0)
		var map_exists = false
		for map in map_list:
			if RPGSYSTEM.map_infos.get_map_id(map) == _target_map_id:
				map_exists = true
				break
		if map_exists: node.item_selected.emit(0)
		node.mouse_filter = Control.MOUSE_FILTER_STOP
	else:
		node.mouse_filter = Control.MOUSE_FILTER_STOP
		for map in map_list:
			if map == "res://addons/RPGMap/Scenes/event_command_testing.tscn": continue
			elif map == "res://addons/RPGMap/Scenes/@DefaultMap@.tscn": continue
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
	if is_multi_events_mode: set_multi_selection()



func fill_events(events: Array) -> void:
	var node = %EventList
	node.clear()
	
	var space = "-"
	if _single_event_mode and not _disable_non_quest_events:
		var target_event_found: Dictionary = {}
		for ev: Dictionary in events:
			if ev.uid == _target_event_id:
				target_event_found = ev
				break
		if not target_event_found.is_empty():
			var quest_count = target_event_found.get("quest_count", 0)
			if quest_count > 0:
				node.add_item(space + "%s: %s" % [target_event_found.id, target_event_found.name])
			else:
				node.add_item("%s: %s" % [target_event_found.id, target_event_found.name])
			node.set_item_metadata(0, target_event_found.uid)
			if quest_count > 0:
				node.set_item_icon(0, LIST_QUEST_ICON)
			if _disable_non_quest_events and quest_count == 0:
				node.set_item_disabled(0, true)
			else:
				node.select(0)
		node.mouse_filter = Control.MOUSE_FILTER_STOP
	else:
		node.mouse_filter = Control.MOUSE_FILTER_STOP
		for ev: Dictionary in events:
			var quest_count = ev.get("quest_count", 0)
			if quest_count > 0:
				node.add_item(space + "%s: %s" % [ev.id, ev.name])
			else:
				node.add_item("%s: %s" % [ev.id, ev.name])
			node.set_item_metadata(-1, ev.uid)
			if quest_count > 0:
				node.set_item_icon(-1, LIST_QUEST_ICON)
			
			if _disable_non_quest_events and quest_count == 0:
				node.set_item_disabled(-1, true)
		
		if events.size() > 0 and not is_multi_events_mode:
			for i in node.get_item_count():
				if not node.is_item_disabled(i):
					node.select(i)
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
					var pg_name = "Page %s" % (i + 1) + (" (" + ev.pages[i].name + ")" if not ev.pages[i].name.is_empty() else "")
					node.add_item(pg_name)
					node.set_item_metadata(-1, ev.pages[i].uid)
					if i in ev.quest_pages: node.set_item_icon(-1, QUEST_ICON)
					if i in ev.quest_pages: node.set_item_disabled(i, not _quest_mode)
					elif _quest_mode: node.set_item_disabled(i, true)
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
				if not node.is_item_disabled(i): node.select(i)
				break
	if is_multi_events_mode or _disable_non_quest_events: _ok_disabled = false
	else: _ok_disabled = not node.is_anything_selected()



func _on_ok_button_pressed() -> void:
	if is_multi_events_mode:
		events_selected.emit(_selection_data)
	elif %MapList.is_anything_selected() and %EventList.is_anything_selected() and (%PageList.is_anything_selected() or _disable_non_quest_events):
		var map_id = %MapList.get_item_metadata(%MapList.get_selected_items()[0])
		var event_id = %EventList.get_item_metadata(%EventList.get_selected_items()[0])
		var page_id = %PageList.get_item_metadata(%PageList.get_selected_items()[0]) if %PageList.is_anything_selected() else -1
		event_selected.emit(map_id, event_id, page_id)
	_on_close_requested_safe()



func _on_cancel_button_pressed() -> void:
	_on_close_requested_safe()



func _on_page_list_item_activated(index: int) -> void:
	_on_ok_button_pressed()



func _on_event_list_item_selected(index: int) -> void:
	fill_pages()



func _on_event_list_multi_selected(index: int, selected: bool) -> void:
	if is_multi_events_mode and %MapList.is_anything_selected():
		var id = %MapList.get_selected_items()[0]
		var map_id = %MapList.get_item_metadata(id)
		if not map_id in _selection_data: _selection_data[map_id] = []
		var events = _selection_data[map_id]
		var event_id = %EventList.get_item_metadata(index)
		if selected and not event_id in events: events.append(event_id)
		elif not selected and event_id in events: events.erase(event_id)


func _on_event_list_item_activated(index: int) -> void:
	if _disable_non_quest_events:
		_on_ok_button_pressed()
