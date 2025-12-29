@tool
extends EditorPlugin


var character_creator_button: Button
var interface
var database_scene_path := "res://addons/rpg_character_creator/Scenes/lpc_character_creator_dialog.tscn"

func _enter_tree() -> void:
	var path = "res://addons/rpg_character_creator/Scenes/character_creator_button.tscn"
	character_creator_button = load(path).instantiate()
	character_creator_button.pressed.connect(_on_create_character_button_pressed)
	character_creator_button.tooltip_text = "[title]Character Creator[/title]\nDisplays the character and npcs creation window."
	
	add_control_to_container(EditorPlugin.CONTAINER_CANVAS_EDITOR_MENU, character_creator_button)
	CustomTooltipManager.plugin_replace_all_tooltips_with_custom(character_creator_button)
	
	ResourceLoader.load_threaded_request(database_scene_path)
	
	while ResourceLoader.load_threaded_get_status(database_scene_path) != ResourceLoader.THREAD_LOAD_LOADED:
		get_tree().process_frame
	
	interface = ResourceLoader.load_threaded_get(database_scene_path).instantiate()
	interface.visibility_changed.connect(_on_interface_visibility_changed)
	interface.tree_exiting.connect(_on_interface_visibility_changed)
	interface.transient = false


func _on_create_character_button_pressed() -> void:
	while !interface and ResourceLoader.load_threaded_get_status(database_scene_path) != ResourceLoader.THREAD_LOAD_LOADED:
		get_tree().process_frame
	
	if !interface:
		interface = ResourceLoader.load_threaded_get(database_scene_path).instantiate()
		interface = RPGDialogFunctions.open_dialog(interface, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
		interface.visibility_changed.connect(_on_interface_visibility_changed)
		interface.tree_exiting.connect(_on_interface_visibility_changed)
		interface.propagate_call("set_plugin_enabled", [true])
	else:
		var dialog = RPGDialogFunctions.open_dialog(interface, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
		dialog.transient = false
	
	var state = FileCache.options.get("lpc_character_creator_dialog", null)
	if !state:
		var s = Vector2i(DisplayServer.screen_get_size() * 0.85)
		interface.size = s
		interface.position = DisplayServer.screen_get_size() / 2 - interface.size / 2
	else:
		interface.size = state.size
		interface.position = state.position


func _on_interface_visibility_changed() -> void:
	if !interface.visible or interface.is_queued_for_deletion():
		FileCache.options.lpc_character_creator_dialog = {"position": interface.position, "size": interface.size}
	elif interface.visible:
		interface.update_controls()
		#interface.propagate_call("set_focus_mode", [Control.FOCUS_NONE])


func _exit_tree() -> void:
	if character_creator_button:
		remove_control_from_container(EditorPlugin.CONTAINER_CANVAS_EDITOR_MENU, character_creator_button)
		character_creator_button.queue_free()
