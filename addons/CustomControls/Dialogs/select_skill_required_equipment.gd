@tool
extends Window


var database: RPGDATA
var target_index: int

signal item_selected(target_index: int, selected_equipment: int, selected_id: int)


func _ready() -> void:
	close_requested.connect(queue_free)


func set_data(_database: RPGDATA, _target_index: int, selected_equipment: int, selected_id: int) -> void:
	target_index = _target_index
	database = _database
	selected_equipment = clamp(selected_equipment, 0, 1)
	%EquipmentList.select(selected_equipment)
	fill_items(selected_equipment, selected_id - 1)


func fill_items(selected_equipment: int, selected_id: int) -> void:
	%ItemList.clear()
	
	if !database: return
	
	var data = database.weapons if selected_equipment == 0 else database.armors
	
	for i in range(1, data.size(), 1):
		var data_name = str(i).pad_zeros(str(data.size()).length()) + ": " + data[i].name
		%ItemList.add_item(data_name)
	
	if %ItemList.get_item_count() > selected_id and selected_id >= 0:
		%ItemList.select(selected_id)
	else:
		%ItemList.select(0)


func _on_ok_button_pressed() -> void:
	var selected_equipment = %EquipmentList.get_selected_id()
	var selected_id = %ItemList.get_selected_id() + 1
	item_selected.emit(target_index, selected_equipment, selected_id)
	queue_free()


func _on_cancel_button_pressed() -> void:
	queue_free()


func _on_equipment_list_item_selected(index: int) -> void:
	fill_items(index, 0)
