@tool
extends Control


var current_map_id: int = -1
var current_dialog_data: Dictionary = {}
var current_events_res: RPGEvents = null
var events_path: String = "res://data/MapEvents/Map_mapid_events.tres"
var last_map_index: int = -1
var last_dialog_index: int = -1
var search_filter: String = ""
var _tag_regex: RegEx = RegEx.new()

const ICONS = preload("uid://i4aygdaodxpr")


#region Lifecycle
## Initializes the control, compiles the regex, and connects signals.
func _ready() -> void:
	_tag_regex.compile("\\[.*?\\]")
	%RightColum.propagate_call("set_disabled", [true])
	visibility_changed.connect(_on_visibility_changed)
	%SearchBar.text_changed.connect(_on_search_text_changed)
	_fill_map_list()
#endregion


#region Map List Management
## Populates the map list using the RPGMapsInfo autoload and handles persistent selection.
func _fill_map_list() -> void:
	var node = %MapList
	node.clear()
	
	var map_ids = RPGMapsInfo.map_infos.get_map_list()
	
	for i in map_ids.size():
		var map_name = "%s: %s" % [i + 1, RPGMapsInfo.get_map_name_from_id(map_ids[i])]
		node.add_item(map_name)
		node.set_item_metadata(i, map_ids[i])
	
	if node.get_item_count() == 0:
		%RightColum.propagate_call("set_disabled", [true])
		last_map_index = -1
		current_map_id = -1
		_fill_dialog_events()
	else:
		var idx = last_map_index if (last_map_index >= 0 and last_map_index < node.get_item_count()) else 0
		node.select(idx)
		last_map_index = idx
		current_map_id = node.get_item_metadata(idx)
		_fill_dialog_events()


## Triggered when a map is selected from the map list.
func _on_map_list_item_selected(index: int) -> void:
	_apply_text_changes(%CurrentDialog.text, false)
	last_map_index = index
	current_map_id = %MapList.get_item_metadata(index)
	last_dialog_index = -1
	_fill_dialog_events()
#endregion


#region Search and Filtering
## Updates the search filter, saves current text if needed, and refreshes the dialog list.
func _on_search_text_changed(new_text: String) -> void:
	search_filter = new_text
	_apply_text_changes(%CurrentDialog.text, false)
	last_dialog_index = -1
	_fill_dialog_events()
#endregion


#region Dialog List Management
## Parses the events of the current map, applies the regex cleanup, filters by search, and populates the list.
func _fill_dialog_events() -> void:
	var node = %DialogList
	node.clear()
	current_dialog_data = {}
	
	var path = events_path.replace("mapid", str(current_map_id))
	
	var img = ICONS.get_image()
	var w = img.get_width() / 3
	var h = img.get_height()
	var icon_dialog = ImageTexture.create_from_image(img.get_region(Rect2(0, 0, w, h)))
	var icon_scroll_dialog = ImageTexture.create_from_image(img.get_region(Rect2(w, 0, w, h)))
	var icon_instant_dialog = ImageTexture.create_from_image(img.get_region(Rect2(w*2, 0, w, h)))
	
	if ResourceLoader.exists(path):
		var res: RPGEvents = load(path)
		current_events_res = res
		
		for j in res.events.size():
			var ev: RPGEvent = res.events[j]
			
			for i: int in ev.pages.size():
				var page: RPGEventPage = ev.pages[i]
				
				if not page:
					continue
				
				var page_list = page.list
				var k: int = 0
				
				while k < page_list.size():
					var cmd: RPGEventCommand = page_list[k]
					if cmd.code in [2, 10, 34]:
						var parent: RPGEventCommand = cmd
						var start_idx: int = k
						var child_code: int = cmd.code + 1
						var lines: PackedStringArray = PackedStringArray()
						
						if cmd.code == 34:
							lines.append(page_list[k].parameters.first_line)
						
						k += 1
						
						while k < page_list.size() and page_list[k].code == child_code:
							lines.append(page_list[k].parameters.line)
							k += 1
						
						var end_idx: int = k - 1
						var block_text: String = "\n".join(lines)
						var clean_text: String = _tag_regex.sub(block_text.replace("\n", " "), "", true).strip_edges()
						
						if not search_filter.is_empty() and not search_filter.to_lower() in clean_text.to_lower() and not search_filter.to_lower() in block_text.to_lower():
							continue
						
						var data: Dictionary = {
							"parent_code": cmd.code,
							"start_index": start_idx,
							"end_index": end_idx,
							"text": block_text,
							"parent": parent,
							"page": page,
							"child_code": child_code,
							"event_idx": j,
							"page_idx": i,
							"icon": icon_dialog if cmd.code == 2 else \
								icon_scroll_dialog if cmd.code == 10 else \
								icon_instant_dialog
						}
						
						var text_preview = _truncate_text(clean_text, 36)
						node.add_item(
							"[EV %s | P %s] - \"%s\"" % [j, i, text_preview],
							data.icon
						)
						node.set_item_metadata(node.get_item_count() - 1, data)
					else:
						k += 1
	
	if node.get_item_count() > 0:
		var idx = last_dialog_index if (last_dialog_index >= 0 and last_dialog_index < node.get_item_count()) else 0
		node.select(idx)
		last_dialog_index = idx
		current_dialog_data = node.get_item_metadata(idx)
		_fill_text()
	else:
		last_dialog_index = -1
		_fill_text()


