@tool
class_name MapInfos
extends Resource

#region VARIABLES

## Array containing the file paths of all registered RPGMaps.
@export var maps: Array

## Dictionary mapping map paths to their string names.
@export var map_names: Dictionary = {} 

## Dictionary mapping map paths to their internal integer IDs.
@export var map_ids: Dictionary = {}

## Dictionary mapping map paths to their array of converted event dictionaries.
@export var map_events: Dictionary = {}

## Dictionary mapping map paths to their packed array of extraction event IDs.
@export var map_extraction_events: Dictionary = {}

## Dictionary mapping map paths to their array of converted event region dictionaries.
@export var map_event_regions: Dictionary = {}

## Dictionary mapping map paths to their array of converted enemy spawn region dictionaries.
@export var map_enemy_spawn_regions: Dictionary = {}

## Dictionary mapping global unique event IDs to their corresponding map paths.
@export var global_event_lookup: Dictionary = {}

#endregion


#region CORE METHODS

## Returns the class name as a string.
func get_class() -> String:
	return "MapInfos"



## Recursively checks if a node or any of its children is an RPGMap.
func is_rpgmap_in(node: Node) -> bool:
	if node is RPGMap:
		return true
	
	for child in node.get_children():
		var result = is_rpgmap_in(child)
		if result:
			return true
	
	return false



## Physically deletes the .tres events file associated with a map ID to keep the project clean.
func _delete_events_file(map_id: int) -> void:
	var events_path = "res://data/MapEvents/Map_%s_events.tres" % str(map_id)
	
	if FileAccess.file_exists(events_path):
		var err = DirAccess.remove_absolute(events_path)
		if err == OK:
			print("[MapInfos] Deleted orphaned events file: ", events_path)
		else:
			push_error("[MapInfos] Failed to delete events file: ", events_path)



## Validates project integrity by cleaning orphaned data and physically deleting missing map event files.
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
		
		if map_ids.has(map_path):
			_delete_events_file(map_ids[map_path])
		
		if map_events.has(map_path):
			var events_list = map_events[map_path]
			for event_data in events_list:
				if event_data is Dictionary and event_data.has("uid"):
					global_event_lookup.erase(event_data["uid"])
		
		map_names.erase(map_path)
		map_ids.erase(map_path)
		map_events.erase(map_path)
		map_extraction_events.erase(map_path)
		map_event_regions.erase(map_path)
		map_enemy_spawn_regions.erase(map_path)

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



## Updates internal map data from a provided array of RPGMap nodes and removes missing ones safely, deleting their files.
func fix_maps(data: Array) -> void:
	for map: RPGMap in data:
		var map_path = map.get_scene_file_path()
		if not map_path in maps:
			maps.append(map_path)
		set_map_name(map_path, map.name)
		set_map_id(map_path, map.internal_id)
		set_map_events(map.internal_id, map.events)
		set_map_extraction_events(map.internal_id, map.extraction_events)
		set_map_event_regions(map.internal_id, map.event_regions)
		set_map_enemy_spawn_regions(map.internal_id, map.regions)
	
	for i in range(maps.size() - 1, -1, -1):
		var map_path = maps[i]
		var map_in_data = false
		for map_node: RPGMap in data:
			if map_node.get_scene_file_path() == map_path:
				map_in_data = true
				break
		
		if !map_in_data and !ResourceLoader.exists(map_path):
			maps.remove_at(i)
			
			var map_id = map_ids.get(map_path, 0)
			if map_id != 0:
				_delete_events_file(map_id)
				
			map_names.erase(map_path)
			map_ids.erase(map_path)
			if map_events.has(map_path):
				for item in map_events[map_path]:
					if item.has("uid"):
						global_event_lookup.erase(item["uid"])
			map_events.erase(map_path)
			map_extraction_events.erase(map_path)
			map_event_regions.erase(map_path)
			map_enemy_spawn_regions.erase(map_path)
			
	save.call_deferred()

#endregion


#region SETTERS AND DATA UPDATE

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



