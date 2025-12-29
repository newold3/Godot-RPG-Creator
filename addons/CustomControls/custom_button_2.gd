@tool
extends Button


signal middle_click_pressed()
signal right_click_pressed()

func _ready() -> void:
	gui_input.connect(_on_gui_input)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.is_pressed():
			if event.button_index == MOUSE_BUTTON_MIDDLE:
				middle_click_pressed.emit()
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				right_click_pressed.emit()
