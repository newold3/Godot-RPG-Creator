@tool
extends Window

signal selected_value(value: float)


func _ready() -> void:
	close_requested.connect(queue_free)
	await get_tree().process_frame
	%ValueSpinBox.get_line_edit().select_all()
	%ValueSpinBox.get_line_edit().grab_focus()


func set_min_max_values(min_value: float, max_value: float, step: float = 1) -> void:
	%ValueSpinBox.step = step
	%ValueSpinBox.rounded = (step == 1)
	%ValueSpinBox.max_value = max_value
	%ValueSpinBox.min_value = min_value


func set_prefix(text: String) -> void:
	%Prefix.text = text


func set_suffix(text: String) -> void:
	%Suffix.text = text


func set_title_and_contents(t: String, c: String) -> void:
	title = t if t else tr("Number Input")
	%Contents.text = c if c else tr("Number:")


func set_value(value: float) -> void:
	%ValueSpinBox.value = value
	%ValueSpinBox.get_line_edit().select_all()


func _on_cancel_button_pressed() -> void:
	queue_free()


func _on_ok_button_pressed() -> void:
	%ValueSpinBox.apply()
	if %ValueSpinBox.rounded:
		selected_value.emit(%ValueSpinBox.value)
	else:
		selected_value.emit(snappedf(%ValueSpinBox.value, %ValueSpinBox.step))
	queue_free()
