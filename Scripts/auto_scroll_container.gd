@tool
class_name AutoScrollContainer
extends Container

enum SCROLL_MODE {NORMAL, REVERSE}
enum SCROLL_DIRECTION {VERTICAL, HORIZONTAL, BOTH}

@export_category("Scroll Configuration")
@export var scroll_direction: SCROLL_DIRECTION = SCROLL_DIRECTION.VERTICAL
@export var pause_on_mouse_hover: bool = true

@export_category("Speed Settings")
@export var min_scroll_speed: float = 12.0  # px/s
@export var max_scroll_speed: float = 40.0  # px/s
@export var target_cycle_time: float = 10.0 # total seconds
@export var reverse_duration: float = 0.5 # total seconds

@export_category("Margins")
@export var scroll_margin: float = 5.0 # margen extra para el scroll

@export_category("Delays")
@export var initial_delay: float = 2.0
@export var ping_pong_delay: float = 1.5

var autoscroll_enabled: bool = false
var has_auto_scroll_vertical: bool = false
var has_auto_scroll_horizontal: bool = false
var max_height: int = 0
var max_width: int = 0
var scroll_mode: SCROLL_MODE = SCROLL_MODE.NORMAL
var scroll_speed: float = 0.0
var reverse_scroll_speed: float = 0.0
var current_scroll_vertical: float = 0.0
var current_scroll_horizontal: float = 0.0
var delay_timer: float = 0.0
var is_waiting: bool = false
var initial_delay_finished: bool = false


func _ready() -> void:
	_setup_children()
	child_entered_tree.connect(_on_node_entered)
	child_exiting_tree.connect(_on_node_exited)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	gui_input.connect(_on_gui_input)
	item_rect_changed.connect(_try_enable_autoscroll)
	_try_enable_autoscroll()


func _on_mouse_entered() -> void:
	if pause_on_mouse_hover:
		autoscroll_enabled = false


func _on_mouse_exited() -> void:
	if (has_auto_scroll_vertical or has_auto_scroll_horizontal):
		autoscroll_enabled = true


func _on_node_entered(node: Node) -> void:
	node.set_meta("current_size", node.size)
	node.set_meta("current_size_flags", {"h": node.size_flags_horizontal, "v": node.size_flags_vertical})
	if not node.item_rect_changed.is_connected(_on_child_item_rect_changed):
		node.item_rect_changed.connect(_on_child_item_rect_changed.bind(node))
	_layout_children()
	_try_enable_autoscroll()


func _on_node_exited(_node: Node) -> void:
	_layout_children()
	_try_enable_autoscroll()


func _setup_children() -> void:
	for child in get_children():
		if child is Control:
			child.set_meta("current_size", child.size)
			child.set_meta("current_size_flags", {"h": child.size_flags_horizontal, "v": child.size_flags_vertical})
			child.item_rect_changed.connect(_on_child_item_rect_changed.bind(child))


func _on_child_item_rect_changed(node: Control) -> void:
	var size_changed = node.size != node.get_meta("current_size")
	var flags_changed = false
	
	if node.has_meta("current_size_flags"):
		var old_flags = node.get_meta("current_size_flags")
		flags_changed = old_flags.h != node.size_flags_horizontal or old_flags.v != node.size_flags_vertical
	
	if size_changed or flags_changed:
		node.set_meta("current_size", node.size)
		node.set_meta("current_size_flags", {"h": node.size_flags_horizontal, "v": node.size_flags_vertical})
		_layout_children()
		_try_enable_autoscroll()


func _notification(what: int) -> void:
	if what == NOTIFICATION_SORT_CHILDREN:
		_layout_children()


func _layout_children() -> void:
	var current_y: float = 0.0
	var current_x: float = 0.0
	
	for child in get_children():
		if child is Control:
			var base_pos = Vector2.ZERO
			
			# Posicionamiento horizontal basado en size_flags_horizontal
			if child.size_flags_horizontal & SIZE_FILL:
				child.size.x = size.x
				base_pos.x = 0
			elif child.size_flags_horizontal & SIZE_SHRINK_CENTER:
				base_pos.x = (size.x - child.size.x) / 2.0
			elif child.size_flags_horizontal & SIZE_SHRINK_END:
				base_pos.x = size.x - child.size.x
			else: # SHRINK_BEGIN o default
				base_pos.x = current_x
				if scroll_direction == SCROLL_DIRECTION.HORIZONTAL or scroll_direction == SCROLL_DIRECTION.BOTH:
					current_x += child.size.x
			
			# Posicionamiento vertical basado en size_flags_vertical
			if child.size_flags_vertical & SIZE_FILL:
				child.size.y = size.y
				base_pos.y = 0
			elif child.size_flags_vertical & SIZE_SHRINK_CENTER:
				base_pos.y = (size.y - child.size.y) / 2.0
			elif child.size_flags_vertical & SIZE_SHRINK_END:
				base_pos.y = size.y - child.size.y
			else: # SHRINK_BEGIN o default
				base_pos.y = current_y
				if scroll_direction == SCROLL_DIRECTION.VERTICAL or scroll_direction == SCROLL_DIRECTION.BOTH:
					current_y += child.size.y
			
			child.set_meta("base_position", base_pos)
			
			# Aplicar scroll actual
			var final_pos = base_pos
			if has_auto_scroll_vertical and (scroll_direction == SCROLL_DIRECTION.VERTICAL or scroll_direction == SCROLL_DIRECTION.BOTH):
				final_pos.y -= current_scroll_vertical
			if has_auto_scroll_horizontal and (scroll_direction == SCROLL_DIRECTION.HORIZONTAL or scroll_direction == SCROLL_DIRECTION.BOTH):
				final_pos.x -= current_scroll_horizontal
			
			child.position = final_pos


