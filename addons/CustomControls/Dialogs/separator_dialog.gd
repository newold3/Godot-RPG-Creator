@tool
extends Window

var _show_text_color: bool = true
var _show_background_color: bool = true

signal data_changed(text: String, text_color: Color, background_color: Color)


func set_data(data: RPGSeparator, show_text_color: bool = true, show_background_color: bool = true) -> void:
	%Text.text = data.name
	%TextColor.color = data.text_color
	%BackgroundColor.color = data.background_color
	
	_show_text_color = show_text_color
	_show_background_color = show_background_color
	
	%TextColorContainer.visible = _show_text_color == true
	%TextBackgroundColorContainer.visible = _show_background_color == true
	
	size.y = 0
	
	%Text.grab_focus.call_deferred()


func _on_reset_text_color_pressed() -> void:
	%TextColor.color = Color.WHITE


func _on_reset_background_color_pressed() -> void:
	%BackgroundColor.color = Color("4e363eff")


func _on_ok_button_pressed() -> void:
	data_changed.emit(
		%Text.text,
		%TextColor.color,
		%BackgroundColor.color
	)
	queue_free()


func _on_cancel_button_pressed() -> void:
	queue_free()
