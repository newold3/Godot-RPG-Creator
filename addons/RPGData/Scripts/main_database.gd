@tool
class_name MainDatabasePanel
extends Control

const BACKUP_PATH: String = "user://db_backup_recovery.tres"


var current_tab: int = -1
var current_panel: Control
var panels: Dictionary

var cache_dialog : Dictionary = {}

var data: RPGDATA
var real_data: RPGDATA

var resource_previewer: EditorResourcePreview

var editor_interface: EditorInterface

var main_file_dialog: EditorFileDialog

var is_dialog: bool = false

var data_saved: bool = false

signal destroy_all_tooltips()
signal saved()
signal cancel()


func _ready() -> void:
	CustomTooltipManager.restore_all_tooltips_for(self)
	clear_panels()
	notify_property_list_changed()
	setup_button_groups()
	var node = Engine.get_main_loop().root.get_node_or_null("RPGSYSTEM")
	if node:
		while !node.is_node_ready():
			await get_tree().process_frame
		real_data = node.database
		data = real_data.clone(true)
		
		if DatabaseLoader.is_develop_build:
			%DeveloperSection.visible = true
			%DatabaseVersion.value = int(real_data._id_version)
		else:
			%DeveloperSection.visible = false
			
		start()
	else:
		printerr("RPGSYSTEM is not set as autoload")
		get_parent().queue_free()


func clear_panels() -> void:
	for child in %PanelContents.get_children():
		child.queue_free()


func _on_parent_visibility_changed() -> void:
	if !Engine.get_main_loop().root.get_node_or_null("RPGSYSTEM"):
		printerr("RPGSYSTEM is not set as autoload")
		get_parent().queue_free()
		return
	if get_parent().visible:
		var node = Engine.get_main_loop().root.get_node_or_null("RPGSYSTEM")
		if node:
			while !node.is_node_ready():
				await get_tree().process_frame
			real_data = node.database
			data = real_data.clone()
			node.database = data
			if current_panel:
				current_panel.database = data
				current_panel.set_data(get_current_data(current_tab))
			elif current_tab >= 0:
				current_panel = panels.get(current_tab, null)
				if current_panel:
					current_panel.database = data
					current_panel.set_data(get_current_data(current_tab))
			if current_panel:
				# Forces a visibility update to address any potential inconsistencies arising from deleted data.
				current_panel.hide()
				current_panel.show()
			if DatabaseLoader.is_develop_build:
				%DeveloperSection.visible = true
				%DatabaseVersion.value = int(real_data._id_version)
			else:
				%DeveloperSection.visible = false
			%LeftMenu.get_child(current_tab).set_pressed_no_signal(true)
		CustomTooltipManager.replace_all_tooltips_with_custom(self)
	else:
		if !data_saved:
			show_confirm_save_dialog()
		else:
			data = null
		data_saved = false
		CustomTooltipManager.restore_all_tooltips_for(self)
		notify_property_list_changed()


func set_tool_connections() -> void:
	get_parent().visibility_changed.connect(_on_parent_visibility_changed)
	CustomTooltipManager.restore_all_tooltips_for(self)
	CustomTooltipManager.replace_all_tooltips_with_custom(self)
	is_dialog = true


func setup_button_groups() -> void:
	var button_group = ButtonGroup.new()
	var index = 0
	var child_count = %LeftMenu.get_child_count()
	for child in %LeftMenu.get_children():
		if "button_group" in child:
			child.button_group = button_group
			var real_index = index if child.get_index() < child_count - 2 else \
				5000 if child.get_index() == child_count - 2 else 6000
			child.pressed.connect(_on_button_pressed.bind(child, real_index))
			index += 1


func start() -> void:
	%CustomButton1.set_pressed(true) # No auto emit pressed signal
	%CustomButton1.pressed.emit()


func _on_button_pressed(_button: CustomSimpleButton, index: int) -> void:
	if index == 5000:
		_on_ok_pressed()
		return
	elif index == 6000:
		_on_cancel_pressed()
		return
		
	if current_tab != index:
		current_tab = index
		
		if current_panel:
			current_panel.hide()
			%PanelContents.call_deferred("remove_child", current_panel)
			await current_panel.tree_exited
		
		var node
		if panels.has(current_tab):
			node = panels[current_tab]
			node.database = data
			var current_data = get_current_data(index)
			node.set_data(current_data)
			%PanelContents.add_child(node)
		else:
			node = await get_panel(current_tab)
			TranslationManager.translate(node)
		
		if node:
			node.show()
			current_panel = node
		else:
			current_panel = null


