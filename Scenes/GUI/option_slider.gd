@tool
class_name MagicSlide
extends Control


@export_category("Slider Style")
@export var slider_button_focused: Texture
@export var slider_button_no_focused: Texture
@export var slider_button_no_focused_hightlight: Texture
@export var slider_button_hightlight: Texture
@export var slider_panel: StyleBox
@export var slider_button_size: int
@export var slider_panel_height: int
@export var vertical_extra_margin: int
@export_category("Value Range")
@export var mod_value_curve: Curve
@export var step: float = 0.01
@export var key_step: float = 0.04
@export var current_value = 1.0
@export var focus_on_hover: bool = true

var main_tween: Tween

var is_dragging: bool = false
var last_relative = Vector2.ZERO

var reset_value: float

@onready var slide_button: Control = %SlideButton


signal changed(value: float)


func _ready() -> void:
	reset_value = current_value
	item_rect_changed.connect(
		func():
			queue_redraw()
			slide_button.queue_redraw()
	)
	mouse_entered.connect(_on_mouse_entered)
	slide_button.focus_entered.connect(func(): focus_entered.emit())
	slide_button.mouse_entered.connect(_on_mouse_entered)
	custom_minimum_size.y = max(slider_button_size, slider_button_size) + vertical_extra_margin * 2
	@warning_ignore("unsafe_property_access")
	size.y = custom_minimum_size.y
	slide_button.custom_minimum_size = Vector2(slider_button_size, slider_button_size)
	slide_button.size = slide_button.custom_minimum_size
	
	await get_tree().process_frame
	
	slide_button.pivot_offset = slide_button.size * 0.5
	_set_slide_button_position()


func _on_mouse_entered() -> void:
	if focus_on_hover:
		slide_button.grab_focus()


func set_value(value: float) -> void:
	if mod_value_curve:
		# Encontramos la posición en la curva usando búsqueda binaria
		current_value = find_position_binary(value)
		change_value(current_value, true)


func find_position_binary(target_value: float, tolerance: float = 0.001) -> float:
	var left := 0.0
	var right := 1.0
	
	# Limitamos el target_value al rango de la curva
	target_value = clamp(target_value, mod_value_curve.min_value, mod_value_curve.max_value)
	
	while right - left > tolerance:
		var mid := (left + right) / 2.0
		var sampled_value := mod_value_curve.sample(mid)
		
		if abs(sampled_value - target_value) < tolerance:
			return mid
		elif sampled_value < target_value:
			left = mid
		else:
			right = mid
	
	return (left + right) / 2.0


func select() -> void:
	slide_button.grab_focus()


func _input(event: InputEvent) -> void:
	if is_dragging and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		is_dragging = false
		
	var mouse_is_over = has_mouse_over()
	if not is_dragging and not mouse_is_over and not slide_button.has_focus(): return
	
	if GameManager.is_key_pressed(["ui_left", "ui_right"], true):
		var callable =  func():
			var direction = GameManager.get_last_key_pressed()
			match direction:
				"ui_left":
					change_value(-key_step)
				"ui_right":
					change_value(key_step)
		var action_name = GameManager.get_last_key_pressed()
		GameManager.add_key_callback(action_name, callable)
	
	if not mouse_is_over: return
	
	# Handle mouse input for dragging
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				select()
				# Start dragging
				is_dragging = true
				if not slide_button_has_mouse_over():
					_update_value_from_mouse_position(get_clamped_mouse_position(last_relative))
			else:
				# Stop dragging
				is_dragging = false
		elif event.button_index == MOUSE_BUTTON_MIDDLE and event.is_pressed():
			set_value(reset_value)
	
	if event is InputEventMouseMotion:
		last_relative = event.relative
		if is_dragging:
			_update_value_from_mouse_position(get_clamped_mouse_position(last_relative))


func get_clamped_mouse_position(relative: Vector2) -> Vector2:
	var pos = get_local_mouse_position()
	var real_pos = pos.clamp(Vector2.ZERO, size)
	if pos.x < 0 or pos.x > size.x: real_pos.x = clamp(pos.x + ceil(relative.x), 0, size.x)
	if pos.y < 0 or pos.y > size.y: real_pos.y = clamp(pos.y + ceil(relative.y), 0, size.y)
	
	return real_pos


func _update_value_from_mouse_position(mouse_pos: Vector2) -> void:
	# Calculate the percentage based on mouse x position within the control
	var percentage = clamp(mouse_pos.x / size.x, 0, 1)
	current_value = percentage
	
	var real_value: float
	if mod_value_curve:
		real_value = mod_value_curve.sample(current_value)
	changed.emit(real_value)
	_set_slide_button_position()
	if not slide_button.has_focus():
		slide_button.grab_focus()
	get_viewport().set_input_as_handled()


func change_value(amount: float, replace_value: bool = false) -> void:
	if replace_value:
		current_value = amount
	else:
		current_value = max(0, min(current_value + amount, 1.0))
	var real_value: float
	if mod_value_curve:
		real_value = mod_value_curve.sample(current_value)
	changed.emit(real_value)
	_set_slide_button_position()
	if not slide_button.has_focus():
		slide_button.grab_focus()
	get_viewport().set_input_as_handled()


func has_mouse_over() -> bool:
	if self_has_mouse_over() or slide_button_has_mouse_over(): return true
	
	return false


func self_has_mouse_over() -> bool:
	var pos = get_global_mouse_position()
	return get_global_rect().has_point(pos)


func slide_button_has_mouse_over() -> bool:
	var pos = get_global_mouse_position()
	return slide_button.get_global_rect().has_point(pos)


func _set_slide_button_position() -> void:
	# Button width is the same as control height
	var button_size = slider_button_size
	slide_button.min_texture_size_no_pressed = Vector2(slider_button_size, slider_button_size)
	slide_button.min_texture_size_pressed = Vector2(slider_button_size, slider_button_size)
	
	# Calculate button x position centered on the calculated point
	@warning_ignore("integer_division")
	var button_x = current_value * size.x - button_size / 2
	@warning_ignore("integer_division")
	var button_y = size.y / 2 - button_size / 2
	
	slide_button.position = Vector2(button_x, button_y)
	
	slide_button.queue_redraw()


func _draw() -> void:
	if slider_panel:
		@warning_ignore("integer_division")
		var y = size.y / 2 - slider_panel_height / 2
		draw_style_box(slider_panel, Rect2(Vector2(0, y), Vector2(size.x, slider_panel_height)))


func _on_slide_button_draw() -> void:
	pass
