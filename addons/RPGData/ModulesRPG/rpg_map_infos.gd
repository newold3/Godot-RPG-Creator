@tool
class_name MapInfos
extends Resource

func get_class(): return "MapInfos"

@export var maps: Array
@export var map_names: Dictionary = {} 
@export var map_ids: Dictionary = {}
@export var map_events: Dictionary = {}
@export var map_extraction_events: Dictionary = {}

@export var global_event_lookup: Dictionary = {}


func is_rpgmap_in(node: Node) -> bool:
	if node is RPGMap:
		return true
	
	for child in node.get_children():
		var result = is_rpgmap_in(child)
		if result:
			return true
	
	return false


func validate_and_clean_project() -> void:
	var dirty: bool = false
	
	print("[MapInfos] Validating project integrity...")

	for i in range(maps.size() - 1, -1, -1):
		var map_path = maps[i]
		if not FileAccess.file_exists(map_path):
			print("[MapInfos] File not found, removing from master list: ", map_path)
			maps.remove_at(i)
			dirty = true

	var paths_to_clean: Array = []
	
	for path_key in map_events.keys():
		if not path_key in maps:
			if not paths_to_clean.has(path_key):
				paths_to_clean.append(path_key)
	
	for path_key in map_ids.keys():
		if not path_key in maps:
			if not paths_to_clean.has(path_key):
				paths_to_clean.append(path_key)

	for map_path in paths_to_clean:
		print("[MapInfos] Cleaning orphaned data from: ", map_path)
		dirty = true
		
		if map_events.has(map_path):
			var events_list = map_events[map_path]
			for event_data in events_list:
				if event_data is Dictionary and event_data.has("uid"):
					global_event_lookup.erase(event_data["uid"])
		
		map_names.erase(map_path)
		map_ids.erase(map_path)
		map_events.erase(map_path)
		map_extraction_events.erase(map_path)

	for map_path in map_events:
		if map_path in maps:
			var events_list = map_events[map_path]
			for event_data in events_list:
				if event_data is Dictionary and event_data.has("uid"):
					var uid = event_data["uid"]
					if not global_event_lookup.has(uid) or global_event_lookup[uid] != map_path:
						global_event_lookup[uid] = map_path
						dirty = true

	if dirty:
		print("[MapInfos] Cleaning completed. Saving changes...")
		save()
	else:
		print("[MapInfos] Clean project.")


## Updates internal map data from a provided array of RPGMap nodes and removes missing ones safely.
func fix_maps(data: Array) -> void:
	for map: RPGMap in data:
		var map_path = map.get_scene_file_path()
		if not map_path in maps:
			maps.append(map_path)
		set_map_name(map_path, map.name)
		set_map_id(map_path, map.internal_id)
		set_map_events(map.internal_id, map.events)
		set_map_extraction_events(map.internal_id, map.extraction_events)
	for i in range(maps.size() - 1, -1, -1):
		var map_path = maps[i]
		var map_in_data = false
		for map_node: RPGMap in data:
			if map_node.get_scene_file_path() == map_path:
				map_in_data = true
				break
		if !map_in_data and !ResourceLoader.exists(map_path):
			maps.remove_at(i)
			map_names.erase(map_path)
			map_ids.erase(map_path)
			if map_events.has(map_path):
				for item in map_events[map_path]:
					if item.has("uid"):
						global_event_lookup.erase(item["uid"])
			map_events.erase(map_path)
			map_extraction_events.erase(map_path)
	save.call_deferred()


## Updates the dictionary containing all extraction event IDs for a specific map.
func set_map_extraction_events(map_id: int, extraction_events: Array) -> void:
	var map_path_key: String = ""
	for key in map_ids:
		if map_ids[key] == map_id:
			map_path_key = key
			break
	if map_path_key == "":
		return
	var ids: PackedInt32Array = PackedInt32Array()
	for item in extraction_events:
		if item != null:
			ids.append(item.id)
	map_extraction_events[map_path_key] = ids


func set_map_name(map_path: String, map_name: String) -> void:
	map_names[map_path] = map_name


func set_map_id(map_path: String, map_id: int) -> void:
	map_ids[map_path] = map_id


func get_map_name_from_path(map_path: String) -> String:
	return map_names.get(map_path, "")


func get_map_name_from_id(map_id: int) -> String:
	for map_path: String in map_ids.keys():
		if map_ids[map_path] == map_id:
			return map_names.get(map_path, "")
	
	return ""


func get_path_from_id(map_id: int) -> String:
	for map_path in map_ids.keys():
		if map_ids[map_path] == map_id:
			return map_path
	
	return ""


