@tool
extends EditorPlugin

var database_button: Button
var main_database

var database_scene_path := "res://addons/RPGData/Scenes/database_dialog.tscn"

var create_rpg_map_button: Button
var main_separator: HSeparator


func _enter_tree() -> void:
	TranslationServer.set_translation_domain("en")
	if Engine.is_editor_hint():
		var path = "res://addons/RPGData/Scenes/database_button.tscn"
		database_button = load(path).instantiate()
		database_button.pressed.connect(_on_database_button_pressed)
		database_button.tooltip_text = "[title]DATABASE[/title]\nDisplays the database and allows to edit it"
		
		add_control_to_container(EditorPlugin.CONTAINER_CANVAS_EDITOR_MENU, database_button)
		CustomTooltipManager.plugin_replace_all_tooltips_with_custom(database_button)
		
		RPGSYSTEM.editor_interface = get_editor_interface()
		
		ResourceLoader.load_threaded_request(database_scene_path)
		
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
		var value = map.get(prop_name)
		saved_properties[prop_name] = value
	
	var new_script: GDScript = GDScript.new()
	new_script.source_code = "@tool\nextends RPGMap\n"
	
	## We must save the script first so it has a valid resource path before packing
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


func _find_create_root_container(node: Node) -> Node:
	if node.name == "Scene":
		var container = _get_create_container(node)
		if container:
			return container
	
	for child in node.get_children():
		var container = _find_create_root_container(child)
		if container:
			return container
	
	return null


func _get_create_container(node: Node) -> Node:
	if node and node.name == "Scene" and node.get_class() == "SceneTreeDock" and node.get_child_count() > 2:
		var c1 = node.get_child(2)
		if c1.get_child_count() == 2 and c1.get_child(1) is ScrollContainer:
			var c2 = c1.get_child(1)
			if c2.get_child_count() > 0 and c2.get_child(0) is VBoxContainer:
				var c3 = c2.get_child(0)
				if c3.get_child_count() > 0 and c3.get_child(0) is VBoxContainer:
					var c4 = c3.get_child(0)
					if c4.get_children().all(
						func(child: Node):
							return child is Button
					):
						# Real conjtainer found?????
						print("Container found: ", c4, ". Map creation button injected.")
						return c4
	
	return null


func _on_database_button_pressed() -> void:
	while !main_database and ResourceLoader.load_threaded_get_status(database_scene_path) != ResourceLoader.THREAD_LOAD_LOADED:
		get_tree().process_frame
	
	if !main_database:
		main_database = ResourceLoader.load_threaded_get(database_scene_path).instantiate()
		var f = RPGDialogFunctions.open_dialog
		main_database = f.call(main_database, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
		main_database.get_child(0).editor_interface = get_editor_interface()
		main_database.get_child(0).resource_previewer = EditorInterface.get_resource_previewer()
		main_database.get_child(0).set_tool_connections()
		main_database.visibility_changed.connect(
			func():
				if !main_database.visible:
					FileCache.options.main_database_dialog = {"position": main_database.position, "size": main_database.size}
		)
	else:
		var f = RPGDialogFunctions.show_dialog
		f.call(main_database, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	
	var state = FileCache.options.get("main_database_dialog", null)
	if !state:
		var s = Vector2i(DisplayServer.screen_get_size() * 0.85)
		main_database.size = s
		main_database.position = DisplayServer.screen_get_size() / 2 - main_database.size / 2
	else:
		main_database.size = state.size
		main_database.position = state.position


func _exit_tree() -> void:
	if main_separator:
		main_separator.queue_free()
	if create_rpg_map_button:
		create_rpg_map_button.queue_free()
	if database_button:
		remove_control_from_container(EditorPlugin.CONTAINER_CANVAS_EDITOR_MENU, database_button)
		database_button.queue_free()
	if main_database:
		main_database.queue_free()
