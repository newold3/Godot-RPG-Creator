@tool
class_name CustomSimpleButton
extends Button


var tween: Tween
var last_state: bool

signal double_click()


func _ready() -> void:
	pivot_offset = size * 0.5
	last_state = disabled
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	item_rect_changed.connect(_on_item_rect_changed)
	gui_input.connect(_on_gui_input)


func _process(delta: float) -> void:
	if last_state != disabled:
		_set_disabled(disabled)
	
	if !disabled and modulate.a != 1.0:
		modulate.a = 1.0


func _on_mouse_entered() -> void:
	if disabled:
		return
		
	if tween:
		tween.kill()

	tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.025, 1.025), 0.15).set_trans(Tween.TRANS_SINE)


func _on_mouse_exited() -> void:
	if disabled and scale == Vector2.ONE:
		return
		
	if tween:
		tween.kill()
	
	tween = create_tween()
	tween.tween_property(self, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_SINE)


func _on_item_rect_changed() -> void:
	pivot_offset = size * 0.5


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.is_double_click():
				double_click.emit()


func _set_disabled(value: bool) -> void:
	modulate.a = 1.0 if !value else 0.65
	last_state = value
