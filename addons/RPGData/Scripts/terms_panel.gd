@tool
extends HBoxContainer


@export var terms_title_style: StyleBox

var data: RPGTerms
var database: RPGDATA

var real_indexes: Dictionary

var filter_update_timer: float = 0.0

var can_delete_message: bool = false

const CLOSE_ICON = preload("res://addons/CustomControls/Images/close_icon.png")


func _ready() -> void:
	# Prevents the dialog from closing automatically when pressing enter if this control is set to on.
	%TermList.lock_enter = true
	%TermList.get_item_list().gui_input.connect(_on_term_list_gui_input)


func _process(delta: float) -> void:
	if filter_update_timer > 0:
		filter_update_timer -= delta
		if filter_update_timer <= 0.0:
			filter_update_timer = 0.0
			update_terms_by_filter()


func update_terms_by_filter() -> void:
	var node = %TermList
	node.set_filter(%Filter.text)
	var selected_items = node.get_selected_items()
	
	await fill_terms_list()
	
	node.set_selected_items(selected_items)
	


func set_data(real_data: RPGTerms) -> void:
	if !is_inside_tree():
		return
		
	data = real_data
	
	await get_tree().process_frame
	await fill_terms_list()
	
	#data.messages.resize(real_indexes.size())


func fill_terms_list() -> void:
	var node = %TermList
	node.clear()
	
	real_indexes.clear()
	
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
	var current_header_index = -1
	var items_in_current_category: Array = []
	
	for message: RPGTerm in data.messages:
		var columns: Array
		
		if message.unselectable:
			# Procesar la categoría anterior antes de empezar una nueva
			if current_header != null and items_in_current_category.size() > 0:
				# Añadir el encabezado
				unselectable_items.append(current_index)
				columns = [current_header.id, current_header.text]
				node.add_column(columns)
				node.add_row_color(current_index, terms_title_style)
				fast_selection.add_item(current_header.id)
				current_index += 1
				
				# Añadir los items que pasaron el filtro
				for item_data in items_in_current_category:
					node.add_column(item_data.columns)
					if item_data.is_user_message:
						node.add_custom_icon(current_index, CLOSE_ICON)
					real_indexes[current_index] = item_data.real_index
					current_index += 1
			
			# Guardar el nuevo encabezado y limpiar items temporales
			current_header = message
			current_header_index = current_index
			items_in_current_category.clear()
		else:
			# Verificar si el item pasa el filtro
			if filter.length() == 0 or message.text.to_lower().find(filter) != -1 or message.id.to_lower().find(filter) != -1:
				# Guardar el item temporalmente
				var item_data = {
					"columns": [message.id, message.text],
					"is_user_message": message.is_user_message,
					"real_index": real_index
				}
				items_in_current_category.append(item_data)
			
			real_index += 1
	
	# Procesar la última categoría
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
			real_indexes[current_index] = item_data.real_index
			current_index += 1
	
	fast_selection.select(0)
	
	await node.columns_setted
	
	for i in unselectable_items:
		node.set_item_selectable(i, false)


func _on_term_list_delete_pressed(indexes: PackedInt32Array) -> void:
	for index in indexes:
		data.update_message(real_indexes[index], "")
	
	var selected_items = %TermList.get_selected_items()
	await fill_terms_list()
	%TermList.select_items(selected_items)


func _on_term_list_item_activated(index: int) -> void:
	
	if real_indexes.has(index):
		if %TermList.is_item_selectable(index):
			# edit message
			var path = "res://addons/CustomControls/Dialogs/select_text_dialog.tscn"
			var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
			var item_name = %TermList.get_column(index)[0]
			dialog.title = TranslationManager.tr(item_name)
			dialog.set_text(data.get_message(real_indexes[index]))
			dialog.text_selected.connect(_update_term.bind(index))
	else:
		# create new message
		var path = "res://addons/CustomControls/Dialogs/create_term_dialog.tscn"
		var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
		dialog.message_selected.connect(_create_new_message)


func _update_term(text: String, index: int) -> void:
	data.update_message(real_indexes[index], text)
	await fill_terms_list()
	%TermList.select(index)


func _create_new_message(id: String, text: String) -> void:
	if id:
		var message = data.create_message(id, text, false, true, false)
		if message:
			await fill_terms_list()
			var selected_id = %TermList.get_item_list().get_item_count() - 2
			real_indexes[selected_id] = data.messages.size() - 1
			%TermList.select(selected_id)


func _confirm_remove_message(index: int) -> void:
	var confirm_dialog := ConfirmationDialog.new()
	confirm_dialog.title = "Confirm Remove Message"
	confirm_dialog.dialog_text = "Do you want to delete this message?\n(If the game tries to display this message\nand it doesn’t exist, an empty message will appear)."
	confirm_dialog.ok_button_text = "Remove Message"
	confirm_dialog.confirmed.connect(_remove_message.bind(index))
	add_child(confirm_dialog)
	confirm_dialog.popup_centered()


func _remove_message(index: int) -> void:
	var real_index = real_indexes[index]
	data.remove_message_at(real_index)
	await fill_terms_list()
	%TermList.select(index)


func _on_term_list_gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("EnterKey") and !event.is_ctrl_pressed():
		var selected_items = %TermList.get_selected_items()
		if selected_items.size() == 1:
			_on_term_list_item_activated(selected_items[0])
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		var index = %TermList.get_item_at_position(event.position)
		if index != -1 and index in real_indexes:
			var message: RPGTerm = data.get_message_obj(real_indexes[index])
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
