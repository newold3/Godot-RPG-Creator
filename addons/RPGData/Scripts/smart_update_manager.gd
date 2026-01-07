class_name SmartUpdateManager
extends Node

## Unified Update Manager for Godot RPG Creator.
## In dev mode, it strictly uses user:// to avoid conflicts with master branch files.

signal update_status(msg: String)
signal update_error(msg: String)

const REPO_OWNER: String = "newold3"
const REPO_NAME: String = "Godot-RPG-Creator-4.5.6-"
const BRANCH: String = "develop"

const SHA_USER_FILE: String = "user://version_sha.txt"
const SHA_RES_FILE: String = "res://addons/RPGData/version_sha.txt"
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
	
	_initialize_local_sha()


func _initialize_local_sha() -> void:
	# Priority logic:
	# In develop mode, we ONLY trust user:// to test incremental updates.
	# res:// is only a fallback for fresh end-user installs.
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
	
	# Final check: In dev mode we don't look at res:// sha to avoid 'master' interference
	if _local_sha == _target_sha:
		_save_sha_to_user(_target_sha)
		update_status.emit("Project is up to date.")
		update_error.emit("No update needed.")
		return
	
	if _local_sha == "":
		_start_full_download()
	else:
		_start_incremental_update()


func _start_full_download() -> void:
	update_status.emit("Initial download...")
	_http.request_completed.disconnect(_on_sha_received)
	_http.request_completed.connect(_on_tree_received)
	_http.request("https://api.github.com/repos/%s/%s/git/trees/%s?recursive=1" % [REPO_OWNER, REPO_NAME, BRANCH])


func _start_incremental_update() -> void:
	update_status.emit("Checking changes...")
	_http.request_completed.disconnect(_on_sha_received)
	_http.request_completed.connect(_on_comparison_received)
	_http.request("https://api.github.com/repos/%s/%s/compare/%s...%s" % [REPO_OWNER, REPO_NAME, _local_sha, _target_sha])


func _on_tree_received(_result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if code != 200:
		update_error.emit("Failed to fetch tree")
		return
		
	var json = JSON.parse_string(body.get_string_from_utf8())
	var files: Array = []
	for item in json.get("tree", []):
		if item["type"] == "blob" and not item["path"].begins_with("UserContents/"):
			files.append(item["path"])
	_launch_thread(files)


func _on_comparison_received(_result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if code != 200:
		update_error.emit("Comparison failed")
		return
		
	var json = JSON.parse_string(body.get_string_from_utf8())
	var files: Array = []
	for f in json.get("files", []):
		if not f["filename"].begins_with("UserContents/"):
			files.append(f["filename"])
	_launch_thread(files)


func _launch_thread(files: Array) -> void:
	if files.is_empty():
		_save_sha_to_user(_target_sha)
		update_error.emit("No changes found.")
		return
	_thread = Thread.new()
	_thread.start(_threaded_download_process.bind(files))


func _threaded_download_process(files: Array) -> void:
	var count = 0
	var total = files.size()
	for path in files:
		count += 1
		call_deferred("emit_signal", "update_status", "Downloading (%d/%d): %s" % [count, total, path.get_file()])
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
	client.request(HTTPClient.METHOD_GET, url.replace("https://raw.githubusercontent.com", ""), [])
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
	FileAccess.open(ProjectSettings.globalize_path(TEMP_FOLDER) + "version_sha.txt", FileAccess.WRITE).store_string(_target_sha)
	_create_and_run_bat()


func _create_and_run_bat() -> void:
	var bat_path = ProjectSettings.globalize_path("user://updater.bat")
	var project_res = ProjectSettings.globalize_path("res://").replace("/", "\\").trim_suffix("\\")
	var temp_res = ProjectSettings.globalize_path(TEMP_FOLDER).replace("/", "\\").trim_suffix("\\")
	var user_sha = ProjectSettings.globalize_path(SHA_USER_FILE).replace("/", "\\")
	var godot_exe = OS.get_executable_path().replace("/", "\\")
	var script = "@echo off\r\ntimeout /t 5 /nobreak > NUL\r\n"
	script += 'xcopy "%s\\*" "%s" /Y /S /E /I /R /H\r\n' % [temp_res, project_res]
	script += 'copy /Y "%s\\version_sha.txt" "%s"\r\n' % [temp_res, user_sha]
	script += 'rmdir /s /q "%s"\r\n' % temp_res
	script += 'start "" "%s" --path "%s" -e\r\n' % [godot_exe, project_res]
	script += '(goto) 2>nul & del "%~f0"'
	FileAccess.open(bat_path, FileAccess.WRITE).store_string(script)
	OS.create_process("cmd.exe", ["/c", bat_path])
	get_tree().quit()
