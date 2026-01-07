@tool
extends SpinBox


@export var disabled: bool = false :
	set(_value):
		disabled = _value
		set_disabled(_value)

## Replace the selected numbers with the specified text.
## key = Number to replace, Value = text to replace the value by
@export var value_replace: Dictionary = {}


var old_value: float
var dragging: bool = false
var warp_position: Vector2
var last_click: Vector2
var arrow_need_refresh_on_mouse_exit: bool = false
var drag_timer: Timer
var waiting_for_drag: bool = false
var initial_mouse_position: Vector2
var busy: bool = false
var _initialization_complete: bool = false

# This variable will store the real value, bypassing the initial clamping of the standard SpinBox.
# It is exposed to storage via _get_property_list but hidden from the inspector.
var _custom_value: float = 0.0

static var current_line_edit_selected

const SPINBOX_ARROWS_HOVER = preload("res://addons/CustomControls/Images/spinbox_arrows_hover.png")
const DRAG_CURSOR = preload("res://addons/CustomControls/Images/drag_cursor.png")

const INITIAL_DRAG_DELAY = 0.4
const FOCUSED_DRAG_DELAY = 0.15

static var _current_spinbox_focused: LineEdit

signal value_updated(old_value: float, new_value: float)
signal text_changed(text: String)


func _get_property_list() -> Array:
	return [
		{
			"name": "_custom_value",
			"type": TYPE_FLOAT,
			"usage": PROPERTY_USAGE_STORAGE
		}
	]


func _ready() -> void:
	# Temporarily allow any value to avoid clamping during initialization
	var _prev_greater = allow_greater
	var _prev_lesser = allow_lesser
	allow_greater = true
	allow_lesser = true
	
	# Apply the stored value cleanly
	value = _custom_value
	
	allow_greater = _prev_greater
	allow_lesser = _prev_lesser
	
	old_value = value
	
	var lineedit = get_line_edit()
	lineedit.set_script(load("res://addons/CustomControls/custom_line_edit.gd"))
	lineedit.focus_entered.connect(_on_line_edit_focus_entered)
	lineedit.focus_exited.connect(_on_line_edit_focus_exited)
	lineedit.text_changed.connect(func(text: String): text_changed.emit(text))
	value_changed.connect(_on_value_changed)
	
	drag_timer = Timer.new()
	drag_timer.wait_time = INITIAL_DRAG_DELAY
	drag_timer.one_shot = true
	drag_timer.timeout.connect(_on_drag_timer_timeout)
	add_child(drag_timer)
	
	if step == int(step):
		rounded = true
	else:
		rounded = false
	
	# Mark initialization as complete
	_initialization_complete = true
	
	changed.connect(_on_changed)
	
	# Initial text update
	_on_text_changed(lineedit.text)


func _on_changed() -> void:
	if step == int(step):
		rounded = true
	else:
		rounded = false


func grab_focus() -> void:
	if !is_editable() or disabled: return
	super()


func _physics_process(delta: float) -> void:
	var lineedit = get_line_edit()
	if not lineedit.has_focus():
		if not lineedit.get_selected_text().is_empty():
			lineedit.deselect()


func set_disabled(_value: bool) -> void:
	if disabled != _value:
		disabled = _value
		return
	set_editable(!_value)
	var lineedit = get_line_edit()
	if !_value:
		lineedit.set_text(prefix + str(value) + suffix)
		lineedit.set_selecting_enabled(true)
		set_process_input(true)
		lineedit.set_process_input(true)
		mouse_filter = Control.MOUSE_FILTER_STOP
		lineedit.mouse_filter = Control.MOUSE_FILTER_STOP
	else:
		lineedit.set_text("")
		lineedit.set_selecting_enabled(false)
		if lineedit.has_focus():
			lineedit.release_focus()
		set_process_input(false)
		lineedit.set_process_input(false)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		lineedit.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	if lineedit.get_script() != null and "set_disabled" in lineedit:
		lineedit.set_disabled(_value)
	else:
		lineedit.set_script(load("res://addons/CustomControls/custom_line_edit.gd"))
		lineedit.set_disabled(_value)
	
	if !_value:
		lineedit.set_text(prefix + str(value) + suffix)


