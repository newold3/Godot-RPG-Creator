class_name SmartUpdateManager
extends Node

## Handles logic for downloading, extracting, and applying updates via Git.
## Supports full ZIP downloads and incremental file updates.

signal update_status(msg: String)
signal update_ready_to_restart
signal update_error(msg: String)

const REPO_OWNER: String = "newold3"
const REPO_NAME: String = "Godot-RPG-Creator"
const BRANCH: String = "develop"

const USER_SAFE_FOLDER: String = "UserContents/"
const SHA_FILE: String = "user://version_sha.txt"
const TEMP_FOLDER: String = "user://temp_update_data/"
const DELETE_LIST_FILE: String = "delete_list.txt"
const ZIP_FILENAME: String = "update.zip"

var _http: HTTPRequest
var _monitor_timer: Timer
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
	
	_monitor_timer = Timer.new()
	_monitor_timer.wait_time = 0.5
	_monitor_timer.one_shot = false
	_monitor_timer.timeout.connect(_monitor_download_status)
	add_child(_monitor_timer)
	
	_thread = Thread.new()
	
	if FileAccess.file_exists(SHA_FILE):
		_local_sha = FileAccess.get_file_as_string(SHA_FILE).strip_edges()


func _exit_tree() -> void:
	if _thread.is_started():
		_thread.wait_to_finish()


func check_updates() -> void:
	update_status.emit("Checking GitHub")
	_http.download_file = ""
	_http.request("https://api.github.com/repos/%s/%s/commits/%s" % [REPO_OWNER, REPO_NAME, BRANCH])


