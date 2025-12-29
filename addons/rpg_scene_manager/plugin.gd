@tool
extends EditorPlugin


var button: RPGSceneButton


func _enter_tree() -> void:
	var path = "res://addons/rpg_scene_manager/Scenes/rpg_scene_manager.tscn"
	button = load(path).instantiate()
	button.editor_interface = get_editor_interface()
	button.tooltip_text = "[title]Scene Manager[/title]\nDisplays a list with several options such as creating a new map, editing a map, editing one of the default scenes, etc."
	
	add_control_to_container(EditorPlugin.CONTAINER_CANVAS_EDITOR_MENU, button)
	CustomTooltipManager.plugin_replace_all_tooltips_with_custom(button)


func _exit_tree() -> void:
	if button:
		remove_control_from_container(EditorPlugin.CONTAINER_CANVAS_EDITOR_MENU, button)
		button.queue_free()
