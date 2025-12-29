@tool
extends Window


var selected_index: int = -1
var flash: RPGAnimationFlash
var busy: bool = false


signal value_changed(selected_index: int, flash: RPGAnimationFlash)


func _ready() -> void:
	close_requested.connect(queue_free)


func set_data(_selected_index: int, _flash: RPGAnimationFlash) -> void:
	selected_index = _selected_index
	flash = _flash.clone(true)
	%Frame.value = flash.frame
	%Duration.value = flash.duration
	%ColorPickerButton.set_pick_color(flash.color)
	%Target.select(flash.target)
	%BlendType.select(flash.screen_blend_type)
	%BlendType.set_disabled(flash.target == 0)
	
	await get_tree().process_frame
	%Frame.get_line_edit().grab_focus()


func _on_ok_button_pressed() -> void:
	propagate_call("apply")
	value_changed.emit(selected_index, flash)
	queue_free()


func _on_cancel_button_pressed() -> void:
	queue_free()


func _on_frame_value_changed(value: float) -> void:
	flash.frame = value


func _on_duration_value_changed(value: float) -> void:
	flash.duration = value


func _on_color_picker_button_color_changed(color: Color) -> void:
	flash.color = color


func _on_target_item_selected(index: int) -> void:
	flash.target = index
	%BlendType.set_disabled(index == 0)


func _on_blend_type_item_selected(index: int) -> void:
	flash.screen_blend_type = index
