@tool
extends Window

signal selected_item(map_id: int)


func _ready() -> void:
	close_requested.connect(queue_free)
	fill_maps()


func fill_maps() -> void:
	var node = %MapList
	node.clear()
	for i: int in range(0, RPGSYSTEM.map_infos.map_infos.maps.size(), 1):
		var map = RPGSYSTEM.map_infos.map_infos.maps[i]
		var map_id = RPGSYSTEM.map_infos.get_map_id(map)
		var map_name = RPGSYSTEM.map_infos.get_map_name_from_id(map_id)
		node.add_item("Map: %s" % map_name)
		node.set_item_metadata(-1, map_id)
	
	if node.get_item_count() > 0:
		node.select(0)


func set_selected(map_id: int) -> void:
	var node = %MapList
	for i in node.get_item_count():
		if node.get_item_metadata(i) == map_id:
			node.select(i)
			break


func _on_ok_button_pressed() -> void:
	var node = %MapList
	var indexes = node.get_selected_items()
	selected_item.emit(node.get_item_metadata(indexes[0]))
	queue_free()


func _on_cancel_button_pressed() -> void:
	queue_free()


func _on_map_list_item_activated(index: int) -> void:
	_on_ok_button_pressed()
