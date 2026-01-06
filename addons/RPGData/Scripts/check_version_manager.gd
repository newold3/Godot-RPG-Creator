@tool
extends Node

## Emitted when a newer version is found.
signal update_found(new_version: String)

## URL to the raw text file. IMPORTANT: Must be the 'Raw' link.
@export var version_check_url: String = "https://gist.githubusercontent.com/newold3/3ff01f9859cc46ae86b8eb5344cbb800/raw/godot_rpg_creator_version.txt"

## Reference to the HTTPRequest node.
var _http_request: HTTPRequest


func _ready() -> void:
	_http_request = HTTPRequest.new()
	add_child(_http_request)
	_http_request.request_completed.connect(_on_request_completed)
	update_found.connect(_try_update)

	if Engine.is_editor_hint():
		check_for_updates()


func _try_update(_new_version: String) -> void:
	var manager = UpdateManager.new()
	add_child(manager)
	manager.request_update()


func check_for_updates() -> void:
	_http_request.request(version_check_url)


func _on_request_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		print("Failed to reach update server.")
		return
	
	var response_text: String = body.get_string_from_utf8().strip_edges()
	
	if response_text.begins_with("version:"):
		var remote_version: String = response_text.split(":")[1].strip_edges()
		
		if _is_newer_version(remote_version):
			print("Update available: %s" % remote_version)
			update_found.emit(remote_version)
		else:
			print("There are no updates available.")
	else:
		print("Invalid version file format.")


func _is_newer_version(remote_ver: String) -> bool:
	var current_version: String = ProjectSettings.get_setting("application/config/version")
	# Returns > 0 if remote_ver is naturally "larger" (newer) than current_version.
	return remote_ver.naturalnocasecmp_to(current_version) > 0
