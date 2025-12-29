@tool
extends Container
class_name StaggeredButtonContainer

## Left margin for all buttons
@export var margin_left: int = 11 : set = set_margin_left
## Vertical separation between buttons
@export var vertical_separation: int = 8 : set = set_vertical_separation
## Curve to define horizontal position distribution
@export var horizontal_curve: Curve = preload("res://Assets/Resourcers/CustomResources/staggered_container_default_curve.tres") : set = set_horizontal_curve
## If there is no defined curve, the value of this variable will be used to calculate the horizontal offset of the buttons.
@export var horizontal_offset_fallback: int = 15 : set = set_horizontal_offset_fallback
## Height of the background stylebox
@export var stylebox_height: float = 3.0 : set = set_stylebox_height
## Background stylebox to draw behind buttons
@export var background_stylebox: StyleBox = preload("res://Assets/Resourcers/CustomResources/staggered_container_line.tres") : set = set_background_stylebox
## Delay between each button animation
@export_range(0.0, 2.0, 0.001) var animation_delay: float = 0.025 : set = set_animation_delay
## Duration of each button animation
@export_range(0.0, 5.0, 0.001) var animation_duration: float = 0.3 : set = set_animation_duration
## Invert animation order (top to bottom instead of bottom to top)
@export var invert_animation: bool = false : set = set_invert_animation
## Preview start animation
@export var preview_start: bool = false : set = set_preview_start
## Preview end animation
@export var preview_end: bool = false : set = set_preview_end

## Array of visible button controls in the container
var buttons: Array[Control] = []
## Final positions for buttons in staggered formation
var target_positions: Array[Vector2] = []
## Initial positions for buttons (x=0, correct y)
var initial_positions: Array[Vector2] = []
## Flag to prevent overlapping animations
var is_animating: bool = false

## Tween used to animation
var main_tween: Tween

## Signal emitted when all buttons complete their animation.
signal animation_completed(animation_type: String)


## Initialize container and connect child signals
func _init():
	child_entered_tree.connect(_on_child_added)
	child_exiting_tree.connect(_on_child_removed)


## Setup initial button positions when container is ready
func _ready():
	if horizontal_curve: horizontal_curve.setup_local_to_scene()
	_update_buttons_list()
	_calculate_positions()
	_set_buttons_to_initial_positions()


## Called when a child is added to the container
func _on_child_added(child: Node):
	if child is Control:
		_update_buttons_list()
		_calculate_positions()
		_set_buttons_to_initial_positions()
		queue_redraw()


## Called when a child is removed from the container
func _on_child_removed(child: Node):
	if child is Control:
		_update_buttons_list()
		_calculate_positions()
		_set_buttons_to_initial_positions()
		queue_redraw()


## Update the list of visible button controls
func _update_buttons_list():
	buttons.clear()
	for child in get_children():
		if child is Control and child.visible:
			buttons.append(child)


## Set left margin and recalculate positions
func set_margin_left(value: float) -> void:
	margin_left = value
	_calculate_positions()
	_set_buttons_to_initial_positions()
	queue_redraw()


## Set vertical separation and recalculate positions
func set_vertical_separation(value: float):
	vertical_separation = value
	_calculate_positions()
	_set_buttons_to_initial_positions()
	queue_redraw()


## Set horizontal curve and recalculate positions
func set_horizontal_curve(value: Curve):
	horizontal_curve = value
	if horizontal_curve and not horizontal_curve.changed.is_connected(_on_curve_changed):
		horizontal_curve.changed.connect(_on_curve_changed)
	_calculate_positions()
	_set_buttons_to_initial_positions()
	queue_redraw()


## Called when the curve is modified
func _on_curve_changed():
	_calculate_positions()
	_set_buttons_to_initial_positions()
	queue_redraw()


## Set horizontal offset fallback and recalculate positions
func set_horizontal_offset_fallback(value: int) -> void:
	horizontal_offset_fallback = value
	_calculate_positions()
	_set_buttons_to_initial_positions()
	queue_redraw()


## Set stylebox height and redraw
func set_stylebox_height(value: float):
	stylebox_height = value
	queue_redraw()


## Set animation delay
func set_animation_delay(value: float):
	animation_delay = value


## Set animation duration
func set_animation_duration(value: float):
	animation_duration = value


## Set background stylebox and redraw
func set_background_stylebox(value: StyleBox):
	background_stylebox = value
	queue_redraw()


## Set animation inversion
func set_invert_animation(value: bool):
	invert_animation = value


## Preview start animation
func set_preview_start(value: bool):
	if value and not is_animating:
		_set_buttons_to_initial_positions()
		start()
	preview_start = false


## Preview end animation
func set_preview_end(value: bool):
	if value and not is_animating:
		_set_buttons_to_target_positions()
		end()
	preview_end = false


## Calculate both initial and target positions for all buttons
func _calculate_positions():
	if buttons.is_empty():
		return
	
	var container_size = get_rect().size
	if container_size == Vector2.ZERO:
		container_size = _get_minimum_size()
	
	var min_size = _get_minimum_size()
	custom_minimum_size = min_size
	container_size = min_size
	
	target_positions.clear()
	initial_positions.clear()
	var accumulated_height = 0.0
	
	for i in range(buttons.size()):
		var button = buttons[i]
		if not button.item_rect_changed.is_connected(queue_redraw):
			button.item_rect_changed.connect(queue_redraw)
		var button_size = button.get_combined_minimum_size()
		
		var y_pos = container_size.y - accumulated_height - button_size.y
		accumulated_height += button_size.y + vertical_separation
		
		var target_x = margin_left
		if horizontal_curve and buttons.size() > 1:
			var t = float(i) / float(buttons.size() - 1)
			var offset = horizontal_curve.sample(t)
			target_x += i * offset
		elif horizontal_curve:
			var offset = horizontal_curve.sample(0.0)
			target_x += i * offset
		else:
			target_x += i * horizontal_offset_fallback
		
		var initial_x = 0
		
		target_positions.append(Vector2(target_x, y_pos))
		initial_positions.append(Vector2(initial_x, y_pos))
		button.size = button_size


