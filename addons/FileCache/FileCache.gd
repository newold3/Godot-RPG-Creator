@tool
class_name FileCache
extends EditorPlugin

## FileCache - Godot Editor Plugin for Asset Management and Caching
##
## Optimized to use Regex for class detection instead of instantiation (.new).
##
## Key Features:
## - Instant file scanning using EditorFileSystem.
## - Static type checking via class_name.
## - Fallback to Regex analysis for scripts using get_class() overrides.
## - Zero instantiation of scenes during scanning.

## Path to the cache file where all cached data is stored.
const CACHE_FILE_PATH = "res://.godot/file_cache.cfg"

## Path to the options file where dialog configurations are stored.
const OPTIONS_FILE_PATH = "res://.godot/dialog_options.cfg"

## Dictionary that stores all cached file data organized by resource type.
static var cache: Dictionary = {}

## Flag indicating whether the cache has been fully initialized and is ready to use.
static var cache_setted: bool = false

## Timer used to delay cache refresh operations to avoid excessive rebuilding.
static var refresh_timer: float = 0.0

## Dictionary containing configuration and preset options that are saved to disk.
static var options = {}

## Array of file paths waiting to be processed and added to the cache.
var pending_files_to_process = []

## Flag to prevent concurrent file processing operations.
var is_processing_files = false

## Maximum number of files to process in a single batch to avoid freezing the editor.
var file_batch_size = 100

## Time delay between processing batches to maintain editor responsiveness.
var scan_throttle_time = 0.01

## List of file extensions recognized as image files.
var image_extensions = ["png", "bmp", "jpg", "jpeg", "svg", "tga", "webp"]

## List of file extensions recognized as audio/sound files.
var sound_extensions = ["mp3str", "oggvorbisstr", "sample", "wav", "ogg", "mp3"]

## List of file extensions recognized as font files.
var font_extensions = ["fondata", "ttf", "ttc", "otf", "otc", "woff", "woff2", "pfb", "pfm", "font", "fnt"]

## List of file extensions recognized as videos.
var video_extensions = ["ogv"]

var _known_files: Dictionary = {}

## Whether to show debug print statements for cache operations.
static var _show_prints: bool = false

## Static reference to the main FileCache instance for global access.
static var main_scene: FileCache

## Maximum number of file previews that can be generated simultaneously.
const MAX_SIMULTANEOUS_PREVIEWS: int = 15

## Counter to track the number of previews currently being generated.
var preview_counter: int = 0

## Regex used to parse the return value of get_class() from script source code.
static var _class_regex: RegEx = RegEx.new()

## Thread used for asynchronous file processing to prevent editor freezes.
var cache_thread: Thread

## Mutex to protect shared cache data during multithreaded operations.
var cache_mutex: Mutex

## Semaphore to wake the processing thread when new files are pending.
var cache_semaphore: Semaphore

## Flag indicating whether the background thread should terminate.
var thread_exit: bool = false


#region Lifecycle Methods

## Initializes the plugin, loads existing cache and options, and sets up file system monitoring.
func _enter_tree() -> void:
	# Compile regex once on startup to save performance
	_class_regex.compile("func\\s+get_class[\\s\\S]*?return\\s*[\"']([^\"']+)[\"']")
	main_scene = self
	
	cache_mutex = Mutex.new()
	cache_semaphore = Semaphore.new()
	cache_thread = Thread.new()
	thread_exit = false
	cache_thread.start(_thread_process_loop)
	
	tree_exiting.connect(_on_tree_exiting)
	
	StaticSignal.create_signal("_cache_ready")


## Rebuilds the internal dictionary of known files to optimize future scans.
func _rebuild_known_files() -> void:
	cache_mutex.lock()
	_known_files.clear()
	for category in cache.values():
		for file_path in category.keys():
			_known_files[file_path] = true
	cache_mutex.unlock()


## Called when the scene tree is ready and marks the cache as fully initialized.
func _ready() -> void:
	await get_tree().create_timer(0.1).timeout
	if not is_instance_valid(self) or not is_inside_tree(): return
	_initial_setup.call_deferred()


