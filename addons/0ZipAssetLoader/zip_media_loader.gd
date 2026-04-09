@tool
extends ResourceFormatLoader
class_name ZipMediaLoader

static var _files_index: Dictionary = {}
static var _open_readers: Array[ZIPReader] = []
static var _resource_cache: Dictionary = {}
static var _initialized: bool = false


func _init() -> void:
	if not _initialized:
		_mount_system()


## Mounts all archives defined in AssetConfig.
## Checks global paths and local paths next to executable.
static func _mount_system() -> void:
	if _initialized:
		return
		
	for zip_path in AssetConfig.ZIPS:
		_mount_single_archive(zip_path)
		
	_initialized = true
	print("📦 [ZipMediaLoader] System initialized. Total indexed assets: ", _files_index.size())


## Mounts a single archive handling different path strategies based on export or editor.
static func _mount_single_archive(zip_path: String) -> void:
	var reader = ZIPReader.new()
	var err = Error.FAILED
	
	var path_global = ProjectSettings.globalize_path(zip_path)
	err = reader.open(path_global)
	
	if err != OK:
		var exe_dir = OS.get_executable_path().get_base_dir()
		var local_path = exe_dir.path_join(zip_path.replace("res://", ""))
		err = reader.open(local_path)
		
	if err != OK:
		err = reader.open(zip_path)
		
	if err != OK:
		return
		
	var files = reader.get_files()
	
	for f in files:
		_files_index[f] = reader
		
	_open_readers.append(reader)


## Public static method to check if a file exists on Disk OR Zip.
static func file_exists(path: String) -> bool:
	if FileAccess.file_exists(path):
		return true
		
	if not _initialized:
		_mount_system()
		
	var path_clean = path.replace("res://", "")
	
	return _files_index.has(path_clean)


## Returns recognized extensions configured globally.
func _get_recognized_extensions() -> PackedStringArray:
	return PackedStringArray(AssetConfig.ALLOWED_EXTENSIONS)


## Verifies if the loader handles a specific resource type.
func _handles_type(type: StringName) -> bool:
	return type == "Texture2D" or type == "ImageTexture" or type == "AudioStream" or type == ""


## Recognizes valid paths excluding files existing on disk to let native loaders act.
func _recognize_path(path: String, _type: StringName) -> bool:
	if FileAccess.file_exists(path):
		return false
		
	var path_clean = path.replace("res://", "")
	
	return _files_index.has(path_clean)


## Loads the resource from the indexed packed archives.
func _load(path: String, original_path: String, _use_sub_threads: bool, _cache_mode: int) -> Variant:
	if _resource_cache.has(path):
		return _resource_cache[path]
		
	if not _initialized:
		_mount_system()
		
	var path_clean = path.replace("res://", "")
	
	if not _files_index.has(path_clean):
		return Error.ERR_FILE_NOT_FOUND
		
	var reader: ZIPReader = _files_index[path_clean]
	
	var bytes = reader.read_file(path_clean)
	
	if bytes.size() == 0:
		return Error.ERR_FILE_NOT_FOUND
		
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
			
	if resource:
		if resource is Resource:
			resource.take_over_path(original_path)
			
		_resource_cache[path] = resource
		
		return resource
		
	return Error.FAILED


## Returns a list of all indexed files that end with the given extension.
static func get_files_by_extension(extension: String) -> Array[String]:
	var found_files: Array[String] = []
	var ext_with_dot = "." + extension.get_extension() if "." in extension else "." + extension
	
	ext_with_dot = ext_with_dot.to_lower()
	
	for path in _files_index.keys():
		if path.to_lower().ends_with(ext_with_dot):
			found_files.append("res://" + path)
			
	return found_files


## Returns files in a specific path, filtering by extension. Searches both physical disk and packed archives. Can be recursive.
static func get_files_in_path(base_path: String, allowed_extensions: Array = [], recursive: bool = false) -> Array[String]:
	var results: Array[String] = []
	var clean_base = base_path.replace("res://", "")
	
	if DirAccess.dir_exists_absolute(base_path):
		var dirs_to_check: Array[String] = [base_path]
		
		while not dirs_to_check.is_empty():
			var current_dir = dirs_to_check.pop_back()
			var dir = DirAccess.open(current_dir)
			
			if dir:
				dir.list_dir_begin()
				var file_name = dir.get_next()
				
				while file_name != "":
					var full_path = current_dir.path_join(file_name)
					
					if dir.current_is_dir():
						if recursive:
							dirs_to_check.append(full_path)
					else:
						var ext = file_name.get_extension().to_lower()
						
						if allowed_extensions.is_empty() or ext in allowed_extensions:
							results.append(full_path)
							
					file_name = dir.get_next()
					
	for path in _files_index.keys():
		if path.begins_with(clean_base):
			var sub_path = path.replace(clean_base, "")
			
			if recursive or not "/" in sub_path:
				var ext = path.get_extension().to_lower()
				
				if allowed_extensions.is_empty() or ext in allowed_extensions:
					var full_res_path = "res://" + path
					
					if not full_res_path in results:
						results.append(full_res_path)
						
	return results


## Retrieves raw text content from either physical disk or indexed packed archives.
static func get_text_content(path: String) -> String:
	if FileAccess.file_exists(path):
		return FileAccess.get_file_as_string(path)
		
	var path_clean = path.replace("res://", "")
	
	if not _files_index.has(path_clean): 
		return ""
		
	var reader: ZIPReader = _files_index[path_clean]
	var bytes = reader.read_file(path_clean)
	
	if bytes.size() == 0:
		return ""
		
	return bytes.get_string_from_utf8()


## Returns an AudioStream from either physical disk or packed archive.
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


## Decodes image files from packed bytes into an ImageTexture.
func _load_image(bytes: PackedByteArray, ext: String) -> ImageTexture:
	var img = Image.new()
	var err = Error.FAILED
	
	match ext:
		"png": 
			err = img.load_png_from_buffer(bytes)
		"jpg", "jpeg": 
			err = img.load_jpg_from_buffer(bytes)
		"bmp": 
			err = img.load_bmp_from_buffer(bytes)
		"tga": 
			err = img.load_tga_from_buffer(bytes)
		"webp": 
			err = img.load_webp_from_buffer(bytes)
			
	if err != OK:
		printerr("❌ Error decoding image: ", ext)
		return null
		
	return ImageTexture.create_from_image(img)


## Decodes OGG vorbis files from packed bytes.
func _load_audio_ogg(bytes: PackedByteArray) -> AudioStreamOggVorbis:
	return AudioStreamOggVorbis.load_from_buffer(bytes)


## Decodes MP3 files from packed bytes.
func _load_audio_mp3(bytes: PackedByteArray) -> AudioStreamMP3:
	var stream = AudioStreamMP3.new()
	stream.data = bytes
	
	return stream
