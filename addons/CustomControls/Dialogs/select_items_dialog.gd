@tool
extends Window

var current_data: Array
var current_type = 0

signal changed(data: Array)



#region Lifecycle
func _ready() -> void:
	prepare_buttons()
	close_requested.connect(queue_free)
#endregion



#region Setup
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
#endregion



#region UI_Handlers
func _button_toggled(toggled: bool, type: int) -> void:
	current_type = type
	if toggled:
		_fill_item_list()



func _fill_item_list() -> void:
	var node = %ItemList
	node.clear()
	
	var db_key = _get_db_key()
	var source_data = RPGSYSTEM.database[db_key]
	var type_name = [tr("Items"), tr("Weapons"), tr("Armors"), tr("Costumes")][current_type]
	
	var items_to_select: PackedInt32Array = []
	var items_selected = current_data.filter(func(item: Dictionary): return item.get("type", 0) == current_type)
	
	for i in range(1, source_data.size(), 1):
		var item_data = source_data[i]
		if not item_data: continue
		
		var uid = RPGSYSTEM.id_to_uid(db_key, i)
		var column = [type_name, i, item_data.name]
		node.add_column(column)
		
		if items_selected.any(func(item: Dictionary): return item.get("id", 1) == uid):
			items_to_select.append(i - 1)
	
	await node.columns_setted
	
	if items_to_select.size() > 0:
		node.select_items(items_to_select)



func _get_db_key() -> String:
	match current_type:
		0: return "items"
		1: return "weapons"
		2: return "armors"
		3: return "costumes"
	return "items"



func _on_ok_button_pressed() -> void:
	changed.emit(current_data)
	queue_free()



func _on_cancel_button_pressed() -> void:
	queue_free()
#endregion



#region List_Interaction
func _on_item_list_multi_selected(index: int, selected: bool, erase_enabled: bool = true) -> void:
	var real_index = index + 1
	var db_key = _get_db_key()
	var uid = RPGSYSTEM.id_to_uid(db_key, real_index)
	
	var has_index = current_data.any(func(d: Dictionary): return d.type == current_type and d.id == uid)
	
	if selected and not has_index:
		current_data.append({"type": current_type, "id": uid})
	elif not selected and has_index:
		for d: Dictionary in current_data:
			if d.type == current_type and d.id == uid:
				current_data.erase(d)
				break



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
	pass



func _on_item_list_copy_requested(indexes: PackedInt32Array) -> void:
	pass



func _on_item_list_cut_requested(indexes: PackedInt32Array) -> void:
	pass



func _on_item_list_delete_pressed(indexes: PackedInt32Array) -> void:
	pass



func _on_item_list_paste_requested(index: int) -> void:
	pass
#endregion
