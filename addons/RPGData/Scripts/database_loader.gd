class_name DatabaseLoader
extends Object


## Path to the file containing the raw password/secret content (The Key).
const PASSWORD_FILE_PATH: String = "user://dev_access.key"

## Path to the text file containing ONLY the expected SHA256 string (The Lock).
const SHA_LOCK_FILE_PATH: String = "user://dev_access.sha"

## Folder where the obfuscated master data is stored (Developer Mode).
const MASTER_FOLDER: String = "res://addons/RPGData/MasterData/"

## Folder where the user data is stored (Normal Mode).
const USER_FOLDER: String = "res://data/"

## Path to the launcher identification file.
const PROJECT_CONFIG_FILE: String = "res://rpg_project.cfg"

# -- File Names --
const FILE_DATABASE: String = "database"
const FILE_SYSTEM: String = "system"
const FILE_MAP_INFO: String = "map_info"
const FILE_VERSION: String = "version.dat"


static var is_develop_build: bool = false
static var is_setup: bool = false


## Initial setup to determine mode and ensure folder structures.
static func setup() -> void:
	if is_setup: return
	
	is_develop_build = _check_dev_access()
	
	if is_develop_build:
		if not DirAccess.dir_exists_absolute(MASTER_FOLDER):
			DirAccess.make_dir_recursive_absolute(MASTER_FOLDER)
	
	if not DirAccess.dir_exists_absolute(USER_FOLDER):
		DirAccess.make_dir_recursive_absolute(USER_FOLDER)

	is_setup = true


# ------------------------------------------------------------------------------
# SAVE FUNCTIONS
# ------------------------------------------------------------------------------


## Saves the Database resource.
static func save_database() -> void:
	var resource = RPGSYSTEM.database
	_save_generic(resource, FILE_DATABASE)
	if is_develop_build and resource:
		_save_master_version(resource._id_version)


## Saves the System resource.
static func save_system() -> void:
	var resource = RPGSYSTEM.system
	_save_generic(resource, FILE_SYSTEM)
	_save_project_config_file()


## Saves the MapInfos resource.
static func save_map_infos() -> void:
	var resource = RPGSYSTEM.map_infos.map_infos
	_save_generic(resource, FILE_MAP_INFO)


## Generates the config file required by the Launcher to identify this project.
static func _save_project_config_file() -> void:
	var config = ConfigFile.new()
	
	# 1. Get Project Name from ProjectSettings
	var project_name: String = ProjectSettings.get_setting("application/config/name", "Untitled RPG")
	
	# 2. Get Game Version from ProjectSettings (custom property or standard if available)
	# Defaulting to 1.0.0 if not set in settings
	var project_version: String = ProjectSettings.get_setting("application/config/version", "1.0.0")
	
	# 3. Get Editor/Creator Version from the Database resource
	var editor_id_version: int = 0
	if RPGSYSTEM.database:
		editor_id_version = RPGSYSTEM.database._id_version

	# Set values
	config.set_value("config", "name", project_name)
	config.set_value("config", "icon", "res://icon.svg")
	config.set_value("config", "version", project_version)
	
	# We save the internal DB version ID as the "creator_version"
	config.set_value("config", "creator_version", editor_id_version) 
	
	config.save(PROJECT_CONFIG_FILE)


# ------------------------------------------------------------------------------
# LOAD FUNCTIONS
# ------------------------------------------------------------------------------


## Loads the Database resource.
static func load_database() -> Resource:
	var res = _load_generic(FILE_DATABASE)
	sanitize_database_custom_data(res)
	return res


## Loads the System resource.
static func load_system() -> Resource:
	var res = _load_generic(FILE_SYSTEM)
	sanitize_database_custom_data(res)
	return res


## Loads the MapInfos resource.
static func load_map_infos() -> Resource:
	return _load_generic(FILE_MAP_INFO)


# ------------------------------------------------------------------------------
# INTERNAL LOGIC
# ------------------------------------------------------------------------------


## Handles saving based on the current mode (Dev vs User).
static func _save_generic(resource: Resource, filename: String) -> void:
	setup()
	
	if resource == null:
		printerr("Error: Trying to save null resource for: ", filename)
		return

	if is_develop_build:
		# Dev Mode: Save compressed binary using store_var
		var path = MASTER_FOLDER + filename + ".bin"
		var file = FileAccess.open_compressed(path, FileAccess.WRITE, FileAccess.COMPRESSION_ZSTD)
		if file:
			file.store_var(resource, true) # true = full_objects (saves the resource structure)
			file.close()
		else:
			printerr("Failed to save Master Data: ", path)
	else:
		# User Mode: Standard ResourceSaver
		var path = USER_FOLDER + filename + ".res"
		ResourceSaver.save(resource, path)
		resource.take_over_path(path)


