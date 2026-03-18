@tool
extends Button

var locked: bool = false


func _on_lock_toggled(toggled_on: bool) -> void:
	locked = toggled_on

func is_locked() -> bool:
	return locked

func enable_part_installed(value: bool) -> void:
	%Partinstalled.visible = value
	var alpha = modulate.a
	if value:
		modulate = Color(0.952, 1.0, 0.938, 1.0)
	else:
		modulate = Color.WHITE
	modulate.a = alpha
