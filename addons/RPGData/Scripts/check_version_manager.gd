@tool
extends Node

## Checks for updates from a remote Gist file.
## Waits for other startup warnings to close before showing UI.

signal update_found(new_version: String)

@export var version_check_url: String = "https://gist.githubusercontent.com/newold3/3ff01f9859cc46ae86b8eb5344cbb800/raw/godot_rpg_creator_version.txt"

var _http_request: HTTPRequest
var _pre_update_dialog: ConfirmationDialog
const BLOCKING_GROUP: String = "startup_blocking_window" # Must match StartupWarning script


func _ready() -> void:
	_http_request = HTTPRequest.new()
	add_child(_http_request)
	_http_request.request_completed.connect(_on_request_completed)

	if Engine.is_editor_hint():
		await get_tree().create_timer(4.0).timeout
		if not is_instance_valid(self) or not is_inside_tree(): return
		check_for_updates()


func check_for_updates() -> void:
	_http_request.request(version_check_url)


func _on_request_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		return
	
	var response_text: String = body.get_string_from_utf8().strip_edges()
	
	if response_text.begins_with("version:"):
		var parts = response_text.split(":")
		if parts.size() > 1:
			var remote_version: String = parts[1].strip_edges()
			
			if _is_newer_version(remote_version):
				print("New version found: %s" % remote_version)
				update_found.emit(remote_version)
				
				_wait_and_show_dialog(remote_version)
	else:
		printerr("Invalid version file format.")


func _is_newer_version(remote_ver: String) -> bool:
	var current_version: String = ProjectSettings.get_setting("application/config/version")
	return remote_ver.naturalnocasecmp_to(current_version) > 0


func _wait_and_show_dialog(new_version: String) -> void:
	# Loop while the blocking group has members
	while get_tree().get_nodes_in_group(BLOCKING_GROUP).size() > 0:
		await get_tree().create_timer(0.5).timeout
	
	if not is_instance_valid(self) or not is_inside_tree(): return
	_show_update_dialog(new_version)


func _show_update_dialog(new_version: String) -> void:
	if not is_instance_valid(self) or not is_inside_tree(): return
	
	if not _pre_update_dialog:
		_create_pre_update_dialog()
	
	_pre_update_dialog.dialog_text = "A new version of Godot RPG Creator is available: v%s\n\nDo you want to update now?" % new_version
	_pre_update_dialog.popup_centered()


func _create_pre_update_dialog() -> void:
	_pre_update_dialog = ConfirmationDialog.new()
	_pre_update_dialog.title = "New Version Available"
	_pre_update_dialog.min_size = Vector2(300, 100)
	_pre_update_dialog.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_MAIN_WINDOW_SCREEN
	
	_pre_update_dialog.confirmed.connect(func(): call_deferred("_instantiate_update_manager"))
	
	add_child(_pre_update_dialog)


func _instantiate_update_manager() -> void:
	var manager = SmartUpdateManager.new()
	add_child(manager)
	manager.check_updates()
