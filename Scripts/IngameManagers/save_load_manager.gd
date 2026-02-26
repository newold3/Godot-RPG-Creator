extends Node


func has_any_save_file() -> bool:
	return RPGSavedGameData.has_any_save_file()


func perform_auto_save() -> void:
	save_game(RPGSavedGameData.AUTO_SAVE_SLOT_ID)


func save_game(slot_id: int = 0) -> void:
	RPGSavedGameData.save_to_slot(
		slot_id,
		GameManager.game_state,
		GameManager.current_map,
		GameManager.get_main_scene_texture()
	)
	GameManager.current_save_slot = slot_id


func load_game(slot_id: int = 0) -> RPGSavedGameData:
	var game_data = RPGSavedGameData.load_from_slot(slot_id)
	if game_data:
		GameManager.current_save_slot = slot_id
	return game_data


func get_slot_preview_data(slot_id: int) -> RPGSavedGamePreview:
	return RPGSavedGameData.get_preview_data(slot_id)


func get_slot_image_path(slot_id: int) -> String:
	return RPGSavedGameData.get_image_path(slot_id)


func get_slot_save_date(slot_id: int) -> int:
	return RPGSavedGameData.get_save_date(slot_id)


func remove_game(slot_id: int = 0) -> void:
	RPGSavedGameData.delete_slot(slot_id)