## Set buttons to their initial positions (x=0, correct y)
func _set_buttons_to_initial_positions():
	for i in range(buttons.size()):
		buttons[i].position = initial_positions[i]


## Set buttons to their target positions (staggered formation)
func _set_buttons_to_target_positions():
	for i in range(buttons.size()):
		if i < target_positions.size():
			buttons[i].position = target_positions[i]


func restart() -> void:
	is_animating = false
	_set_buttons_to_initial_positions()
	start()


## Animate buttons to their target positions
func start():
	if is_animating or buttons.is_empty():
		return
		
	is_animating = true
	
	var animation_order = range(buttons.size())
	if invert_animation:
		animation_order.reverse()
	
	
	if main_tween:
		main_tween.kill()
	
	main_tween = create_tween()
	main_tween.set_speed_scale(1.5)
	main_tween.set_parallel(true)
	
	for i in animation_order:
		var button = buttons[i]
		var target_pos = target_positions[i]
		var delay_index = animation_order.find(i)
		var delay = delay_index * animation_delay
		
		button.set_meta("original_position", target_pos)
		
		main_tween.tween_property(button, "position", target_pos, animation_duration).set_delay(delay)
		
		if i == animation_order[-1]:
			main_tween.tween_interval(0.00001)
			main_tween.set_parallel(false)
			main_tween.tween_callback(_on_animation_finished.bind("start"))


## Animate buttons back to their initial positions
func end():
	if is_animating or buttons.is_empty():
		return
		
	is_animating = true
	
	var animation_order = range(buttons.size())
	if invert_animation:
		animation_order.reverse()
	
	for i in animation_order:
		var button = buttons[i]
		var initial_pos = initial_positions[i]
		var delay_index = animation_order.find(i)
		var delay = delay_index * animation_delay
		
		var tween = create_tween()
		tween.tween_interval(delay)
		tween.tween_property(button, "position", initial_pos, animation_duration)
		
		# Solo el último botón en terminar su animación emite la señal
		if delay_index == animation_order.size() - 1:
			tween.tween_callback(_on_animation_finished.bind("end"))


## Called when the animation finishes completely
func _on_animation_finished(animation_type: String):
	is_animating = false
	animation_completed.emit(animation_type)


## Calculate minimum size needed to contain all buttons
func _get_minimum_size() -> Vector2:
	if buttons.is_empty():
		return Vector2.ZERO
	
	var min_width: float = 0
	var min_height: float = 0
	
	for i in range(buttons.size()):
		var button = buttons[i]
		var button_size = button.get_combined_minimum_size()
		
		var button_x = margin_left
		if horizontal_curve and buttons.size() > 1:
			var t = float(i) / float(buttons.size() - 1)
			var offset = horizontal_curve.sample(t)
			button_x += i * offset
		elif horizontal_curve:
			var offset = horizontal_curve.sample(0.0)
			button_x += i * offset
		
		var button_right = button_x + button_size.x
		min_width = max(min_width, button_right)
		
		min_height += button_size.y
		if i < buttons.size() - 1:
			min_height += vertical_separation
	
	return Vector2(min_width, min_height)


## Handle container notifications
func _notification(what: int):
	match what:
		NOTIFICATION_RESIZED:
			_calculate_positions()
			_set_buttons_to_initial_positions()
		NOTIFICATION_SORT_CHILDREN:
			_update_buttons_list()
			_calculate_positions()
			_set_buttons_to_initial_positions()
		NOTIFICATION_DRAW:
			_draw_styleboxes()


## Draw background styleboxes for each button
## Draw background styleboxes for each button
func _draw_styleboxes():
	if not background_stylebox or buttons.is_empty() or target_positions.is_empty():
		return
	
	for i in range(min(buttons.size(), target_positions.size())):
		var button = buttons[i]
		if not button.visible:
			continue
		
		var target_pos = target_positions[i]
		var button_size = button.size
		
		var content_top = target_pos.y
		var content_height = button_size.y
		var content_center_y = content_top + content_height * 0.5
		
		var stylebox_y = content_center_y - stylebox_height * 0.5
		
		# Stylebox desde la posición actual del botón hasta el centro del botón
		var stylebox_width = button.position.x + button_size.x * 0.5
		
		var stylebox_rect = Rect2(
			0, 
			stylebox_y, 
			stylebox_width, 
			stylebox_height
		)
		
		background_stylebox.draw(get_canvas_item(), stylebox_rect)
		
		# Stylebox desde la parte derecha del control hasta el lado derecho de la pantalla
		var viewport_size = get_viewport_rect().size
		var extended_stylebox_width = viewport_size.x - (button.position.x + button_size.x * 0.5)
		
		var extended_stylebox_rect = Rect2(
			button.position.x + button_size.x * 0.5,
			stylebox_y,
			extended_stylebox_width,
			stylebox_height
		)
		
		background_stylebox.draw(get_canvas_item(), extended_stylebox_rect)


## Add a button control to the container
func add_button(button: Control):
	add_child(button)


## Get a copy of all button controls
func get_buttons() -> Array[Control]:
	return buttons.duplicate()


## Override to prevent base container interference
func _gui_input(_event: InputEvent):
	pass


## Override to prevent base container interference
func fit_child_in_rect(_child: Control, _rect: Rect2):
	pass
