@tool
extends Window


signal command_selected(enabled: bool, time: float)


func _ready() -> void:
	close_requested.connect(queue_free)


func set_data(enabled: bool, time: float) -> void:
	%NoWait.set_pressed(enabled)
	%Time.value = time
	%Time.set_disabled(!enabled)


func _on_ok_button_pressed() -> void:
	command_selected.emit(%NoWait.is_pressed(), %Time.value)
	queue_free()


func _on_cancel_button_pressed() -> void:
	queue_free()


func _on_no_wait_toggled(toggled_on: bool) -> void:
	%Time.set_disabled(!toggled_on)
