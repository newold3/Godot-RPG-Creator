@tool
extends PanelContainer


@export var button_size: Vector2 = Vector2(100, 100) : set = _set_button_size


signal button_clicked(index: int)
signal button_selected(index: int)


func _ready() -> void:
	%SmoothScrollContainer.single_target_focus = %ButtonsVerticalMenuContainer.get_focus_control()
	%ButtonsVerticalMenuContainer.button_clicked.connect(func(index): button_clicked.emit(index))
	%ButtonsVerticalMenuContainer.button_selected.connect(func(index): button_selected.emit(index))


func _set_button_size(value: Vector2) -> void:
	button_size = value
	if is_inside_tree():
		%ButtonsVerticalMenuContainer.button_size = button_size


func set_images(value: Array[Dictionary]) -> void:
	%ButtonsVerticalMenuContainer.set_images(value)


func set_real_ids(value: PackedInt32Array) -> void:
	%ButtonsVerticalMenuContainer.set_real_ids(value)


func select(id: int) -> void:
	%ButtonsVerticalMenuContainer.select_button_by_index(id)


func navigate_button(direction: int) -> void:
	%ButtonsVerticalMenuContainer.navigate_button(direction)
