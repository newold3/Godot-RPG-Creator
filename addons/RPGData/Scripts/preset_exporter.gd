class_name PresetExporter
extends RefCounted


## Exports selected scenes and dependencies to a custom package file.
## [param scenes_data]: Array of Dictionaries containing DB info (ID, path, name) for the selected scenes.
## [param export_path]: Where to save the file (e.g., "C:/MyPresets/pack.rpgpack").
static func export_preset_package(scenes_data: Dictionary, export_path: String) -> void:
	var packer = ZIPPacker.new()
	var err = packer.open(export_path)
	
	if err != OK:
		printerr("Failed to open ZIP for writing: ", err)
		return

	# 1. Gather all file paths
	var root_paths: Array = []
	for item in scenes_data.values():
		root_paths.append(item)

	var all_files = DependencyScanner.get_all_dependencies(root_paths)

	# 2. Write files to the ZIP
	# We preserve the directory structure relative to 'res://'
	for file_path in all_files:
		var file_data = FileAccess.get_file_as_bytes(file_path)
		# Convert res://path/to/file -> path/to/file
		var internal_path = file_path.replace("res://", "")
		packer.start_file(internal_path)
		packer.write_file(file_data)
		packer.close_file()

	# 3. Create and Write Manifest
	# This tells the installer how to update the DB
	var manifest = {
		"version": "1.0",
		"created_by": "Godot RPG Creator",
		"scenes_to_register": scenes_data # Pass the full DB object info
	}
	
	var json_string = JSON.stringify(manifest, "\t")
	packer.start_file("manifest.json")
	packer.write_file(json_string.to_utf8_buffer())
	packer.close_file()

	packer.close()
	print("Package exported successfully to: " + export_path)
