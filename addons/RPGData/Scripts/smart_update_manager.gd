class_name SmartUpdateManager
extends Node

## Hybrid Update Manager for Godot RPG Creator.
## Handles ZIP for full installs and Incremental for patches with Windows stability.
## Includes an atomic rollback system to prevent corruption on power loss or write errors.

signal update_status(msg: String)
signal update_error(msg: String)

const REPO_OWNER: String = "newold3"
const REPO_NAME: String = "Godot-RPG-Creator-4.5.6-"
const BRANCH: String = "master"

const SHA_USER_FILE: String = "user://version_sha.txt"
const SHA_RES_FILE: String = "res://addons/RPGData/version_sha.txt"
const TEMP_FOLDER: String = "user://temp_update_data/"
const TEMP_ZIP_PATH: String = "user://update_package.zip"
const BACKUP_FOLDER: String = "user://update_backup/"
const STATUS_FILE: String = "user://update_status.txt"

var _http: HTTPRequest
var _local_sha: String = ""
var _target_sha: String = ""
var _thread: Thread


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_http = HTTPRequest.new()
	add_child(_http)
	_http.request_completed.connect(_on_sha_received)
	
	_check_previous_update_status()
	_initialize_local_sha()


## Verifies if the last update succeeded, failed, or was interrupted.
func _check_previous_update_status() -> void:
	if not FileAccess.file_exists(STATUS_FILE): 
		return

	var status = FileAccess.get_file_as_string(STATUS_FILE).strip_edges()
	
	if status == "SUCCESS":
		call_deferred("emit_signal", "update_status", "Update applied successfully!")
		DirAccess.remove_absolute(STATUS_FILE)
		_remove_dir_recursive(ProjectSettings.globalize_path(BACKUP_FOLDER))
	elif status == "FAILED" or status == "UPDATING":
		call_deferred("emit_signal", "update_error", "Update failed or interrupted. Restoring stable backup...")
		_restore_from_backup_and_clean()


func _initialize_local_sha() -> void:
	if FileAccess.file_exists(SHA_USER_FILE):
		_local_sha = FileAccess.get_file_as_string(SHA_USER_FILE).strip_edges()
	elif not DatabaseLoader.is_develop_build and FileAccess.file_exists(SHA_RES_FILE):
		_local_sha = FileAccess.get_file_as_string(SHA_RES_FILE).strip_edges()


func check_updates() -> void:
	update_status.emit("Connecting to GitHub...")
	var url = "https://api.github.com/repos/%s/%s/commits/%s" % [REPO_OWNER, REPO_NAME, BRANCH]
	_http.request(url)


