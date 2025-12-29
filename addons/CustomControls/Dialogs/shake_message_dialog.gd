@tool
extends Window


signal command_changed(parameter: String)


func _ready() -> void:
	close_requested.connect(queue_free)


func set_data(magnitude: float = 1.1, frequency: float = 10, duration: float = 0.6, wait: bool = false) -> void:
	%ShakeMagnitude.value = magnitude
	%ShakeFrequency.value = frequency
	%ShakeDuration.value = duration
	%ShakeWaitToFinished.set_pressed(wait)


func _on_ok_button_pressed() -> void:
	propagate_call("apply")
	var command: String = "[dialog_shake magnitude=%s frequency=%s duration=%s wait=%s]" % [
		%ShakeMagnitude.value,
		%ShakeFrequency.value,
		%ShakeDuration.value,
		1 if %ShakeWaitToFinished.is_pressed() else 0
	]
	command_changed.emit(command)
	queue_free()


func _on_cancel_button_pressed() -> void:
	queue_free()
