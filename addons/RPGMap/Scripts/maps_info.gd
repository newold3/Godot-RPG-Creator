@tool
extends Node

var map_infos: MapInfos


func _ready() -> void:
	load_maps_info()


func load_maps_info() -> void:
	map_infos = DatabaseLoader.load_map_infos()
	
	if map_infos == null:
		map_infos = MapInfos.new()
	
	map_infos.validate_and_clean_project()


func fix_maps(data: Array) -> void:
	map_infos.fix_maps(data)


func set_map_name(map_path: String, map_name: String) -> void:
	map_infos.set_map_name(map_path, map_name)


# Unsafe method. If there are two or more maps with
# duplicate names the map returned by this function
# may not be the one you were really looking for.
func get_map_by_name(map_name: String) -> String:
	var map_path = ""
	for map in map_infos.map_names.keys():
		if map_infos.map_names[map] == map_name:
			map_path = map
			break
		
	return map_path


func get_map_by_id(map_id: int) -> String:
	var map_path = ""
	for map in map_infos.map_ids.keys():
		if map_infos.map_ids[map] == map_id:
			map_path = map
			break
			
	return map_path


func get_map_id(map_path: String) -> int:
	if map_path in map_infos.map_ids:
		return map_infos.map_ids[map_path]
	else:
		return -1


func get_events(map_id: int) -> Array:
	var events: Array = []
	var map = get_map_by_id(map_id)
	if map in map_infos.map_events:
		events = map_infos.map_events[map]
	
	return events


func get_event_name(map_id: int, event_id: int) -> String:
	var event_name = ""
	
	var map = get_map_by_id(map_id)
	if map in map_infos.map_events:
		var events = map_infos.map_events[map]
		for event in events:
			if event.uid == event_id or event.id == event_id:
				event_name = event.name
				break
	
	return event_name


func get_event(map_id: int, event_id: int) -> Dictionary:
	var map = get_map_by_id(map_id)
	if map in map_infos.map_events:
		var events = map_infos.map_events[map]
		for event in events:
			if event.uid == event_id or event.id == event_id:
				return event
	
	return {}


func get_event_page(map_id: int, event_id: int, page_id: int) -> RPGEventPage:
	var map = get_map_by_id(map_id)
	if map in map_infos.map_events:
		var events = map_infos.map_events[map]
		for event in events:
			if event.uid == event_id or event.id == event_id:
				for i in event.pages.size():
					var page = event.pages[i]
					if i == page_id or page.uid == page_id:
						return page
	
	return null


func get_event_page_name(map_id: int, event_id: int, page_id: int) -> String:
	var page_name = ""
	
	var map = get_map_by_id(map_id)
	if map in map_infos.map_events:
		var events = map_infos.map_events[map]
		for event in events:
			if event.uid == event_id or event.id == event_id:
				for i in event.pages.size():
					var page = event.pages[i]
					if page.uid == page_id:
						page_name = "Page %s" % (i + 1) + (" (" + page.name + ")" if not page.name.is_empty() else "")
						return page_name
	
	return page_name


func get_event_regions(map_id: int) -> Array:
	return map_infos.get_map_event_regions(map_id)


func get_event_region_name(map_id: int, region_id: int) -> String:
	return map_infos.get_event_region_name(map_id, region_id)


func get_enemy_spawn_regions(map_id: int) -> Array:
	return map_infos.get_map_enemy_spawn_regions(map_id)


func get_enemy_spawn_region_name(map_id: int, region_id: int) -> String:
	return map_infos.get_enemy_spawn_region_name(map_id, region_id)


func get_map_name_from_path(map_path: String) -> String:
	return map_infos.get_map_name_from_path(map_path)


func get_map_name_from_id(map_id: int) -> String:
	return map_infos.get_map_name_from_id(map_id)


func update_file_path(old_file: String, new_file: String) -> void:
	map_infos.update_file_path.call_deferred(old_file, new_file)


func update_single_event(map_id: int, event: RPGEvent) -> void:
	map_infos.update_single_event(map_id, event)


func _exit_tree() -> void:
	if map_infos:
		map_infos.save()
