class_name UpdateManager
extends Node

## Signal emitted when the update process starts.
signal update_started
## Signal emitted on failure.
signal update_error(msg: String)

const SOURCE_ZIP_URL: String = "https://github.com/newold3/Godot-RPG-Creator/archive/refs/heads/master.zip"
const UPDATE_ZIP_FILE: String = "update_source.zip"
const TEMP_EXTRACT_FOLDER: String = "user://temp_update_source/"

var _http_request: HTTPRequest
var _confirm_dialog: ConfirmationDialog
var _blocking_panel: Panel
var _status_label: Label
var _last_print_time: int = 0

# Threading variables
var _thread: Thread
var _files_processed_count: int = 0 
var _total_files_count: int = 0
var _current_task_name: String = ""


func _ready() -> void:
	# Ensure this node runs even if the scene tree is paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)
	
	_thread = Thread.new()
	
	_http_request = HTTPRequest.new()
	_http_request.use_threads = true 
	add_child(_http_request)
	_http_request.request_completed.connect(_on_zip_downloaded)
	
	_create_ui()


func _exit_tree() -> void:
	if _thread.is_started():
		_thread.wait_to_finish()


func _process(_delta: float) -> void:
	# Limit UI updates to save resources
	var current_time = Time.get_ticks_msec()
	if current_time - _last_print_time < 50: return
	_last_print_time = current_time

	# 1. Download Phase
	if not _thread.is_started() and _http_request.get_body_size() > 0:
		var downloaded = _http_request.get_downloaded_bytes()
		var total = _http_request.get_body_size()
		var mb = downloaded / (1024.0 * 1024.0)
		var percent = (float(downloaded) / total) * 100.0
		_status_label.text = "Downloading... %.1f%% (%.2f MB)" % [percent, mb]
		return

	# 2. Extraction Phase (Threaded)
	if _thread.is_started():
		var count = _files_processed_count
		var task = _current_task_name
		
		if _total_files_count > 0:
			var percent = (float(count) / _total_files_count) * 100.0
			_status_label.text = "%s\n%d / %d (%.1f%%)" % [task, count, _total_files_count, percent]
		else:
			_status_label.text = "%s..." % task


func _create_ui() -> void:
	_confirm_dialog = ConfirmationDialog.new()
	_confirm_dialog.title = "Update Confirmation"
	_confirm_dialog.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_MAIN_WINDOW_SCREEN
	_confirm_dialog.min_size = Vector2(450, 200)
	_confirm_dialog.dialog_text = "Update Godot RPG Creator?\nLocal repository files will be replaced.\nYour custom files are safe."
	_confirm_dialog.confirmed.connect(_on_user_confirmed_update)
	_confirm_dialog.canceled.connect(_on_user_cancelled_update)
	add_child(_confirm_dialog)

	_blocking_panel = Panel.new()
	_blocking_panel.visible = false
	_blocking_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.8) 
	_blocking_panel.add_theme_stylebox_override("panel", style)
	_blocking_panel.z_index = 4096 
	
	_status_label = Label.new()
	_status_label.text = "Initializing..."
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status_label.set_anchors_preset(Control.PRESET_CENTER)
	_blocking_panel.add_child(_status_label)
	
	var canvas = CanvasLayer.new()
	canvas.layer = 100 
	canvas.add_child(_blocking_panel)
	add_child(canvas)


func request_update() -> void:
	_confirm_dialog.popup_centered()


func _on_user_confirmed_update() -> void:
	_blocking_panel.visible = true
	_status_label.text = "Starting download..."
	download_source_update()


func _on_user_cancelled_update() -> void:
	_cleanup_and_die()


func download_source_update() -> void:
	update_started.emit()
	_http_request.download_file = ProjectSettings.globalize_path("user://") + UPDATE_ZIP_FILE
	
	var error = _http_request.request(SOURCE_ZIP_URL)
	if error != OK:
		update_error.emit("Request failed.")
		_cleanup_and_die()
	else:
		set_process(true)