func get_current_data(index: int) -> Variant:
	var current_data
	
	if index == 0: current_data = data.actors
	elif index == 1: current_data = data.classes
	elif index == 2: current_data = data.professions
	elif index == 3: current_data = data.skills
	elif index == 4: current_data = data.items
	elif index == 5: current_data = data.weapons
	elif index == 6: current_data = data.armors
	elif index == 7: current_data = data.enemies
	elif index == 8: current_data = data.troops
	elif index == 9: current_data = data.states
	elif index == 10: current_data = data.animations
	elif index == 11: current_data = data.common_events
	elif index == 12: current_data = data.types
	elif index == 13: current_data = data.terms
	elif index == 14: current_data = data.system
	elif index == 15: current_data = data.speakers
	elif index == 16: current_data = data.quests
	
	return current_data


func get_panel(index) -> Control:
	var node: Control
	if index == 0:
		node = await load_panel("res://addons/RPGData/Scenes/actors_panel.tscn", data.actors)
	elif index == 1:
		node = await load_panel("res://addons/RPGData/Scenes/classes_panel.tscn", data.classes)
	elif index == 2:
		node = await load_panel("res://addons/RPGData/Scenes/professions_panel.tscn", data.professions)
	elif index == 3:
		node = await load_panel("res://addons/RPGData/Scenes/skills_panel.tscn", data.skills)
	elif index == 4:
		node = await load_panel("res://addons/RPGData/Scenes/items_panel.tscn", data.items)
	elif index == 5:
		node = await load_panel("res://addons/RPGData/Scenes/weapons_panel.tscn", data.weapons)
	elif index == 6:
		node = await load_panel("res://addons/RPGData/Scenes/armors_panel.tscn", data.armors)
	elif index == 7:
		node = await load_panel("res://addons/RPGData/Scenes/enemies_panel.tscn", data.enemies)
	elif index == 8:
		node = await load_panel("res://addons/RPGData/Scenes/troops_panel.tscn", data.troops)
	elif index == 9:
		node = await load_panel("res://addons/RPGData/Scenes/states_panel.tscn", data.states)
	elif index == 10:
		node = await load_panel("res://addons/RPGData/Scenes/animations_panel.tscn", data.animations)
	elif index == 11:
		node = await load_panel("res://addons/RPGData/Scenes/common_events_panel.tscn", data.common_events)
	elif index == 12:
		node = await load_panel("res://addons/RPGData/Scenes/types_panel.tscn", data.types)
	elif index == 13:
		node = await load_panel("res://addons/RPGData/Scenes/terms_panel.tscn", data.terms)
	elif index == 14:
		node = await load_panel("res://addons/RPGData/Scenes/system_panel.tscn", data.system)
	elif index == 15:
		node = await load_panel("res://addons/RPGData/Scenes/speakers_panel.tscn", data.speakers)
	elif index == 16:
		node = await load_panel("res://addons/RPGData/Scenes/quests_panel.tscn", data.quests)
		
	
	return node


func load_panel(path: String, _real_data) -> Control:
	if not current_tab in panels:
		var node = load(path).instantiate()
		panels[current_tab] = node
	
	var node = panels[current_tab]
	node.visible = false
	%PanelContents.call_deferred("add_child", node)
	await node.ready
	
	node.database = data
	if _real_data:
		node.set_data(_real_data)
	
	return node


func _on_ok_pressed() -> void:
	propagate_call("apply")
	if current_tab == 12:
		propagate_call("fix_data")
	var database_changed = !data.is_equal_to(real_data)
	if database_changed:
		real_data.update_with_other_db(data)
		
	data_saved = true
	
	EditorInterface.mark_scene_as_unsaved()
	saved.emit()
	get_parent().hide()


func _on_cancel_pressed() -> void:
	RPGSYSTEM.database = real_data
	cancel.emit()
	get_parent().hide()


func show_confirm_save_dialog() -> void:
	get_viewport().set_input_as_handled()
	var database_changed = !data.is_equal_to(real_data)
	if database_changed:
		var confirm_dialog := ConfirmationDialog.new()
		confirm_dialog.title = "Confirm Save Data"
		confirm_dialog.dialog_text = "The database has changed and has not been saved, do you want to save it before closing it?"
		confirm_dialog.ok_button_text = "Save"
		confirm_dialog.confirmed.connect(_on_save_confirm_save_data)
		confirm_dialog.visibility_changed.connect(
			func():
				if !confirm_dialog.visible:
					await get_tree().process_frame
					RPGSYSTEM.database = real_data
					data = null
		)
		get_parent().get_parent().add_child(confirm_dialog)
		confirm_dialog.popup_centered()


func _on_save_confirm_save_data() -> void:
	real_data.update_with_other_db(data)


