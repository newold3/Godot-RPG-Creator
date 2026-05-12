@tool
class_name RPGSceneButton
extends MarginContainer


#region VARIABLES
var editor_interface: EditorInterface

var edit_maps_menu: PopupMenu
var edit_scenes_menu: PopupMenu
#endregion



func _ready() -> void:
	%MainButton.get_popup().index_pressed.connect(_on_item_selected)
	%MainButton.get_popup().about_to_popup.connect(_update_map_list)
	%MainButton.get_popup().about_to_popup.connect(_change_arrow.bind(1))
	%MainButton.get_popup().popup_hide.connect(_change_arrow.bind(0))

	edit_maps_menu = PopupMenu.new()
	edit_maps_menu.name = "EditMapsMenu"
	edit_maps_menu.index_pressed.connect(_edit_map)

	%MainButton.get_popup().add_child(edit_maps_menu)
	%MainButton.get_popup().set_item_submenu_node(1, edit_maps_menu)

	edit_scenes_menu = PopupMenu.new()
	edit_scenes_menu.name = "EditScenesMenu"
	edit_scenes_menu.index_pressed.connect(_edit_scene)

	%MainButton.get_popup().add_child(edit_scenes_menu)
	%MainButton.get_popup().set_item_submenu_node(2, edit_scenes_menu)

	%MainButton.alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	_populate_scenes_menu()

	CustomTooltipManager.plugin_replace_all_tooltips_with_custom.call_deferred(self)


func _change_arrow(idx: int) -> void:
	var text = tr("RPG Scene Manager")
	if idx == 1:
		%MainButton.text = text + " ▶"
	else:
		%MainButton.text = text + " ▼"



## Rellena dinámicamente la lista de mapas disponibles usando metadata para asegurar la ruta
func _update_map_list() -> void:
	edit_maps_menu.clear()
	
	for map in RPGMapsInfo.map_infos.map_names.keys():
		if map == "res://addons/RPGMap/Scenes/event_command_testing.tscn": continue
		elif map == "res://addons/RPGMap/Scenes/@DefaultMap@.tscn": continue
		
		edit_maps_menu.add_item(map.get_basename().get_file())
		
		var item_index: int = edit_maps_menu.get_item_count() - 1
		edit_maps_menu.set_item_metadata(item_index, map)



## Rellena la lista estática de escenas core del sistema usando metadata
func _populate_scenes_menu() -> void:
	edit_scenes_menu.clear()
	
	var core_scenes: Dictionary = RPGSYSTEM.database.system.game_scenes
	
	for key in core_scenes.keys():
		edit_scenes_menu.add_item(key)
		edit_scenes_menu.set_item_metadata(-1, core_scenes[key])



## Maneja la selección de un mapa en el submenú de mapas
func _edit_map(index: int) -> void:
	var map_path: String = edit_maps_menu.get_item_metadata(index)
	
	if map_path and ResourceLoader.exists(map_path):
		editor_interface.open_scene_from_path(map_path)
		RPGMenuAPI.close_menu()



## Maneja la selección de una escena core en el submenú de escenas
func _edit_scene(index: int) -> void:
	var scene_path: String = edit_scenes_menu.get_item_metadata(index)
	
	if scene_path and ResourceLoader.exists(scene_path):
		editor_interface.open_scene_from_path(scene_path)
		RPGMenuAPI.close_menu()



## Gestiona las opciones del menú principal (ahora mucho más limpio)
func _on_item_selected(index: int) -> void:
	if !editor_interface:
		return

	match index:
		0:
			RPGMenuAPI.close_menu()
			create_rpg_map.call_deferred()
		1:
			pass
		2:
			pass



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
