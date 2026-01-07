@tool
extends Node

## Checks for updates from a remote Gist file.
## Uses a custom Editor Panel (not a Window) to prevent closing via ESC/X.

signal update_found(new_version: String)

@export var version_check_url: String = "https://gist.githubusercontent.com/newold3/3ff01f9859cc46ae86b8eb5344cbb800/raw/godot_rpg_creator_version.txt"

const BLOCKING_GROUP: String = "startup_blocking_window"

var _http_request: HTTPRequest
var _pre_update_dialog: ConfirmationDialog

# Custom UI Elements
var _overlay: ColorRect
var _panel_container: PanelContainer
var _status_label: Label
var _dots_timer: Timer

var _base_text: String = "Initializing"
var _dot_count: int = 0


func _ready() -> void:
	_http_request = HTTPRequest.new()
	add_child(_http_request)
	_http_request.request_completed.connect(_on_request_completed)

	_dots_timer = Timer.new()
	_dots_timer.wait_time = 0.15
	_dots_timer.one_shot = false
	_dots_timer.timeout.connect(_on_animate_dots)
	add_child(_dots_timer)

	if Engine.is_editor_hint():
		_cleanup_ui()
		
		await get_tree().create_timer(4.0).timeout
		if not is_instance_valid(self) or not is_inside_tree(): return
		check_for_updates()


func _exit_tree() -> void:
	_cleanup_ui()


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
				update_found.emit(remote_version)
				_wait_and_show_dialog(remote_version)


func _is_newer_version(remote_ver: String) -> bool:
	var current_version: String = ProjectSettings.get_setting("application/config/version")
	return remote_ver.naturalnocasecmp_to(current_version) > 0


func _wait_and_show_dialog(new_version: String) -> void:
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
	_pre_update_dialog.min_size = Vector2(350, 150)
	_pre_update_dialog.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_MAIN_WINDOW_SCREEN
	_pre_update_dialog.confirmed.connect(func(): call_deferred("_instantiate_update_manager"))
	add_child(_pre_update_dialog)


func _instantiate_update_manager() -> void:
	_create_progress_ui()
	
	var manager = SmartUpdateManager.new()
	add_child(manager)
	
	manager.update_status.connect(_on_manager_status)
	manager.update_error.connect(_on_manager_error)
	
	manager.check_updates()


func _create_progress_ui() -> void:
	var base_control = EditorInterface.get_base_control()
	if not base_control: return

	# 1. Full Screen Overlay
	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 0.8)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.focus_mode = Control.FOCUS_ALL
	base_control.add_child(_overlay)
	_overlay.grab_focus()
	
	# 2. Central Panel
	_panel_container = PanelContainer.new()
	_panel_container.custom_minimum_size = Vector2(400, 150)
	_panel_container.layout_mode = 1 
	_panel_container.anchors_preset = Control.PRESET_CENTER
	_overlay.add_child(_panel_container)
	
	# 3. Content
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_child(vbox)
	_panel_container.add_child(margin)
	
	var title = Label.new()
	title.text = "UPDATING RPG CREATOR"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.4, 0.7, 1.0))
	vbox.add_child(title)
	
	vbox.add_child(HSeparator.new())
	
	_status_label = Label.new()
	_status_label.text = "Initializing..."
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_status_label)
	
	_dots_timer.start()


func _on_manager_status(msg: String) -> void:
	_base_text = msg
	
	# Update text immediately
	if _status_label:
		_status_label.text = msg
	
	# Disable animation for Extraction phase, Enable for Downloading
	if "Extracting" in msg:
		if not _dots_timer.is_stopped():
			_dots_timer.stop()
	else:
		# Downloading or Initializing -> Enable dots
		if _dots_timer.is_stopped():
			_dots_timer.start()
			_dot_count = 0


func _on_animate_dots() -> void:
	if not _status_label or not is_instance_valid(_status_label): return
	
	_dot_count = (_dot_count + 1) % 4
	
	var dots = ""
	match _dot_count:
		1: dots = "."
		2: dots = ".."
		3: dots = "..."
		_: dots = "" # 0 is empty
	
	_status_label.text = _base_text + dots


func _on_manager_error(msg: String) -> void:
	_dots_timer.stop()
	
	if _status_label:
		_status_label.text = "ERROR: " + msg
		_status_label.add_theme_color_override("font_color", Color(1, 0.4, 0.4))
	
	if _overlay:
		# Allow closing on error
		_overlay.gui_input.connect(func(event):
			if event is InputEventMouseButton and event.pressed:
				_cleanup_ui()
		)
		
		var btn = Button.new()
		btn.text = "Close"
		btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		btn.pressed.connect(_cleanup_ui)
		
		var margin = _panel_container.get_child(0)
		var vbox = margin.get_child(0)
		vbox.add_child(HSeparator.new())
		vbox.add_child(btn)


func _cleanup_ui() -> void:
	if _overlay and is_instance_valid(_overlay):
		_overlay.queue_free()
		_overlay = null
	
	if _pre_update_dialog and is_instance_valid(_pre_update_dialog):
		_pre_update_dialog.queue_free()
