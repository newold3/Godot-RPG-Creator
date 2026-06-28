extends TextureButton

@export var animation_direction: Vector2 = Vector2.ZERO


func _ready() -> void:
	pass


func _gui_input(event: InputEvent) -> void:
	if ControllerManager.is_confirm_pressed():
		_click()


func _click() -> void:
	var t = create_tween()
	t.tween_property(self, "offset_transform_position", animation_direction, 0.1)
	t.tween_property(self, "offset_transform_position", Vector2.ZERO, 0.2)
	pressed.emit()