## Performs the initial data loading, validation, and connection of file system signals.
func _initial_setup() -> void:
	if FileAccess.file_exists(CACHE_FILE_PATH):
		var f = FileAccess.open(CACHE_FILE_PATH, FileAccess.READ)
		cache_mutex.lock()
		cache = f.get_var()
		cache_setted = true
		cache_mutex.unlock()
		f.close()
		_rebuild_known_files()
	else:
		build_cache()

	build_options()
	if FileAccess.file_exists(OPTIONS_FILE_PATH):
		var f = FileAccess.open(OPTIONS_FILE_PATH, FileAccess.READ)
		options.merge(f.get_var(), true)
		f.close()

	var fs_dock = get_editor_interface().get_file_system_dock()
	fs_dock.files_moved.connect(_on_files_moved)
	fs_dock.file_removed.connect(_on_file_removed)

	var fs = get_editor_interface().get_resource_filesystem()
	fs.filesystem_changed.connect(_rescan_files)
	fs.resources_reimported.connect(_on_resources_imports)
	fs.resources_reload.connect(_on_resources_imports)
	
	scene_saved.connect(_on_scene_saved)
	resource_saved.connect(_on_resource_save)
	resource_saved.connect(save_options)
	
	cache_mutex.lock()
	cache_setted = true
	cache_mutex.unlock()


## Main processing loop that handles delayed cache refresh operations.
func _process(delta: float) -> void:
	if refresh_timer > 0.0:
		refresh_timer -= delta
		if refresh_timer <= 0.0:
			refresh_timer = 0.0
			cache_mutex.lock()
			cache_setted = false
			cache_mutex.unlock()
			
			fix_cache.call_deferred()
			cache_semaphore.post()
			
			cache_mutex.lock()
			cache_setted = true
			cache_mutex.unlock()
			
			set_process(false)


## Removes invalid or deleted file entries from the cache.
func fix_cache() -> void:
	cache_mutex.lock()
	for key in cache:
		var file_paths = cache[key].keys()
		for file_path in file_paths:
			if not ZipMediaLoader.file_exists(file_path):
				cache[key].erase(file_path)
	cache_mutex.unlock()


## Final cleanup method called when the editor is closing.
func _on_tree_exiting() -> void:
	cache_mutex.lock()
	thread_exit = true
	cache_mutex.unlock()
	
	cache_semaphore.post()
	
	if cache_thread and cache_thread.is_started():
		cache_thread.wait_to_finish()
		
	cache_mutex.lock()
	var remaining = pending_files_to_process.duplicate()
	pending_files_to_process.clear()
	cache_mutex.unlock()
	
	for file_path in remaining:
		cache_file(file_path)
		
	save()
#endregion
#region Threading & Queuing


## Adds a file to the processing queue in a thread-safe manner.
func _queue_file_for_processing(file_path: String) -> void:
	cache_mutex.lock()
	if !pending_files_to_process.has(file_path):
		pending_files_to_process.append(file_path)
	cache_mutex.unlock()
	cache_semaphore.post()


## Continuous loop executed by the background thread to process files.
func _thread_process_loop() -> void:
	while true:
		cache_semaphore.wait()
		
		cache_mutex.lock()
		var should_exit = thread_exit
		cache_mutex.unlock()
		
		if should_exit:
			break
			
		var has_files = true
		var processed_any = false
		
		while has_files:
			cache_mutex.lock()
			should_exit = thread_exit
			if should_exit:
				cache_mutex.unlock()
				break
				
			var file_path = ""
			if pending_files_to_process.size() > 0:
				file_path = pending_files_to_process.pop_front()
			else:
				has_files = false
				
			cache_mutex.unlock()
			
			if file_path != "":
				cache_file(file_path)
				processed_any = true
				
		if not should_exit and processed_any:
			call_deferred("_on_batch_finished")


## Called asynchronously when a batch of files finishes processing in the thread.
func _on_batch_finished() -> void:
	save()
	StaticSignal.emit("_cache_ready")


## Thread-safe method to add a file to a specific cache category.
func _add_to_cache(category: String, file_path: String) -> void:
	cache_mutex.lock()
	if cache.has(category):
		cache[category][file_path] = true
	cache_mutex.unlock()


## Thread-safe method to remove a file from all cache categories.
func _remove_from_cache_all(file_path: String) -> void:
	cache_mutex.lock()
	for key in cache.keys():
		if cache[key].has(file_path):
			cache[key].erase(file_path)
	cache_mutex.unlock()
#endregion
#region File Manipulation


## Updates the cache when a resource is saved in the editor.
func _on_resource_save(resource) -> void:
	var path = resource.get_path()
	_queue_file_for_processing(path)


