@tool
extends Window

signal OK(scenes: PackedFloat32Array)


func _ready() -> void:
	%SceneList.set_toggled_mode(true)
	%SceneList.get_item_list().mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_requested.connect(queue_free)
	fill_list()


func fill_list() -> void:
	var node = %SceneList
	node.clear()
	
	var items = RPGSYSTEM.database.system.game_scenes.keys()
	
	for item in items:
		var column = [item]
		node.add_column(column)


func _on_ok_button_pressed() -> void:
	var node = %SceneList
	var scene_ids = node.get_selected_items()
		
	if not scene_ids.is_empty():
		OK.emit(scene_ids)
	
	queue_free()


func _on_cancel_button_pressed() -> void:
	queue_free()


func _on_select_all_pressed() -> void:
	%SceneList.select_all()


func _on_select_none_pressed() -> void:
	%SceneList.deselect_all()