## Handles loading logic, including fallback creation from Master if User data is missing.
static func _load_generic(filename: String) -> Resource:
	setup()
	
	var master_path = MASTER_FOLDER + filename + ".bin"
	var user_path = USER_FOLDER + filename + ".res"

	# 1. Developer Mode: Always load Master
	if is_develop_build:
		if FileAccess.file_exists(master_path):
			return _load_from_compressed_bin(master_path)
		else:
			printerr("Dev Warning: Master file missing: ", master_path)
			return null

	# 2. User Mode: Try loading User file
	if FileAccess.file_exists(user_path):
		var user_res = ResourceLoader.load(user_path)
		sanitize_database_custom_data(user_res)
		return user_res
	
	# 3. User Mode Fallback: User file missing, load Master and create User copy
	if FileAccess.file_exists(master_path):
		var master_resource = _load_from_compressed_bin(master_path)
		if master_resource:
			sanitize_database_custom_data(master_resource)
			# Save immediately to user folder so next time it loads normally
			ResourceSaver.save(master_resource, user_path)
			return master_resource
	
	printerr("Critical Error: Both User data and Master template are missing for: ", filename)
	return null


## Recursively ensures that any RPG resource in the database has a valid `custom_data` Dictionary.
## If `custom_data` is null or not a Dictionary, assigns `{}`.
static func sanitize_database_custom_data(root: Variant, visited: Dictionary = {}) -> void:
	if root == null:
		return
	if root is Array:
		for item in root:
			if item is Object or item is Array:
				sanitize_database_custom_data(item, visited)
		return
	if not (root is Object):
		return
		
	var obj_id: int = root.get_instance_id()
	if visited.has(obj_id):
		return
	visited[obj_id] = true
	
	if "custom_data" in root:
		if root.custom_data == null or not (root.custom_data is Dictionary):
			root.custom_data = {}
			
	var prop_list = root.get_property_list()
	for prop in prop_list:
		var usage: int = prop.get("usage", 0)
		if (usage & PROPERTY_USAGE_STORAGE) == 0:
			continue
		var p_name: String = prop.get("name", "")
		if p_name in ["resource_path", "resource_local_to_scene", "resource_scene_unique_id", "resource_name", "script"]:
			continue
		var val = root.get(p_name)
		if val is Object or val is Array:
			sanitize_database_custom_data(val, visited)


## Helper to load a resource from a compressed binary file created with store_var.
static func _load_from_compressed_bin(path: String) -> Resource:
	var file = FileAccess.open_compressed(path, FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
	if not file:
		return null
	
	var data = file.get_var(true) # true = allow_objects
	file.close()
	
	if data is Resource:
		sanitize_database_custom_data(data)
		if "terms" in data and data.terms and "messages" in data.terms:
			for m in data.terms.messages:
				if m and m.id == "Game End" and m.text == "Quit Game":
					m.id = "Quit Game"
		if "quests" in data and data.quests:
			for quest in data.quests:
				if quest:
					if ("icon_available" in quest) and not quest.icon_available:
						quest.icon_available = RPGIcon.new("res://Scenes/QuestMarkers/quest_available.tscn")
					if ("icon_progress" in quest) and not quest.icon_progress:
						quest.icon_progress = RPGIcon.new("res://Scenes/QuestMarkers/quest_in_progress.tscn")
					if ("icon_completed" in quest) and not quest.icon_completed:
						quest.icon_completed = RPGIcon.new("res://Scenes/QuestMarkers/quest_completed.tscn")
					if ("icon_failed" in quest) and not quest.icon_failed:
						quest.icon_failed = RPGIcon.new("res://Scenes/QuestMarkers/quest_failed.tscn")
					if ("icon_escort" in quest) and not quest.icon_escort:
						quest.icon_escort = RPGIcon.new("res://Scenes/QuestMarkers/quest_escort.tscn")
		return data
	
	printerr("Error: Loaded data is not a Resource: ", path)
	return null


## Saves the current version ID to a file in the Master folder.
static func _save_master_version(version: int) -> void:
	var path = MASTER_FOLDER + FILE_VERSION
	var file = FileAccess.open_compressed(path, FileAccess.WRITE, FileAccess.COMPRESSION_ZSTD)
	if file:
		file.store_32(version)
		file.close()


## Reads the master version ID from the Master folder.
## Returns 0 if the file doesn't exist.
static func get_master_version() -> int:
	var path = MASTER_FOLDER + FILE_VERSION
	if FileAccess.file_exists(path):
		var file = FileAccess.open_compressed(path, FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
		if file:
			var v = file.get_32()
			file.close()
			return v
	return 0


## Checks dev access keys.
static func _check_dev_access() -> bool:
	if not FileAccess.file_exists(PASSWORD_FILE_PATH) or not FileAccess.file_exists(SHA_LOCK_FILE_PATH):
		return false

	var expected_sha: String = FileAccess.get_file_as_string(SHA_LOCK_FILE_PATH).strip_edges()
	var actual_sha: String = FileAccess.get_sha256(PASSWORD_FILE_PATH)

	return actual_sha == expected_sha