func _process(delta: float) -> void:
	var has_any_scroll = has_auto_scroll_vertical or has_auto_scroll_horizontal
	if has_any_scroll and autoscroll_enabled:
		var max_scroll_vertical = max_height - size.y
		var max_scroll_horizontal = max_width - size.x
		
		if is_waiting:
			delay_timer += delta
			var current_delay = initial_delay if not initial_delay_finished else ping_pong_delay
			
			if delay_timer >= current_delay:
				is_waiting = false
				delay_timer = 0.0
				if not initial_delay_finished:
					initial_delay_finished = true
			return
		
		if scroll_mode == SCROLL_MODE.NORMAL:
			# Scroll vertical
			if has_auto_scroll_vertical and (scroll_direction == SCROLL_DIRECTION.VERTICAL or scroll_direction == SCROLL_DIRECTION.BOTH):
				current_scroll_vertical += scroll_speed * delta
				if current_scroll_vertical >= max_scroll_vertical:
					current_scroll_vertical = max_scroll_vertical
			
			# Scroll horizontal
			if has_auto_scroll_horizontal and (scroll_direction == SCROLL_DIRECTION.HORIZONTAL or scroll_direction == SCROLL_DIRECTION.BOTH):
				current_scroll_horizontal += scroll_speed * delta
				if current_scroll_horizontal >= max_scroll_horizontal:
					current_scroll_horizontal = max_scroll_horizontal
			
			# Verificar si alguno llegó al final
			var vertical_at_end = !has_auto_scroll_vertical or (scroll_direction != SCROLL_DIRECTION.VERTICAL and scroll_direction != SCROLL_DIRECTION.BOTH) or current_scroll_vertical >= max_scroll_vertical
			var horizontal_at_end = !has_auto_scroll_horizontal or (scroll_direction != SCROLL_DIRECTION.HORIZONTAL and scroll_direction != SCROLL_DIRECTION.BOTH) or current_scroll_horizontal >= max_scroll_horizontal
			
			if vertical_at_end and horizontal_at_end:
				is_waiting = true
				scroll_mode = SCROLL_MODE.REVERSE
		else:
			# Scroll reverso vertical
			if has_auto_scroll_vertical and (scroll_direction == SCROLL_DIRECTION.VERTICAL or scroll_direction == SCROLL_DIRECTION.BOTH):
				current_scroll_vertical -= reverse_scroll_speed * delta
				if current_scroll_vertical <= 0:
					current_scroll_vertical = 0
			
			# Scroll reverso horizontal
			if has_auto_scroll_horizontal and (scroll_direction == SCROLL_DIRECTION.HORIZONTAL or scroll_direction == SCROLL_DIRECTION.BOTH):
				current_scroll_horizontal -= reverse_scroll_speed * delta
				if current_scroll_horizontal <= 0:
					current_scroll_horizontal = 0
			
			# Verificar si ambos llegaron al inicio
			var vertical_at_start = !has_auto_scroll_vertical or (scroll_direction != SCROLL_DIRECTION.VERTICAL and scroll_direction != SCROLL_DIRECTION.BOTH) or current_scroll_vertical <= 0
			var horizontal_at_start = !has_auto_scroll_horizontal or (scroll_direction != SCROLL_DIRECTION.HORIZONTAL and scroll_direction != SCROLL_DIRECTION.BOTH) or current_scroll_horizontal <= 0
			
			if vertical_at_start and horizontal_at_start:
				is_waiting = true
				scroll_mode = SCROLL_MODE.NORMAL
		
		_apply_scroll_to_children()


func _apply_scroll_to_children() -> void:
	for child in get_children():
		if child is Control and child.has_meta("base_position"):
			var base_pos = child.get_meta("base_position")
			var new_pos = base_pos
			
			if has_auto_scroll_vertical and (scroll_direction == SCROLL_DIRECTION.VERTICAL or scroll_direction == SCROLL_DIRECTION.BOTH):
				new_pos.y -= current_scroll_vertical
			
			if has_auto_scroll_horizontal and (scroll_direction == SCROLL_DIRECTION.HORIZONTAL or scroll_direction == SCROLL_DIRECTION.BOTH):
				new_pos.x -= current_scroll_horizontal
			
			child.position = new_pos


