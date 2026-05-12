@tool
extends EditorPlugin

## Plugin that manages the RPG Database UI and update system integration.

var database_button: Button
var update_button: Button
var main_database: Window
var main_separator: HSeparator
var create_rpg_map_button: Button

var database_scene_path := "res://addons/RPGData/Scenes/database_dialog.tscn"


func _enter_tree() -> void:
	TranslationServer.set_translation_domain("en")
	
	if Engine.is_editor_hint():
		_setup_database_button()
		_setup_update_button()
		_setup_map_creation_ui()


func _shortcut_input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		if event.keycode == KEY_F9:
			get_viewport().set_input_as_handled()
			_on_database_button_pressed()


func _setup_database_button() -> void:
	var path = "res://addons/RPGData/Scenes/database_button.tscn"
	database_button = load(path).instantiate()
	database_button.pressed.connect(_on_database_button_pressed, CONNECT_DEFERRED)
	database_button.tooltip_text = "[title]DATABASE[/title]\nDisplays the database and allows to edit it"
	
	
	#add_control_to_container(EditorPlugin.CONTAINER_CANVAS_EDITOR_MENU, database_button)
	RPGMenuAPI.add_menu_item(database_button)
	CustomTooltipManager.plugin_replace_all_tooltips_with_custom(database_button)
	
	RPGSYSTEM.editor_interface = get_editor_interface()
	ResourceLoader.load_threaded_request(database_scene_path)


func _setup_update_button() -> void:
	update_button = Button.new()
	update_button.flat = true
	
	# Icon from editor theme (Reload icon)
	var editor_base = get_editor_interface().get_base_control()
	update_button.icon = editor_base.get_theme_icon("Reload", "EditorIcons")
	update_button.tooltip_text = "[title]Updates[/title]\nCheck for RPG Creator Updates"
	update_button.pressed.connect(_on_update_button_pressed)
	update_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	
	# MOVED: To the top right toolbar (near Play/Pause buttons)
	add_control_to_container(EditorPlugin.CONTAINER_TOOLBAR, update_button)
	CustomTooltipManager.plugin_replace_all_tooltips_with_custom(update_button)


func _setup_map_creation_ui() -> void:
	var container = _find_create_root_container(EditorInterface.get_base_control())
	if container:
		main_separator = HSeparator.new()
		container.add_child(main_separator)
		container.move_child(main_separator, 0)
		
		create_rpg_map_button = Button.new()
		create_rpg_map_button.icon = preload("res://addons/rpg_scene_manager/Assets/Images/map.png")
		create_rpg_map_button.text = "Create Map"
		create_rpg_map_button.pressed.connect(_create_new_map)
		
		container.add_child(create_rpg_map_button)
		container.move_child(create_rpg_map_button, 0)


func _on_update_button_pressed() -> void:
	if CheckVersionManager:
		CheckVersionManager.check_for_updates()
	else:
		printerr("CheckVersionManager autoload not found.")


func _on_database_button_pressed() -> void:
	while !main_database and ResourceLoader.load_threaded_get_status(database_scene_path) != ResourceLoader.THREAD_LOAD_LOADED:
		await get_tree().process_frame
	
	if !main_database:
		var scene = ResourceLoader.load_threaded_get(database_scene_path)
		main_database = scene.instantiate()
		
		var f = RPGDialogFunctions.open_dialog
		main_database = f.call(main_database, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
		
		var inner_logic = main_database.get_child(0)
		inner_logic.editor_interface = get_editor_interface()
		inner_logic.resource_previewer = EditorInterface.get_resource_previewer()
		inner_logic.set_tool_connections()
		
		main_database.visibility_changed.connect(_on_database_visibility_changed)
	else:
		RPGDialogFunctions.show_dialog.call(main_database, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	
	_restore_database_window_state()


func _on_database_visibility_changed() -> void:
	if main_database and !main_database.visible:
		FileCache.options.main_database_dialog = {
			"position": main_database.position, 
			"size": main_database.size
		}


func _restore_database_window_state() -> void:
	var state = FileCache.options.get("main_database_dialog", null)
	if !state:
		var s = Vector2i(DisplayServer.screen_get_size() * 0.85)
		main_database.size = s
		main_database.position = DisplayServer.screen_get_size() / 2 - main_database.size / 2
	else:
		main_database.size = state.size
		main_database.position = state.position


func _create_new_map() -> void:
	var map: RPGMap = preload("uid://cp8vj6xsxc1ad").instantiate()
	map.name = "RPGMap" + str(RPGMapsInfo.map_infos.maps.size() + 1).pad_zeros(4)
	
	var file_path: String = "res://Scenes/Maps/%s.tscn" % map.name
	var script_path: String = "res://Scenes/Maps/%s.gd" % map.name
	
	var saved_properties: Dictionary = {}
	var property_list: Array = map.get_property_list()
	
	for property in property_list:
		var prop_name: String = property.name
		if prop_name == "internal_id" or prop_name == "script": 
			continue
		saved_properties[prop_name] = map.get(prop_name)
	
	var new_script: GDScript = GDScript.new()
	new_script.source_code = "@tool\nextends RPGMap\n"
	
	ResourceSaver.save(new_script, script_path)
	new_script = load(script_path)
	map.set_script(new_script)
	
	for prop_name in saved_properties:
		map.set(prop_name, saved_properties[prop_name])
	
	map.internal_id = 0
	var packed_scene: PackedScene = PackedScene.new()
	packed_scene.pack(map)
	
	ResourceSaver.save(packed_scene, file_path)
	EditorInterface.get_resource_filesystem().scan()
	EditorInterface.open_scene_from_path(file_path)
	EditorInterface.mark_scene_as_unsaved()
	
	RPGMapsInfo.fix_maps([EditorInterface.get_edited_scene_root()])


func _find_create_root_container(node: Node) -> Control:
	# 1. Check if this node is a candidate (has enough children).
	if node.get_child_count() >= 2:
		var target_2d_text := tr("2D Scene")
		var target_3d_text := tr("3D Scene")
		
		var found_2d := false
		
		# Iterate through children to find the specific sequence.
		for child in node.get_children():
			# We only care about Buttons.
			if child is Button:
				if child.text == target_2d_text:
					found_2d = true
				elif found_2d and child.text == target_3d_text:
					# Found "2D Scene" followed immediately by "3D Scene".
					return node as Control
				elif found_2d and child.text != target_3d_text:
					# Sequence broken (e.g. found 2D scene, but next wasn't 3D scene).
					found_2d = false
			else:
				# If we hit a separator or other node, reset the sequence search.
				found_2d = false

	# 2. Recursive step: Search inside children.
	for child in node.get_children():
		var result := _find_create_root_container(child)
		if result:
			return result

	return null


func _exit_tree() -> void:
	if main_separator:
		main_separator.queue_free()
	if create_rpg_map_button:
		create_rpg_map_button.queue_free()
	if update_button:
		remove_control_from_container(EditorPlugin.CONTAINER_TOOLBAR, update_button)
		update_button.queue_free()
	if database_button:
		#remove_control_from_container(EditorPlugin.CONTAINER_CANVAS_EDITOR_MENU, database_button)
		RPGMenuAPI.remove_menu_item(database_button)
		database_button.queue_free()
	if main_database:
		main_database.queue_free()
