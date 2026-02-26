@tool
extends ResourceFormatLoader
class_name ZipMediaLoader

# Static cache to allow global access via ZipMediaLoader.file_exists()
# and to share the index across the engine.
static var _files_index: Dictionary = {} # Key: String (path), Value: ZIPReader instance
static var _open_readers: Array[ZIPReader] = []
static var _resource_cache: Dictionary = {}
static var _initialized: bool = false

func _init() -> void:
	if not _initialized:
		_mount_system()


## Mounts all archives defined in AssetConfig.
## Checks global paths (Editor) and local paths next to executable (Export).
static func _mount_system() -> void:
	if _initialized:
		return

	# Iterate through all configured ZIP/BIN files
	for zip_path in AssetConfig.ZIPS:
		_mount_single_archive(zip_path)
	
	_initialized = true
	print("📦 [ZipMediaLoader] System initialized. Total indexed assets: ", _files_index.size())


static func _mount_single_archive(zip_path: String) -> void:
	var reader = ZIPReader.new()
	var err = Error.FAILED
	
	# 1. Try Global Path (Best for Editor / Windows)
	# This bypasses the editor's virtual file system locks.
	var path_global = ProjectSettings.globalize_path(zip_path)
	err = reader.open(path_global)
	
	# 2. Try Relative Path to Executable (Critical for Exported Builds)
	# If the game is exported, the assets are likely copied next to the .exe
	if err != OK:
		var exe_dir = OS.get_executable_path().get_base_dir()
		# Remove "res://" to append to the OS path. 
		# E.g., "res://data/assets.bin" becomes "data/assets.bin"
		var local_path = exe_dir.path_join(zip_path.replace("res://", ""))
		err = reader.open(local_path)
	
	# 3. Try Standard Path (Fallback for Android/PCK embedded)
	if err != OK:
		err = reader.open(zip_path)
	
	# If failed, we stop processing this specific zip, but don't crash.
	if err != OK:
		# In runtime, it is normal if assets are missing (e.g. no mods installed)
		# In editor, this might happen if the bin hasn't been generated yet.
		return

	# Index the content
	var files = reader.get_files()
	for f in files:
		# Map the file path directly to this specific Reader instance
		_files_index[f] = reader
	
	# Keep a reference so the reader doesn't get garbage collected
	_open_readers.append(reader)


## Public static method to check if a file exists (Disk OR Zip).
static func file_exists(path: String) -> bool:
	# 1. Priority to physical disk (allows users to override/mod assets)
	if FileAccess.file_exists(path):
		return true
	
	# 2. Ensure system is mounted
	if not _initialized:
		_mount_system()
	
	# 3. Check internal index
	var path_clean = path.replace("res://", "")
	return _files_index.has(path_clean)


# --- RESOURCE LOADER API ---


func _get_recognized_extensions() -> PackedStringArray:
	# Use the global configuration
	return PackedStringArray(AssetConfig.ALLOWED_EXTENSIONS)


func _handles_type(type: StringName) -> bool:
	return type == "Texture2D" or type == "ImageTexture" or type == "AudioStream" or type == ""


func _recognize_path(path: String, _type: StringName) -> bool:
	# If it exists on disk, return false to let Godot handle it natively.
	if FileAccess.file_exists(path):
		return false
	
	var path_clean = path.replace("res://", "")
	return _files_index.has(path_clean)


func _load(path: String, original_path: String, _use_sub_threads: bool, _cache_mode: int) -> Variant:
	# 1. Check Cache
	if _resource_cache.has(path):
		return _resource_cache[path]
	
	if not _initialized:
		_mount_system()

	var path_clean = path.replace("res://", "")
	
	# 2. Identify the correct ZIP Reader for this file
	if not _files_index.has(path_clean):
		return Error.ERR_FILE_NOT_FOUND

	var reader: ZIPReader = _files_index[path_clean]
	
	# 3. Read bytes
	var bytes = reader.read_file(path_clean)
	if bytes.size() == 0:
		return Error.ERR_FILE_NOT_FOUND

	# 4. Decode
	var ext = path.get_extension().to_lower()
	var resource = null
	
	match ext:
		"png", "jpg", "jpeg", "bmp", "tga", "webp":
			resource = _load_image(bytes, ext)
		"ogg":
			resource = _load_audio_ogg(bytes)
		"mp3":
			resource = _load_audio_mp3(bytes)
		_:
			return Error.ERR_FILE_UNRECOGNIZED
	
	# 5. Finalize
	if resource:
		if resource is Resource:
			resource.take_over_path(original_path)
		
		_resource_cache[path] = resource
		return resource
	
	return Error.FAILED


