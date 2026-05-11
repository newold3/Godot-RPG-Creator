@tool
class_name MapGeneratorPresets
extends Resource


## Array containing the saved presets dictionaries
@export var presets_list: Array[Dictionary] = []


## Saves the resource directly to the user folder for persistence
func save_presets() -> void:
	ResourceSaver.save(self, "user://map_generator_presets.tres")


## Loads the presets from the user folder or creates a new one if it does not exist
static func load_presets() -> MapGeneratorPresets:
	if ResourceLoader.exists("user://map_generator_presets.tres"):
		return ResourceLoader.load("user://map_generator_presets.tres") as MapGeneratorPresets
		
	return MapGeneratorPresets.new()
