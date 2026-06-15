## ==============================================================================
## MODDING RULES & GUIDELINES
## ==============================================================================
## 1. No Global Identifiers: Mod scripts MUST NOT contain a `class_name` declaration.
## 2. Base Extension: Mod scripts MUST explicitly extend the base script they are 
##    modifying (e.g., extends "res://scripts/core/RpgMap.gd").
## 3. Indentation: Mod scripts MUST be indented using Tabs, not spaces.
## ==============================================================================
extends Node

const CACHE_DIR: String = "user://.plugin_cache"
const REGISTRY_PATH: String = "user://mod_registry.tres"

var registry: Dictionary = {}
var _active_chains: Array[GDScript] = []



#region Initialization
## Initializes the autoload, loads registry, prepares cache, and injects global scripts.
func _ready() -> void:
	if not Engine.is_editor_hint():
		_load_registry()
		_prepare_cache_directory()
		_apply_global_plugins()



## Clears the cache directory when the application is requested to close.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_clear_cache_directory()
#endregion



#region Registry & Cache Management
## Loads the registered plugin configuration from the resource on disk into memory.
func _load_registry() -> void:
	if ResourceLoader.exists(REGISTRY_PATH):
		var resource: Resource = load(REGISTRY_PATH)
		
		if resource is RPGPluginList:
			registry = resource.plugins.duplicate(true)



## Creates a temporary directory for plugin chains, clearing previous sessions safely.
func _prepare_cache_directory() -> void:
	if DirAccess.dir_exists_absolute(CACHE_DIR):
		_clear_cache_directory()
		
	DirAccess.make_dir_absolute(CACHE_DIR)



## Deletes all temporary script files and the directory itself to keep the disk clean.
func _clear_cache_directory() -> void:
	if DirAccess.dir_exists_absolute(CACHE_DIR):
		var cache_dir: DirAccess = DirAccess.open(CACHE_DIR)
		
		if cache_dir:
			var files: PackedStringArray = cache_dir.get_files()
			
			for file in files:
				cache_dir.remove(file)
				
		var root_dir: DirAccess = DirAccess.open("user://")
		
		if root_dir:
			root_dir.remove(CACHE_DIR.replace("user://", ""))
#endregion



#region Global Injection
## Processes the registry and globally hijacks base scripts before scenes are instanced.
func _apply_global_plugins() -> void:
	var global_classes: Array[Dictionary] = ProjectSettings.get_global_class_list()
	
	# Ordenar por jerarquía: Las clases que NO heredan de nada de la registry van primero
	# Esto es vital: LPCBase antes que LPCCharacter
	var sorted_classes = _sort_by_inheritance(registry.keys(), global_classes)
	
	for class_key in sorted_classes:
		var base_script_path: String = _get_path_from_class_name(class_key, global_classes)
		if base_script_path.is_empty():
			continue
		
		print("PluginManager: Inyectando en clase base: ", class_key)
		_build_and_hijack_chain(base_script_path, class_key)

## Helper to sort classes so parents are hijacked before children.
func _sort_by_inheritance(keys: Array, global_classes: Array) -> Array:
	var sorted = []
	var remaining = keys.duplicate()
	
	while not remaining.is_empty():
		for key in remaining:
			var script = load(_get_path_from_class_name(key, global_classes))
			var parent_name = ""
			if script and script.get_base_script():
				parent_name = script.get_base_script().get_global_name()
			
			if parent_name == "" or not parent_name in remaining:
				sorted.append(key)
				remaining.erase(key)
				break
	return sorted



## Searches the project settings to resolve a physical script path from a class name.
func _get_path_from_class_name(target_class: String, classes_list: Array[Dictionary]) -> String:
	for cls in classes_list:
		if cls["class"] == target_class:
			return cls["path"]
			
	return ""



## Builds the plugin chain and uses take_over_path to overwrite the engine's resource cache.
func _build_and_hijack_chain(base_script_path: String, class_key: String) -> void:
	var current_parent_path: String = base_script_path
	var plugin_paths: Array = registry[class_key]
	var final_script: GDScript = null
	var index: int = 0
	
	for path in plugin_paths:
		var plugin_script: GDScript = load(path) as GDScript
		if not plugin_script: continue
		
		# Proceso de limpieza (Igual que antes)
		var regex_extends = RegEx.create_from_string("(?m)^\\s*extends\\s+.*$")
		var no_extends_source = regex_extends.sub(plugin_script.source_code, "", true)
		var regex_class = RegEx.create_from_string("(?m)^\\s*class_name\\s+.*$")
		var stripped_source = regex_class.sub(no_extends_source, "", true)
		
		var fixed_source = stripped_source.replace("    ", "\t")
		# AQUI EL CAMBIO CRÍTICO: Usamos la ruta física exacta del padre
		var final_source = "extends \"" + current_parent_path + "\"\n" + fixed_source
		
		var cryptic_name = (base_script_path + class_key + str(index)).sha256_text().substr(0, 24) + ".gd"
		var disk_path = CACHE_DIR + "/" + cryptic_name
		
		# Guardado seguro
		var file = FileAccess.open(disk_path, FileAccess.WRITE)
		file.store_string(final_source)
		file.flush()
		file.close()
			
		# FORZAR RECARGA
		var loaded_script = GDScript.new()
		loaded_script.resource_path = disk_path
		var err = loaded_script.reload() 
		
		if err == OK:
			_active_chains.append(loaded_script)
			current_parent_path = disk_path
			final_script = loaded_script
			print("PluginManager: Plugin ", index, " inyectado correctamente en ", class_key)
		else:
			push_error("PluginManager: Error recargando script: ", err)
			
		index += 1
		
	if final_script:
		# TRUCO FINAL: Secuestro de ruta
		final_script.take_over_path(base_script_path)
		# Forzamos a Godot a limpiar el caché del script original
		var original = load(base_script_path)
		if original:
			original.reload()
#endregion