func _on_sha_received(_result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if code != 200:
		update_error.emit("GitHub Connection Error: " + str(code))
		return
		
	var json = JSON.parse_string(body.get_string_from_utf8())
	if not json or not json.has("sha"):
		update_error.emit("Invalid SHA response")
		return
		
	_target_sha = json["sha"]
	
	if _local_sha == "":
		_save_sha_to_user(_target_sha)
		update_status.emit("Project initialized successfully.")
		await get_tree().create_timer(1.5).timeout
		update_error.emit("CLOSE_SUCCESS") 
		return

	if _local_sha == _target_sha:
		update_status.emit("Your project is already up to date.")
		await get_tree().create_timer(1.5).timeout
		update_error.emit("CLOSE_SUCCESS")
		return
	
	_start_incremental_update()


func _start_zip_download() -> void:
	update_status.emit("Downloading full project (ZIP)...")
	var zip_url = "https://github.com/%s/%s/archive/refs/heads/%s.zip" % [REPO_OWNER, REPO_NAME, BRANCH]
	
	for sig in _http.request_completed.get_connections():
		_http.request_completed.disconnect(sig.callable)
		
	_http.request_completed.connect(_on_zip_received)
	_http.request(zip_url)


func _on_zip_received(_result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if code != 200:
		update_error.emit("Failed to download ZIP")
		return
		
	var f = FileAccess.open(TEMP_ZIP_PATH, FileAccess.WRITE)
	if f:
		f.store_buffer(body)
		f.close()
		update_status.emit("Extracting files...")
		_thread = Thread.new()
		_thread.start(_threaded_zip_process)
	else:
		update_error.emit("Could not save temporary ZIP to disk")


func _threaded_zip_process() -> void:
	var zip = ZIPReader.new()
	var err = zip.open(TEMP_ZIP_PATH)
	
	if err != OK:
		call_deferred("emit_signal", "update_error", "Failed to open ZIP (Error %d)" % err)
		return
		
	var files = zip.get_files()
	if files.is_empty():
		zip.close()
		call_deferred("emit_signal", "update_error", "ZIP is empty")
		return

	var root_folder = files[0] 
	var total_files = files.size()
	var processed_count = 0
	
	for path in files:
		processed_count += 1
		if path.ends_with("/"): continue
		
		# Feedback and saturation control
		call_deferred("emit_signal", "update_status", "Extracting (%d/%d):\n%s" % [processed_count, total_files, path.get_file()])
		
		var internal_path = path.replace(root_folder, "")
		if internal_path.begins_with("UserContents/"): continue
		
		var content = zip.read_file(path)
		_write_to_temp(internal_path, content)
		
		if processed_count % 50 == 0:
			OS.delay_msec(50)
	
	zip.close()
	if FileAccess.file_exists(TEMP_ZIP_PATH):
		DirAccess.remove_absolute(TEMP_ZIP_PATH)
	
	call_deferred("_finalize_update")


func _start_incremental_update() -> void:
	update_status.emit("Checking changes...")
	_http.request_completed.disconnect(_on_sha_received)
	_http.request_completed.connect(_on_comparison_received)
	_http.request("https://api.github.com/repos/%s/%s/compare/%s...%s" % [REPO_OWNER, REPO_NAME, _local_sha, _target_sha])


func _on_comparison_received(_result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if code != 200:
		update_error.emit("Comparison failed")
		return
		
	var json = JSON.parse_string(body.get_string_from_utf8())
	var files: Array = []
	for f in json.get("files", []):
		if not f["filename"].begins_with("UserContents/"):
			files.append(f["filename"])
	
	if files.is_empty():
		_save_sha_to_user(_target_sha)
		update_error.emit("No changes found.")
		return
		
	update_status.emit("Downloading %d updated files..." % files.size())
	_thread = Thread.new()
	_thread.start(_threaded_incremental_process.bind(files))


func _threaded_incremental_process(files: Array) -> void:
	var count = 0
	var total = files.size()
	for path in files:
		count += 1
		call_deferred("emit_signal", "update_status", "Patching (%d/%d):\n%s" % [count, total, path.get_file()])
		var result = _sync_download("https://raw.githubusercontent.com/%s/%s/%s/%s" % [REPO_OWNER, REPO_NAME, BRANCH, path.uri_encode()])
		if result.is_empty():
			call_deferred("emit_signal", "update_error", "Failed: " + path)
			return
		_write_to_temp(path, result)
	call_deferred("_finalize_update")


func _sync_download(url: String) -> PackedByteArray:
	var client = HTTPClient.new()
	client.connect_to_host("raw.githubusercontent.com", 443, TLSOptions.client())
	while client.get_status() < 3: client.poll(); OS.delay_msec(5)
	if client.get_status() != 3: return PackedByteArray()
	client.request(HTTPClient.METHOD_GET, url.replace("https://raw.githubusercontent.com", ""), ["User-Agent: Godot-Updater"])
	while client.get_status() == HTTPClient.STATUS_REQUESTING: client.poll(); OS.delay_msec(5)
	var rb = PackedByteArray()
	while client.get_status() == HTTPClient.STATUS_BODY:
		client.poll()
		var chunk = client.read_response_body_chunk()
		if chunk.size() > 0: rb.append_array(chunk)
	client.close()
	return rb


func _write_to_temp(path: String, data: PackedByteArray) -> void:
	var full_path = ProjectSettings.globalize_path(TEMP_FOLDER) + path
	DirAccess.make_dir_recursive_absolute(full_path.get_base_dir())
	FileAccess.open(full_path, FileAccess.WRITE).store_buffer(data)


func _save_sha_to_user(sha_value: String) -> void:
	FileAccess.open(SHA_USER_FILE, FileAccess.WRITE).store_string(sha_value)


func _finalize_update() -> void:
	if _thread and _thread.is_started(): _thread.wait_to_finish()
	
	update_status.emit("Securing backup...")
	_backup_target_files()
	
	FileAccess.open(ProjectSettings.globalize_path(TEMP_FOLDER) + "version_sha.txt", FileAccess.WRITE).store_string(_target_sha)
	FileAccess.open(STATUS_FILE, FileAccess.WRITE).store_string("UPDATING")
	_create_and_run_bat()


## Copies the currently existing files to a backup folder before they are overwritten.
func _backup_target_files() -> void:
	var temp_base = ProjectSettings.globalize_path(TEMP_FOLDER)
	var backup_base = ProjectSettings.globalize_path(BACKUP_FOLDER)
	var res_base = ProjectSettings.globalize_path("res://")

	if DirAccess.dir_exists_absolute(backup_base):
		_remove_dir_recursive(backup_base)
	DirAccess.make_dir_recursive_absolute(backup_base)

	var files_to_replace = _get_all_files_recursive(temp_base)
	for temp_file in files_to_replace:
		var relative_path = temp_file.replace(temp_base, "")
		var res_file = res_base + relative_path

		if FileAccess.file_exists(res_file):
			var backup_file = backup_base + relative_path
			DirAccess.make_dir_recursive_absolute(backup_file.get_base_dir())
			DirAccess.copy_absolute(res_file, backup_file)


## Restores the files from the backup directory back to the main project.
func _restore_from_backup_and_clean() -> void:
	var backup_base = ProjectSettings.globalize_path(BACKUP_FOLDER)
	var res_base = ProjectSettings.globalize_path("res://")

	if DirAccess.dir_exists_absolute(backup_base):
		var backup_files = _get_all_files_recursive(backup_base)
		for b_file in backup_files:
			var relative_path = b_file.replace(backup_base, "")
			var target_file = res_base + relative_path
			DirAccess.make_dir_recursive_absolute(target_file.get_base_dir())
			DirAccess.copy_absolute(b_file, target_file)

	DirAccess.remove_absolute(STATUS_FILE)
	update_error.emit("Project successfully restored to the previous stable state.")


## Retrieves all files recursively within a specific path.
func _get_all_files_recursive(path: String) -> PackedStringArray:
	var files = PackedStringArray()
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name != "." and file_name != "..":
				var full_path = path + "/" + file_name
				if dir.current_is_dir():
					files.append_array(_get_all_files_recursive(full_path))
				else:
					files.append(full_path)
			file_name = dir.get_next()
	return files


## Deletes a directory and all its contents natively.
func _remove_dir_recursive(path: String) -> void:
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name != "." and file_name != "..":
				var full_path = path + "/" + file_name
				if dir.current_is_dir():
					_remove_dir_recursive(full_path)
				else:
					dir.remove(file_name)
			file_name = dir.get_next()
		dir.remove(path)


func _create_and_run_bat() -> void:
	var bat_path = ProjectSettings.globalize_path("user://updater.bat")
	var project_res = ProjectSettings.globalize_path("res://").replace("/", "\\").trim_suffix("\\")
	var temp_res = ProjectSettings.globalize_path(TEMP_FOLDER).replace("/", "\\").trim_suffix("\\")
	var backup_res = ProjectSettings.globalize_path(BACKUP_FOLDER).replace("/", "\\").trim_suffix("\\")
	var user_sha = ProjectSettings.globalize_path(SHA_USER_FILE).replace("/", "\\")
	var status_file = ProjectSettings.globalize_path(STATUS_FILE).replace("/", "\\")
	var godot_exe = OS.get_executable_path().replace("/", "\\")
	
	var script = "@echo off\r\n"
	script += "timeout /t 5 /nobreak > NUL\r\n"
	
	# Attempt the copy
	script += 'xcopy "%s\\*" "%s" /Y /S /E /I /R /H\r\n' % [temp_res, project_res]
	
	# If xcopy fails (errorlevel != 0), jump to rollback
	script += "if %ERRORLEVEL% NEQ 0 goto rollback\r\n"
	
	# SUCCESS PATH
	script += 'copy /Y "%s\\version_sha.txt" "%s"\r\n' % [temp_res, user_sha]
	script += 'echo SUCCESS > "%s"\r\n' % status_file
	script += 'rmdir /s /q "%s"\r\n' % temp_res
	script += 'start "" "%s" --path "%s" -e\r\n' % [godot_exe, project_res]
	script += '(goto) 2>nul & del "%~f0"\r\n'
	
	# ROLLBACK PATH
	script += ":rollback\r\n"
	script += 'xcopy "%s\\*" "%s" /Y /S /E /I /R /H\r\n' % [backup_res, project_res]
	script += 'echo FAILED > "%s"\r\n' % status_file
	script += 'start "" "%s" --path "%s" -e\r\n' % [godot_exe, project_res]
	script += '(goto) 2>nul & del "%~f0"'
	
	FileAccess.open(bat_path, FileAccess.WRITE).store_string(script)
	OS.create_process("cmd.exe", ["/c", bat_path])
	get_tree().quit()
