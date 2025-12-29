@tool
extends Control
class_name ImageButtonControl

class ButtonAnimator:
	var scale: float = 1.0
	var target_scale: float = 1.0
	var tween: Tween
	var control: Control
	
	func _init(parent_control: Control) -> void:
		control = parent_control
	
	func animate_to_scale(new_scale: float, duration: float = 0.2) -> void:
		if tween:
			tween.kill()
		
		target_scale = new_scale
		tween = control.create_tween()
		tween.tween_method(_update_scale, scale, target_scale, duration)
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_BACK)
	
	func _update_scale(new_scale: float) -> void:
		scale = new_scale
		control.queue_redraw()
	
	func get_scale() -> float:
		return scale


@export var images: Array[Dictionary] = []
@export var button_size: Vector2 = Vector2(100, 100) : set = _set_button_size
@export var vertical_separation: float = 10.0
@export var vertical_margin_top: float = 0.0 : set = _set_vertical_margin_top
@export var vertical_margin_bottom: float = 0.0 : set = _set_vertical_margin_bottom
@export var horizontal_margin_left: float = 0.0 : set = _set_horizontal_margin_left
@export var horizontal_margin_right: float = 0.0 : set = _set_horizontal_margin_right
@export var background_style: StyleBox : set = _set_background_style
@export var normal_style: StyleBox : set = _set_normal_style
@export var hover_style: StyleBox : set = _set_hover_style
@export var selected_style: StyleBox : set = _set_selected_style
@export var clicked_style: StyleBox : set = _set_clicked_style
@export var max_scale: float = 1.15
@export var scroll_container: ScrollContainer : set = _set_scroll_container
@export var scroll_offset: Vector2 = Vector2.ZERO : set = _set_scroll_offset

var buttons_data: Array = []
var button_animators: Array[ButtonAnimator] = []
var real_ids: PackedInt32Array = []
var selected_index: int = -1
var hovered_index: int = -1
var clicked_index: int = -1
var focus_control: Control
var is_fully_ready: bool = false

signal button_clicked(index: int)
signal button_selected(index: int)


func set_images(value: Array[Dictionary]) -> void:
	_set_images(value)


func set_real_ids(value: PackedInt32Array) -> void:
	real_ids = value


func add_image(texture: Dictionary) -> void:
	images.append(texture)
	_update_buttons()
	queue_redraw()


func remove_image(index: int) -> void:
	if index >= 0 and index < images.size():
		images.remove_at(index)
		
		if selected_index == index:
			selected_index = -1
		elif selected_index > index:
			selected_index -= 1
			
		if hovered_index == index:
			hovered_index = -1
		elif hovered_index > index:
			hovered_index -= 1
			
		_update_buttons()
		queue_redraw()


func clear_images() -> void:
	images.clear()
	selected_index = -1
	hovered_index = -1
	clicked_index = -1
	_update_buttons()
	queue_redraw()


func get_selected_index() -> int:
	return selected_index


func select_button_by_index(index: int, skip_animation: bool = false) -> void:
	selected_index = -1
	hovered_index = -1
	for i in real_ids.size():
		if real_ids[i] == index:
			index = i
			break
	
	if index >= 0 and index < buttons_data.size():
		_select_button(index, not skip_animation)


func grab_focus() -> void:
	if focus_control:
		focus_control.grab_focus()


func get_focus_control() -> Control:
	return focus_control


func _ready() -> void:
	mouse_entered.connect(_reset_hovered)
	mouse_exited.connect(_reset_hovered)
	_create_focus_control()
	
	
	mouse_filter = Control.MOUSE_FILTER_PASS
	call_deferred("_initialize_after_ready")


func _create_focus_control() -> void:
	focus_control = Control.new()
	focus_control.name = "FocusControl"
	focus_control.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	focus_control.size = Vector2.ZERO
	focus_control.focus_mode = Control.FOCUS_CLICK
	focus_control.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	focus_control.focus_entered.connect(_on_focus_entered)
	add_child(focus_control)


func _reset_hovered() -> void:
	if hovered_index != -1:
		hovered_index = -1
		queue_redraw()


func _draw() -> void:
	if background_style:
		background_style.draw(get_canvas_item(), Rect2(Vector2.ZERO, size))
	
	for i in range(buttons_data.size()):
		var button_data = buttons_data[i]
		_draw_button(i, button_data)


func _gui_input(event) -> void:
	mouse_default_cursor_shape = Control.CURSOR_ARROW
	if event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event)


