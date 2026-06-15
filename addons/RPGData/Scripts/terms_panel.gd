@tool
extends HBoxContainer

## The style applied to the title of the terms.
@export var terms_title_style: StyleBox

var data: RPGTerms
var database: RPGDATA
var filter_update_timer: float = 0.0
var can_delete_message: bool = false

var is_dragging_item: bool = false
var drag_hover_index: int = -1

const CLOSE_ICON = preload("res://addons/CustomControls/Images/close_icon.png")



## Initializes the term list and connects inputs.
func _ready() -> void:
	%TermList.lock_enter = true
	var list_node = %TermList.get_item_list()
	list_node.gui_input.connect(_on_term_list_gui_input)
	list_node.set_drag_forwarding(_get_drag_data, _can_drop_data, _drop_data)
	list_node.draw.connect(_on_item_list_draw)
	list_node.mouse_exited.connect(_on_item_list_mouse_exited)


#region Develop

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		is_dragging_item = false
		drag_hover_index = -1
		if is_inside_tree():
			var term_list = get_node_or_null("%TermList")
			if term_list:
				var list = term_list.get_item_list()
				if list:
					list.queue_redraw()


func _on_item_list_draw() -> void:
	if is_dragging_item and drag_hover_index != -1:
		var term_list = get_node_or_null("%TermList")
		if term_list:
			var list_node = term_list.get_item_list()
			if drag_hover_index < list_node.get_item_count():
				var rect = list_node.get_item_rect(drag_hover_index)
				rect.position.y -= term_list.get_v_scroll_bar().value
				list_node.draw_rect(rect, Color(0.2, 0.6, 1.0, 0.4), true)
				list_node.draw_line(Vector2(rect.position.x, rect.position.y), Vector2(rect.position.x + rect.size.x, rect.position.y), Color(0.2, 0.8, 1.0, 1.0), 3.0)


func _on_item_list_mouse_exited() -> void:
	if is_dragging_item:
		drag_hover_index = -1
		var term_list = get_node_or_null("%TermList")
		if term_list:
			term_list.get_item_list().queue_redraw()


func _enable_develop() -> void:
	%Develop.visible = true
	
	_fill_develop_headers()
	
	if not %HeaderList.item_selected.is_connected(_on_develop_header_select):
		%HeaderList.item_selected.connect(_on_develop_header_select)
	
	if not %DevelopAddTerm.pressed.is_connected(_on_develop_add_term_pressed):
		%DevelopAddTerm.pressed.connect(_on_develop_add_term_pressed)


func _on_develop_header_select(index: int) -> void:
	var text = %HeaderList.get_item_text(index)
	%DevelopHeader.text = text
	%HeaderList.select(0)


## Creates the drag data and preview for reordering terms in develop mode.
func _get_drag_data(_at_position: Vector2) -> Variant:
	if not DatabaseLoader.is_develop_build or %Filter.text.length() > 0:
		return null
		
	var list_node = %TermList.get_item_list()
	var local_pos = list_node.get_local_mouse_position()
	var index = %TermList.get_item_at_position(local_pos)
	
	if index == -1:
		return null
		
	var real_idx = %TermList.get_item_metadata(index)
	if real_idx == null:
		return null
		
	var columns = %TermList.get_column(index)
	var item_name = columns[0] if columns.size() > 0 else "Item"
	
	var preview_container = Control.new()
	var preview = Label.new()
	preview.text = item_name
	
	if terms_title_style != null:
		preview.add_theme_stylebox_override("normal", terms_title_style)
		
	preview.position = Vector2(10, 10)
	preview_container.add_child(preview)
	
	list_node.set_drag_preview(preview_container)
	is_dragging_item = true
	
	return {"type": "rpg_term", "real_index": real_idx}


