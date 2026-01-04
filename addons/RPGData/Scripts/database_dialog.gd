@tool
extends Window

@onready var timer: Timer = %Timer

func _ready() -> void:
	RPGMapPlugin.reload_inputs_safely()
	#InputMap.load_from_project_settings()
	close_requested.connect(hide_me)
	visibility_changed.connect(_on_visibility_changed)
	_load_backup()


func _load_backup() -> void:
	return
	var database_backup = MainDatabasePanel.BACKUP_PATH
	if ResourceLoader.exists(database_backup):
		RPGSYSTEM.database = ResourceLoader.load(database_backup)
		DirAccess.remove_absolute(database_backup)
		return


func _on_cancel_button_pressed() -> void:
	hide_me()


func _on_ok_button_pressed() -> void:
	hide_me()


func hide_me() -> void:
	get_tree().notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	get_tree().root.propagate_call("refresh_canvas")
	DirAccess.remove_absolute(MainDatabasePanel.BACKUP_PATH)
	await get_tree().process_frame
	hide()


func _input(event: InputEvent) -> void:
	if !visible: return
	
	if !event is InputEventMouseMotion:
		CustomTooltipManager.destroy_all_tooltips.emit()
	
	if event is InputEventKey and event.is_pressed() and event.keycode == KEY_S and event.is_ctrl_pressed():
		save()
		print("database saved!")


func _on_visibility_changed() -> void:
	if visible:
		if ResourceLoader.exists(MainDatabasePanel.BACKUP_PATH):
			await _restore_database_requested()
		timer.start()
		if mode == Window.MODE_MINIMIZED:
			mode = Window.MODE_WINDOWED
			grab_focus()
			move_to_foreground()
	else:
		timer.stop()
		var scene_root = EditorInterface.get_edited_scene_root()
		if scene_root and scene_root is RPGMap:
			scene_root.refresh_canvas()


func _restore_database_requested() -> void:
	var path: String = MainDatabasePanel.BACKUP_PATH
	if ResourceLoader.exists(path):
		pass
	
	DirAccess.remove_absolute(MainDatabasePanel.BACKUP_PATH)


func _on_timer_timeout() -> void:
	if visible and RPGSYSTEM.database:
		ResourceSaver.save(RPGSYSTEM.database, MainDatabasePanel.BACKUP_PATH)


func save() -> void:
	DatabaseLoader.save_database()
	#var data_folder_path = DatabaseLoader.get_data_folder_path()
	#var absolute_data_folder_path = ProjectSettings.globalize_path(data_folder_path)
	#if !DirAccess.dir_exists_absolute(absolute_data_folder_path):
		#DirAccess.make_dir_recursive_absolute(absolute_data_folder_path)
#
	#var file = "database.res"
	#var database_path = data_folder_path.path_join(file)
	#RPGSYSTEM.database.take_over_path(database_path)
	#ResourceSaver.save(RPGSYSTEM.database, database_path, ResourceSaver.FLAG_COMPRESS)
	#
	#DirAccess.remove_absolute(MainDatabasePanel.BACKUP_PATH)


func _on_main_database_saved() -> void:
	save()


func _on_main_database_cancel() -> void:
	DirAccess.remove_absolute(MainDatabasePanel.BACKUP_PATH)
