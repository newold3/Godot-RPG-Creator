@tool
extends Window

#region Variables
var database: RPGDATA
var target_index: int

signal item_selected(target_index: int, selected_equipment: int, selected_uid: int)
#endregion



#region Lifecycle
## Initializes the dialog and connects the close signal
func _ready() -> void:
	close_requested.connect(queue_free)
#endregion



#region Setup
## Loads the dialog with the current selected equipment data and UIDs
func set_data(_database: RPGDATA, _target_index: int, selected_equipment: int, selected_uid: int) -> void:
	target_index = _target_index
	database = _database
	selected_equipment = clamp(selected_equipment, 0, 1)
	
	if %EquipmentList.has_method("select"):
		if %EquipmentList is ItemList:
			%EquipmentList.select(selected_equipment, true)
		else:
			%EquipmentList.select(selected_equipment)
			
	var final_uid = selected_uid if selected_uid > 1000000 else 0
	fill_items(selected_equipment, final_uid)



## Fills the items dropdown with weapons or armors dynamically and stores UIDs
func fill_items(selected_equipment: int, selected_uid: int) -> void:
	%ItemList.clear()
	
	if !database: return
	
	var db_key = "weapons" if selected_equipment == 0 else "armors"
	var data_list = database[db_key]
	var match_idx = 0
	
	for i in range(1, data_list.size(), 1):
		var item = data_list[i]
		if not item: continue
		
		var is_sep = false
		if item and "separator" in item and item.separator != null:
			is_sep = true
		
		var id_padded = str(i).pad_zeros(str(data_list.size()).length())
		var data_name = "%s: %s" % [id_padded, item.name]
		%ItemList.add_item(data_name)
		
		var item_index = %ItemList.get_item_count() - 1
		if is_sep:
			%ItemList.set_item_disabled(item_index, true)
		%ItemList.set_item_metadata(item_index, item._uniq_id)
		
		if item._uniq_id == selected_uid:
			match_idx = item_index
	
	if %ItemList.get_item_count() > 0:
		if %ItemList is ItemList:
			%ItemList.select(match_idx, true)
		else:
			%ItemList.select(match_idx)
#endregion



#region UI Handlers
## Helper to safely get the selected index handling both OptionButton and ItemList correctly in Godot 4
func _get_safe_index(node: Node) -> int:
	if node is ItemList:
		var items = node.get_selected_items()
		return items[0] if items.size() > 0 else 0
	elif node is OptionButton:
		return node.selected
		
	if node.has_method("get_selected_id"):
		return node.get_selected_id()
		
	return 0



## Submits the selected equipment UID to the parent and closes the dialog
func _on_ok_button_pressed() -> void:
	var selected_equipment = _get_safe_index(%EquipmentList)
	var idx = _get_safe_index(%ItemList)
	
	var selected_uid = %ItemList.get_item_metadata(idx) if idx != -1 else 0
	
	item_selected.emit(target_index, selected_equipment, selected_uid)
	queue_free()



## Cancels the operation and closes the dialog
func _on_cancel_button_pressed() -> void:
	queue_free()



## Refreshes the items list when the equipment category changes
func _on_equipment_list_item_selected(index: int) -> void:
	fill_items(index, 0)
#endregion