func _try_enable_autoscroll() -> void:
	var min_y: float = 0
	var max_y: float = 0
	var min_x: float = 0
	var max_x: float = 0
	
	for child in get_children():
		if child is Control and child.has_meta("base_position"):
			var base_pos = child.get_meta("base_position")
			var child_bottom = base_pos.y + child.size.y
			var child_right = base_pos.x + child.size.x
			max_y = max(max_y, child_bottom)
			min_y = min(min_y, base_pos.y)
			max_x = max(max_x, child_right)
			min_x = min(min_x, base_pos.x)
	
	var content_height = max_y - min_y
	var content_width = max_x - min_x
	
	var previous_has_auto_scroll_vertical = has_auto_scroll_vertical
	var previous_has_auto_scroll_horizontal = has_auto_scroll_horizontal
	
	has_auto_scroll_vertical = content_height > size.y
	has_auto_scroll_horizontal = content_width > size.x
	
	if has_auto_scroll_vertical:
		max_height = int(content_height + scroll_margin)
	else:
		max_height = int(content_height)
	
	if has_auto_scroll_horizontal:
		max_width = int(content_width + scroll_margin)
	else:
		max_width = int(content_width)
	
	var has_any_scroll = has_auto_scroll_vertical or has_auto_scroll_horizontal
	
	if not has_any_scroll:
		current_scroll_vertical = 0.0
		current_scroll_horizontal = 0.0
		scroll_mode = SCROLL_MODE.NORMAL
		is_waiting = false
		delay_timer = 0.0
		initial_delay_finished = false
		autoscroll_enabled = false
		_layout_children()
	elif (not previous_has_auto_scroll_vertical and has_auto_scroll_vertical) or (not previous_has_auto_scroll_horizontal and has_auto_scroll_horizontal):
		var overflow_vertical = max_height - size.y if has_auto_scroll_vertical else 0.0
		var overflow_horizontal = max_width - size.x if has_auto_scroll_horizontal else 0.0
		var max_overflow = max(overflow_vertical, overflow_horizontal)
		
		if max_overflow > 0:
			var speed = (max_overflow * 2) / target_cycle_time
			scroll_speed = clamp(speed, min_scroll_speed, max_scroll_speed)
			reverse_scroll_speed = max_overflow / reverse_duration
		else:
			scroll_speed = min_scroll_speed
			reverse_scroll_speed = min_scroll_speed
		
		current_scroll_vertical = 0.0
		current_scroll_horizontal = 0.0
		scroll_mode = SCROLL_MODE.NORMAL
		is_waiting = true
		delay_timer = 0.0
		initial_delay_finished = false
		autoscroll_enabled = true


func _on_gui_input(event: InputEvent) -> void:
	if not pause_on_mouse_hover:
		return
	
	var has_any_scroll = has_auto_scroll_vertical or has_auto_scroll_horizontal
	if has_any_scroll and event is InputEventMouseButton and event.is_pressed():
		# Para scroll horizontal, la rueda arriba/abajo hace scroll horizontal
		if scroll_direction == SCROLL_DIRECTION.HORIZONTAL:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				if has_auto_scroll_horizontal:
					current_scroll_horizontal = max(0, current_scroll_horizontal - 50)
				_apply_scroll_to_children()
				get_viewport().set_input_as_handled()
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				if has_auto_scroll_horizontal:
					var max_scroll = max_width - size.x
					current_scroll_horizontal = min(max_scroll, current_scroll_horizontal + 50)
				_apply_scroll_to_children()
				get_viewport().set_input_as_handled()
		else:
			# Para scroll vertical o ambos, comportamiento normal
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				if has_auto_scroll_vertical:
					current_scroll_vertical = max(0, current_scroll_vertical - 50)
				_apply_scroll_to_children()
				get_viewport().set_input_as_handled()
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				if has_auto_scroll_vertical:
					var max_scroll = max_height - size.y
					current_scroll_vertical = min(max_scroll, current_scroll_vertical + 50)
				_apply_scroll_to_children()
				get_viewport().set_input_as_handled()
			elif event.button_index == MOUSE_BUTTON_WHEEL_LEFT:
				if has_auto_scroll_horizontal:
					current_scroll_horizontal = max(0, current_scroll_horizontal - 50)
				_apply_scroll_to_children()
				get_viewport().set_input_as_handled()
			elif event.button_index == MOUSE_BUTTON_WHEEL_RIGHT:
				if has_auto_scroll_horizontal:
					var max_scroll = max_width - size.x
					current_scroll_horizontal = min(max_scroll, current_scroll_horizontal + 50)
				_apply_scroll_to_children()
				get_viewport().set_input_as_handled()


func toggle_autoscroll() -> void:
	autoscroll_enabled = !autoscroll_enabled


func set_scroll_speed(new_speed: float) -> void:
	scroll_speed = new_speed


func set_ping_pong_delay(new_delay: float) -> void:
	ping_pong_delay = new_delay


func set_initial_delay(new_delay: float) -> void:
	initial_delay = new_delay