func _on_options_pressed() -> void:
	var dialog = %OptionsMenu
	var mouse_position = Vector2(DisplayServer.mouse_get_position())
	var p: Vector2 = mouse_position - dialog.size * 0.5
	var margin = 64
	var screen_size = Vector2(DisplayServer.screen_get_size())
	if p.x < margin:
		p.x = margin
	elif p.x > screen_size.x - margin - dialog.size.x:
		p.x = screen_size.x - margin - dialog.size.x
	if p.y < margin:
		p.y = margin
	elif p.y > screen_size.y - margin - dialog.size.y:
		p.y = screen_size.y - margin - dialog.size.y
	if (
		p.x + dialog.size.x < 0 or
		p.x > get_viewport().size.x or
		p.y + dialog.size.y < 0 or
		p.y > get_viewport().size.y
	):
		p = get_viewport().size * 0.5
	var rect: Rect2 = Rect2(p, dialog.size)
	dialog.popup(rect)


func _on_options_menu_index_pressed(index: int) -> void:
	match index:
		0: # Save
			var parent = get_parent()
			if parent and parent.has_method("save"):
				parent.save()
				print("database saved!")
		2: # New Database
			_create_new_database()
		3: # Load Database
			_load_from_databse()
		5: # Save To Json
			_save_to_json()
		6: # Load From Json
			_load_from_json()
		8: # Export Database
			_save_to_database()


func _replace_data_with(other_data: RPGDATA) -> void:
	RPGSYSTEM.database = other_data
	_on_parent_visibility_changed()


func _create_new_database() -> void:
	var path = "res://addons/CustomControls/Dialogs/confirm_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	dialog.set_text("Replace the current database with a new database?")
	dialog.title = TranslationManager.tr("Override Database")
	dialog.OK.connect(
		func():
			var new_data = RPGDATA.new()
			_replace_data_with(new_data)
	)


func _show_select_folder_and_file_dialog(base_dir: String, extension: String, callable: Callable, file_mode: FileDialog.FileMode, filters: Array) -> void:
	var path = "res://addons/CustomControls/Dialogs/default_file_dialog.tscn"
	var dialog_size = FileCache.options.get("default_file_dialog_config", Vector2i(640, 480))
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE, dialog_size)
	dialog.set_file_mode(file_mode)
	dialog.set_filters(filters)
	dialog.file_selected.connect(callable)
	dialog.size_changed.connect(_cache_file_dialog_size.bind(dialog))


func _cache_file_dialog_size(dialog: Window) -> void:
	FileCache.options.default_file_dialog_config = dialog.size


func _save_to_json() -> void:
	var json = JSON.stringify(JSON.from_native(data, true))
	var path = ProjectSettings.globalize_path("res://")
	_show_select_folder_and_file_dialog(path, "json", _save_json.bind(json), FileDialog.FILE_MODE_SAVE_FILE,  ["*.json;Json Files"])


func _save_json(path: String, contents: String) -> void:
	FileAccess.open(path, FileAccess.WRITE).store_string(contents)


func _load_from_json() -> void:
	var path = ProjectSettings.globalize_path("res://")
	_show_select_folder_and_file_dialog(path, "json", _load_json, FileDialog.FILE_MODE_OPEN_FILE, ["*.json;Json Files"])


func _load_json(path: String) -> void:
	var new_data
	if FileAccess.file_exists(path):
		var json: String = FileAccess.get_file_as_string(path)
		new_data = JSON.to_native(JSON.parse_string(json), true)
		if new_data is RPGDATA:
			_replace_data_with(new_data)
		else:
			printerr("The file '%s' is not valid database" % path)


func _load_from_databse() -> void:
	var path = ProjectSettings.globalize_path("res://")
	_show_select_folder_and_file_dialog(path, "res", _load_database, FileDialog.FILE_MODE_OPEN_FILE, ["*.res;Database Files"])


func _load_database(path: String) -> void:
	var new_data
	if ResourceLoader.exists(path):
		new_data = ResourceLoader.load(path)
		if new_data is RPGDATA:
			_replace_data_with(new_data)
		else:
			printerr("The file '%s' is not valid database" % path)


func _save_to_database() -> void:
	var path = ProjectSettings.globalize_path("res://")
	_show_select_folder_and_file_dialog(path, "res", _save_database, FileDialog.FILE_MODE_SAVE_FILE, ["*.res;Databse Files"])


func _save_database(path: String) -> void:
	ResourceSaver.save(data, path)


func _on_database_version_value_changed(value: float) -> void:
	if DatabaseLoader.is_develop_build:
		real_data._id_version = value
		data._id_version = value