## Updates cache entries when files are moved or renamed in the file system.
func _on_files_moved(old_file: String, new_file: String) -> void:
	var rpg_maps_info = main_scene.get_node_or_null("/root/RPGMapsInfo")
	if is_instance_valid(rpg_maps_info):
		rpg_maps_info.update_file_path.call_deferred(old_file, new_file)
		
	cache_mutex.lock()
	cache_setted = false
	for key in cache:
		if cache[key].has(old_file):
			cache[key][new_file] = cache[key][old_file]
			cache[key].erase(old_file)
			cache_setted = true
			cache_mutex.unlock()
			return
			
	cache_setted = true
	cache_mutex.unlock()


## Removes deleted files from the cache when they are deleted from the file system.
func _on_file_removed(removed_file: String) -> void:
	var rpg_maps_info = main_scene.get_node_or_null("/root/RPGMapsInfo")
	if is_instance_valid(rpg_maps_info):
		rpg_maps_info.update_file_path.call_deferred(removed_file, "")
		
	cache_mutex.lock()
	cache_setted = false
	for key in cache:
		if cache[key].has(removed_file):
			cache[key].erase(removed_file)
			cache_setted = true
			cache_mutex.unlock()
			return
			
	cache_setted = true
	cache_mutex.unlock()


## Re-caches resources when they are imported or reloaded by the Godot editor.
func _on_resources_imports(paths: PackedStringArray) -> void:
	for path in paths:
		_queue_file_for_processing(path)


## Updates the cache when a scene file is saved in the editor.
func _on_scene_saved(path: String) -> void:
	_queue_file_for_processing(path)
#endregion
#region Building Dialog Options


## Initializes default configuration settings for known dialog types.
func build_options() -> void:
	options = {
		"event_dialog": {"detached": false, "position": Vector2i.ZERO, "size": Vector2i.ZERO},
		"extraction_event_dialog": {"detached": false, "position": Vector2i.ZERO, "size": Vector2i.ZERO},
		"enemy_spawn_region_dialog": {"detached": false, "position": Vector2i.ZERO, "size": Vector2i.ZERO},
		"event_region_dialog": {"detached": false, "position": Vector2i.ZERO, "size": Vector2i.ZERO}
	}
#endregion
#region Building Cache


## Static method to trigger a complete cache rebuild from anywhere in the codebase.
static func rebuild(full_scan: bool = false) -> void:
	if main_scene:
		if full_scan:
			main_scene.cache_mutex.lock()
			cache.clear()
			main_scene.cache_mutex.unlock()
		main_scene.set_process(true)
		main_scene.build_cache()


## Initializes the cache structure and begins scanning using EditorFileSystem.
func build_cache() -> void:
	cache_mutex.lock()
	cache_setted = false
	cache = {
		"animated_images": {}, "images": {}, "sounds": {}, "animations": {}, "maps": {},
		"characters": {}, "events": {}, "equipment_parts_weapons": {}, "equipment_parts_others": {},
		"enemies": {}, "curves": {}, "sets": {}, "costumes": {},
		"fonts": {}, "message_dialogs": {}, "scroll_scenes": {}, "choice_scenes": {},
		"vehicles": {}, "weather": {}, "expressive_bubbles": {}, "numerical_input_scenes": {},
		"text_input_scenes": {}, "transition_scenes": {}, "videos": {}, "map_parallax_scenes": {},
		"battle_background_scenes": {}, "tilesets": {}, "timer_scenes": {},
		"shop_scene": {}, "extraction_scenes": {}, "weapon_attack_scripts": {}, "label_settings": {}
	}
	cache_mutex.unlock()
	
	var temp_files = []
	var fs = get_editor_interface().get_resource_filesystem().get_filesystem()
	
	if fs:
		temp_files = _scan_filesystem_recursively(fs)
	else:
		temp_files = collect_all_files("res://")
		
	# Inject virtual files from ZipMediaLoader
	if not ZipMediaLoader._initialized:
		ZipMediaLoader._mount_system()
		
	for zip_file in ZipMediaLoader._files_index.keys():
		var full_path = "res://" + zip_file
		if not temp_files.has(full_path):
			temp_files.append(full_path)
			
	cache_mutex.lock()
	for f in temp_files:
		if !pending_files_to_process.has(f):
			pending_files_to_process.append(f)
	cache_mutex.unlock()
	
	cache_semaphore.post()


