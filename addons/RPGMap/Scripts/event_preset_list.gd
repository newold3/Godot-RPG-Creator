@tool
class_name EventPresetList
extends Resource

signal presets_loaded(items: Dictionary)

var _thread: Thread

# Struct: {"id": {"name": "X", "path": "...", "timestamp": 123}}
@export var presets: Dictionary = {}

func _init() -> void:
	_thread = Thread.new()


func refresh_async(folder_name: String, cache_filename: String) -> void:
	if _thread.is_started():
		if _thread.is_alive(): return
		_thread.wait_to_finish()
	
	_thread.start(_threaded_scan.bind(presets.duplicate(), folder_name, cache_filename))


func _threaded_scan(current_cache: Dictionary, folder_name: String, cache_filename: String) -> Dictionary:
	var documents_path = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	var presets_folder = documents_path.path_join("GodotRPGCreatorPresets").path_join(folder_name)
	
	var new_presets: Dictionary = {}
	var folder_changed: bool = false
	
	if not DirAccess.dir_exists_absolute(presets_folder):
		DirAccess.make_dir_recursive_absolute(presets_folder)
		call_deferred("_on_thread_finished", {}, false, folder_name, cache_filename)
		return {}

	var dir = DirAccess.open(presets_folder)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		
		while file_name != "":
			if not file_name.begins_with("_") and file_name.ends_with(".res"):
				var full_path = presets_folder.path_join(file_name)
				var id = file_name.trim_suffix(".res")
				
				var current_timestamp = FileAccess.get_modified_time(full_path)
				
				if current_cache.has(id) and \
				   current_cache[id].get("timestamp", 0) == current_timestamp and \
				   current_cache[id].get("path") == full_path:
					
					new_presets[id] = current_cache[id]
				
				else:
					if FileAccess.file_exists(full_path):
						var res = FileAccess.open(full_path, FileAccess.READ)
						if res:
							var data: EventPreset = res.get_var(true)
							if data:
								new_presets[id] = {
									"name": data.name,
									"path": full_path,
									"timestamp": current_timestamp
								}
								folder_changed = true
			
			file_name = dir.get_next()
	
	if current_cache.size() != new_presets.size():
		folder_changed = true

	call_deferred("_on_thread_finished", new_presets, folder_changed, folder_name, cache_filename)
	return new_presets


func _on_thread_finished(new_presets: Dictionary, has_changes: bool, folder_name: String, cache_filename: String) -> void:
	_thread.wait_to_finish()
	presets = new_presets
	
	if has_changes:
		_save_cache_to_disk(folder_name, cache_filename)
		
	presets_loaded.emit(presets)


func _save_cache_to_disk(folder_name: String, cache_filename: String) -> void:
	var documents_path = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	var full_save_path = documents_path.path_join("GodotRPGCreatorPresets").path_join(folder_name).path_join(cache_filename)
	
	ResourceSaver.save(self, full_save_path)


# Get all preset names as an array (useful for UI lists)
func get_preset_names() -> Array[String]:
	var names: Array[String] = []
	for preset_data in presets.values():
		names.append(preset_data.name)
	return names


func _to_string() -> String:
	var names = get_preset_names()
	return "<EventPresetList: %s>" % [names]