## Triggered when a dialog item is selected.
func _on_dialog_list_item_selected(index: int) -> void:
	last_dialog_index = index
	
	if not _apply_text_changes(%CurrentDialog.text, true):
		current_dialog_data = %DialogList.get_item_metadata(index)
		_fill_text()
#endregion


#region Text Editing
## Populates the text editor with the combined lines of the selected dialog block.
func _fill_text() -> void:
	if current_dialog_data.is_empty():
		%RightColum.propagate_call("set_disabled", [true])
		%CurrentDialog.text = ""
	else:
		%RightColum.propagate_call("set_disabled", [false])
		%CurrentDialog.text = current_dialog_data.text


## Updates the page list replacing the old child commands with the new text lines.
func _apply_text_changes(new_text: String, rebuild_list: bool = true) -> bool:
	if current_dialog_data.is_empty():
		return false
		
	if new_text == current_dialog_data.text:
		return false
	
	var page: RPGEventPage = current_dialog_data.page
	var start_idx: int = current_dialog_data.start_index
	var end_idx: int = current_dialog_data.end_index
	var child_code: int = current_dialog_data.child_code
	
	for idx in range(end_idx, start_idx, -1):
		page.list.remove_at(idx)
	
	var new_lines: PackedStringArray = new_text.split("\n")
	var current_insert_idx: int = start_idx + 1
	
	for line in new_lines:
		var new_cmd: RPGEventCommand = RPGEventCommand.new()
		new_cmd.code = child_code
		new_cmd.parameters = {"line": line}
		page.list.insert(current_insert_idx, new_cmd)
		current_insert_idx += 1
	
	current_dialog_data = {}
	
	# Persist changes to disk immediately, regardless of whether the map scene is open.
	if current_events_res and is_instance_valid(current_events_res):
		var save_path = events_path.replace("mapid", str(current_map_id))
		ResourceSaver.save(current_events_res, save_path)
	
	if rebuild_list:
		_fill_dialog_events()
		
	return true


## Truncates a string to a maximum length appending ellipsis if necessary.
func _truncate_text(text: String, max_length: int) -> String:
	if text.length() > max_length:
		return text.left(max_length - 3) + "..."
		
	return text
#endregion


#region Utilities
## Handles state saving and updating when the visibility of the control changes.
func _on_visibility_changed() -> void:
	if visible:
		_fill_map_list()
	else:
		_apply_text_changes(%CurrentDialog.text, false)
#endregion


func _on_advance_edit_pressed() -> void:
	if current_dialog_data.is_empty():
		return
	
	var path = "res://addons/CustomControls/Dialogs/CommandEvents/advanced_text_editor_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	
	# Build the full ordered command array: [parent, child1, child2, ...]
	var page: RPGEventPage = current_dialog_data.page
	var start_idx: int = current_dialog_data.start_index
	var end_idx: int = current_dialog_data.end_index
	var commands: Array[RPGEventCommand] = []
	for i in range(start_idx, end_idx + 1):
		commands.append(page.list[i])
	
	# Determine editor mode from the parent command code (2=normal, 10=scroll, 34=instant)
	var parent_code: int = current_dialog_data.parent_code
	var mode: int = 0 if parent_code == 2 else 1 if parent_code == 10 else 2
	
	dialog.set_dialog_manager_mode(mode)
	dialog.set_parameters(commands)
	dialog.command_changed.connect(
		func(new_commands: Array[RPGEventCommand]) -> void:
			_apply_full_command_changes(new_commands)
	)


## Applies the full command change (parent config + text lines) received from the AdvancedTextEditor.
## [param new_commands]: Array returned by build_command_list() — children reversed, parent last.
func _apply_full_command_changes(new_commands: Array[RPGEventCommand]) -> void:
	if current_dialog_data.is_empty():
		return
	
	var page: RPGEventPage = current_dialog_data.page
	var start_idx: int = current_dialog_data.start_index
	var end_idx: int = current_dialog_data.end_index
	
	# Remove old commands from end to start to preserve indices
	for idx in range(end_idx, start_idx - 1, -1):
		page.list.remove_at(idx)
	
	# build_command_list() returns [child_n, ..., child_1, parent] — reverse to [parent, child_1, ..., child_n]
	var ordered: Array[RPGEventCommand] = []
	ordered.assign(new_commands)
	ordered.reverse()
	
	for i in ordered.size():
		page.list.insert(start_idx + i, ordered[i])
	
	current_dialog_data = {}
	
	if current_events_res and is_instance_valid(current_events_res):
		var save_path = events_path.replace("mapid", str(current_map_id))
		ResourceSaver.save(current_events_res, save_path)
	
	_fill_dialog_events()


func _on_reset_filter_text_pressed() -> void:
	%SearchBar.text = ""
	_on_search_text_changed("")
