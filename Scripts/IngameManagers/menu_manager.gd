class_name MenuManager
extends Node


var main_menu: Control
var starting_menu: SCENE_TITTLE


func show_menu() -> void:
	if main_menu and main_menu.visible: return
	if not GameManager.busy and not GameInterpreter.is_busy() and GameManager.game_state and not GameManager.game_state.menu_scene_prohibited:
		GameManager.busy = true
		if RPGSYSTEM.database.system.pause_day_night_in_menu:
			DayNightManager.process_mode = Node.PROCESS_MODE_DISABLED
			
		await get_tree().process_frame
		
		if not main_menu: 
			create_main_menu()
			
		if main_menu:
			if main_menu.is_inside_tree():
				main_menu.get_parent().remove_child(main_menu)
				return
			if GameManager.gui_canvas_layer:
				GameManager.gui_canvas_layer.add_child(main_menu)
				main_menu.show()
				main_menu.start()


func create_main_menu() -> void:
	if GameManager.gui_canvas_layer:
		var scene_path = RPGSYSTEM.database.system.game_scenes["Scene Main Menu"]
		if AssetManager.exists(scene_path):
			var scn = load(scene_path)
			main_menu = scn.instantiate()
			main_menu.visible = false
			main_menu.visibility_changed.connect(_on_main_menu_visibility_changed)
			main_menu.end.connect(_on_main_menu_end)


func _on_main_menu_visibility_changed() -> void:
	GameManager.busy = main_menu.visible
	if not main_menu.visible and main_menu.is_inside_tree():
		if GameManager.gui_canvas_layer:
			GameManager.gui_canvas_layer.remove_child(main_menu)


func _on_main_menu_end() -> void:
	GameManager.busy = false
	if RPGSYSTEM.database.system.pause_day_night_in_menu:
		DayNightManager.process_mode = Node.PROCESS_MODE_INHERIT