## Updates the dictionary containing all event region data for a specific map.
func set_map_event_regions(map_id: int, event_regions: Array) -> void:
	var map_path_key: String = ""
	for key in map_ids:
		if map_ids[key] == map_id:
			map_path_key = key
			break
			
	if map_path_key == "":
		return
		
	var items: Array = []
	for item in event_regions:
		if item != null:
			items.append({
				"id": item.id,
				"name": item.name
			})
			
	map_event_regions[map_path_key] = items



## Updates the dictionary containing all enemy spawn region data for a specific map.
func set_map_enemy_spawn_regions(map_id: int, enemy_spawn_regions: Array) -> void:
	var map_path_key: String = ""
	for key in map_ids:
		if map_ids[key] == map_id:
			map_path_key = key
			break
			
	if map_path_key == "":
		return
		
	var items: Array = []
	for item in enemy_spawn_regions:
		if item != null:
			items.append({
				"id": item.id,
				"name": item.name
			})
			
	map_enemy_spawn_regions[map_path_key] = items



## Registers the map name in the dictionary based on its path.
func set_map_name(map_path: String, map_name: String) -> void:
	map_names[map_path] = map_name



## Registers the map ID in the dictionary based on its path.
func set_map_id(map_path: String, map_id: int) -> void:
	map_ids[map_path] = map_id



## Updates the events for a specific map and rebuilds the global lookup registry.
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



## Updates a single event inside the dictionary and resaves the resource.
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

#endregion


#region GETTERS

## Get the list of maps added to the project (list of unique IDs).
func get_map_list() -> PackedInt64Array:
	var list: PackedInt64Array = []
	for map_path in map_ids.keys():
		var id = map_ids[map_path]
		# ignore core maps
		if id in [8600607177269889, 8017326834547071]: continue
		list.append(id)

	return list


## Returns the map name given its file path.
func get_map_name_from_path(map_path: String) -> String:
	return map_names.get(map_path, "")



## Returns the map name given its internal ID.
func get_map_name_from_id(map_id: int) -> String:
	for map_path: String in map_ids.keys():
		if map_ids[map_path] == map_id:
			return map_names.get(map_path, "")
	
	return ""



## Returns the map path given its internal ID.
func get_path_from_id(map_id: int) -> String:
	for map_path in map_ids.keys():
		if map_ids[map_path] == map_id:
			return map_path
	
	return ""



## Retrieves the array of events dictionaries for a given map ID.
func get_map_events(map_id: int) -> Array:
	var events: Array = []
	for key in map_ids:
		if map_ids[key] == map_id:
			events = map_events[key]
			break
	return events



## Retrieves the name of a specific event using its map ID and event ID.
func get_event_name(map_id: int, event_id: int) -> String:
	var map_name = get_map_name_from_id(map_id)
	var events = get_map_events(map_id)
	
	for event_data in events:
		if event_data.has("id") and event_data["id"] == event_id:
			return event_data.get("name", "")
		if event_data.has("uid") and event_data["uid"] == event_id:
			return event_data.get("name", "")
			
	return ""



## Returns the map path where a globally unique event is stored.
func get_map_path_for_event(event_uniq_id: int) -> String:
	return global_event_lookup.get(event_uniq_id, "")



## Checks if an event unique ID exists in the global lookup registry.
func uniq_id_exists_globally(event_uniq_id: int) -> bool:
	return global_event_lookup.has(event_uniq_id)



## Retrieves the array of extraction event IDs for a given map ID.
func get_map_extraction_events(map_id: int) -> PackedInt32Array:
	var extraction_events: PackedInt32Array = PackedInt32Array()
	for key in map_ids:
		if map_ids[key] == map_id:
			extraction_events = map_extraction_events[key]
			break
	
	return extraction_events



## Retrieves the array of event region dictionaries for a given map ID.
func get_map_event_regions(map_id: int) -> Array:
	var event_regions: Array = []
	for key in map_ids:
		if map_ids[key] == map_id:
			event_regions = map_event_regions.get(key, [])
			break
	event_regions.sort_custom(
		func(a, b):
			return a.id < b.id
	)
	return event_regions



