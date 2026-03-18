@tool
extends EditorScript

func _run() -> void:
	print("📦 Starting Asset Packing Process...")

	# 1. Validate Configuration
	if AssetConfig.SOURCE_FOLDERS.size() != AssetConfig.ZIPS.size():
		printerr("❌ Configuration Error: SOURCE_FOLDERS and ZIPS arrays in AssetConfig must have the same size.")
		return

	var total_files_packed = 0

	# 2. Iterate through defined packs in AssetConfig
	for i in range(AssetConfig.SOURCE_FOLDERS.size()):
		var source = AssetConfig.SOURCE_FOLDERS[i]
		var dest = AssetConfig.ZIPS[i]
		
		print("   🔹 Processing Pack %d: %s -> %s" % [i, source, dest])
		
		var count = _create_archive(source, dest)
		total_files_packed += count

	print("✅ Batch Export Complete! Total files packed: %d" % total_files_packed)


func _create_archive(source_path: String, dest_path: String) -> int:
	# Ensure the destination directory exists
	var dest_dir = dest_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dest_dir):
		var err = DirAccess.make_dir_recursive_absolute(dest_dir)
		if err != OK:
			printerr("   ❌ Error creating directory: ", dest_dir)
			return 0

	# Initialize ZIP Packer
	var zip = ZIPPacker.new()
	var err = zip.open(dest_path)
	
	if err != OK:
		printerr("   ❌ Error creating archive file at: ", dest_path)
		return 0
	
	# Start recursive scanning
	var count = _pack_folder_recursive(zip, source_path)
	
	zip.close()
	return count


func _pack_folder_recursive(zip: ZIPPacker, current_path: String) -> int:
	var dir = DirAccess.open(current_path)
	if not dir:
		printerr("   ⚠️ Could not open folder: ", current_path)
		return 0
		
	dir.list_dir_begin()
	var file_name = dir.get_next()
	var packed_count = 0
	
	while file_name != "":
		# Ignore navigation folders
		if file_name == "." or file_name == "..":
			file_name = dir.get_next()
			continue
		
		var full_path = current_path.path_join(file_name)
		
		if dir.current_is_dir():
			# Recursion for subdirectories
			packed_count += _pack_folder_recursive(zip, full_path)
		else:
			# FILTERING LOGIC
			if _is_media_file(file_name):
				# Clean the path to remove "res://" prefix for the internal ZIP structure
				# The ZipMediaLoader expects paths like "addons/path/to/image.png"
				var internal_path = full_path.replace("res://", "")
				
				# Write the file to the ZIP/BIN
				zip.start_file(internal_path)
				zip.write_file(FileAccess.get_file_as_bytes(full_path))
				zip.close_file()
				
				packed_count += 1
		
		file_name = dir.get_next()
		
	return packed_count


func _is_media_file(file_name: String) -> bool:
	# 1. Use the global configuration for extensions
	var ext = file_name.get_extension().to_lower()
	if not ext in AssetConfig.ALLOWED_EXTENSIONS:
		return false
		
	# 2. Extra safety: Ignore import files or hidden files
	if file_name.ends_with(".import"): return false
	if file_name.begins_with("."): return false
	
	return true
