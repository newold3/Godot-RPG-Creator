class_name SmartUpdateManager
extends Node

## Emitted to update the UI status label with the current process.
signal update_status(msg: String)

## Emitted when the update is finished and the editor is ready to restart.
signal update_ready_to_restart

## Emitted if a critical error occurs.
signal update_error(msg: String)


const REPO_OWNER: String = "newold3"
const REPO_NAME: String = "Godot-RPG-Creator"
const BRANCH: String = "develop"

## The folder where user custom files are safe from deletion.
const USER_SAFE_FOLDER: String = "UserContents/"

const SHA_FILE: String = "user://version_sha.txt"
const TEMP_FOLDER: String = "user://temp_update_data/"
const DELETE_LIST_FILE: String = "delete_list.txt"
const ZIP_FILENAME: String = "update.zip"


var _http: HTTPRequest
var _local_sha: String = ""
var _remote_sha: String = ""
var _thread: Thread
var _pending_downloads: Array = []
var _pending_deletes: Array = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	_http = HTTPRequest.new()
	add_child(_http)
	_http.request_completed.connect(_on_api_response)
	
	_thread = Thread.new()
	
	if FileAccess.file_exists(SHA_FILE):
		_local_sha = FileAccess.get_file_as_string(SHA_FILE).strip_edges()


func _exit_tree() -> void:
	if _thread.is_started():
		_thread.wait_to_finish()


## Checks GitHub for the latest commit SHA.
func check_updates() -> void:
	update_status.emit("Checking GitHub...")
	_http.download_file = "" # Ensure we are not in file download mode
	_http.request("https://api.github.com/repos/%s/%s/commits/%s" % [REPO_OWNER, REPO_NAME, BRANCH])


