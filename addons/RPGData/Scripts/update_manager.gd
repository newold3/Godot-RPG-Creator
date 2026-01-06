class_name UpdateManager
extends Node

## Signal emitted when the update process starts (after confirmation).
signal update_started

## Signal emitted on failure.
signal update_error(msg: String)

## URL to the GitHub repository ZIP archive (Master Branch).
const SOURCE_ZIP_URL: String = "https://github.com/newold3/Godot-RPG-Creator/archive/refs/heads/master.zip"

## File name for the downloaded zip.
const UPDATE_ZIP_FILE: String = "update_source.zip"

## Temp folder for extraction.
const TEMP_EXTRACT_FOLDER: String = "user://temp_update_source/"

var _http_request: HTTPRequest
var _confirm_dialog: ConfirmationDialog


func _ready() -> void:
	# Create HTTP Request node
	_http_request = HTTPRequest.new()
	add_child(_http_request)
	_http_request.request_completed.connect(_on_zip_downloaded)
	
	# Create UI immediately
	_create_confirmation_dialog()


func _create_confirmation_dialog() -> void:
	_confirm_dialog = ConfirmationDialog.new()
	_confirm_dialog.title = "Update Confirmation"
	_confirm_dialog.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_MAIN_WINDOW_SCREEN
	_confirm_dialog.min_size = Vector2(400, 150)
	
	var msg: String = "You are about to update Godot RPG Creator.\n\n"
	msg += "WARNING:\n"
	msg += "- All local files matching the repository will be REPLACED.\n"
	msg += "- Files created by you (external to the tool) will be KEPT.\n"
	msg += "- 'project.godot' will be MERGED: New tool settings will be applied,\n"
	msg += "  but your custom Autoloads and configurations will be preserved.\n\n"
	msg += "Godot will restart automatically after the process.\n"
	msg += "Do you want to proceed?"
	
	_confirm_dialog.dialog_text = msg
	
	_confirm_dialog.confirmed.connect(_on_user_confirmed_update)
	_confirm_dialog.canceled.connect(_on_user_cancelled_update)
	
	add_child(_confirm_dialog)


## Entry point called by external scripts.
func request_update() -> void:
	_confirm_dialog.popup()


## --- USER INTERACTION ---

func _on_user_confirmed_update() -> void:
	print("User confirmed update. Starting download...")
	download_source_update()


func _on_user_cancelled_update() -> void:
	print("Update cancelled by user.")
	_cleanup_and_die()


## --- LOGIC ---

func download_source_update() -> void:
	update_started.emit()
	
	_http_request.download_file = ProjectSettings.globalize_path("user://") + UPDATE_ZIP_FILE
	
	var error = _http_request.request(SOURCE_ZIP_URL)
	if error != OK:
		update_error.emit("Request failed.")
		_cleanup_and_die()


func _on_zip_downloaded(result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		update_error.emit("Download failed. Code: " + str(response_code))
		_cleanup_and_die()
		return
	
	print("Download complete. Extracting source...")
	_extract_zip_contents()


func _extract_zip_contents() -> void:
	var zip_reader: ZIPReader = ZIPReader.new()
	var zip_path: String = ProjectSettings.globalize_path("user://") + UPDATE_ZIP_FILE
	
	if zip_reader.open(zip_path) != OK:
		update_error.emit("Failed to open ZIP.")
		_cleanup_and_die()
		return

	var files: PackedStringArray = zip_reader.get_files()
	var base_extract_path: String = ProjectSettings.globalize_path(TEMP_EXTRACT_FOLDER)
	
	# Cleanup temp folder before starting
	var dir = DirAccess.open("user://")
	if dir.dir_exists(TEMP_EXTRACT_FOLDER):
		dir.remove(TEMP_EXTRACT_FOLDER)
	dir.make_dir_recursive(TEMP_EXTRACT_FOLDER)

	# Detect GitHub root folder logic
	var root_folder_in_zip: String = ""
	if files.size() > 0:
		var first_file = files[0]
		if "/" in first_file:
			root_folder_in_zip = first_file.split("/")[0] + "/"

	for file_path in files:
		if file_path.ends_with("/"):
			continue
			
		var content: PackedByteArray = zip_reader.read_file(file_path)
		
		# Trim root folder
		var clean_path: String = file_path
		if not root_folder_in_zip.is_empty() and file_path.begins_with(root_folder_in_zip):
			clean_path = file_path.trim_prefix(root_folder_in_zip)
		
		var abs_file_path: String = base_extract_path + clean_path
		
		# Create directories
		var base_dir: String = abs_file_path.get_base_dir()
		if not DirAccess.dir_exists_absolute(base_dir):
			DirAccess.make_dir_recursive_absolute(base_dir)
		
		var file_access = FileAccess.open(abs_file_path, FileAccess.WRITE)
		if file_access:
			file_access.store_buffer(content)
			file_access.close()

	zip_reader.close()
	
	print("Files extracted. Merging project settings...")
	_merge_project_settings(base_extract_path)
	
	print("Merge complete. Preparing update script...")
	_create_updater_bat(base_extract_path)


func _merge_project_settings(temp_folder_path: String) -> void:
	var local_config_path: String = "res://project.godot"
	var remote_config_path: String = temp_folder_path + "project.godot"
	
	if not FileAccess.file_exists(remote_config_path):
		print("Warning: Remote project.godot not found.")
		return
		
	var local_config = ConfigFile.new()
	var remote_config = ConfigFile.new()
	
	if local_config.load(local_config_path) != OK:
		push_error("Could not load local project.godot. Aborting merge.")
		return
		
	if remote_config.load(remote_config_path) != OK:
		push_error("Could not load downloaded project.godot.")
		return
	
	for section in remote_config.get_sections():
		for key in remote_config.get_section_keys(section):
			
			# FORCE UPDATE VERSION
			if section == "application" and key == "config/version":
				var new_version = remote_config.get_value(section, key)
				local_config.set_value(section, key, new_version)
				continue
			
			# ADD ONLY IF MISSING
			if not local_config.has_section_key(section, key):
				var new_val = remote_config.get_value(section, key)
				local_config.set_value(section, key, new_val)
	
	local_config.save(remote_config_path)


func _create_updater_bat(source_folder: String) -> void:
	if OS.get_name() != "Windows":
		print("Update script only supports Windows currently.")
		_cleanup_and_die()
		return

	var bat_path: String = ProjectSettings.globalize_path("user://updater.bat")
	var project_root: String = ProjectSettings.globalize_path("res://")
	var godot_exe: String = OS.get_executable_path()
	
	var script_content: String = "@echo off\r\n"
	script_content += "timeout /t 3 /nobreak > NUL\r\n"
	script_content += 'xcopy "%s" "%s" /E /Y /I\r\n' % [source_folder, project_root]
	script_content += 'start "" "%s" --path "%s"\r\n' % [godot_exe, project_root]
	script_content += '(goto) 2>nul & del "%~f0"'

	var file = FileAccess.open(bat_path, FileAccess.WRITE)
	if file:
		file.store_string(script_content)
		file.close()
		
		print("Update ready. Restarting...")
		OS.create_process(bat_path, [])
		get_tree().quit()
	else:
		update_error.emit("Could not create batch file.")
		_cleanup_and_die()


## Helper to remove itself from the tree
func _cleanup_and_die() -> void:
	print("UpdateManager cleaning up.")
	queue_free()