## Retrieves the name of a specific event region using its map ID and region ID.
func get_event_region_name(map_id: int, region_id: int) -> String:
	var regions = get_map_event_regions(map_id)
	for region_data in regions:
		if region_data.has("id") and region_data["id"] == region_id:
			return region_data.get("name", "")
	return ""



## Retrieves the array of enemy spawn region dictionaries for a given map ID.
func get_map_enemy_spawn_regions(map_id: int) -> Array:
	var enemy_spawn_regions: Array = []
	for key in map_ids:
		if map_ids[key] == map_id:
			enemy_spawn_regions = map_enemy_spawn_regions.get(key, [])
			break
	
	return enemy_spawn_regions



## Retrieves the name of a specific enemy spawn region using its map ID and region ID.
func get_enemy_spawn_region_name(map_id: int, region_id: int) -> String:
	var regions = get_map_enemy_spawn_regions(map_id)
	for region_data in regions:
		if region_data.has("id") and region_data["id"] == region_id:
			return region_data.get("name", "")
	return ""

#endregion


#region UTILS AND SAVING

## Converts an RPGEvent resource into a lightweight dictionary for storage in MapInfos.
func _convert_event_to_dict(event: RPGEvent) -> Dictionary:
	var pages: Array[Dictionary] = []
	var quest_pages: PackedInt32Array = []
	var quest_ids: Dictionary = {}
	
	for i in event.pages.size():
		var page: RPGEventPage = event.pages[i]
		pages.append({"name": page.name, "uid": page._uniq_id, "id": i})
		if page.is_quest_page:
			quest_pages.append(i)
	
	var real_quest_db = RPGSYSTEM.database.quests
	
	for q: RPGEventPQuest in event.quests:
		if q:
			var _current_name = q.override_name
			var real_quest_id = q.id
			
			for rq in real_quest_db:
				if not rq: continue
				if rq._uniq_id == real_quest_id or rq.id == real_quest_id:
					if not rq.name.is_empty() and _current_name.is_empty():
						_current_name = rq.name
					break
					
			quest_ids[q._uniq_id] = {"real_quest_id": real_quest_id, "name": _current_name}
	
	return {
		"id": event.id,
		"uid": event._uniq_id,
		"name": event.name,
		"pages": pages,
		"quest_pages": quest_pages,
		"quest_ids": quest_ids,
		"quest_count": event.quests.size()
	}



## Updates map registries when a file is moved, renamed, or deleted.
func update_file_path(old_file: String, new_file: String) -> void:
	var index = maps.find(old_file)
	if index >= 0:
		var old_map_name = map_names.get(old_file, "")
		var old_map_id = map_ids.get(old_file, 0)
		var old_events = map_events.get(old_file, [])
		var old_extractions = map_extraction_events.get(old_file, [])
		var old_event_regions = map_event_regions.get(old_file, [])
		var old_enemy_spawn_regions = map_enemy_spawn_regions.get(old_file, [])
		
		if new_file.length() > 0:
			maps[index] = new_file
		else:
			maps.remove_at(index)

		map_names.erase(old_file)
		map_ids.erase(old_file)
		map_events.erase(old_file)
		map_extraction_events.erase(old_file)
		map_event_regions.erase(old_file)
		map_enemy_spawn_regions.erase(old_file)
		
		if new_file.length() > 0:
			map_names[new_file] = old_map_name
			map_ids[new_file] = old_map_id
			map_events[new_file] = old_events
			map_extraction_events[new_file] = old_extractions
			map_event_regions[new_file] = old_event_regions
			map_enemy_spawn_regions[new_file] = old_enemy_spawn_regions
			
			for item in old_events:
				if item.has("uid"):
					global_event_lookup[item["uid"]] = new_file
		else:
			_delete_events_file(old_map_id)
			for item in old_events:
				if item.has("uid"):
					global_event_lookup.erase(item["uid"])
		
		save.call_deferred()



## Triggers the database loader to save the map infos file to disk.
func save() -> void:
	DatabaseLoader.save_map_infos()

#endregion