func _on_zip_downloaded(result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		update_error.emit("Download failed.")
		_cleanup_and_die()
		return
	
	_status_label.text = "Download Complete. Starting Thread..."
	_thread.start(_threaded_extraction_logic)


## --- THREADED LOGIC ---
func _threaded_extraction_logic() -> void:
	var zip_reader = ZIPReader.new()
	var zip_path = ProjectSettings.globalize_path("user://") + UPDATE_ZIP_FILE
	
	if zip_reader.open(zip_path) != OK:
		call_deferred("_on_thread_error", "Failed to open ZIP.")
		return

	var files = zip_reader.get_files()
	var base_extract_path = ProjectSettings.globalize_path(TEMP_EXTRACT_FOLDER)
	
	_total_files_count = files.size()
	_files_processed_count = 0
	_current_task_name = "Extracting Files"

	# Prepare temp directory
	var dir = DirAccess.open("user://")
	dir.make_dir_recursive(TEMP_EXTRACT_FOLDER)

	var root_folder_in_zip = ""
	if files.size() > 0 and "/" in files[0]:
		root_folder_in_zip = files[0].split("/")[0] + "/"

	var last_created_dir = "" 
	
	for file_path in files:
		_files_processed_count += 1
		
		if file_path.ends_with("/"): continue
			
		var content = zip_reader.read_file(file_path)
		
		var clean_path = file_path
		if not root_folder_in_zip.is_empty() and file_path.begins_with(root_folder_in_zip):
			clean_path = file_path.trim_prefix(root_folder_in_zip)
		
		var abs_file_path = base_extract_path + clean_path
		
		var current_base_dir = abs_file_path.get_base_dir()
		if current_base_dir != last_created_dir:
			if not DirAccess.dir_exists_absolute(current_base_dir):
				DirAccess.make_dir_recursive_absolute(current_base_dir)
			last_created_dir = current_base_dir
		
		var file_access = FileAccess.open(abs_file_path, FileAccess.WRITE)
		if file_access:
			file_access.store_buffer(content)
			file_access.close()

	zip_reader.close()
	
	# CLEANUP 1: Delete ZIP
	if dir.file_exists(UPDATE_ZIP_FILE):
		dir.remove(UPDATE_ZIP_FILE)
	
	_current_task_name = "Merging Config"
	_thread_safe_merge_project(base_extract_path)
	
	_current_task_name = "Creating Installer"
	_thread_safe_create_bat(base_extract_path)
	
	call_deferred("_on_thread_finished")


func _thread_safe_merge_project(temp_folder_path: String) -> void:
	var local_config_path = "res://project.godot"
	var remote_config_path = temp_folder_path + "project.godot"
	
	if not FileAccess.file_exists(remote_config_path):
		return
		
	var local_config = ConfigFile.new()
	var remote_config = ConfigFile.new()
	
	if local_config.load(local_config_path) != OK: pass
	if remote_config.load(remote_config_path) != OK: return
	
	for section in remote_config.get_sections():
		for key in remote_config.get_section_keys(section):
			if section == "application" and key == "config/version":
				local_config.set_value(section, key, remote_config.get_value(section, key))
				continue
			if not local_config.has_section_key(section, key):
				local_config.set_value(section, key, remote_config.get_value(section, key))
	
	local_config.save(remote_config_path)


func _thread_safe_create_bat(source_folder: String) -> void:
	if OS.get_name() != "Windows": return

	var bat_path = ProjectSettings.globalize_path("user://updater.bat")
	var project_root = ProjectSettings.globalize_path("res://")
	var godot_exe = OS.get_executable_path()
	
	# 1. Sanitize paths for Windows (convert / to \)
	var win_source = source_folder.replace("/", "\\")
	var win_dest = project_root.replace("/", "\\")
	var win_exe = godot_exe.replace("/", "\\")
	
	# 2. Fix the "Escaped Quote" issue:
	# If a path ends in backslash, "Path\" is interpreted as Path" by cmd.
	# We remove trailing backslashes for the arguments that are wrapped in quotes.
	var win_dest_clean = win_dest.trim_suffix("\\")
	var win_exe_clean = win_exe.trim_suffix("\\")
	
	# 3. Source needs wildcard for xcopy (keep backslash here if needed)
	if not win_source.ends_with("\\"):
		win_source += "\\"
	var win_source_contents = win_source + "*"
	
	# Remove trailing slash for the rmdir command just in case
	var win_source_clean = win_source.trim_suffix("\\")
	
	var script_content = "@echo off\r\n"
	script_content += "timeout /t 3 /nobreak > NUL\r\n"
	
	# XCOPY: Copy everything from temp to root
	script_content += 'xcopy "%s" "%s" /Y /S /E /I\r\n' % [win_source_contents, win_dest_clean]
	
	# CLEANUP 2: Delete the temp folder using RMDIR
	script_content += 'rmdir /s /q "%s"\r\n' % [win_source_clean]
	
	# RESTART: Launch Godot Editor.
	# CRITICAL: We use 'start' with proper quoting and clean paths.
	script_content += 'start "" "%s" --path "%s" -e\r\n' % [win_exe_clean, win_dest_clean]
	
	# SELF DELETE
	# We add a small delay to ensure 'start' has dispatched the process
	script_content += 'timeout /t 1 > NUL\r\n'
	script_content += '(goto) 2>nul & del "%~f0"'

	var file = FileAccess.open(bat_path, FileAccess.WRITE)
	if file:
		file.store_string(script_content)
		file.close()


func _on_thread_error(msg: String) -> void:
	_thread.wait_to_finish()
	update_error.emit(msg)
	_cleanup_and_die()


func _on_thread_finished() -> void:
	_thread.wait_to_finish()
	_status_label.text = "Restarting..."
	
	var bat_path = ProjectSettings.globalize_path("user://updater.bat")
	if FileAccess.file_exists(bat_path):
		OS.create_process(bat_path, [])
		get_tree().quit()
	else:
		_cleanup_and_die()


func _cleanup_and_die() -> void:
	if _blocking_panel: _blocking_panel.visible = false
	queue_free()
