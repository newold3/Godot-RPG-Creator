@tool
extends Control

var is_selected: bool = false
var mouse_hover: bool = false
var can_be_selected: bool = true
var color: Color :
	set(value):
		color = value
		queue_redraw()

var target: Variant


signal pressed(target: Variant)


func _ready() -> void:
	mouse_entered.connect(func(): mouse_hover = true; queue_redraw())
	mouse_exited.connect(func(): mouse_hover = false; queue_redraw())
	gui_input.connect(
		func(event: InputEvent):
			if event is InputEventMouseButton:
				if event.is_pressed():
					if event.button_index == MOUSE_BUTTON_LEFT:
						pressed.emit(target)
						if can_be_selected:
							is_selected = true
						queue_redraw()
	)


func deselect() -> void:
	is_selected = false
	queue_redraw()


func select(emit_signal: bool = false) -> void:
	is_selected = true
	if emit_signal:
		pressed.emit(target)
	queue_redraw()


func _draw() -> void:
	if mouse_hover:
		draw_rect(Rect2(0, 0, size.x, size.y), Color(0.263, 0.57, 0.864), false, 2, true)
		draw_rect(Rect2(2, 2, size.x - 4, size.y - 4), Color(0.097, 0.225, 0.443), false, 2, true)
	elif !is_selected:
		draw_rect(Rect2(0, 0, size.x, size.y), Color("#000000"), false, 2, true)
		draw_rect(Rect2(2, 2, size.x - 4, size.y - 4), Color(0.573, 0.573, 0.573), false, 2, true)
	else:
		draw_rect(Rect2(0, 0, size.x, size.y), Color(0.86, 0.395, 0.218), false, 2, true)
		draw_rect(Rect2(2, 2, size.x - 4, size.y - 4), Color(0.391, 0.149, 0.053), false, 2, true)
	draw_rect(Rect2(3, 3, size.x - 6, size.y - 6), color, true)