func _on_api_response(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	# Check if this response is a ZIP download (handled differently)
	if _http.download_file.ends_with(ZIP_FILENAME):
		_on_zip_downloaded(result, code)
		return

	if code != 200:
		update_error.emit("GitHub API Error: " + str(code))
		return
	
	var json = JSON.parse_string(body.get_string_from_utf8())
	if not json:
		update_error.emit("Invalid JSON response.")
		return
	
	# 1. Commit SHA Response
	if json.has("sha") and not json.has("files"):
		_remote_sha = json["sha"]
		
		if _local_sha.is_empty():
			update_status.emit("First run detected. Downloading full project...")
			_start_full_download() 
		elif _local_sha == _remote_sha:
			update_status.emit("Up to date.")
		else:
			update_status.emit("New version found. Calculating differences...")
			_http.request("https://api.github.com/repos/%s/%s/compare/%s...%s" % [REPO_OWNER, REPO_NAME, _local_sha, _remote_sha])
	
	# 2. Compare/Diff Response
	elif json.has("files"):
		_process_diff(json)


func _process_diff(data: Dictionary) -> void:
	# If history diverged or too many files changed, fallback to full ZIP
	if data.get("status") == "diverged" or data["files"].size() > 100:
		update_status.emit("Major update detected. Downloading full ZIP...")
		_start_full_download()
		return
	
	_pending_downloads.clear()
	_pending_deletes.clear()
	
	for f in data["files"]:
		var path = f["filename"]
		var status = f["status"]
		
		# CRITICAL: Ignore deletion if the file is inside the sacred user folder.
		var is_safe_zone = path.begins_with(USER_SAFE_FOLDER)
		
		if status == "removed":
			if not is_safe_zone: 
				_pending_deletes.append(path)
		elif status == "renamed":
			if not is_safe_zone: 
				_pending_deletes.append(f["previous_filename"])
			_pending_downloads.append(path)
		else:
			# Added or Modified
			_pending_downloads.append(path)
	
	if _pending_downloads.is_empty() and _pending_deletes.is_empty():
		_update_sha_only()
	else:
		update_status.emit("Update Plan: %d downloads, %d deletions." % [_pending_downloads.size(), _pending_deletes.size()])
		_start_incremental_download()


## --- FULL DOWNLOAD PATH (ZIP) ---


func _start_full_download() -> void:
	# Configure HTTPRequest to download the ZIP file
	var zip_path = ProjectSettings.globalize_path("user://") + ZIP_FILENAME
	_http.download_file = zip_path
	
	var zip_url = "https://github.com/%s/%s/archive/refs/heads/%s.zip" % [REPO_OWNER, REPO_NAME, BRANCH]
	_http.request(zip_url)


func _on_zip_downloaded(result: int, code: int) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		update_error.emit("Failed to download ZIP.")
		return
	
	update_status.emit("ZIP Downloaded. Extracting...")
	_thread.start(_zip_extraction_worker)


func _zip_extraction_worker() -> void:
	var zip_reader = ZIPReader.new()
	var zip_path = ProjectSettings.globalize_path("user://") + ZIP_FILENAME
	
	if zip_reader.open(zip_path) != OK:
		call_deferred("emit_signal", "update_error", "Failed to open ZIP.")
		return

	var files = zip_reader.get_files()
	var base_extract_path = ProjectSettings.globalize_path(TEMP_FOLDER)
	
	# Create temp folder
	var dir = DirAccess.open("user://")
	dir.make_dir_recursive(TEMP_FOLDER)

	# Detect root folder inside ZIP (e.g. "Godot-RPG-Creator-master/")
	var root_folder_in_zip = ""
	if files.size() > 0 and "/" in files[0]:
		root_folder_in_zip = files[0].split("/")[0] + "/"
	
	for file_path in files:
		if file_path.ends_with("/"): continue
		
		var content = zip_reader.read_file(file_path)
		
		# Remove the root folder prefix
		var clean_path = file_path
		if not root_folder_in_zip.is_empty() and file_path.begins_with(root_folder_in_zip):
			clean_path = file_path.trim_prefix(root_folder_in_zip)
		
		_save_temp_file(clean_path, content)

	zip_reader.close()
	
	# Cleanup ZIP file immediately
	if dir.file_exists(ZIP_FILENAME):
		dir.remove(ZIP_FILENAME)
	
	_finalize_update_process()


## --- INCREMENTAL PATH (RAW FILES) ---


func _start_incremental_download() -> void:
	var dir = DirAccess.open("user://")
	dir.make_dir_recursive(TEMP_FOLDER)
	_thread.start(_incremental_worker)


func _incremental_worker() -> void:
	var http_client = HTTPClient.new()
	var total = _pending_downloads.size()
	var count = 0
	
	# 1. Download Files
	for file_path in _pending_downloads:
		count += 1
		call_deferred("emit_signal", "update_status", "Downloading (%d/%d): %s" % [count, total, file_path])
		
		var raw_url = "/%s/%s/%s/%s" % [REPO_OWNER, REPO_NAME, BRANCH, file_path.uri_encode()]
		var err = http_client.connect_to_host("raw.githubusercontent.com", 443, TLSOptions.client())
		
		if err == OK:
			while http_client.get_status() == HTTPClient.STATUS_CONNECTING or http_client.get_status() == HTTPClient.STATUS_RESOLVING:
				http_client.poll(); OS.delay_msec(10)
			
			http_client.request(HTTPClient.METHOD_GET, raw_url, PackedStringArray(["User-Agent: GodotUpdater"]))
			
			while http_client.get_status() == HTTPClient.STATUS_REQUESTING:
				http_client.poll(); OS.delay_msec(10)
			
			if http_client.has_response() and http_client.get_response_code() == 200:
				var body = PackedByteArray()
				while http_client.get_status() == HTTPClient.STATUS_BODY:
					http_client.poll()
					var chunk = http_client.read_response_body_chunk()
					if chunk.size() > 0: body.append_array(chunk)
				
				_save_temp_file(file_path, body)
			http_client.close()
	
	# 2. Generate Delete List
	if not _pending_deletes.is_empty():
		var f_del = FileAccess.open(TEMP_FOLDER + DELETE_LIST_FILE, FileAccess.WRITE)
		for del_path in _pending_deletes:
			# Safety: Never delete user content
			if not del_path.begins_with(USER_SAFE_FOLDER):
				f_del.store_line(del_path.replace("/", "\\"))
		f_del.close()
	
	_finalize_update_process()


## --- COMMON UTILITIES ---


func _save_temp_file(path: String, content: PackedByteArray) -> void:
	var full_path = ProjectSettings.globalize_path(TEMP_FOLDER) + path
	var base_dir = full_path.get_base_dir()
	
	if not DirAccess.dir_exists_absolute(base_dir):
		DirAccess.make_dir_recursive_absolute(base_dir)
	
	if path == "project.godot":
		_merge_configs(full_path, content)
	else:
		var f = FileAccess.open(full_path, FileAccess.WRITE)
		if f: f.store_buffer(content)


func _merge_configs(temp_path: String, new_content: PackedByteArray) -> void:
	# Save raw content first
	var f = FileAccess.open(temp_path, FileAccess.WRITE)
	f.store_buffer(new_content)
	f.close()
	
	# Load to merge
	var local = ConfigFile.new()
	var remote = ConfigFile.new()
	local.load("res://project.godot")
	remote.load(temp_path)
	
	for s in remote.get_sections():
		for k in remote.get_section_keys(s):
			if s == "application" and k == "config/version":
				local.set_value(s, k, remote.get_value(s, k))
			elif not local.has_section_key(s, k):
				local.set_value(s, k, remote.get_value(s, k))
	
	local.save(temp_path)


func _finalize_update_process() -> void:
	# Save the new SHA to the temp folder, to be moved by BAT
	var f_sha = FileAccess.open(TEMP_FOLDER + "version_sha.txt", FileAccess.WRITE)
	f_sha.store_string(_remote_sha)
	f_sha.close()
	
	_create_bat_script()
	call_deferred("_on_thread_finished")


func _create_bat_script() -> void:
	if OS.get_name() != "Windows": return
	
	var bat_path = ProjectSettings.globalize_path("user://updater.bat")
	var project_root = ProjectSettings.globalize_path("res://").replace("/", "\\")
	var temp_root = ProjectSettings.globalize_path(TEMP_FOLDER).replace("/", "\\")
	var godot_exe = OS.get_executable_path().replace("/", "\\")
	
	var script = "@echo off\r\n"
	script += "timeout /t 2 /nobreak > NUL\r\n"
	
	# 1. PROCESS DELETIONS
	var delete_list_path = temp_root + DELETE_LIST_FILE
	script += 'if exist "%s" (\r\n' % delete_list_path
	script += '  for /f "usebackq delims=" %%f in ("%s") do (\r\n' % delete_list_path
	script += '    if exist "%s\\%%f" del /f /q "%s\\%%f"\r\n' % [project_root, project_root]
	script += '  )\r\n'
	script += ')\r\n'
	
	# 2. OVERWRITE FILES
	script += 'xcopy "%s*" "%s" /Y /S /E /I\r\n' % [temp_root, project_root]
	
	# 3. UPDATE LOCAL SHA
	var user_sha_dest = ProjectSettings.globalize_path("user://version_sha.txt").replace("/", "\\")
	script += 'copy /Y "%sversion_sha.txt" "%s"\r\n' % [temp_root, user_sha_dest]
	
	# 4. CLEANUP
	script += 'rmdir /s /q "%s"\r\n' % temp_root
	
	# 5. RESTART
	script += 'start "" "%s" --path "%s" -e\r\n' % [godot_exe.trim_suffix("\\"), project_root.trim_suffix("\\")]
	script += '(goto) 2>nul & del "%~f0"'
	
	var f = FileAccess.open(bat_path, FileAccess.WRITE)
	f.store_string(script)


func _update_sha_only() -> void:
	var f = FileAccess.open(SHA_FILE, FileAccess.WRITE)
	f.store_string(_remote_sha)
	f.close()
	update_status.emit("Already up to date.")


func _on_thread_finished() -> void:
	_thread.wait_to_finish()
	update_status.emit("Restarting editor...")
	call_deferred("emit_signal", "update_ready_to_restart")
	
	var bat_path = ProjectSettings.globalize_path("user://updater.bat")
	if FileAccess.file_exists(bat_path):
		OS.create_process(bat_path, [])
		get_tree().quit()
