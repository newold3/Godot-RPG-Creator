@tool
extends Window

var result: bool = false

signal OK()


func _ready() -> void:
	close_requested.connect(queue_free)


func set_text(text: String) -> void:
	%MainLabel.text = text


func _on_ok_button_pressed() -> void:
	result = true
	OK.emit()
	queue_free()


func _on_cancel_button_pressed() -> void:
	result = false
	queue_free()
