@tool
extends EditorExportPlugin

# Variable to store the export path captured in _export_begin
var _current_export_path: String = ""

# Defines the plugin name for the editor
func _get_name() -> String:
	return "RPG Asset Copier"


# 1. Capture the path when export starts
func _export_begin(features: PackedStringArray, is_debug: bool, path: String, flags: int) -> void:
	_current_export_path = path


# 2. Execute the copy when export finishes successfully
func _export_end() -> void:
	if _current_export_path.is_empty():
		return

	print("📦 [AutoExport] Starting external asset copy...")
	
	# 'path' is the full path to the executable (e.g., C:/Games/MyRPG/Game.exe)
	var export_base_dir = _current_export_path.get_base_dir()
	var copied_count = 0

	# Loop through all configured ZIP/BIN files in AssetConfig
	for zip_path in AssetConfig.ZIPS:
		if not FileAccess.file_exists(zip_path):
			printerr("❌ [AutoExport] Source file not found: ", zip_path)
			printerr("   Please run the AssetPacker script first.")
			continue

		# Calculate the destination path to match the internal structure
		# Example: Source "res://data/assets.bin" -> Dest "C:/Games/MyRPG/data/assets.bin"
		var relative_path = zip_path.replace("res://", "")
		var dest_path = export_base_dir.path_join(relative_path)
		
		# Perform the copy
		if _copy_file(zip_path, dest_path):
			copied_count += 1
			print("   ✅ Copied: ", relative_path)
	
	if copied_count > 0:
		print("📦 [AutoExport] Successfully copied %d asset packages to export folder." % copied_count)
	else:
		printerr("⚠️ [AutoExport] No assets were copied.")
	
	# Reset path for next export
	_current_export_path = ""


func _copy_file(source: String, destination: String) -> bool:
	# 1. Ensure the destination folder exists
	var dest_dir = destination.get_base_dir()
	if not DirAccess.dir_exists_absolute(dest_dir):
		var err = DirAccess.make_dir_recursive_absolute(dest_dir)
		if err != OK:
			printerr("   ❌ Error creating directory: ", dest_dir)
			return false

	# 2. Read Source
	var file_src = FileAccess.open(source, FileAccess.READ)
	if not file_src:
		printerr("   ❌ Could not read source: ", source)
		return false
	
	var buffer = file_src.get_buffer(file_src.get_length())
	file_src.close()

	# 3. Write Destination
	var file_dest = FileAccess.open(destination, FileAccess.WRITE)
	if not file_dest:
		printerr("   ❌ Could not write to destination: ", destination)
		return false
		
	file_dest.store_buffer(buffer)
	file_dest.close()
	
	return true
