@tool
extends Node


func _on_parent_visibility_changed() -> void:
	if Engine.is_editor_hint(): return
	
	if get_parent().visible:
		%TitleContainer.start()
		%MainMenuScene.restart()
		%BottomMainMenu.restart()


func destroy() -> void:
	GameManager.set_cursor_manipulator("")
	$"..".destroy()
