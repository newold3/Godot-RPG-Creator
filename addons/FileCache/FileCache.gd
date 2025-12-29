@tool
class_name FileCache
extends EditorPlugin

## FileCache - Godot Editor Plugin for Asset Management and Caching
##
## Key Features:
## - Automatic scanning and categorization of project assets by type (images, sounds, fonts, etc.)
## - Real-time cache updates when files are moved, deleted, or modified
## - Batch processing system to maintain editor responsiveness during large operations
## - Persistent storage of cache data and dialog configurations
## - Support for custom RPG-specific resource types (characters, maps, enemies, etc.)
## - File system monitoring with automatic cache invalidation and refresh
##
## The plugin organizes cached files into categories such as:
## - Media assets: images, sounds, fonts, animations
## - Game content: maps, characters, events, enemies, vehicles
## - UI components: dialogs, scenes, transitions, input handlers
## - Technical assets: curves, tilesets, battle backgrounds
##
## Cache data is automatically saved to `.godot/file_cache.cfg` and dialog settings
## to `.godot/dialog_options.cfg` for persistence across editor sessions.
##
## Usage: The plugin runs automatically in the editor background, providing
## cached asset data through static access methods for other tools and editors.


## Signal emitted when the file cache is fully loaded and ready for use.
static var cache_ready: Signal = StaticSignal.make()

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
var file_batch_size = 40
## Time delay between processing batches to maintain editor responsiveness.
var scan_throttle_time = 0.05

## List of file extensions recognized as image files.
var image_extensions = ["png", "bmp", "jpg", "jpeg", "svg", "tga", "webp"]
## List of file extensions recognized as audio/sound files.
var sound_extensions = ["mp3str", "oggvorbisstr", "sample", "wav", "ogg", "mp3"]
## List of file extensions recognized as font files.
var font_extensions = ["fondata", "ttf", "ttc", "otf", "otc", "woff", "woff2", "pfb", "pfm", "font"]
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

## Initializes the plugin, loads existing cache and options, and sets up file system monitoring.
func _enter_tree() -> void:
	main_scene = self
	tree_exiting.connect(_on_tree_exiting)


func _rebuild_known_files() -> void:
	_known_files.clear()
	for category in cache.values():
		for file_path in category.keys():
			_known_files[file_path] = true


## Called when the scene tree is ready and marks the cache as fully initialized.
func _ready() -> void:
	await get_tree().create_timer(0.1).timeout
	_initial_setup.call_deferred()


func _initial_setup() -> void:
	if FileAccess.file_exists(CACHE_FILE_PATH):
		var f = FileAccess.open(CACHE_FILE_PATH, FileAccess.READ)
		cache = f.get_var()
		f.close()
		cache_setted = true
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
	cache_setted = true


## Main processing loop that handles deferred cache refresh operations and file batch processing.
func _process(delta: float) -> void:
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		return
		
	if refresh_timer > 0.0:
		refresh_timer -= delta
		if refresh_timer <= 0.0:
			refresh_timer = 0.0
			cache_setted = false
			fix_cache.call_deferred()
			process_pending_files.call_deferred()
			cache_setted = true

	if !is_processing_files and !pending_files_to_process.is_empty():
		process_pending_files.call_deferred()

## Processes pending files in batches to maintain editor responsiveness during large cache operations.
func process_pending_files() -> void:
	if is_processing_files:
		return
	is_processing_files = true
	var files_to_process = min(file_batch_size, pending_files_to_process.size())
	var processed = 0
	while processed < files_to_process and !pending_files_to_process.is_empty():
		var file_path = pending_files_to_process.pop_front()
		cache_file(file_path)
		processed += 1
	if !pending_files_to_process.is_empty():
		get_tree().create_timer(scan_throttle_time).timeout.connect(func(): is_processing_files = false)
	else:
		is_processing_files = false
		save()
		cache_ready.emit()

## Removes invalid or deleted file entries from the cache to keep it clean and accurate.
func fix_cache() -> void:
	for key in cache:
		var file_paths = cache[key].keys()
		for file_path in file_paths:
			if !FileAccess.file_exists(file_path):
				cache[key].erase(file_path)

