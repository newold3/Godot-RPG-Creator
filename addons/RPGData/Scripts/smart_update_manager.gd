class_name SmartUpdateManager
extends Node

## Unified Update Manager for Godot RPG Creator.
## Handles both initial full download and incremental updates using threads.

signal update_status(msg: String)
signal update_error(msg: String)

const REPO_OWNER: String = "newold3"
const REPO_NAME: String = "Godot-RPG-Creator"
const BRANCH: String = "develop"

const SHA_FILE: String = "user://version_sha.txt"
const TEMP_FOLDER: String = "user://temp_update_data/"

var _http: HTTPRequest
var _local_sha: String = ""
var _target_sha: String = ""
var _thread: Thread


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	_http = HTTPRequest.new()
	add_child(_http)
	_http.request_completed.connect(_on_sha_received)
	
	if FileAccess.file_exists(SHA_FILE):
		_local_sha = FileAccess.get_file_as_string(SHA_FILE).strip_edges()


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
	
	if _local_sha == _target_sha:
		update_status.emit("Project is up to date.")
		update_error.emit("No update needed.")
		return
		
	if _local_sha == "":
		_start_full_download()
	else:
		_start_incremental_update()


func _start_full_download() -> void:
	update_status.emit("Initial download detected...")
	_http.request_completed.disconnect(_on_sha_received)
	_http.request_completed.connect(_on_tree_received)
	_http.request("https://api.github.com/repos/%s/%s/git/trees/%s?recursive=1" % [REPO_OWNER, REPO_NAME, BRANCH])


func _start_incremental_update() -> void:
	update_status.emit("Comparing versions...")
	_http.request_completed.disconnect(_on_sha_received)
	_http.request_completed.connect(_on_comparison_received)
	_http.request("https://api.github.com/repos/%s/%s/compare/%s...%s" % [REPO_OWNER, REPO_NAME, _local_sha, _target_sha])


func _on_tree_received(_result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if code != 200:
		update_error.emit("Failed to fetch repository tree")
		return
		
	var json = JSON.parse_string(body.get_string_from_utf8())
	var files_to_download: Array = []
	
	for item in json.get("tree", []):
		if item["type"] == "blob":
			var path = item["path"]
			if not path.begins_with("UserContents/"):
				files_to_download.append(path)
				
	_launch_thread(files_to_download)


func _on_comparison_received(_result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if code != 200:
		update_error.emit("Comparison failed")
		return
		
	var json = JSON.parse_string(body.get_string_from_utf8())
	var files_to_download: Array = []
	
	for f in json.get("files", []):
		var fname = f["filename"]
		if not fname.begins_with("UserContents/"):
			files_to_download.append(fname)
			
	_launch_thread(files_to_download)


func _launch_thread(files: Array) -> void:
	if files.is_empty():
		_save_sha_locally()
		update_error.emit("No changes to apply.")
		return
		
	update_status.emit("Preparing %d files..." % files.size())
	_thread = Thread.new()
	_thread.start(_threaded_download_process.bind(files))


func _threaded_download_process(files: Array) -> void:
	var count = 0
	var total = files.size()
	
	for file_path in files:
		count += 1
		call_deferred("emit_signal", "update_status", "Downloading (%d/%d): %s" % [count, total, file_path.get_file()])
		
		var url = "https://raw.githubusercontent.com/%s/%s/%s/%s" % [REPO_OWNER, REPO_NAME, BRANCH, file_path.uri_encode()]
		var result = _sync_download(url)
		
		if result.is_empty():
			call_deferred("emit_signal", "update_error", "Failed: " + file_path)
			return
			
		_write_to_temp_disk(file_path, result)
	
	call_deferred("_finalize_update")


func _sync_download(url: String) -> PackedByteArray:
	var client = HTTPClient.new()
	var err = client.connect_to_host("raw.githubusercontent.com", 443, TLSOptions.client())
	
	if err != OK: return PackedByteArray()
	while client.get_status() == HTTPClient.STATUS_CONNECTING or client.get_status() == HTTPClient.STATUS_RESOLVING:
		client.poll()
		OS.delay_msec(5)
		
	if client.get_status() != HTTPClient.STATUS_CONNECTED: return PackedByteArray()
	
	client.request(HTTPClient.METHOD_GET, url.replace("https://raw.githubusercontent.com", ""), [])
	
	while client.get_status() == HTTPClient.STATUS_REQUESTING:
		client.poll()
		OS.delay_msec(5)
		
	var rb = PackedByteArray()
	while client.get_status() == HTTPClient.STATUS_BODY:
		client.poll()
		var chunk = client.read_response_body_chunk()
		if chunk.size() > 0: rb.append_array(chunk)
		
	client.close()
	return rb


func _write_to_temp_disk(path: String, data: PackedByteArray) -> void:
	var full_path = ProjectSettings.globalize_path(TEMP_FOLDER) + path
	DirAccess.make_dir_recursive_absolute(full_path.get_base_dir())
	var f = FileAccess.open(full_path, FileAccess.WRITE)
	if f:
		f.store_buffer(data)
		f.close()


func _save_sha_locally() -> void:
	var f = FileAccess.open(SHA_FILE, FileAccess.WRITE)
	if f:
		f.store_string(_target_sha)
		f.close()


func _finalize_update() -> void:
	if _thread and _thread.is_started():
		_thread.wait_to_finish()
		
	var f = FileAccess.open(ProjectSettings.globalize_path(TEMP_FOLDER) + "version_sha.txt", FileAccess.WRITE)
	f.store_string(_target_sha)
	f.close()
	
	_create_and_run_bat()


func _create_and_run_bat() -> void:
	var bat_path = ProjectSettings.globalize_path("user://updater.bat")
	var project_res = ProjectSettings.globalize_path("res://").replace("/", "\\").trim_suffix("\\")
	var temp_res = ProjectSettings.globalize_path(TEMP_FOLDER).replace("/", "\\").trim_suffix("\\")
	var user_sha_dest = ProjectSettings.globalize_path(SHA_FILE).replace("/", "\\")
	var godot_exe = OS.get_executable_path().replace("/", "\\")
	
	var script = "@echo off\r\n"
	script += "timeout /t 5 /nobreak > NUL\r\n"
	script += 'xcopy "%s\\*" "%s" /Y /S /E /I /R /H\r\n' % [temp_res, project_res]
	script += 'copy /Y "%s\\version_sha.txt" "%s"\r\n' % [temp_res, user_sha_dest]
	script += 'rmdir /s /q "%s"\r\n' % temp_res
	script += 'start "" "%s" --path "%s" -e\r\n' % [godot_exe, project_res]
	script += '(goto) 2>nul & del "%~f0"'
	
	FileAccess.open(bat_path, FileAccess.WRITE).store_string(script)
	OS.create_process("cmd.exe", ["/c", bat_path])
	get_tree().quit()
