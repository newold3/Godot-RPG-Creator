@tool
extends HBoxContainer

## The style applied to the title of the terms.
@export var terms_title_style: StyleBox

var data: RPGTerms
var database: RPGDATA
var filter_update_timer: float = 0.0
var can_delete_message: bool = false

const CLOSE_ICON = preload("res://addons/CustomControls/Images/close_icon.png")



## Initializes the term list and connects inputs.
func _ready() -> void:
	%TermList.lock_enter = true
	%TermList.get_item_list().gui_input.connect(_on_term_list_gui_input)


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
		
		if message.unselectable:
			if current_header != null and items_in_current_category.size() > 0:
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
	
	if current_header != null and items_in_current_category.size() > 0:
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
	for index in indexes:
		data.update_message(%TermList.get_item_metadata(index), "")
	
	var selected_items = %TermList.get_selected_items()
	await fill_terms_list()
	%TermList.select_items(selected_items)


## Triggers edition or creation of a term when activated.
func _on_term_list_item_activated(index: int) -> void:
	var real_idx = %TermList.get_item_metadata(index)
	if real_idx != null and index != %TermList.get_item_count() - 1:
		if %TermList.is_item_selectable(index):
			var path = "res://addons/CustomControls/Dialogs/select_text_dialog.tscn"
			var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
			var item_name = %TermList.get_column(index)[0]
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
	data.remove_message_at(real_idx)
	await fill_terms_list()
	%TermList.select(index)


## Intercepts inputs to handle fast selection and deletion.
func _on_term_list_gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("EnterKey") and !event.is_ctrl_pressed():
		var selected_items = %TermList.get_selected_items()
		if selected_items.size() == 1:
			_on_term_list_item_activated(selected_items[0])
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		var index = %TermList.get_item_at_position(event.position)
		if index != -1 and %TermList.get_item_metadata(index) != null:
			var real_idx = %TermList.get_item_metadata(index)
			var message: RPGTerm = data.get_message_obj(real_idx)
			if message and message.is_user_message:
				if event.position.x <= CLOSE_ICON.get_width():
					%TermList.get_item_list().mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
					can_delete_message = true
				else:
					%TermList.get_item_list().mouse_default_cursor_shape = Control.CURSOR_ARROW
					can_delete_message = false
	elif can_delete_message and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		var index = %TermList.get_item_at_position(event.position)
		_confirm_remove_message(index)


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
	var terms = FileAccess.open("res://addons/RPGData/default_terms_list.txt", FileAccess.READ).get_as_text().split("\n")
	
	for term: String in terms:
		var new_term: RPGTerm
		if term.find(",") != -1:
			var id = term.get_slice(", ", 0)
			var message = term.get_slice(", ", 1)
			new_term = RPGTerm.new(id, message, false)
		else:
			new_term = RPGTerm.new(term, "", true)
	
		data.messages.append(new_term)
		
	if data.messages.size() > 0:
		data.messages.append(RPGTerm.new("User Messages", "", true))
		data.messages.append_array(old_messages)
	
	fill_terms_list()
