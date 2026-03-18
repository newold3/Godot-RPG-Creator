@tool
class_name DigitButton
extends PanelContainer


var is_selected: bool = false


@export var id: int

@export var button_text: String:
	set(value):
		button_text = value
		if is_node_ready() and button_text_label:
			button_text_label.text = value

@export_range(0, 2500) var button_text_font_size: int = 0:
	set(value):
		button_text_font_size = value
		if is_node_ready() and button_text_font_size > 0:
			%ButtonTextLabel.set("theme_override_font_sizes/font_size", button_text_font_size)
		else:
			%ButtonTextLabel.set("theme_override_font_sizes/font_size", null)

@export var button_text_color: Color = Color.WHITE:
	set(value):
		button_text_color = value
		%ButtonTextLabel.set("theme_override_colors/font_color", button_text_color)


@export var repeat_pressed_enabled: bool = true


@export_group("Focusable Children")
@export var left_child: DigitButton
@export var right_child: DigitButton
@export var upper_child: DigitButton
@export var bottom_child: DigitButton


@onready var button_text_label: Label = %ButtonTextLabel
@onready var button: Button = %Button

var animator_tween: Tween

var process_delay: float = 0.0

var enabled: bool = true

var all_digits: Array = []


signal button_pressed(id: int)
signal back_pressed(id: int)
@warning_ignore("unused_signal")
signal left_pressed(id: int)
@warning_ignore("unused_signal")
signal right_pressed(id: int)
@warning_ignore("unused_signal")
signal up_pressed(id: int)
@warning_ignore("unused_signal")
signal down_pressed(id: int)
signal select_next_neighbor(id: int, direction: String)
signal select_child(node: DigitButton)


func _ready() -> void:
	pivot_offset = size * 0.5
	item_rect_changed.connect(
		func():
			pivot_offset = size * 0.5
	)
	focus_entered.connect(button.grab_focus)
	button_text_label.text = button_text
	button.focus_entered.connect(func(): focus_entered.emit(); is_selected = true)
	button.focus_exited.connect(func(): is_selected = false)
	button_pressed.connect(_animate_button.unbind(1))

	select_next_neighbor.connect(
		func(_x, _y):
			GameManager.remove_key_callback(get_instance_id())
			is_selected = false
			get_viewport().set_input_as_handled()
	)
	
	if button_text_font_size > 0:
		%ButtonTextLabel.set("theme_override_font_sizes/font_size", button_text_font_size)
	else:
		%ButtonTextLabel.set("theme_override_font_sizes/font_size", null)
		
	%ButtonTextLabel.set("theme_override_colors/font_color", button_text_color)
	
	focus_neighbor_left = str(left_child.get_path()) if left_child else ""
	focus_neighbor_top = str(upper_child.get_path()) if upper_child else ""
	focus_neighbor_right = str(right_child.get_path()) if right_child else ""
	focus_neighbor_bottom = str(bottom_child.get_path()) if bottom_child else ""


func select() -> void:
	process_delay = 0.02
	button.grab_focus()


func deselect() -> void:
	if has_focus():
		release_focus()
	elif button.has_focus():
		button.release_focus()
	
	is_selected = false


func _process(delta: float) -> void:
	if not is_selected or not button.has_focus() or not enabled:
		return
	
	if process_delay > 0.0:
		process_delay -= delta
		return
		
	# Check Direction Pressed
	var direction = ControllerManager.get_pressed_direction()
	if direction:
		var bind: Node = ControllerManager.get_closest_focusable_control(self, direction, true, all_digits)
		print(bind, all_digits)
		if bind is DigitButton:
			bind.select()
		elif bind is Button:
			button.grab_focus()
		
		process_delay = 0.05
	
	# Check Backspace Button Pressed
	elif ControllerManager.is_erase_letter_pressed():
		back_pressed.emit(id)
		if not repeat_pressed_enabled:
			ControllerManager.remove_erase_letter()
	
	# Check Select Button Pressed
	elif ControllerManager.is_confirm_pressed():
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			var focused_control = get_viewport().gui_get_focus_owner()
			if not focused_control or not focused_control.get_global_rect().has_point(get_global_mouse_position()):
				return
		button_pressed.emit(id)
		if not repeat_pressed_enabled:
			ControllerManager.remove_confirm()


func get_text() -> String:
	return button_text


func change_text_color(color: Color) -> void:
	%ButtonTextLabel.set("theme_override_colors/font_color", color)


func _emit_select_child_signal(node: DigitButton) -> void:
	if node:
		select_child.emit(node)


func _animate_button() -> void:
	if animator_tween:
		animator_tween.kill()
	
	animator_tween = create_tween()
	
	animator_tween.set_parallel(true)
	animator_tween.tween_property(self, "scale", Vector2(0.9,0.9), 0.1).from(Vector2.ONE)
	animator_tween.tween_property(self, "modulate", Color(0.63, 0.63, 0.63), 0.1).from(Color.WHITE)
	animator_tween.set_parallel(false)
	animator_tween.tween_interval(0.001)
	animator_tween.set_parallel(true)
	animator_tween.tween_property(self, "scale", Vector2.ONE, 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BOUNCE)
	animator_tween.tween_property(self, "modulate", Color.WHITE, 0.15)