#region File Manipulation

## Updates the cache when a resource is saved in the editor.
func _on_resource_save(resource) -> void:
	var path = resource.get_path()
	if !pending_files_to_process.has(path):
		pending_files_to_process.append(path)

## Updates cache entries when files are moved or renamed in the file system.
func _on_files_moved(old_file: String, new_file: String) -> void:
	var rpg_maps_info = get_node_or_null("/root/RPGMapsInfo")
	if is_instance_valid(rpg_maps_info):
		rpg_maps_info.update_file_path.call_deferred(old_file, new_file)
		
	cache_setted = false
	for key in cache:
		if cache[key].has(old_file):
			cache[key][new_file] = cache[key][old_file]
			cache[key].erase(old_file)
			cache_setted = true
			return
	cache_setted = true

## Removes deleted files from the cache when they are deleted from the file system.
func _on_file_removed(removed_file: String) -> void:
	var rpg_maps_info = get_node_or_null("/root/RPGMapsInfo")
	if is_instance_valid(rpg_maps_info):
		rpg_maps_info.update_file_path.call_deferred(removed_file, "")
		
	cache_setted = false
	for key in cache:
		if cache[key].has(removed_file):
			cache[key].erase(removed_file)
			cache_setted = true
			return
	cache_setted = true

## Re-caches resources when they are imported or reloaded by the Godot editor.
func _on_resources_imports(paths: PackedStringArray) -> void:
	for path in paths:
		if !pending_files_to_process.has(path):
			pending_files_to_process.append(path)

## Updates the cache when a scene file is saved in the editor.
func _on_scene_saved(path: String) -> void:
	if !pending_files_to_process.has(path):
		pending_files_to_process.append(path)

#endregion

#region Building Dialog Options

## Initializes default configuration settings for known dialog types with their default states.
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
static func rebuild() -> void:
	if main_scene:
		main_scene.build_cache()

## Initializes the cache structure and begins scanning all project files for caching.
func build_cache() -> void:
	cache_setted = false
	cache = {
		"animated_images": {}, "images": {}, "sounds": {}, "animations": {}, "maps": {},
		"characters": {}, "events": {}, "equipment_parts": {}, "enemies": {}, "curves": {},
		"fonts": {}, "message_dialogs": {}, "scroll_scenes": {}, "choice_scenes": {},
		"vehicles": {}, "weather": {}, "expressive_bubbles": {}, "numerical_input_scenes": {},
		"text_input_scenes": {}, "transition_scenes": {}, "videos": {}, "map_parallax_scenes": {},
		"battle_background_scenes": {}, "tilesets": {}, "timer_scenes": {},
		"shop_scene": {}, "extraction_scenes": {}
	}
	pending_files_to_process = collect_all_files("res://")
	process_pending_files()

## Recursively collects all file paths in the project that should be included in the cache.
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

## Determines whether a directory should be excluded from cache scanning based on predefined rules.
func should_skip_directory(dir_path: String) -> bool:
	return (
		dir_path.begins_with("res://.")
		or (dir_path.begins_with("res://addons/") 
			and !dir_path.begins_with("res://addons/rpg_character_creator/sounds")
			and !dir_path.begins_with("res://addons/CustomControls/Resources")
			and !dir_path.begins_with("res://addons/CustomControls/Images"))
	)

## Determines whether a file should be excluded from cache scanning based on extension and validity.
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
		if !pending_files_to_process.has(file_path):
			pending_files_to_process.append(file_path)
			_known_files[file_path] = true
	
	if !pending_files_to_process.is_empty():
		rescan_files()


func _find_new_files_only(dir: EditorFileSystemDirectory) -> Array:
	var new_files = []
	
	# Revisar archivos en este directorio
	for i in range(dir.get_file_count()):
		var file_path = dir.get_file_path(i)
		if file_path not in _known_files:  # O(1) en diccionario
			new_files.append(file_path)
	
	# Recursivamente en subdirectorios
	for i in range(dir.get_subdir_count()):
		new_files.append_array(_find_new_files_only(dir.get_subdir(i)))
	
	return new_files