## Returns a list of all indexed files that end with the given extension.
## Useful for rebuilding databases from packed files.
static func get_files_by_extension(extension: String) -> Array[String]:
	var found_files: Array[String] = []
	var ext_with_dot = "." + extension.get_extension() if "." in extension else "." + extension
	
	# Clean the search extension (e.g., ".lcc")
	ext_with_dot = ext_with_dot.to_lower()
	
	for path in _files_index.keys():
		if path.to_lower().ends_with(ext_with_dot):
			# We return the "res://" version so it's ready to be used by 'load()'
			found_files.append("res://" + path)
			
	return found_files


## Returns files in a specific path, filtering by extension.
## Searches both physical disk and packed archives.
static func get_files_in_path(base_path: String, allowed_extensions: Array = []) -> Array[String]:
	var results: Array[String] = []
	var clean_base = base_path.replace("res://", "")
	
	# 1. Check Physical Disk first (for dev/mods)
	if DirAccess.dir_exists_absolute(base_path):
		var dir = DirAccess.open(base_path)
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir():
				var ext = file_name.get_extension().to_lower()
				if allowed_extensions.is_empty() or ext in allowed_extensions:
					results.append(base_path.path_join(file_name))
			file_name = dir.get_next()

	# 2. Check Packed Index
	for path in _files_index.keys():
		if path.begins_with(clean_base):
			# Ensure we are in the same folder (not subfolders)
			var sub_path = path.replace(clean_base, "")
			if not "/" in sub_path:
				var ext = path.get_extension().to_lower()
				if allowed_extensions.is_empty() or ext in allowed_extensions:
					var full_res_path = "res://" + path
					if not full_res_path in results:
						results.append(full_res_path)
	
	return results


static func get_text_content(path: String) -> String:
	# 1. Try to read from Physical Disk first
	if FileAccess.file_exists(path):
		return FileAccess.get_file_as_string(path)
	
	# 2. If not on disk, search in the packed index
	var path_clean = path.replace("res://", "")
	if not _files_index.has(path_clean): 
		return ""
	
	var reader: ZIPReader = _files_index[path_clean]
	var bytes = reader.read_file(path_clean)
	
	if bytes.size() == 0:
		return ""
		
	return bytes.get_string_from_utf8()


## Returns an AudioStream from either physical disk or packed archive
static func get_audio_stream(path: String) -> AudioStream:
	if FileAccess.file_exists(path):
		var res = ResourceLoader.load(path)
		if res is AudioStream:
			return res

	var path_clean = path.replace("res://", "")
	if not _files_index.has(path_clean):
		return null

	var reader: ZIPReader = _files_index[path_clean]
	var bytes = reader.read_file(path_clean)
	
	if bytes.size() == 0:
		return null
		
	if path.to_lower().ends_with(".ogg"):
		return AudioStreamOggVorbis.load_from_buffer(bytes)
		
	return null


# --- DECODERS ---


func _load_image(bytes: PackedByteArray, ext: String) -> ImageTexture:
	var img = Image.new()
	var err = Error.FAILED
	
	match ext:
		"png": err = img.load_png_from_buffer(bytes)
		"jpg", "jpeg": err = img.load_jpg_from_buffer(bytes)
		"bmp": err = img.load_bmp_from_buffer(bytes)
		"tga": err = img.load_tga_from_buffer(bytes)
		"webp": err = img.load_webp_from_buffer(bytes)
	
	if err != OK:
		printerr("❌ Error decoding image: ", ext)
		return null
	
	return ImageTexture.create_from_image(img)


func _load_audio_ogg(bytes: PackedByteArray) -> AudioStreamOggVorbis:
	return AudioStreamOggVorbis.load_from_buffer(bytes)


func _load_audio_mp3(bytes: PackedByteArray) -> AudioStreamMP3:
	var stream = AudioStreamMP3.new()
	stream.data = bytes
	return stream
