extends Control

@export_category("Button Style")
@export var check_box_unselected: StyleBox
@export var check_box_unselected_hover: StyleBox
@export var check_box_selected: StyleBox
@export var check_box_selected_hover: StyleBox

var main_tween: Tween

var is_selected: bool = false

signal pressed()
signal selected()


func _ready() -> void:
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	gui_input.connect(_on_gui_input)
	focus_entered.connect(
		func():
			if main_tween:
				main_tween.kill()
				
			main_tween = create_tween()
			main_tween.tween_property(self, "scale", Vector2(1.1, 1.1), 0.1)
			main_tween.tween_property(self, "scale", Vector2.ONE, 0.2)
			
			selected.emit()
	)
	
	focus_neighbor_left = get_path()
	focus_neighbor_top = get_path()
	focus_neighbor_right = get_path()
	focus_neighbor_bottom = get_path()
	focus_next = get_path()
	focus_previous = get_path()
	
	await get_tree().process_frame
	pivot_offset = size * 0.5


func set_value(value: bool) -> void:
	set_pressed(value)


func select() -> void:
	grab_focus()


func _on_gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_select") or event.is_action_pressed("Mouse Left"):
		is_selected = !is_selected
		pressed.emit()
		queue_redraw()


func set_pressed(value: bool) -> void:
	is_selected = value
	queue_redraw()


func _draw() -> void:
	var rect = Rect2(Vector2.ZERO, size)
	if get_global_rect().has_point(get_global_mouse_position()):
		if is_selected:
			draw_style_box(check_box_selected_hover, rect)
		else:
			draw_style_box(check_box_unselected_hover, rect)
	else:
		if is_selected:
			draw_style_box(check_box_selected, rect)
		else:
			draw_style_box(check_box_unselected, rect)
