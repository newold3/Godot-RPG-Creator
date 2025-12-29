@tool
class_name MapInfos
extends Resource


func get_class(): return "MapInfos"


# maps = [scene path, ...]
@export var maps: Array
@export var map_names: Dictionary = {} 
@export var map_ids: Dictionary = {}
@export var map_events: Dictionary = {}
@export var map_extraction_events: Dictionary = {}



func is_rpgmap_in(node: Node) -> bool:
	if node is RPGMap:
		return true
	
	for child in node.get_children():
		var result = is_rpgmap_in(child)
		if result:
			return true
	
	return false


func fix_maps(data: Array) -> void:
	for map: RPGMap in data:
		var map_path = map.get_scene_file_path()
		if not map_path in maps:
			maps.append(map_path)
		set_map_name(map_path, map.name)
		set_map_id(map_path, map.internal_id)
		set_map_events(map.internal_id, map.events)

	for map in maps:
		if !map in data and !ResourceLoader.exists(map):
			maps.erase(map)
			map_names.erase(map)
			map_ids.erase(map)
			map_events.erase(map)
			map_extraction_events.erase(map)
	save.call_deferred()


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


func set_map_events(map_id: int, events: RPGEvents) -> void:
	var map: String
	for key in map_ids:
		if map_ids[key] == map_id:
			var items: Array = []
			for ev: RPGEvent in events.events:
				var pages: PackedStringArray = []
				var quest_pages: PackedInt32Array = []
				for i in ev.pages.size():
					var page: RPGEventPage = ev.pages[i]
					pages.append(page.name)
					if  page.is_quest_page:
						quest_pages.append(i)
				items.append({"id": ev.id, "name": ev.name, "pages": pages, "quest_pages": quest_pages})
			
			map_events[key] = items
			
			break


func get_map_events(map_id: int) -> PackedInt32Array:
	var events: PackedInt32Array = PackedInt32Array()
	for key in map_ids:
		if map_ids[key] == map_id:
			events = map_events[key]
			break
	
	return events


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
		
		if new_file.length() > 0: # move
			maps[index] = new_file
		else: # remove
			maps.remove_at(index)

		map_names.erase(old_file)
		map_ids.erase(old_file)
		
		if new_file.length() > 0:
			map_names[new_file] = old_map_name
			map_ids[new_file] = old_map_id
		
		save.call_deferred()


func save() -> void:
	var dir = "res://Data"
	var file = "map_info.res"
	var path = "%s/%s" % [dir, file]
	if ResourceLoader.exists(path):
		ResourceSaver.save(self, path)
	else:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
		ResourceSaver.save(self, path)