func _set_images(value: Array[Dictionary]) -> void:
	images = value
	if is_inside_tree():
		_update_buttons()
		queue_redraw()


func _set_button_size(value: Vector2) -> void:
	button_size = value
	if is_inside_tree():
		_update_buttons()
		queue_redraw()


func _set_vertical_margin_top(value: float) -> void:
	vertical_margin_top = value
	if is_inside_tree():
		_calculate_button_positions()
		_calculate_minimum_size()
		queue_redraw()


func _set_vertical_margin_bottom(value: float) -> void:
	vertical_margin_bottom = value
	if is_inside_tree():
		_calculate_button_positions()
		_calculate_minimum_size()
		queue_redraw()


func _set_horizontal_margin_left(value: float) -> void:
	horizontal_margin_left = value
	if is_inside_tree():
		_calculate_button_positions()
		_calculate_minimum_size()
		queue_redraw()


func _set_horizontal_margin_right(value: float) -> void:
	horizontal_margin_right = value
	if is_inside_tree():
		_calculate_button_positions()
		_calculate_minimum_size()
		queue_redraw()


func _set_background_style(style: StyleBox) -> void:
	background_style = style
	if style and not style.changed.is_connected(queue_redraw):
		style.changed.connect(queue_redraw)
	_update_buttons()
	queue_redraw()


func _set_normal_style(style: StyleBox) -> void:
	normal_style = style
	if style and not style.changed.is_connected(queue_redraw):
		style.changed.connect(queue_redraw)
	queue_redraw()


func _set_hover_style(style: StyleBox) -> void:
	hover_style = style
	if style and not style.changed.is_connected(queue_redraw):
		style.changed.connect(queue_redraw)
	queue_redraw()


func _set_selected_style(style: StyleBox) -> void:
	selected_style = style
	if style and not style.changed.is_connected(queue_redraw):
		style.changed.connect(queue_redraw)
	queue_redraw()


func _set_clicked_style(style: StyleBox) -> void:
	clicked_style = style
	if style and not style.changed.is_connected(queue_redraw):
		style.changed.connect(queue_redraw)
	queue_redraw()


func _set_scroll_container(value: ScrollContainer) -> void:
	scroll_container = value
	if is_inside_tree():
		queue_redraw()


func _set_scroll_offset(value: Vector2) -> void:
	scroll_offset = value
	if is_inside_tree():
		queue_redraw()


func _initialize_after_ready() -> void:
	is_fully_ready = true
	_update_buttons()
	queue_redraw()


func _update_buttons() -> void:
	if images.is_empty():
		return
	
	buttons_data.clear()
	for animator in button_animators:
		if animator.tween:
			animator.tween.kill()
	button_animators.clear()
	
	for i in range(images.size()):
		var button_data = {
			"rect": Rect2(Vector2.ZERO, button_size),
			"image": images[i]
		}
		buttons_data.append(button_data)
		var animator = ButtonAnimator.new(self)
		button_animators.append(animator)
	
	_calculate_button_positions()
	_calculate_minimum_size()
	_update_focus_control_position()


func _calculate_button_positions() -> void:
	var margins = _get_background_margins()
	var y_offset = margins.top + vertical_margin_top
	var center_x = margins.left + horizontal_margin_left + (button_size.x / 2.0)
	
	for i in range(buttons_data.size()):
		buttons_data[i]["rect"].position = Vector2(center_x - button_size.x / 2.0, y_offset)
		buttons_data[i]["rect"].size = button_size
		y_offset += button_size.y + vertical_separation


func _calculate_minimum_size() -> void:
	if buttons_data.is_empty():
		custom_minimum_size = Vector2.ZERO
		position = Vector2.ZERO
		return
	
	var margins = _get_background_margins()
	var content_height = (button_size.y * buttons_data.size()) + (vertical_separation * (buttons_data.size() - 1))
	var content_width = button_size.x * max_scale
	var extra_space_vertical = (button_size.y * (max_scale - 1.0)) / 2.0
	
	custom_minimum_size = Vector2(
		content_width + margins.left + margins.right + horizontal_margin_left + horizontal_margin_right,
		content_height + margins.top + margins.bottom + vertical_margin_top + vertical_margin_bottom + (extra_space_vertical * 2.0)
	)
	position = Vector2.ZERO