## Static method to initiate a delayed cache rebuild, typically called after file system changes.
static func rescan_files() -> void:
	if _show_prints:
		print("rebuilding cache...")
	refresh_timer = 0.15

## Analyzes and categorizes a file by its type and content, adding it to the appropriate cache category.
func cache_file(file_path: String, force_rescan: bool = false) -> void:
	if should_skip_file(file_path):
		return
	if !force_rescan:
		for key in cache:
			if cache[key].has(file_path):
				return
	else:
		for key in cache:
			if cache[key].has(file_path):
				cache[key].erase(file_path)
	var extension = file_path.get_extension().to_lower()
	if extension in image_extensions:
		if !cache.images.has(file_path): cache.images[file_path] = true
		return
	if extension in sound_extensions:
		if !cache.sounds.has(file_path): cache.sounds[file_path] = true
		return
	if extension in font_extensions:
		if !cache.fonts.has(file_path): cache.fonts[file_path] = true
		return
	if extension in video_extensions:
		if !cache.videos.has(file_path): cache.videos[file_path] = true
		return
	if extension == "efkefc":
		if !cache.animations.has(file_path): cache.animations[file_path] = true
	elif extension in ["res", "tres"]:
		classify_resource_file(file_path)
	elif extension == "tscn":
		classify_scene_file(file_path)

## Loads and analyzes a Godot resource file to determine its type and cache it appropriately.
## Optimized to fail safely and check lightweight types first.
func classify_resource_file(file_path: String) -> void:
	if !ResourceLoader.exists(file_path):
		return

	# Try to get the class type string without loading the full file first (Faster/Safer)
	# This works well for built-in types like Texture2D, AudioStream, etc.
	# Note: For custom script resources, it might just return "Resource", so we still need load() fallback.
	var file_type = get_editor_interface().get_resource_filesystem().get_file_type(file_path)
	
	match file_type:
		"CompressedTexture2D", "ImageTexture", "GradientTexture2D":
			cache.images[file_path] = true; return
		"AudioStreamMP3", "AudioStreamWAV", "AudioStreamOggVorbis":
			cache.sounds[file_path] = true; return
		"FontFile", "SystemFont":
			cache.fonts[file_path] = true; return
		"TileSet":
			cache.tilesets[file_path] = true; return
		"Curve":
			cache.curves[file_path] = true; return
		"VideoStreamTheora":
			cache.videos[file_path] = true; return
	
	# If we are here, it's likely a Custom Resource or complex type.
	# We perform a safe load.
	var res = null
	
	# Using load() inside a try/catch structure is not possible in GDScript directly,
	# but we rely on ResourceLoader safety checks.
	res = load(file_path)
	
	if res == null:
		return # File might be corrupted or invalid

	# Check inheritance
	# Note: These checks trigger the resource script logic.
	if res is AudioStream:
		cache.sounds[file_path] = true
	elif res is RPGLPCCharacter:
		if res.event_preview:
			cache.events[file_path] = true
		else:
			cache.characters[file_path] = true
	elif res is RPGLPCEquipmentPart:
		cache.equipment_parts[file_path] = true
	elif res is Curve:
		cache.curves[file_path] = true
	elif res is Font:
		cache.fonts[file_path] = true
	elif res is Texture2D:
		cache.images[file_path] = true
	elif res is TileSet:
		cache.tilesets[file_path] = true
	elif res is VideoStream:
		cache.videos[file_path] = true
	
	# Explicitly release reference (though Godot does this automatically for locals, 
	# it's good practice in tool scripts handling heavy data)
	res = null


