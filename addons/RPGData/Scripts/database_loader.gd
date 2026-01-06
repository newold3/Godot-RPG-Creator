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


## Saves the MapInfos resource.
static func save_map_infos() -> void:
	var resource = RPGSYSTEM.map_infos.map_infos
	_save_generic(resource, FILE_MAP_INFO)


# ------------------------------------------------------------------------------
# LOAD FUNCTIONS
# ------------------------------------------------------------------------------


## Loads the Database resource.
static func load_database() -> Resource:
	return _load_generic(FILE_DATABASE)


## Loads the System resource.
static func load_system() -> Resource:
	return _load_generic(FILE_SYSTEM)


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
		return ResourceLoader.load(user_path)
	
	# 3. User Mode Fallback: User file missing, load Master and create User copy
	if FileAccess.file_exists(master_path):
		var master_resource = _load_from_compressed_bin(master_path)
		if master_resource:
			# Save immediately to user folder so next time it loads normally
			ResourceSaver.save(master_resource, user_path)
			return master_resource
	
	printerr("Critical Error: Both User data and Master template are missing for: ", filename)
	return null


## Helper to load a resource from a compressed binary file created with store_var.
static func _load_from_compressed_bin(path: String) -> Resource:
	var file = FileAccess.open_compressed(path, FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
	if not file:
		return null
	
	var data = file.get_var(true) # true = allow_objects
	file.close()
	
	if data is Resource:
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