## Recursively collects all file paths from the EditorFileSystem (In-Memory).
func _scan_filesystem_recursively(dir: EditorFileSystemDirectory) -> Array:
	var files = []
	for i in range(dir.get_file_count()):
		var file_path = dir.get_file_path(i)
		if file_path.ends_with(".import") or file_path.begins_with("res://."):
			continue
		files.append(file_path)
		
	for i in range(dir.get_subdir_count()):
		var subdir = dir.get_subdir(i)
		var subdir_path = subdir.get_path()
		if !should_skip_directory(subdir_path):
			files.append_array(_scan_filesystem_recursively(subdir))
			
	return files


## Legacy method: Recursively collects all file paths in the project (Disk I/O).
func collect_all_files(path: String = "res://") -> Array:
	var files = []
	var dir: DirAccess = DirAccess.open(path)
	if DirAccess.get_open_error() == OK:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if dir.current_is_dir():
				var subdir_path = dir.get_current_dir().path_join(file_name)
				if !should_skip_directory(subdir_path):
					files.append_array(collect_all_files(subdir_path))
			else:
				var file_path = dir.get_current_dir().path_join(file_name)
				if !should_skip_file(file_path):
					files.append(file_path)
			file_name = dir.get_next()
	return files


## Determines whether a directory should be excluded from cache scanning.
func should_skip_directory(dir_path: String) -> bool:
	return (
		dir_path.begins_with("res://.")
		or (dir_path.begins_with("res://addons/") 
			and !dir_path.begins_with("res://addons/rpg_character_creator/sounds")
			and !dir_path.begins_with("res://addons/CustomControls/Resources")
			and !dir_path.begins_with("res://addons/CustomControls/Images"))
	)


## Determines whether a file should be excluded from cache scanning.
func should_skip_file(file_path: String) -> bool:
	return (
		file_path.ends_with(".import") 
		or !ResourceLoader.exists(file_path)
		or file_path.begins_with("res://addons/tile_bit_tools/")
	)


## Internal callback that initiates a cache refresh when the file system changes.
func _rescan_files() -> void:
	var fs = get_editor_interface().get_resource_filesystem()
	var new_files = _find_new_files_only(fs.get_filesystem())
	
	for file_path in new_files:
		_queue_file_for_processing(file_path)
		
		cache_mutex.lock()
		_known_files[file_path] = true
		cache_mutex.unlock()
		
	if !new_files.is_empty():
		rescan_files()


## Recursively identifies new files that have not been previously cached.
func _find_new_files_only(dir: EditorFileSystemDirectory) -> Array:
	var new_files = []
	for i in range(dir.get_file_count()):
		var file_path = dir.get_file_path(i)
		
		cache_mutex.lock()
		var known = file_path in _known_files
		cache_mutex.unlock()
		
		if not known:
			new_files.append(file_path)
	
	for i in range(dir.get_subdir_count()):
		new_files.append_array(_find_new_files_only(dir.get_subdir(i)))
		
	return new_files


## Static method to initiate a delayed cache rebuild.
static func rescan_files() -> void:
	if _show_prints:
		print("rebuilding cache...")
		
	refresh_timer = 0.15
	
	if main_scene:
		main_scene.set_process(true)


## Analyzes and categorizes a file by its type and content.
func cache_file(file_path: String, force_rescan: bool = false) -> void:
	if should_skip_file(file_path):
		return
		
	if !force_rescan:
		cache_mutex.lock()
		var already_cached = false
		for key in cache:
			if cache[key].has(file_path):
				already_cached = true
				break
		cache_mutex.unlock()
		
		if already_cached:
			return
	else:
		_remove_from_cache_all(file_path)
				
	var extension = file_path.get_extension().to_lower()
	if extension in image_extensions:
		_add_to_cache("images", file_path)
		return
		
	if extension in sound_extensions:
		_add_to_cache("sounds", file_path)
		return
		
	if extension in font_extensions:
		_add_to_cache("fonts", file_path)
		return
		
	if extension in video_extensions:
		_add_to_cache("videos", file_path)
		return
		
	if extension == "efkefc":
		_add_to_cache("animations", file_path)
	elif extension in ["res", "tres"]:
		classify_resource_file(file_path)
	elif extension == "tscn":
		classify_scene_file(file_path)
	elif extension == "gd":
		classify_script_file(file_path)


## Analyzes a standalone script file to determine if it inherits from specific base classes like CombatActionBase.
func classify_script_file(file_path: String) -> void:
	if !ResourceLoader.exists(file_path):
		return
		
	var script_res = load(file_path)
	if script_res is Script:
		var current_script = script_res
		
		# Climb the inheritance tree to see if it extends CombatActionBase
		while current_script:
			var global_name = current_script.get_global_name()
			var script_name = current_script.resource_path.get_file()
			
			if global_name == "CombatActionBase" or script_name == "combat_action_base.gd":
				_add_to_cache("weapon_attack_scripts", file_path)
				return
				
			current_script = current_script.get_base_script()