## Analyzes a scene file by examining its root node's script to determine its purpose and cache category.
func classify_scene_file(file_path: String) -> void:
	# Verificación rápida de mapas por ruta (sin cargar escena)
	var node = get_node_or_null("/root/RPGMapsInfo")
	if node and node.map_infos.maps.has(file_path):
		cache.maps[file_path] = true
		return

	# Carga el estado de la escena (ligero)
	var state = load(file_path).get_state()
	
	# 1. Chequeo por tipo de nodo nativo
	var root_node_type = state.get_node_type(0)
	if root_node_type in ["Sprite2D", "AnimatedSprite2D", "TextureRect"]:
		cache.animated_images[file_path] = true
		return
	
	# 2. Chequeo por Script
	for prop_idx in state.get_node_property_count(0):
		if state.get_node_property_name(0, prop_idx) == "script":
			var script_res = state.get_node_property_value(0, prop_idx)
			
			# OPTIMIZACIÓN: Intentar chequear sin instanciar primero (usando class_name)
			# Esto evita ejecutar _init() y es mucho más rápido y seguro.
			var global_name = script_res.get_global_name()
			# Mapeo rápido de nombres globales a categorías
			match global_name:
				"BattleAnimation": cache.animations[file_path] = true; return
				"RPGMap": cache.maps[file_path] = true; return
				"LPCEnemy": cache.enemies[file_path] = true; return
				"DialogBase": cache.message_dialogs[file_path] = true; return
				"ScrollText": cache.scroll_scenes[file_path] = true; return
				"RPGVehicle": cache.vehicles[file_path] = true; return
				"GameTransition": cache.transition_scenes[file_path] = true; return
				"TimerScene": cache.timer_scenes[file_path] = true; return
				"WeatherScene": cache.weather[file_path] = true; return
				"ExpressiveBubble": cache.expressive_bubbles[file_path] = true; return
				"ChoiceScene": cache.choice_scenes[file_path] = true; return
				"SelectDigitsScene": cache.numerical_input_scenes[file_path] = true; return
				"SelectTextsScene": cache.text_input_scenes[file_path] = true; return
				"MapParallaxScene": cache.map_parallax_scenes[file_path] = true; return
				"BattleBackgroundScene": cache.battle_background_scenes[file_path] = true; return
				"GeneralShopScene": cache.shop_scene[file_path] = true; return
				"RPGExtractionScene": cache.extraction_scenes[file_path] = true; return

			# FALLBACK: Si no usan class_name o es herencia compleja, instanciamos con cuidado.
			# Solo llegamos aquí si el match de arriba falló.
			var instance = script_res.new()
			
			# Chequeos de tipo con la instancia
			if instance is BattleAnimation: cache.animations[file_path] = true
			elif instance is RPGMap: cache.maps[file_path] = true
			elif instance is LPCEnemy: cache.enemies[file_path] = true
			elif instance is DialogBase: cache.message_dialogs[file_path] = true
			elif instance is ScrollText: cache.scroll_scenes[file_path] = true
			elif instance is RPGVehicle: cache.vehicles[file_path] = true
			elif instance is GameTransition: cache.transition_scenes[file_path] = true
			elif instance is TimerScene: cache.timer_scenes[file_path] = true
			else:
				# Chequeos por string de clase (para scripts sin class_name global fuerte)
				var instance_class = instance.get_class()
				# Nota: get_class() suele devolver el tipo nativo a menos que sobreescribas get_class()
				# Es mejor intentar casteos o flags si es posible.
				pass 

			# ¡CRÍTICO! Liberar la memoria inmediatamente
			if instance is Node:
				instance.free()
			elif instance is Object and not instance is RefCounted:
				instance.free()
			
			# Salimos del loop una vez encontrado el script
			return

## Saves the dialog options configuration to disk for persistence across editor sessions.
func save_options(_resource: Resource = null) -> void:
	var f = FileAccess.open(OPTIONS_FILE_PATH, FileAccess.WRITE)
	f.store_var(options)
	f.close()

## Saves both the cache and options data to disk and emits the cache_ready signal.
func save() -> void:
	save_options()
	if !cache_setted:
		await get_tree().create_timer(0.1).timeout
	var f = FileAccess.open(CACHE_FILE_PATH, FileAccess.WRITE)
	f.store_var(cache)
	f.close()
	cache_setted = true
	cache_ready.emit()
	if _show_prints:
		print("Cache saved!")

## Final cleanup method called when the editor is closing to ensure all data is saved.
func _on_tree_exiting() -> void:
	if !pending_files_to_process.is_empty():
		process_pending_files()
	save()
