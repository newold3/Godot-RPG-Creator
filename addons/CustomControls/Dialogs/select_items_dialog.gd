@tool
extends Window

var current_data: Array
var current_type = 0

signal changed(data: Array)


func _ready() -> void:
	prepare_buttons()
	close_requested.connect(queue_free)


func prepare_buttons() -> void:
	var buttons = %TypeContainer.get_children()
	var button_group = ButtonGroup.new()
	for i in buttons.size():
		var button: CustomSimpleButton = buttons[i]
		button.button_group = button_group
		button.toggled.connect(_button_toggled.bind(i))


func set_data(data: Array) -> void:
	current_data = data.duplicate(true)
	%Button1.set_pressed(true)


func _button_toggled(toggled: bool, type: int) -> void:
	current_type = type
	if toggled:
		_fill_item_list()


func _fill_item_list() -> void:
	var node = %ItemList
	node.clear()
	var source_data
	match current_type:
		0: source_data = RPGSYSTEM.database.items
		1: source_data = RPGSYSTEM.database.weapons
		2: source_data = RPGSYSTEM.database.armors
	
	var type_name = [tr("Items"), tr("Weapons"), tr("Armors")][current_type]
	var items: PackedInt32Array = []
	var items_selected = current_data.filter(func(item: Dictionary): return item.get("type", 0) == current_type)
	for i in range(1, source_data.size(), 1):
		var column = [type_name, i, source_data[i].name]
		node.add_column(column)
		if items_selected.any(
			func(item: Dictionary): return item.get("id", 1) == i and item.get("type", 0) == current_type):
			items.append(i - 1)
	
	await node.columns_setted
	
	if items.size() > 0:
		node.select_items(items)


func _on_ok_button_pressed() -> void:
	changed.emit(current_data)
	queue_free()


func _on_cancel_button_pressed() -> void:
	queue_free()


func _on_item_list_copy_requested(indexes: PackedInt32Array) -> void:
	pass # Replace with function body.


func _on_item_list_cut_requested(indexes: PackedInt32Array) -> void:
	pass # Replace with function body.


func _on_item_list_delete_pressed(indexes: PackedInt32Array) -> void:
	pass # Replace with function body.


func _on_item_list_paste_requested(index: int) -> void:
	pass # Replace with function body.


func _on_item_list_multi_selected(index: int, selected: bool, erase_enabled: bool = true) -> void:
	var items_to_erase = []
	if not (Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_SHIFT)) and selected and erase_enabled:
		for item in current_data:
			if item.get("type", 0) == current_type:
				items_to_erase.append(item)

		for item in items_to_erase:
			current_data.erase(item)
		
	var real_index = index + 1
	if selected:
		if not current_data.any(func(item: Dictionary): return item.get("id", 1) == real_index and item.get("type", 0) == current_type):
			current_data.append({"type": current_type, "id": real_index})
	else:
		for item in current_data:
			if item.get("id", 1) == real_index and item.get("type", 0) == current_type:
				current_data.erase(item)
				%ItemList.deselect(index)
				break
	
	if items_to_erase:
		for item in items_to_erase:
			%ItemList.deselect(item.id)


func _on_select_all_toggled(toggled_on: bool) -> void:
	if toggled_on:
		var itemlist = %ItemList
		for i in itemlist.get_item_count():
			itemlist.select(i, false)
			itemlist.multi_selected.emit(i, true, false)
		%SelectAll.set_pressed_no_signal(false)


func _on_deselect_all_toggled(toggled_on: bool) -> void:
	if toggled_on:
		var itemlist = %ItemList
		for i in itemlist.get_item_count():
			itemlist.deselect(i)
			itemlist.multi_selected.emit(i, false, false)
		%DeselectAll.set_pressed_no_signal(false)


func _on_clear_duplicates_toggled(toggled_on: bool) -> void:
	pass # Replace with function body.