## Validates if a term can be dropped at the given position.
func _can_drop_data(_at_position: Vector2, drag_data: Variant) -> bool:
	if not DatabaseLoader.is_develop_build or %Filter.text.length() > 0:
		return false
		
	if typeof(drag_data) == TYPE_DICTIONARY and drag_data.has("type") and drag_data["type"] == "rpg_term":
		var list_node = %TermList.get_item_list()
		var local_pos = list_node.get_local_mouse_position()
		var to_index = %TermList.get_item_at_position(local_pos)
		
		if drag_hover_index != to_index:
			drag_hover_index = to_index
			list_node.queue_redraw()
			
		return to_index != -1
		
	return false


## Reorders the message array based on the drop position and refreshes the list.
func _drop_data(_at_position: Vector2, drag_data: Variant) -> void:
	var list_node = %TermList.get_item_list()
	is_dragging_item = false
	drag_hover_index = -1
	list_node.queue_redraw()
	
	var from_real_index = drag_data["real_index"]
	var local_pos = list_node.get_local_mouse_position()
	var to_index = %TermList.get_item_at_position(local_pos)
	
	if to_index == -1:
		return
		
	var target_real_index = -1
	var to_metadata = %TermList.get_item_metadata(to_index)
	
	if to_metadata != null:
		target_real_index = to_metadata
	else:
		var columns = %TermList.get_column(to_index)
		if columns.size() > 0:
			var header_name = columns[0]
			for i in data.messages.size():
				var msg: RPGTerm = data.messages[i]
				if msg.unselectable and msg.id == header_name:
					target_real_index = i
					break
					
	if target_real_index == -1 or from_real_index == target_real_index:
		return
		
	var item = data.messages[from_real_index]
	data.messages.remove_at(from_real_index)
	
	if target_real_index > from_real_index:
		target_real_index -= 1
		
	data.messages.insert(target_real_index, item)
	
	await fill_terms_list()
	
	var target_search_id = item.id
	var node = %TermList
	for i in node.items.size():
		var it = node.items[i]
		if it[0] == target_search_id:
			node.select(i)
			if list_node:
				list_node.set_current(i)
				list_node.ensure_current_is_visible()
			break


## Finds or creates a header by ID, prevents duplicate text IDs, and inserts the new term at the end of the header section.
func _on_develop_add_term_pressed() -> void:
	var header = %DevelopHeader.text.capitalize()
	var text_id = %DevelopID.text.capitalize()
	var text = %DevelopTerm.text
	
	if header.is_empty() or header.to_lower() == "user messages" or header.to_lower() == "messages":
		return
	
	var header_index: int = -1
	var user_messages_index: int = -1
	
	for i in data.messages.size():
		var message: RPGTerm = data.messages[i]
		if message.unselectable:
			if message.id == header:
				header_index = i
			if message.id.to_lower() == "user messages":
				user_messages_index = i
				
	var insert_index: int = data.messages.size()
	var target_search_id: String = header
	
	if header_index == -1:
		var new_header: RPGTerm = RPGTerm.new()
		new_header.id = header
		new_header.unselectable = true
		
		if user_messages_index != -1:
			insert_index = user_messages_index
		else:
			insert_index = data.messages.size()
			
		data.messages.insert(insert_index, new_header)
		insert_index += 1
		_fill_develop_headers()
	else:
		insert_index = header_index + 1
		while insert_index < data.messages.size():
			var current_message: RPGTerm = data.messages[insert_index]
			if current_message.unselectable:
				break
			insert_index += 1
			
	if not text_id.is_empty() and not text.is_empty():
		var is_duplicate: bool = false
		
		for i in data.messages.size():
			var message: RPGTerm = data.messages[i]
			if message.id == text_id and not message.unselectable:
				is_duplicate = true
				break
				
		if not is_duplicate:
			var new_term: RPGTerm = RPGTerm.new()
			new_term.id = text_id
			new_term.text = text
			new_term.unselectable = false
			data.messages.insert(insert_index, new_term)
			target_search_id = text_id
			
	await fill_terms_list()
	
	var node = %TermList
	for i in node.items.size():
		var item = node.items[i]
		if item[0] == target_search_id:
			node.select(i)
			var list_node = node.get_item_list()
			if list_node:
				list_node.ensure_current_is_visible()
			break


