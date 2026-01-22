@tool
extends Button

var locked: bool = false


func _on_lock_toggled(toggled_on: bool) -> void:
	locked = toggled_on

func is_locked() -> bool:
	return locked
