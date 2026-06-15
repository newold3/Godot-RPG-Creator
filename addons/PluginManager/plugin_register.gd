class_name PluginRegister
extends RefCounted

const REGISTRY_PATH: String = "user://rpg_plugin_list.tres"



#region Registry Management
## Adds a plugin to the registry resource and saves it to disk.
static func register_plugin(target_class_name: String, plugin_script_path: String) -> void:
	var registry: RPGPluginList = _load_or_create()
	
	if not target_class_name in registry.plugins:
		registry.plugins[target_class_name] = []
		
	if not plugin_script_path in registry.plugins[target_class_name]:
		registry.plugins[target_class_name].append(plugin_script_path)
		
	ResourceSaver.save(registry, REGISTRY_PATH)



## Removes a plugin from the registry resource and saves it to disk.
static func unregister_plugin(target_class_name: String, plugin_script_path: String) -> void:
	var registry: RPGPluginList = _load_or_create()
	
	if target_class_name in registry.plugins:
		registry.plugins[target_class_name].erase(plugin_script_path)
		
		if registry.plugins[target_class_name].is_empty():
			registry.plugins.erase(target_class_name)
			
		ResourceSaver.save(registry, REGISTRY_PATH)



## Clears all registered plugins from the resource file.
static func clear_registry() -> void:
	var registry: RPGPluginList = RPGPluginList.new()
	
	ResourceSaver.save(registry, REGISTRY_PATH)



## Internal helper to load the existing registry or create a new one if it does not exist.
static func _load_or_create() -> RPGPluginList:
	if ResourceLoader.exists(REGISTRY_PATH):
		var loaded_resource: Resource = load(REGISTRY_PATH)
		
		if loaded_resource is RPGPluginList:
			return loaded_resource as RPGPluginList
			
	return RPGPluginList.new()
#endregion