func _convert_event_to_dict(event: RPGEvent) -> Dictionary:
	var pages: Array[Dictionary] = []
	var quest_pages: PackedInt32Array = []
	var quest_ids: PackedInt32Array = []
	
	for i in event.pages.size():
		var page: RPGEventPage = event.pages[i]
		pages.append({"name": page.name, "uid": page._uniq_id})
		if page.is_quest_page:
			quest_pages.append(i)
	
	for q in event.quests:
		quest_ids.append(q.id)
	
	return {
		"id": event.id,
		"uid": event._uniq_id,
		"name": event.name,
		"pages": pages,
		"quest_pages": quest_pages,
		"quest_ids": quest_ids,
		"quest_count": event.quests.size()
	}


func set_map_events(map_id: int, events: RPGEvents) -> void:
	var map_path_key: String = ""
	
	for key in map_ids:
		if map_ids[key] == map_id:
			map_path_key = key
			break
	
	if map_path_key == "":
		return

	if map_events.has(map_path_key):
		var old_items = map_events[map_path_key]
		for item in old_items:
			if item.has("uid"):
				var old_uid = item["uid"]
				if global_event_lookup.get(old_uid) == map_path_key:
					global_event_lookup.erase(old_uid)

	var items: Array = []
	for ev: RPGEvent in events.events:
		var event_data = _convert_event_to_dict(ev)
		items.append(event_data)
		global_event_lookup[ev._uniq_id] = map_path_key
	
	map_events[map_path_key] = items


func update_single_event(map_id: int, event: RPGEvent) -> void:
	var map_path = get_path_from_id(map_id)
	if map_path.is_empty():
		push_warning("RPGMapsInfo: No map with ID %s found to update event." % map_id)
		return

	var new_event_data = _convert_event_to_dict(event)

	if map_events.has(map_path):
		var events_list: Array = map_events[map_path]
		var found = false
		
		for i in events_list.size():
			if events_list[i].get("uid", -1) == event._uniq_id or events_list[i]["id"] == event.id:
				events_list[i] = new_event_data
				found = true
				break
		
		if not found:
			events_list.append(new_event_data)
	else:
		map_events[map_path] = [new_event_data]

	global_event_lookup[event._uniq_id] = map_path
	
	save.call_deferred()


func get_map_events(map_id: int) -> Array:
	var events: Array = []
	for key in map_ids:
		if map_ids[key] == map_id:
			events = map_events[key]
			break
	return events


func get_event_name(map_id: int, event_id: int) -> String:
	var map_name = get_map_name_from_id(map_id)
	var events = get_map_events(map_id)
	for event_data in events:
		if event_data.has("id") and event_data["id"] == event_id:
			return event_data.get("name", "")
		if event_data.has("uid") and event_data["uid"] == event_id:
			return event_data.get("name", "")
	return ""


func get_map_path_for_event(event_uniq_id: int) -> String:
	return global_event_lookup.get(event_uniq_id, "")

func uniq_id_exists_globally(event_uniq_id: int) -> bool:
	return global_event_lookup.has(event_uniq_id)


func get_map_extraction_events(map_id: int) -> PackedInt32Array:
	var extraction_events: PackedInt32Array = PackedInt32Array()
	for key in map_ids:
		if map_ids[key] == map_id:
			extraction_events = map_extraction_events[key]
			break
	
	return extraction_events


func update_file_path(old_file: String, new_file: String) -> void:
	var index = maps.find(old_file)
	if index >= 0:
		var old_map_name = map_names.get(old_file, "")
		var old_map_id = map_ids.get(old_file, 0)
		
		var old_events = map_events.get(old_file, [])
		var old_extractions = map_extraction_events.get(old_file, [])
		
		if new_file.length() > 0:
			maps[index] = new_file
		else:
			maps.remove_at(index)

		map_names.erase(old_file)
		map_ids.erase(old_file)
		map_events.erase(old_file)
		map_extraction_events.erase(old_file)
		
		if new_file.length() > 0:
			map_names[new_file] = old_map_name
			map_ids[new_file] = old_map_id
			map_events[new_file] = old_events
			map_extraction_events[new_file] = old_extractions
			
			for item in old_events:
				if item.has("uid"):
					global_event_lookup[item["uid"]] = new_file
		else:
			for item in old_events:
				if item.has("uid"):
					global_event_lookup.erase(item["uid"])
		
		save.call_deferred()


func save() -> void:
	DatabaseLoader.save_map_infos()
