@tool
extends Resource
class_name EquipItemButtonGroup

var buttons: Array[EquipItemButton] = []

func add_button(button: EquipItemButton):
	if not buttons.has(button):
		buttons.append(button)
		if not button.toggled.is_connected(_on_button_toggled):
			button.toggled.connect(_on_button_toggled.bind(button))
		if not button.tree_exiting.is_connected(_on_button_tree_exiting):
			button.tree_exiting.connect(_on_button_tree_exiting.bind(button))


func get_buttons() -> Array[EquipItemButton]:
	return buttons


func get_selected_button() -> EquipItemButton:
	for button in buttons:
		if button.is_selected:
			return button
	
	return null


func remove_button(button: EquipItemButton):
	if buttons.has(button):
		buttons.erase(button)
		button.toggled.disconnect(_on_button_toggled.bind(button))


func _on_button_toggled(pressed: bool, toggled_button: EquipItemButton):
	if pressed:
		for button in buttons:
			if button != toggled_button:
				button.set_selected(false)


func _on_button_tree_exiting(button: EquipItemButton) -> void:
	buttons.erase(button)
