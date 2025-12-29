@tool
extends Window

signal message_selected(id: String, text: String)


func _ready() -> void:
	close_requested.connect(queue_free)
	await get_tree().process_frame
	%ID.grab_focus()


func _on_ok_button_pressed() -> void:
	message_selected.emit(%ID.text, %Text.text)
	queue_free()


func _on_cancel_button_pressed() -> void:
	queue_free()