func _get_accumulated_growth_until(index: int) -> float:
	var total_growth = 0.0
	for i in range(index):
		if i < button_animators.size():
			var _scale = button_animators[i].get_scale()
			total_growth += button_size.y * (_scale - 1.0)
	return total_growth


func _get_effective_offset() -> Vector2:
	var offset = Vector2.ZERO
	
	if scroll_container:
		var h_scrollbar_visible = scroll_container.is_h_scroll_visible()
		var v_scrollbar_visible = scroll_container.is_v_scroll_visible()
		
		if not h_scrollbar_visible and not v_scrollbar_visible:
			offset = scroll_offset
	
	return offset


func _draw_button(index: int, button_data: Dictionary) -> void:
	if Engine.is_editor_hint(): return
	var rect = button_data["rect"] as Rect2
	var image = button_data["image"] as Dictionary
	
	if index >= button_animators.size():
		return
	
	var animator = button_animators[index]
	var sc = animator.get_scale()
	
	var scaled_size = rect.size * sc
	var offset: Vector2
	var button_rect = rect
	
	# Apply scroll offset if scrollbars are not visible
	var effective_offset = _get_effective_offset()
	button_rect.position += effective_offset
	
	# Each button scales from its own top-center, and items below shift accordingly
	offset = Vector2((rect.size.x - scaled_size.x) * 0.5, 0)
	
	var accumulated_growth = _get_accumulated_growth_until(index)
	button_rect.position.y += accumulated_growth
	
	var scaled_rect = Rect2(button_rect.position + offset, scaled_size)
	
	var style: StyleBox
	if clicked_index == index and clicked_style:
		style = clicked_style
	elif selected_index == index and selected_style:
		style = selected_style
	elif hovered_index == index and hover_style:
		style = hover_style
	elif normal_style:
		style = normal_style
	
	if style:
		style.draw(get_canvas_item(), scaled_rect)
	
	var image_rect = scaled_rect
	if style:
		var content_margin_left = style.get_content_margin(SIDE_LEFT)
		var content_margin_top = style.get_content_margin(SIDE_TOP)
		var content_margin_right = style.get_content_margin(SIDE_RIGHT)
		var content_margin_bottom = style.get_content_margin(SIDE_BOTTOM)
		
		var margin_left = content_margin_left * sc
		var margin_top = content_margin_top * sc
		var margin_right = content_margin_right * sc
		var margin_bottom = content_margin_bottom * sc
		
		image_rect.position.x += margin_left
		image_rect.position.y += margin_top
		image_rect.size.x -= (margin_left + margin_right)
		image_rect.size.y -= (margin_top + margin_bottom)
		
		image_rect.size.x = max(image_rect.size.x, 0)
		image_rect.size.y = max(image_rect.size.y, 0)
	
	if image and image_rect.size.x > 0 and image_rect.size.y > 0:
		if image and image.texture:
			if not image.region:
				draw_texture_rect(image.texture, image_rect, false)
			else:
				draw_texture_rect_region(image.texture, image_rect, image.region)


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var index = _get_button_at_position(event.position)
			if index != -1:
				clicked_index = index
				_select_button(index, true)
				queue_redraw()
		else:
			if clicked_index != -1:
				if real_ids.size() > clicked_index:
					button_clicked.emit(real_ids[clicked_index])
				else:
					button_clicked.emit(clicked_index)
				clicked_index = -1
				queue_redraw()


func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	var index = _get_button_at_position(event.position)
	
	if index != hovered_index:
		hovered_index = index
		
	if index != -1:
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	else:
		mouse_default_cursor_shape = Control.CURSOR_ARROW
		hovered_index = -1
		
	queue_redraw()


func _get_button_at_position(pos: Vector2) -> int:
	var effective_offset = _get_effective_offset()
	
	for i in range(buttons_data.size()):
		var rect = buttons_data[i]["rect"]
		var animator = button_animators[i] if i < button_animators.size() else null
		
		if animator:
			var sc = animator.get_scale()
			var scaled_size = rect.size * sc
			var offset = Vector2((rect.size.x - scaled_size.x) * 0.5, 0)
			var accumulated_growth = _get_accumulated_growth_until(i)
			var adjusted_pos = rect.position + effective_offset + Vector2(0, accumulated_growth)
			var scaled_rect = Rect2(adjusted_pos + offset, scaled_size)
			
			if scaled_rect.has_point(pos):
				return i
		else:
			var adjusted_rect = rect
			adjusted_rect.position += effective_offset
			if adjusted_rect.has_point(pos):
				return i
	return -1


