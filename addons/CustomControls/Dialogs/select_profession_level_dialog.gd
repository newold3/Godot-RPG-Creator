@tool
extends Window


var data: RPGExtractionLevelComponent

signal data_changed(data: RPGExtractionLevelComponent)


func _ready() -> void:
	close_requested.connect(queue_free)


func set_data(p_data: RPGExtractionLevelComponent) -> void:
	data = p_data.clone(true)
	%LevelName.text = data.name
	%ExperienceToMasterize.value = data.experience_to_complete
	%MaxLevels.value = data.max_levels
	%LevelName.call_deferred("grab_focus")


func _on_cancel_button_pressed() -> void:
	queue_free()


func _on_ok_button_pressed() -> void:
	%ExperienceToMasterize.apply()
	%MaxLevels.apply()
	data_changed.emit(data)
	queue_free()


func _on_level_name_text_changed(new_text: String) -> void:
	data.name = new_text


func _on_experience_to_masterize_value_changed(value: float) -> void:
	data.experience_to_complete = value


func _on_max_levels_value_changed(value: float) -> void:
	data.max_levels = value
