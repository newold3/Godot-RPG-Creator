extends TextureButton

@export var animation_direction: Vector2 = Vector2.ZERO


func _ready() -> void:
	modulate.a = 0.5 if disabled else 1.0


func _process(_delta: float) -> void:
	var target_alpha = 0.5 if disabled else 1.0
	if modulate.a != target_alpha:
		modulate.a = target_alpha


func _gui_input(event: InputEvent) -> void:
	if disabled: return
	if ControllerManager.is_confirm_pressed():
		_click()


func _click() -> void:
	if disabled: return
	var t = create_tween()
	t.tween_property(self, "offset_transform_position", animation_direction, 0.1)
	t.tween_property(self, "offset_transform_position", Vector2.ZERO, 0.2)
	pressed.emit()