func _select_button(index: int, animate: bool = true) -> void:
	if selected_index == index:
		return
	
	var previous_index = selected_index
	selected_index = index
	
	if animate and button_animators.size() > 0 and is_fully_ready:
		_animate_button_scales(previous_index, index)
	else:
		_set_button_scales_directly(previous_index, index)
	
	_update_focus_control_position()
	
	if focus_control.has_focus():
		focus_control.release_focus()
	focus_control.grab_focus()
	
	if previous_index != selected_index and previous_index != -1:
		button_selected.emit(index)
	
	queue_redraw()


func select_last_button() -> void:
	var index = selected_index
	selected_index = -1
	_select_button(index)
	_config_hand()


func _set_button_scales_directly(previous_index: int, new_index: int) -> void:
	if previous_index != -1 and previous_index < button_animators.size():
		var previous_animator = button_animators[previous_index]
		previous_animator.scale = 1.0
	
	if new_index != -1 and new_index < button_animators.size():
		var new_animator = button_animators[new_index]
		new_animator.scale = max_scale
	
	queue_redraw()


func _animate_button_scales(previous_index: int, new_index: int) -> void:
	if previous_index != -1 and previous_index < button_animators.size():
		var previous_animator = button_animators[previous_index]
		previous_animator.animate_to_scale(1.0, 0.25)
	
	if new_index != -1 and new_index < button_animators.size():
		var new_animator = button_animators[new_index]
		new_animator.animate_to_scale(max_scale, 0.25)


func _update_focus_control_position() -> void:
	if not focus_control: return
	if selected_index != -1 and selected_index < buttons_data.size():
		var button_rect = buttons_data[selected_index]["rect"]
		var effective_offset = _get_effective_offset()
		
		if selected_index < button_animators.size():
			var animator = button_animators[selected_index]
			var sc = animator.get_scale()
			var scaled_size = button_rect.size * sc
			var offset = Vector2((button_rect.size.x - scaled_size.x) * 0.5, 0)
			var accumulated_growth = _get_accumulated_growth_until(selected_index)
			
			focus_control.position = button_rect.position + effective_offset + Vector2(0, accumulated_growth) + offset
			focus_control.size = scaled_size
		else:
			focus_control.position = button_rect.position + effective_offset
			focus_control.size = button_rect.size
		
		focus_control.visible = true
	else:
		focus_control.visible = false


func navigate_button(direction: int) -> void:
	if buttons_data.is_empty():
		return
	
	var old_index = selected_index
	var new_index = selected_index + direction
	
	if new_index < 0:
		new_index = buttons_data.size() - 1
	elif new_index >= buttons_data.size():
		new_index = 0
	
	if old_index != new_index and new_index >= 0:
		_select_button(new_index, true)
		if real_ids.size() > new_index:
			button_clicked.emit(real_ids[new_index])
		else:
			button_clicked.emit(new_index)


func _config_hand() -> void:
	var hand_manipulator = GameManager.MANIPULATOR_MODES.EQUIP_ACTORS_MENU
	GameManager.set_cursor_manipulator(hand_manipulator)
	var rect = %SmoothScrollContainer.get_global_rect()
	rect.size.x = 1200
	GameManager.set_confin_area(rect, hand_manipulator)
	GameManager.set_hand_position(MainHandCursor.HandPosition.RIGHT, hand_manipulator)
	GameManager.set_cursor_offset(Vector2(-2, 0), hand_manipulator)


func _on_focus_entered() -> void:
	if selected_index == -1 and not buttons_data.is_empty():
		_select_button(0, true)
	_config_hand()


func _get_background_margins() -> Dictionary:
	if not background_style:
		return {"left": 0, "top": 0, "right": 0, "bottom": 0}
	
	return {
		"left": background_style.get_content_margin(SIDE_LEFT),
		"top": background_style.get_content_margin(SIDE_TOP),
		"right": background_style.get_content_margin(SIDE_RIGHT),
		"bottom": background_style.get_content_margin(SIDE_BOTTOM)
	}


func _get_content_area() -> Rect2:
	var margins = _get_background_margins()
	var content_pos = Vector2(margins.left, margins.top)
	var content_size = Vector2(
		size.x - margins.left - margins.right,
		size.y - margins.top - margins.bottom
	)
	
	content_size.x = max(content_size.x, 0)
	content_size.y = max(content_size.y, 0)
	
	return Rect2(content_pos, content_size)
