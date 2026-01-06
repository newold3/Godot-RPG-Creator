@tool
extends Node

## Current version of the installed application.
const CURRENT_VERSION: String = "1.0"

## URL to the raw text file. IMPORTANT: Must be the 'Raw' link.
@export var version_check_url: String = "https://gist.githubusercontent.com/newold3/3ff01f9859cc46ae86b8eb5344cbb800/raw/godot_rpg_creator_version.txt"

## Reference to the HTTPRequest node.
@onready var http_request: HTTPRequest = HTTPRequest.new()


func _ready() -> void:
	add_child(http_request)
	http_request.request_completed.connect(_on_request_completed)

	if Engine.is_editor_hint():
		check_for_updates()


func check_for_updates() -> void:
	http_request.request(version_check_url)


func _on_request_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		print("Failed to reach update server.")
		return
	
	# Convert the response to string and remove extra spaces/newlines.
	var response_text = body.get_string_from_utf8().strip_edges()
	
	# Parse the format "version: 1.0"
	if response_text.begins_with("version:"):
		# Split by ':' and take the second part (the number).
		var remote_version = response_text.split(":")[1].strip_edges()
		
		if _is_newer_version(remote_version):
			print("Update available: ", remote_version)
		else:
			print("There are no updates available.")
	else:
		print("Invalid version file format.")


func _is_newer_version(remote_ver: String) -> bool:
	return remote_ver.naturalnocasecmp_to(CURRENT_VERSION) > 0