func _fill_develop_headers() -> void:
	var node = %HeaderList
	node.clear()
	
	node.add_item("Select Header ▼")
	
	for message: RPGTerm in data.messages:
		if message.unselectable and not message.id.is_empty() and message.id.to_lower() != "user messages" and message.id.to_lower() != "messages":
			node.add_item(message.id)
			
	if node.get_item_count() > 0:
		node.select(0)


#endregion



## Processes the filter timer.
func _process(delta: float) -> void:
	if filter_update_timer > 0:
		filter_update_timer -= delta
		if filter_update_timer <= 0.0:
			filter_update_timer = 0.0
			update_terms_by_filter()


## Refreshes the terms list applying the current filter text.
func update_terms_by_filter() -> void:
	var node = %TermList
	node.set_filter(%Filter.text)
	var selected_items = node.get_selected_items()
	
	await fill_terms_list()
	
	node.set_selected_items(selected_items)


## Sets the real term data and populates the visual list.
func set_data(real_data: RPGTerms) -> void:
	if !is_inside_tree():
		return
		
	data = real_data
	
	if DatabaseLoader.is_develop_build:
		_enable_develop()
	else:
		%Develop.visible = false
	
	await get_tree().process_frame
	await fill_terms_list()


## Fills the term list applying styles to headers and metadata to selectable items.
func fill_terms_list() -> void:
	var node = %TermList
	node.clear()
	
	%TermList.get_item_list().mouse_default_cursor_shape = Control.CURSOR_ARROW
	can_delete_message = false
	
	var unselectable_items: Array = []
	var real_index = 0
	var current_index = 0
	
	var filter = %Filter.text.to_lower()
	var fast_selection = %FastSelection
	fast_selection.clear()
	fast_selection.add_item(tr("Go To Section"))
	fast_selection.set_item_disabled(-1, true)
	
	var current_header = null
	var items_in_current_category: Array = []
	
	for message: RPGTerm in data.messages:
		var columns: Array
		
		if message.id == "Messages":
			real_index += 1
			continue
		
		if message.unselectable:
			if current_header != null and not current_header.id.is_empty() and (items_in_current_category.size() > 0 or filter.is_empty() or current_header.id.to_lower().find(filter) != -1):
				unselectable_items.append(current_index)
				columns = [current_header.id, current_header.text]
				node.add_column(columns)
				node.add_row_color(current_index, terms_title_style)
				fast_selection.add_item(current_header.id)
				current_index += 1
				
				for item_data in items_in_current_category:
					node.add_column(item_data.columns)
					if item_data.is_user_message:
						node.add_custom_icon(current_index, CLOSE_ICON)
					node.set_item_metadata(current_index, item_data.real_index)
					current_index += 1
					
			current_header = message
			items_in_current_category.clear()
		else:
			if filter.length() == 0 or message.text.to_lower().find(filter) != -1 or message.id.to_lower().find(filter) != -1:
				var item_data = {
					"columns": [message.id, message.text],
					"is_user_message": message.is_user_message,
					"real_index": real_index
				}
				items_in_current_category.append(item_data)
				
		real_index += 1
		
	if current_header != null and not current_header.id.is_empty() and (items_in_current_category.size() > 0 or filter.is_empty() or current_header.id.to_lower().find(filter) != -1):
		unselectable_items.append(current_index)
		var columns = [current_header.id, current_header.text]
		node.add_column(columns)
		node.add_row_color(current_index, terms_title_style)
		fast_selection.add_item(current_header.id)
		current_index += 1
		
		for item_data in items_in_current_category:
			node.add_column(item_data.columns)
			if item_data.is_user_message:
				node.add_custom_icon(current_index, CLOSE_ICON)
			node.set_item_metadata(current_index, item_data.real_index)
			current_index += 1
			
	fast_selection.select(0)
	
	await node.columns_setted
	
	for i in unselectable_items:
		node.set_item_selectable(i, false)


