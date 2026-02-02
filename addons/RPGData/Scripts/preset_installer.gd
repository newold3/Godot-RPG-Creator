class_name PresetInstaller
extends RefCounted


## Installs a package .rpgpack into the project and returns the manifest data.
## Returns the dictionary from manifest.json or null if failed.
static func install_package(package_path: String) -> Dictionary:
	var reader := ZIPReader.new()
	var err := reader.open(package_path)

	if err != OK:
		printerr("PresetInstaller: Failed to open package at ", package_path)
		return {}

	# 1. Validate Manifest existence
	if not reader.file_exists("manifest.json"):
		printerr("PresetInstaller: Invalid package. No manifest.json found.")
		return {}

	# 2. Extract Files (excluding manifest)
	var files = reader.get_files()
	for file_path in files:
		if file_path == "manifest.json":
			continue

		var content = reader.read_file(file_path)
		# Restore to res://
		var dest_path = "res://" + file_path
		
		# Ensure directory exists
		var base_dir = dest_path.get_base_dir()
		if not DirAccess.dir_exists_absolute(base_dir):
			DirAccess.make_dir_recursive_absolute(base_dir)

		var f = FileAccess.open(dest_path, FileAccess.WRITE)
		if f:
			f.store_buffer(content)
			f.close()
		else:
			printerr("PresetInstaller: Could not write file ", dest_path)

	# 3. Read Manifest Data
	var manifest_raw = reader.read_file("manifest.json").get_string_from_utf8()
	var manifest = JSON.parse_string(manifest_raw)
	
	reader.close()

	# 4. Refresh Editor FileSystem
	# Essential so Godot sees the new files immediately
	if Engine.is_editor_hint():
		EditorInterface.get_resource_filesystem().scan()
	
	print("PresetInstaller: Files extracted successfully.")
	
	if manifest and manifest.has("scenes_to_register"):
		return manifest["scenes_to_register"]
	
	return {}


## Checks for file conflicts between the package and the current project.
## Returns an Array of Strings with the paths of files that already exist.
static func check_package_conflicts(package_path: String) -> Array[String]:
	var conflicts: Array[String] = []
	
	var reader := ZIPReader.new()
	var err := reader.open(package_path)
	
	if err != OK:
		printerr("PresetInstaller: Failed to open package for check.")
		return []

	var files = reader.get_files()
	for file_path in files:
		if file_path == "manifest.json":
			continue 
			
		var dest_path = "res://" + file_path
		
		# 1. If file does NOT exist, no conflict
		if not FileAccess.file_exists(dest_path):
			continue
			
		# 2. Get hash of existing file on disk
		var existing_md5 = FileAccess.get_md5(dest_path)
		
		# 3. Calculate hash of new file from ZIP (in memory)
		var new_data = reader.read_file(file_path)
		
		# FIX: Use HashingContext for PackedByteArray
		var ctx = HashingContext.new()
		ctx.start(HashingContext.HASH_MD5)
		ctx.update(new_data)
		var new_digest = ctx.finish()
		var new_md5 = new_digest.hex_encode() # Convert bytes to hex string
		
		# 4. Compare
		if existing_md5 != new_md5:
			conflicts.append(dest_path)

	reader.close()
	return conflicts