func is_control_actually_visible() -> bool:
	if not visible or not is_inside_tree():
		return false
	
	var control_rect = get_global_rect()
	var viewport_rect = get_viewport().get_visible_rect()
	
	if not control_rect.intersects(viewport_rect):
		return false
	
	var current_node = get_parent()
	while current_node:
		if current_node is ScrollContainer:
			var scroll_container = current_node as ScrollContainer
			var scroll_rect = scroll_container.get_global_rect()
			
			if not control_rect.intersects(scroll_rect):
				return false
		elif current_node is Control:
			var control_parent = current_node as Control
			if control_parent.clip_contents:
				var parent_rect = control_parent.get_global_rect()
				if not control_rect.intersects(parent_rect):
					return false
		
		current_node = current_node.get_parent()
		if current_node is Window:
			break
	
	return true


func is_mouse_over_visible_control() -> bool:
	if not is_control_actually_visible():
		return false
	
	var mouse_pos = get_global_mouse_position()
	var control_rect = get_global_rect()
	
	if not control_rect.has_point(mouse_pos):
		return false
	
	var current_node = get_parent()
	while current_node:
		if current_node is ScrollContainer:
			var scroll_container = current_node as ScrollContainer
			var scroll_rect = scroll_container.get_global_rect()
			
			if not scroll_rect.has_point(mouse_pos):
				return false
		elif current_node is Control:
			var control_parent = current_node as Control
			if control_parent.clip_contents:
				var parent_rect = control_parent.get_global_rect()
				if not parent_rect.has_point(mouse_pos):
					return false
		
		current_node = current_node.get_parent()
		if current_node is Window:
			break
	
	return true


func _on_line_edit_focus_entered() -> void:
	if dragging or !is_editable() or disabled: return
	
	for i in 2:
		if is_inside_tree():
			await get_tree().process_frame
		else:
			return

	var line_edit = get_line_edit()
	line_edit.caret_column = line_edit.text.length()
	line_edit.call_deferred("select_all")
	_current_spinbox_focused = line_edit


func _on_line_edit_focus_exited() -> void:
	var line_edit = get_line_edit()
	if current_line_edit_selected == line_edit:
		current_line_edit_selected = null
	line_edit.deselect()
	call_deferred("_on_text_changed", line_edit.text)
	
	if _current_spinbox_focused == line_edit:
		_current_spinbox_focused = null


func _on_value_changed(new_value: float) -> void:
	if _initialization_complete and is_node_ready() and not RPGDialogFunctions.there_are_any_dialog_open():
		_custom_value = new_value
	
	var line_edit = get_line_edit()
	var is_focused = line_edit.has_focus()
	value_updated.emit(old_value, new_value)
	old_value = new_value
	var text: String
	if abs(step - int(step)) < 0.00001:
		text = str(int(value))
	else:
		text = str(value)
		
	line_edit.text = text
	
	if not RPGDialogFunctions.there_are_any_dialog_open():
		return
		
	if is_editable() and is_focused:
		_current_spinbox_focused = line_edit
		call_deferred("_line_edit_grab_focus")


func _line_edit_grab_focus() -> void:
	var line_edit = get_line_edit()
	if _current_spinbox_focused == line_edit and line_edit.editable:
		line_edit.grab_focus()


func _on_text_changed(text: String) -> void:
	if busy: return
	busy = true
	var line_edit = get_line_edit()
	for key in value_replace.keys():
		if str(key) == text:
			# Safety await for text replacements
			for i in 3:
				if is_inside_tree():
					await get_tree().process_frame
				else:
					return
			if is_instance_valid(self) and is_inside_tree():
				line_edit.text = prefix + str(value_replace[key]) + suffix
			break
	
	busy = false


func parent_is_invisible(node: Node) -> bool:
	var parent = node.get_parent()
	if parent:
		if not parent.is_visible():
			return true
		else:
			return parent_is_invisible(parent)
	
	return false


