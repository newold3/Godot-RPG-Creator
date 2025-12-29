@tool
extends Resource
class_name ControlBaseItemGroup

## Base resource for converting any control into a list of toggled controls.
## The control must have the toggled signal and the set_selected method
## in order to be added as a valid button.

var buttons: Array[Control] = []


func add_button(button: Control):
	if button.has_signal("toggled") and button.has_method("set_selected"):
		if not buttons.has(button):
			buttons.append(button)
			button.toggled.connect(_on_button_toggled.bind(button))
			button.tree_exiting.connect(buttons.erase.bind(button))


func get_buttons() -> Array[Control]:
	return buttons


func remove_button(button: Control):
	if buttons.has(button):
		buttons.erase(button)
		button.toggled.disconnect(_on_button_toggled.bind(button))


func _on_button_toggled(pressed: bool, toggled_button: Control):
	if pressed:
		for button in buttons:
			if button != toggled_button:
				button.set_selected(false)