## Handles the deletion of selected items via input.
func _on_term_list_delete_pressed(indexes: PackedInt32Array) -> void:
	var items_modified: bool = false
	
	for index in indexes:
		var real_idx = %TermList.get_item_metadata(index)
		if real_idx != null:
			var message: RPGTerm = data.get_message_obj(real_idx)
			if message and message.is_user_message:
				data.update_message(real_idx, "")
				items_modified = true
				
	if items_modified:
		var selected_items = %TermList.get_selected_items()
		await fill_terms_list()
		%TermList.select_items(selected_items)


## Triggers edition or creation of a term when activated.
func _on_term_list_item_activated(index: int) -> void:
	var real_idx = %TermList.get_item_metadata(index)
	var last_index = %TermList.get_item_list().get_item_count() - 1
	
	if real_idx != null and index != last_index:
		if %TermList.is_item_selectable(index):
			var path = "res://addons/CustomControls/Dialogs/select_text_dialog.tscn"
			var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
			var columns = %TermList.get_column(index)
			var item_name = ""
			
			if columns.size() > 0:
				item_name = columns[0]
				
			dialog.title = TranslationManager.tr(item_name)
			dialog.set_text(data.get_message(real_idx))
			dialog.text_selected.connect(_update_term.bind(index))
	else:
		var path = "res://addons/CustomControls/Dialogs/create_term_dialog.tscn"
		var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
		dialog.message_selected.connect(_create_new_message)


## Updates an existing term message and reloads the list.
func _update_term(text: String, index: int) -> void:
	data.update_message(%TermList.get_item_metadata(index), text)
	await fill_terms_list()
	%TermList.select(index)


## Creates a new term message dynamically.
func _create_new_message(id: String, text: String) -> void:
	if id:
		var message = data.create_message(id, text, false, true, false)
		if message:
			await fill_terms_list()
			var selected_id = %TermList.get_item_list().get_item_count() - 2
			%TermList.set_item_metadata(selected_id, data.messages.size() - 1)
			%TermList.select(selected_id)


## Prompts a confirmation dialog before removing a message.
func _confirm_remove_message(index: int) -> void:
	var confirm_dialog := ConfirmationDialog.new()
	confirm_dialog.title = "Confirm Remove Message"
	confirm_dialog.dialog_text = "Do you want to delete this message?\n(If the game tries to display this message\nand it doesn’t exist, an empty message will appear)."
	confirm_dialog.ok_button_text = "Remove Message"
	confirm_dialog.confirmed.connect(_remove_message.bind(index))
	add_child(confirm_dialog)
	confirm_dialog.popup_centered()


## Deletes the message based on its metadata index.
func _remove_message(index: int) -> void:
	var real_idx = %TermList.get_item_metadata(index)
	if real_idx != null:
		data.remove_message_at(real_idx)
		await fill_terms_list()
		if index < %TermList.get_item_list().get_item_count():
			%TermList.select(index)


