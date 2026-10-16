@tool
extends GuiCoreSaveLoadMenu

const PANEL_SCENE = preload("res://Scenes/GUI/SteamPunkTheme/SaveLoad/panel_scene.tscn")


func _get_slot_scene() -> PackedScene:
	if slot_panel_scene:
		return slot_panel_scene
	return PANEL_SCENE


func _config_hand_in_slot() -> void:
	var manipulator = GameManager.MANIPULATOR_MODES.SAVELOAD
	GameManager.set_cursor_manipulator(manipulator)
	GameManager.set_hand_position(MainHandCursor.HandPosition.LEFT, manipulator)
	GameManager.set_cursor_offset(Vector2(48, 2), manipulator)
	var scr = get_scroll_container()
	if scr and scr is Control:
		GameManager.set_confin_area(scr.get_global_rect(), manipulator)
	GameManager.force_show_cursor()


func _config_hand_in_back_button() -> void:
	var manipulator = GameManager.MANIPULATOR_MODES.SAVELOAD
	GameManager.set_cursor_manipulator(manipulator)
	GameManager.set_hand_position(MainHandCursor.HandPosition.UP, manipulator)
	GameManager.set_cursor_offset(Vector2(0, 2), manipulator)
	GameManager.set_confin_area(Rect2(), manipulator)
	GameManager.force_show_cursor()
	GameManager.force_hand_position_over_node(manipulator)