## Loads and analyzes a Godot resource file safely from the processing thread.
func classify_resource_file(file_path: String) -> void:
	if !ResourceLoader.exists(file_path):
		return

	var file_type = get_editor_interface().get_resource_filesystem().get_file_type(file_path)
	
	match file_type:
		"CompressedTexture2D", "ImageTexture", "GradientTexture2D":
			_add_to_cache("images", file_path)
			return
		"AudioStreamMP3", "AudioStreamWAV", "AudioStreamOggVorbis":
			_add_to_cache("sounds", file_path)
			return
		"FontFile", "SystemFont":
			_add_to_cache("fonts", file_path)
			return
		"TileSet":
			_add_to_cache("tilesets", file_path)
			return
		"Curve":
			_add_to_cache("curves", file_path)
			return
		"VideoStreamTheora":
			_add_to_cache("videos", file_path)
			return
		"LabelSettings":
			_add_to_cache("label_settings", file_path)
			return
	
	var res = load(file_path)
	if res == null:
		return

	if res is AudioStream:
		_add_to_cache("sounds", file_path)
	elif res is IngameCostume:
		_add_to_cache("costumes", file_path)
	elif res is RPGLPCCharacter:
		if res.event_preview:
			_add_to_cache("events", file_path)
		else:
			_add_to_cache("characters", file_path)
	elif res is IngameGearSet:
		_add_to_cache("sets", file_path)
	elif res is RPGLPCEquipmentPart:
		if res.layer_id == "mainhand":
			_add_to_cache("equipment_parts_weapons", file_path)
		else:
			_add_to_cache("equipment_parts_others", file_path)
	elif res is Curve:
		_add_to_cache("curves", file_path)
	elif res is Font:
		_add_to_cache("fonts", file_path)
	elif res is Texture2D:
		_add_to_cache("images", file_path)
	elif res is TileSet:
		_add_to_cache("tilesets", file_path)
	elif res is VideoStream:
		_add_to_cache("videos", file_path)
	
	res = null


## Analyzes a scene file by traversing its node structure without explicitly instantiating scenes.
func classify_scene_file(file_path: String) -> void:
	var map_node = main_scene.get_node_or_null("/root/RPGMapsInfo")
	
	if map_node and map_node.map_infos.maps.has(file_path):
		_add_to_cache("maps", file_path)
		return

	_analyze_scene_recursive(file_path, file_path)


func _analyze_scene_recursive(original_file_path: String, current_scene_path: String) -> void:
	var data = _parse_tscn_root_data(current_scene_path)
	
	if data["type"] in ["Sprite2D", "AnimatedSprite2D", "TextureRect"]:
		_add_to_cache("animated_images", original_file_path)
		return
		
	if data["script_path"] != "":
		if ResourceLoader.exists(data["script_path"]):
			var script_res = load(data["script_path"])
			
			if script_res and _check_and_cache_script(original_file_path, script_res):
				return
				
	if data["instance_path"] != "":
		_analyze_scene_recursive(original_file_path, data["instance_path"])


func _parse_tscn_root_data(file_path: String) -> Dictionary:
	var result = {"type": "", "script_path": "", "instance_path": ""}
	var f = FileAccess.open(file_path, FileAccess.READ)
	
	if not f:
		return result
		
	var ext_resources = {}
	
	while not f.eof_reached():
		var line = f.get_line().strip_edges()
		
		if line.begins_with("[ext_resource "):
			var id_start = line.find(" id=\"")
			var path_start = line.find(" path=\"")
			
			if id_start != -1 and path_start != -1:
				id_start += 5
				var id_end = line.find("\"", id_start)
				var id = line.substr(id_start, id_end - id_start)
				
				path_start += 7
				var path_end = line.find("\"", path_start)
				var path = line.substr(path_start, path_end - path_start)
				
				ext_resources[id] = path
				
		elif line.begins_with("[node "):
			var type_start = line.find(" type=\"")
			
			if type_start != -1:
				type_start += 7
				var type_end = line.find("\"", type_start)
				result["type"] = line.substr(type_start, type_end - type_start)
				
			var script_start = line.find(" script=ExtResource(\"")
			
			if script_start != -1:
				script_start += 21
				var script_end = line.find("\")", script_start)
				var script_id = line.substr(script_start, script_end - script_start)
				
				if ext_resources.has(script_id):
					result["script_path"] = ext_resources[script_id]
					
			var instance_start = line.find(" instance=ExtResource(\"")
			
			if instance_start != -1:
				instance_start += 23
				var instance_end = line.find("\")", instance_start)
				var instance_id = line.substr(instance_start, instance_end - instance_start)
				
				if ext_resources.has(instance_id):
					result["instance_path"] = ext_resources[instance_id]
					
			break
			
	f.close()
	
	return result