## Intercepts inputs to handle fast selection and deletion.
func _on_term_list_gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("EnterKey") and !event.is_ctrl_pressed():
		var selected_items = %TermList.get_selected_items()
		if selected_items.size() == 1:
			_on_term_list_item_activated(selected_items[0])
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.keycode == KEY_DELETE and event.is_pressed() and not event.is_echo():
		var selected_items = %TermList.get_selected_items()
		if selected_items.size() == 1:
			var index = selected_items[0]
			if index != -1 and %TermList.get_item_metadata(index) != null:
				var real_idx = %TermList.get_item_metadata(index)
				var message: RPGTerm = data.get_message_obj(real_idx)
				if message and message.is_user_message:
					_confirm_remove_message(index)
					get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		var index = %TermList.get_item_at_position(event.position)
		var hover_delete = false
		
		if index != -1 and %TermList.get_item_metadata(index) != null:
			var real_idx = %TermList.get_item_metadata(index)
			var message: RPGTerm = data.get_message_obj(real_idx)
			if message and message.is_user_message:
				if event.position.x <= CLOSE_ICON.get_width():
					hover_delete = true
					
		if hover_delete:
			%TermList.get_item_list().mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			can_delete_message = true
		else:
			%TermList.get_item_list().mouse_default_cursor_shape = Control.CURSOR_ARROW
			can_delete_message = false
	elif can_delete_message and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		var index = %TermList.get_item_at_position(event.position)
		if index != -1 and %TermList.get_item_metadata(index) != null:
			_confirm_remove_message(index)
			get_viewport().set_input_as_handled()


## Switches the filter icon and starts the timer.
func _on_filter_text_changed(new_text: String) -> void:
	if new_text.length() != 0:
		%Filter.right_icon = ResourceLoader.load("res://addons/CustomControls/Images/filter_reset.png")
	else:
		%Filter.right_icon = ResourceLoader.load("res://addons/CustomControls/Images/magnifying_glass.png")
	filter_update_timer = 0.25


## Clears the filter text if the clear icon is clicked.
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


## Navigates directly to the specified term section.
func _on_fast_selection_item_selected(index: int) -> void:
	if index > 0:
		var node1 = %FastSelection
		var node2 = %TermList
		var text = node1.get_item_text(index)
		for i in node2.items.size():
			var item = node2.items[i]
			if item[0] == text:
				node2.select(i+1)
				break
		node1.select(0)


func _on_reset_pressed() -> void:
	var old_messages = data.messages.filter(func(message: RPGTerm): return message.is_user_message == true)
	data.messages.clear()
	
	var file = FileAccess.open("res://addons/RPGData/default_terms_list.txt", FileAccess.READ)
	if not file:
		return
		
	var terms = file.get_as_text().split("\n")
	
	for term: String in terms:
		term = term.strip_edges()
		
		if term.is_empty():
			continue
			
		var new_term: RPGTerm
		var parsed_id: String = ""
		
		if term.find(",") != -1:
			parsed_id = term.get_slice(",", 0).strip_edges()
			var message = term.get_slice(",", 1).strip_edges()
			
			if parsed_id.to_lower() == "user messages" or parsed_id.to_lower() == "messages":
				continue
				
			if message.is_empty():
				new_term = RPGTerm.new(parsed_id, "", true)
			else:
				new_term = RPGTerm.new(parsed_id, message, false)
		else:
			parsed_id = term
			
			if parsed_id.to_lower() == "user messages" or parsed_id.to_lower() == "messages":
				continue
				
			new_term = RPGTerm.new(parsed_id, "", true)
			
		data.messages.append(new_term)
		
	if data.messages.size() > 0:
		data.messages.append(RPGTerm.new("User Messages", "", true))
		data.messages.append_array(old_messages)
		
	fill_terms_list()


func _on_export_list_pressed() -> void:
	var path = "res://addons/RPGData/default_terms_list.txt"
	var text = ""
	for message: RPGTerm in data.messages:
		text += "%s, %s\n" % [message.id, message.text]
	var f = FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)


func _on_import_list_pressed() -> void:
	var path = "res://addons/RPGData/default_terms_list.txt"
	var f = FileAccess.open(path, FileAccess.READ)
	var texts = f.get_as_text().split("\n")
	data.messages.clear()
	
	for text in texts:
		var arr = text.split(", ")
		var message: RPGTerm
		if arr.size() == 2 and arr[1].is_empty():
			message = RPGTerm.new(arr[0], "", true)
		elif arr.size() == 2:
			message = RPGTerm.new(arr[0], arr[1], false)
		
		if message: data.messages.append(message)
	
	fill_terms_list()
