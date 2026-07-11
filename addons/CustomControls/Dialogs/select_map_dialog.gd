@tool
extends Window


var area_enabled: bool = false


signal selected_item(map_id: int)
signal area_selected(map_id: int, area_id: int)


func _ready() -> void:
	close_requested.connect(queue_free)
	%MapList.item_selected.connect(_on_map_list_item_selected)
	fill_maps()


func enable_areas(value: bool) -> void:
	area_enabled = value
	%AreaContainer.visible = value
	if value:
		var selected_items = %MapList.get_selected_items()
		if not selected_items.is_empty():
			fill_areas(selected_items[0])
		else:
			%AreaList.clear()


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
		if area_enabled:
			fill_areas(0)


func fill_areas(map_index: int) -> void:
	var area_list = %AreaList
	area_list.clear()
	
	var map_id = %MapList.get_item_metadata(map_index)
	var regions = RPGMapsInfo.get_event_regions(map_id)
	
	area_list.add_item(tr("None"))
	area_list.set_item_metadata(-1, -1)
	
	for region in regions:
		var region_id = region.get("id", 0)
		var region_name = region.get("name", "")
		var item_text = ""
		if region_name.strip_edges().is_empty():
			item_text = "%s: Event Region #%s" % [region_id, region_id]
		else:
			item_text = "%s: %s" % [region_id, region_name]
		
		area_list.add_item(item_text)
		area_list.set_item_metadata(-1, region_id)
		
	if area_list.get_item_count() > 0:
		area_list.select(0)


func set_selected(map_id: int, area_selected: int = -1) -> void:
	var node = %MapList
	var map_found: bool = false
	var selected_index: int = -1
	for i in node.get_item_count():
		if node.get_item_metadata(i) == map_id:
			node.select(i)
			map_found = true
			selected_index = i
			break
	
	if map_found:
		if area_enabled:
			fill_areas(selected_index)
			if area_selected != -1:
				var area_node = %AreaList
				for j in area_node.get_item_count():
					if area_node.get_item_metadata(j) == area_selected:
						area_node.select(j)
						break


func _on_ok_button_pressed() -> void:
	var node1 = %MapList
	var map_ids = node1.get_selected_items()
	var node2 = %AreaList
	var area_ids = node2.get_selected_items()
	
	if map_ids.is_empty():
		printerr("No Map selected. Please select a valid Map")
		return
	
	if area_enabled and area_ids.is_empty():
		printerr("No Area selected. Please select a valid Area in the selected map")
		return
		
	if area_enabled:
		area_selected.emit(
			node1.get_item_metadata(map_ids[0]),
			node2.get_item_metadata(area_ids[0])
		)
	else:
		selected_item.emit(node1.get_item_metadata(map_ids[0]))
	
	queue_free()


func _on_cancel_button_pressed() -> void:
	queue_free()


func _on_map_list_item_selected(index: int) -> void:
	if area_enabled:
		fill_areas(index)


func _on_map_list_item_activated(index: int) -> void:
	_on_ok_button_pressed()


func _on_area_list_item_activated(index: int) -> void:
	_on_ok_button_pressed()