func _input(event: InputEvent) -> void:
	if !visible or !is_editable() or disabled or not is_inside_tree() or parent_is_invisible(self): return
	
	var action = is_mouse_over_visible_control()
	
	if !dragging and !waiting_for_drag and !action:
		queue_redraw()
		return
	
	if event is InputEventMouseMotion:
		if dragging:
			var p = sign(get_global_mouse_position().x - last_click.x)
			var v = 1 * p
			value += step * v
			Input.warp_mouse(warp_position)
			last_click = warp_position
			get_viewport().set_input_as_handled()
		elif waiting_for_drag:
			var mouse_moved_distance = get_global_mouse_position().distance_squared_to(initial_mouse_position)
			if mouse_moved_distance > 25.0:
				_start_dragging()
		elif action and get_local_mouse_position().x > size.x - SPINBOX_ARROWS_HOVER.get_width():
			queue_redraw()
		elif arrow_need_refresh_on_mouse_exit:
			queue_redraw()
			arrow_need_refresh_on_mouse_exit = false
			
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if action and event.is_pressed():
				_handle_mouse_press()
			elif event.is_released():
				_handle_mouse_release()
		elif dragging or waiting_for_drag:
			_cancel_drag()


func _handle_mouse_press() -> void:
	var p1 = get_global_mouse_position()
	var p2 = global_position.x + size.x
	
	if p1.x >= p2 - SPINBOX_ARROWS_HOVER.get_width():
		return
	
	initial_mouse_position = p1
	var line_edit = get_line_edit()
	var was_focused = line_edit.has_focus()
	
	if not was_focused:
		current_line_edit_selected = line_edit
		gain_focus()
		get_viewport().set_input_as_handled()
		
		drag_timer.wait_time = INITIAL_DRAG_DELAY
		drag_timer.start()
		waiting_for_drag = true
		warp_position = p1
	else:
		drag_timer.wait_time = FOCUSED_DRAG_DELAY
		drag_timer.start()
		waiting_for_drag = true
		warp_position = p1


func _handle_mouse_release() -> void:
	if waiting_for_drag:
		drag_timer.stop()
		waiting_for_drag = false
	elif dragging:
		_stop_dragging()


func _on_drag_timer_timeout() -> void:
	if waiting_for_drag and Input.is_action_pressed("Mouse Left"):
		_start_dragging()
	else:
		waiting_for_drag = false


func _start_dragging() -> void:
	if not is_control_actually_visible():
		_cancel_drag()
		return
	
	waiting_for_drag = false
	dragging = true
	DisplayServer.mouse_set_mode(DisplayServer.MOUSE_MODE_CONFINED_HIDDEN)
	last_click = warp_position
	CustomTooltipManager.set_no_tooltips(true)


func _stop_dragging() -> void:
	if dragging:
		DisplayServer.mouse_set_mode(DisplayServer.MOUSE_MODE_VISIBLE)
		Input.warp_mouse(warp_position)
		CustomTooltipManager.set_no_tooltips(false)
		dragging = false
		gain_focus()


func _cancel_drag() -> void:
	if drag_timer:
		drag_timer.stop()
	waiting_for_drag = false
	if dragging:
		_stop_dragging()


func _check_for_start_dragging(_warp_position: Vector2) -> void:
	pass


func gain_focus(repeats: int = 3) -> void:
	if dragging or !is_editable() or disabled: return
	
	await get_tree().process_frame
	var lineedit: LineEdit = get_line_edit()
	lineedit.grab_focus()
	lineedit.call_deferred("select_all")
	if repeats > 0:
		gain_focus(repeats - 1)


func _draw() -> void:
	if dragging or !is_editable() or disabled: return
	
	if not is_mouse_over_visible_control():
		mouse_default_cursor_shape = Control.CURSOR_ARROW
		return
	
	var p1 = get_global_mouse_position()
	var p2 = global_position.x + size.x
	
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if p1.x > p2 - SPINBOX_ARROWS_HOVER.get_width():
		var s = SPINBOX_ARROWS_HOVER.get_size()
		var x = size.x - s.x
		var dest_rect: Rect2
		var src_rect: Rect2
		if get_local_mouse_position().y < size.y / 2:
			dest_rect = Rect2(x, size.y / 2 - s.y / 2 - 1, s.x, s.y / 2)
			src_rect = Rect2(0, 0, s.x, s.y / 2)
		else:
			dest_rect = Rect2(x, size.y / 2, s.x, s.y / 2)
			src_rect = Rect2(0, s.y / 2, s.x, s.y / 2)
		draw_texture_rect_region(SPINBOX_ARROWS_HOVER, dest_rect, src_rect)
		arrow_need_refresh_on_mouse_exit = true
	else:
		mouse_default_cursor_shape = Control.CURSOR_IBEAM
