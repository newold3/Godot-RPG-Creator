@tool
extends GuiCoreSaveSlotPanel

func _set_disabled_visual(disabled: bool) -> void:
	modulate = Color(0.5, 0.5, 0.5, 0.8) if disabled else Color(1.0, 1.0, 1.0, 1.0)


func _on_focus_entered_visual() -> void:
	var cur = get_cursor()
	if cur:
		cur.visible = true


func _on_focus_exited_visual() -> void:
	var cur = get_cursor()
	if cur:
		cur.visible = false