func _on_api_response(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if _http.download_file.ends_with(ZIP_FILENAME):
		_monitor_timer.stop()
		_on_zip_downloaded(result, code)
		return

	if code != 200:
		update_error.emit("GitHub API Error: " + str(code))
		return
	
	var json = JSON.parse_string(body.get_string_from_utf8())
	if not json:
		update_error.emit("Invalid JSON response.")
		return
	
	# Initial commit check to get latest SHA
	if json.has("sha") and not json.has("files"):
		_remote_sha = json["sha"]
		
		if _local_sha.is_empty():
			update_status.emit("First run detected. Downloading full project")
			_start_full_download() 
		elif _local_sha == _remote_sha:
			update_status.emit("Up to date")
		else:
			update_status.emit("Analyzing version differences")
			var compare_url = "https://api.github.com/repos/%s/%s/compare/%s...%s" % [REPO_OWNER, REPO_NAME, _local_sha, _remote_sha]
			_http.request(compare_url)
	
	# Comparison results with file list
	elif json.has("files"):
		_process_diff(json)


func _process_diff(data: Dictionary) -> void:
	print("DEBUG: GitHub reported ", data["files"].size(), " changes.")
	
	if data.get("status") == "diverged" or data["files"].size() > 100:
		update_status.emit("Major update. Switching to full download")
		_start_full_download()
		return
	
	_pending_downloads.clear()
	_pending_deletes.clear()
	
	for f in data["files"]:
		var path = f["filename"]
		var status = f["status"]
		
		if path.begins_with(USER_SAFE_FOLDER): continue
		
		print("DEBUG: Pending change: ", path, " (", status, ")")
		
		if status == "removed":
			_pending_deletes.append(path)
		elif status == "renamed":
			_pending_deletes.append(f["previous_filename"])
			_pending_downloads.append(path)
		else:
			_pending_downloads.append(path)
	
	if _pending_downloads.is_empty() and _pending_deletes.is_empty():
		_update_sha_only()
	else:
		update_status.emit("Processing %d files" % [_pending_downloads.size() + _pending_deletes.size()])
		_start_incremental_download()


func _start_full_download() -> void:
	var zip_path = ProjectSettings.globalize_path("user://") + ZIP_FILENAME
	_http.download_file = zip_path
	
	var zip_url = "https://github.com/%s/%s/archive/refs/heads/%s.zip" % [REPO_OWNER, REPO_NAME, BRANCH]
	_http.request(zip_url)
	
	update_status.emit("Downloading full update")
	_monitor_timer.start()


func _monitor_download_status() -> void:
	var downloaded = _http.get_downloaded_bytes()
	var total = _http.get_body_size()
	var mb_dl = downloaded / 1024.0 / 1024.0
	
	if total > 0:
		var mb_tot = total / 1024.0 / 1024.0
		update_status.emit("Downloading: %.1f / %.1f MB" % [mb_dl, mb_tot])
	else:
		update_status.emit("Downloading: %.1f MB" % mb_dl)


func _on_zip_downloaded(result: int, code: int) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		update_error.emit("Failed to download ZIP.")
		return
	
	update_status.emit("Extracting files")
	_thread.start(_zip_extraction_worker.bind(_remote_sha))


func _zip_extraction_worker(safe_sha: String) -> void:
	var zip_reader = ZIPReader.new()
	var zip_path = ProjectSettings.globalize_path("user://") + ZIP_FILENAME
	
	if zip_reader.open(zip_path) != OK:
		call_deferred("emit_signal", "update_error", "Failed to open ZIP.")
		return

	var files = zip_reader.get_files()
	var total_files = files.size()
	var processed_count = 0
	
	var dir = DirAccess.open("user://")
	dir.make_dir_recursive(TEMP_FOLDER)

	var root_folder_in_zip = ""
	if files.size() > 0 and "/" in files[0]:
		root_folder_in_zip = files[0].split("/")[0] + "/"
	
	for file_path in files:
		processed_count += 1
		
		if processed_count % 13 == 0:
			call_deferred("emit_signal", "update_status", "Extracting: %d / %d" % [processed_count, total_files])
		
		if processed_count % 100 == 0:
			OS.delay_msec(25)
		
		if file_path.ends_with("/"): continue
		
		var content = zip_reader.read_file(file_path)
		var clean_path = file_path
		if not root_folder_in_zip.is_empty() and file_path.begins_with(root_folder_in_zip):
			clean_path = file_path.trim_prefix(root_folder_in_zip)
		
		_save_temp_file(clean_path, content)

	zip_reader.close()
	if dir.file_exists(ZIP_FILENAME):
		dir.remove(ZIP_FILENAME)
	
	call_deferred("_finalize_update_process", safe_sha)


func _start_incremental_download() -> void:
	var dir = DirAccess.open("user://")
	dir.make_dir_recursive(TEMP_FOLDER)
	_thread.start(_incremental_worker.bind(_remote_sha))


func _incremental_worker(safe_sha: String) -> void:
	var http_client = HTTPClient.new()
	var total = _pending_downloads.size()
	var count = 0
	
	for file_path in _pending_downloads:
		count += 1
		call_deferred("emit_signal", "update_status", "Downloading file %d of %d" % [count, total])
		
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
	
	if not _pending_deletes.is_empty():
		var f_del = FileAccess.open(TEMP_FOLDER + DELETE_LIST_FILE, FileAccess.WRITE)
		for del_path in _pending_deletes:
			f_del.store_line(del_path.replace("/", "\\"))
		f_del.close()
	
	call_deferred("_finalize_update_process", safe_sha)


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
	var f = FileAccess.open(temp_path, FileAccess.WRITE)
	f.store_buffer(new_content); f.close()
	var local = ConfigFile.new(); var remote = ConfigFile.new()
	local.load("res://project.godot"); remote.load(temp_path)
	for s in remote.get_sections():
		for k in remote.get_section_keys(s):
			if s == "application" and k == "config/version": 
				local.set_value(s, k, remote.get_value(s, k))
			elif not local.has_section_key(s, k): 
				local.set_value(s, k, remote.get_value(s, k))
	local.save(temp_path)


func _finalize_update_process(safe_sha: String) -> void:
	if safe_sha.is_empty():
		call_deferred("emit_signal", "update_error", "Critical: Empty SHA")
		return

	var f_sha = FileAccess.open(TEMP_FOLDER + "version_sha.txt", FileAccess.WRITE)
	f_sha.store_string(safe_sha)
	f_sha.close()
	
	_create_bat_script()
	call_deferred("_on_thread_finished")


func _create_bat_script() -> void:
	if OS.get_name() != "Windows": return
	
	var bat_path = ProjectSettings.globalize_path("user://updater.bat")
	var project_root = ProjectSettings.globalize_path("res://").replace("/", "\\").trim_suffix("\\")
	var temp_root = ProjectSettings.globalize_path(TEMP_FOLDER).replace("/", "\\").trim_suffix("\\")
	var godot_exe = OS.get_executable_path().replace("/", "\\")
	var user_sha_dest = ProjectSettings.globalize_path("user://version_sha.txt").replace("/", "\\")
	var delete_list_path = temp_root + "\\" + DELETE_LIST_FILE
	
	var script = "@echo off\r\n"
	script += "timeout /t 10 /nobreak > NUL\r\n"
	
	script += 'if exist "%s" (\r\n' % delete_list_path
	script += '  for /f "usebackq delims=" %%%%f in ("%s") do (\r\n' % delete_list_path
	script += '    if exist "%s\\%%%%f" del /f /q "%s\\%%%%f"\r\n' % [project_root, project_root]
	script += '  )\r\n'
	script += ')\r\n'
	
	script += 'xcopy "%s\\*" "%s" /Y /S /E /I /R /K\r\n' % [temp_root, project_root]
	script += 'copy /Y "%s\\version_sha.txt" "%s"\r\n' % [temp_root, user_sha_dest]
	script += 'rmdir /s /q "%s"\r\n' % temp_root
	
	script += 'start "" "%s" --path "%s" -e\r\n' % [godot_exe.trim_suffix("\\"), project_root]
	script += '(goto) 2>nul & del "%%~f0"'
	
	var f = FileAccess.open(bat_path, FileAccess.WRITE)
	f.store_string(script)


func _update_sha_only() -> void:
	var f = FileAccess.open(SHA_FILE, FileAccess.WRITE)
	f.store_string(_remote_sha); f.close()
	update_status.emit("Already up to date")


func _on_thread_finished() -> void:
	_thread.wait_to_finish()
	update_status.emit("Restarting editor")
	call_deferred("emit_signal", "update_ready_to_restart")
	
	var bat_path = ProjectSettings.globalize_path("user://updater.bat")
	if FileAccess.file_exists(bat_path):
		var args = ["/c", bat_path]
		OS.create_process("cmd.exe", args)
		get_tree().quit()
