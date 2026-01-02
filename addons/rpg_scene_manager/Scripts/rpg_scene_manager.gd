@tool
class_name RPGSceneButton
extends MarginContainer


var editor_interface: EditorInterface

var edit_maps_menu: PopupMenu


func _ready() -> void:
	%MainButton.can_select_item_with_button_wheel = false
	%MainButton.item_selected.connect(_on_item_selected)
	%MainButton.get_popup().about_to_popup.connect(_update_map_list)

	edit_maps_menu = PopupMenu.new()
	edit_maps_menu.id_pressed.connect(_edit_map)
	
	%MainButton.get_popup().set_item_submenu_node(2, edit_maps_menu)

	CustomTooltipManager.plugin_replace_all_tooltips_with_custom.call_deferred(self)


func _update_map_list() -> void:
	edit_maps_menu.clear()
	for map in RPGMapsInfo.map_infos.map_names.keys():
		if map == "res://addons/RPGMap/Scenes/event_command_testing.tscn": continue
		edit_maps_menu.add_item(map.get_basename().get_file())


func _edit_map(index: int) -> void:
	if RPGMapsInfo.map_infos.map_names.keys().size() > index:
		var map = RPGMapsInfo.map_infos.map_names.keys()[index]
		if ResourceLoader.exists(map):
			editor_interface.open_scene_from_path(map)


func _on_item_selected(index: int) -> void:
	%MainButton.select(0)
	
	if !editor_interface:
		return
	
	var path: String
	
	match index:
		1: # Create RPG Map
			create_rpg_map()
		2: # Edit RPG Map (No configuration, managed by the secondary popup)
			pass
		3: # Edit Title Scene
			path = "res://Scenes/TitleScene/scene_title.tscn"
			pass
		4: # Edit Load Game Scene
			path = "res://Scenes/LoadSaveScene/load_game_scene.tscn"
		5: # Edit Save Game Scene
			pass
		6: # Edit Credits Game Scene
			path = "res://Scenes/OtherScenes/credits_scene.tscn"
		7: # Edit Menu Scene
			path = "res://Scenes/SceneMainMenu/main_menu.tscn"
	
	if ResourceLoader.exists(path):
		editor_interface.open_scene_from_path(path)


func get_editor_main_tabbar() -> String:
	# (May change in future versions of Godot)
	return "/root/@EditorNode@16886/@Panel@13/@VBoxContainer@14/DockHSplitLeftL/DockHSplitLeftR/DockHSplitMain/@VBoxContainer@25/DockVSplitCenter/@VSplitContainer@52/@VBoxContainer@53/@EditorSceneTabs@67/@PanelContainer@54/@HBoxContainer@55/@TabBar@56"


func create_rpg_map() -> void:
	if !editor_interface:
		return
	
	var path = "res://addons/CustomControls/Dialogs/select_text_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path)
	dialog.title = TranslationManager.tr("Set a map name")
	dialog.text_selected.connect(
		func(map_name: String):
			var formatted_name = map_name.to_snake_case().to_lower().strip_edges().replace(" ", "_")
			var map_path = "res://Scenes/Maps/" + formatted_name + ".tscn"
			var path_is_free: Array[bool] = [true]
			if ResourceLoader.exists(map_path):
				path_is_free = [false]
				path = "res://addons/CustomControls/Dialogs/confirm_dialog.tscn"
				dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE, null, true)
				dialog.title = TranslationManager.tr("File Exists")
				dialog.set_text("The file:\n\n[color=red]%s[/color]\n\nalready exists. overwrite it?" % map_path)
				dialog.OK.connect(func(): path_is_free[0] = true)
				await dialog.tree_exited
			if path_is_free[0]:
				_create_new_map(map_name, formatted_name, map_path)
	)


func _create_new_map(map_name: String, formatted_name: String, map_path: String) -> void:
	var map: RPGMap = preload("uid://cp8vj6xsxc1ad").instantiate()
	map.name = map_name
	
	var saved_properties = {}
	var property_list = map.get_property_list()
	for property in property_list:
		var prop_name = property.name
		if prop_name == "internal_id" or prop_name == "script": continue
		var value = map.get(prop_name)
		saved_properties[prop_name] = value
	
	var script = GDScript.new()
	script.source_code = "@tool\nextends RPGMap\n"
	map.set_script(script)
	
	for prop_name in saved_properties:
		map.set(prop_name, saved_properties[prop_name])
	
	map.internal_id = 0
	
	var tmp = PackedScene.new()
	tmp.pack(map)
	
	var file = map_path
	var script_file = "res://Scenes/Maps/%s.gd" % formatted_name
	ResourceSaver.save(tmp, file)
	ResourceSaver.save(script, script_file)
	EditorInterface.open_scene_from_path(file)
	EditorInterface.mark_scene_as_unsaved()
	
	var editor_fs = EditorInterface.get_resource_filesystem()
	editor_fs.scan()
	
	RPGMapsInfo.fix_maps([EditorInterface.get_edited_scene_root()])
