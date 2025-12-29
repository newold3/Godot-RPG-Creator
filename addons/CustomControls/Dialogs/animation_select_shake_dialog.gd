@tool
extends Window


var selected_index: int = -1
var shake: RPGAnimationShake
var busy: bool = false


signal value_changed(selected_index: int, shake: RPGAnimationShake)


func _ready() -> void:
	close_requested.connect(queue_free)


func set_data(_selected_index: int, _shake: RPGAnimationShake) -> void:
	selected_index = _selected_index
	shake = _shake.clone(true)
	%Frame.value = shake.frame
	%Duration.value = shake.duration
	%Target.select(shake.target)
	%Amplitude.value = shake.amplitude
	%Frequency.value = shake.frequency
	
	await get_tree().process_frame
	%Frame.get_line_edit().grab_focus()


func _on_ok_button_pressed() -> void:
	propagate_call("apply")
	value_changed.emit(selected_index, shake)
	queue_free()


func _on_cancel_button_pressed() -> void:
	queue_free()


func _on_frame_value_changed(value: float) -> void:
	shake.frame = value


func _on_duration_value_changed(value: float) -> void:
	shake.duration = value


func _on_target_item_selected(index: int) -> void:
	shake.target = index


func _on_amplitude_value_changed(value: float) -> void:
	shake.amplitude = value


func _on_frequency_value_changed(value: float) -> void:
	shake.frequency = value
