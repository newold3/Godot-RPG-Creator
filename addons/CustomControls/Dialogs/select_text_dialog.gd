@tool
extends Window


var force_emit: bool = false

signal text_selected(text: String)


func _ready() -> void:
	close_requested.connect(queue_free)
	await get_tree().process_frame
	%Filename.grab_focus()


func set_text(text: String) -> void:
	%Filename.text = text


func _on_ok_button_pressed() -> void:
	if force_emit or %Filename.text.length() > 0:
		text_selected.emit(%Filename.text)
	queue_free()


func _on_cancel_button_pressed() -> void:
	queue_free()
