@tool
extends GuiCoreSaveLoadMenu

const PANEL_SCENE = preload("res://Scenes/GUI/BasicTheme/SaveLoad/panel_scene.tscn")


func _get_slot_scene() -> PackedScene:
	if slot_panel_scene:
		return slot_panel_scene
	return PANEL_SCENE