## Helper to identify script class (including inheritance) and update cache.
func _check_and_cache_script(file_path: String, script_res: Resource) -> bool:
	var class_identifier = script_res.get_global_name()
	
	if class_identifier == "":
		var current_script = script_res
		while current_script:
			var source = current_script.source_code
			var regex_match = _class_regex.search(source)
			if regex_match:
				class_identifier = regex_match.get_string(1)
				break
			current_script = current_script.get_base_script()
			
	if class_identifier == "":
		var base_script = script_res.get_base_script()
		while base_script:
			var base_name = base_script.get_global_name()
			if base_name != "":
				if _is_valid_cache_class(base_name):
					class_identifier = base_name
					break
			base_script = base_script.get_base_script()
			
	if class_identifier != "":
		return _match_identifier_to_cache(file_path, class_identifier)
		
	return false


## Helper to check if the class name is relevant for caching.
func _is_valid_cache_class(_class_name: String) -> bool:
	match _class_name:
		"BattleAnimation", "RPGMap", "LPCEnemy", "DialogBase", "ScrollText", \
		"RPGVehicle", "GameTransition", "TimerScene", "WeatherScene", \
		"ExpressiveBubble", "ChoiceScene", "SelectDigitsScene", "SelectTextsScene", \
		"MapParallaxScene", "BattleBackgroundScene", "GeneralShopScene", \
		"RPGExtractionScene":
			return true
	return false


## Helper to assign file path to the correct cache dictionary.
func _match_identifier_to_cache(file_path: String, class_identifier: String) -> bool:
	match class_identifier:
		"BattleAnimation": _add_to_cache("animations", file_path)
		"RPGMap": _add_to_cache("maps", file_path)
		"LPCEnemy": _add_to_cache("enemies", file_path)
		"DialogBase": _add_to_cache("message_dialogs", file_path)
		"ScrollText": _add_to_cache("scroll_scenes", file_path)
		"RPGVehicle": _add_to_cache("vehicles", file_path)
		"GameTransition": _add_to_cache("transition_scenes", file_path)
		"TimerScene": _add_to_cache("timer_scenes", file_path)
		"WeatherScene": _add_to_cache("weather", file_path)
		"ExpressiveBubble": _add_to_cache("expressive_bubbles", file_path)
		"ChoiceScene": _add_to_cache("choice_scenes", file_path)
		"SelectDigitsScene": _add_to_cache("numerical_input_scenes", file_path)
		"SelectTextsScene": _add_to_cache("text_input_scenes", file_path)
		"MapParallaxScene": _add_to_cache("map_parallax_scenes", file_path)
		"BattleBackgroundScene": _add_to_cache("battle_background_scenes", file_path)
		"GeneralShopScene": _add_to_cache("shop_scene", file_path)
		"RPGExtractionScene": _add_to_cache("extraction_scenes", file_path)
		_: return false
	return true
#endregion
#region Saving


## Saves the dialog options configuration to disk.
func save_options(_resource: Resource = null) -> void:
	var f = FileAccess.open(OPTIONS_FILE_PATH, FileAccess.WRITE)
	f.store_var(options)
	f.close()


## Saves both the cache and options data to disk safely.
func save() -> void:
	save_options()
	
	cache_mutex.lock()
	var is_setted = cache_setted
	cache_mutex.unlock()
	
	if !is_setted:
		await get_tree().create_timer(0.1).timeout
		if not is_instance_valid(self) or not is_inside_tree(): return
		
	cache_mutex.lock()
	var cache_copy = cache.duplicate(true)
	cache_setted = true
	cache_mutex.unlock()
	
	var f = FileAccess.open(CACHE_FILE_PATH, FileAccess.WRITE)
	f.store_var(cache_copy)
	f.close()
	
	StaticSignal.emit("_cache_ready")
	if _show_prints:
		print("Cache saved!")
