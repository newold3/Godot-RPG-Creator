@tool
class_name SmoothScrollContainer
extends ScrollContainer

@export var scroll_duration: float = 0.25
@export var curve: Curve = preload("res://addons/CustomControls/Resources/Curves/default_smooth_curve.tres")
@export var single_target_focus: Control = null
@export var wheel_scroll_speed: float = 30.0
@export var focus_scroll_offset: Vector2 = Vector2(0, 64)
@export var instant_scroll_duration: float = 0.1

# Vertical Scrollbar Customization
@export_group("Custom Vertical Scrollbar")
@export var custom_vertical_bar_z_index: int = 0
@export var use_custom_vertical_scroll: bool = false:
	set(value):
		use_custom_vertical_scroll = value
		if is_node_ready():
			_initialize_proxy_bars()
		notify_property_list_changed()

@export var custom_vscroll_size: Vector2 = Vector2(12, 200) : set = _set_custom_vscroll_size
@export var custom_vscroll_offset: Vector2 = Vector2(0, 0) : set = _set_custom_vscroll_offset

# Horizontal Scrollbar Customization
@export_group("Custom Horizontal Scrollbar")
@export var custom_horizontal_bar_z_index: int = 0
@export var use_custom_horizontal_scroll: bool = false:
	set(value):
		use_custom_horizontal_scroll = value
		if is_node_ready():
			_initialize_proxy_bars()
		notify_property_list_changed()

@export var custom_hscroll_size: Vector2 = Vector2(200, 12) : set = _set_custom_hscroll_size
@export var custom_hscroll_offset: Vector2 = Vector2(0, 0) : set = _set_custom_hscroll_offset

var busy: bool = false
var elapsed_time: float = 0.0
var is_animating: bool = false
var dragging_middle_mouse: bool = false
var current_position: Vector2 = Vector2.ZERO
var target_position: Vector2 = Vector2.ZERO
var movement_enabled: bool = true
var saved_position: Vector2

var custom_bars_container: Control
var custom_vbar: VScrollBar
var custom_hbar: HScrollBar

@onready var child = get_child(0) if get_child_count() > 0 else null


func _ready() -> void:
	# Desactivar follow_focus nativo para manejarlo manualmente
	#follow_focus = false
	
	if child:
		child.item_rect_changed.connect(_on_child_item_rect_changed)
		var vscroll = get_v_scroll_bar()
		var hscroll = get_h_scroll_bar()
		vscroll.scrolling.connect(_on_scrollbar_scrolled)
		vscroll.value_changed.connect(_on_scrollbar_changed)
		vscroll.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		vscroll.z_index = custom_vertical_bar_z_index
		vscroll.draw.connect(_on_scrollbar_scrolled)
		if use_custom_vertical_scroll:
			vscroll.modulate.a = 0.0
			vscroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hscroll.scrolling.connect(_on_scrollbar_scrolled)
		hscroll.value_changed.connect(_on_scrollbar_changed)
		hscroll.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		hscroll.z_index = custom_horizontal_bar_z_index
		hscroll.draw.connect(_on_scrollbar_scrolled)
		if use_custom_horizontal_scroll:
			hscroll.modulate.a = 0.0
			hscroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
		get_viewport().gui_focus_changed.connect(_on_focus_changed)
		call_deferred("_sync_child_to_scrollbar")
		call_deferred("_initialize_proxy_bars")


func _initialize_proxy_bars() -> void:
	if not custom_bars_container:
		custom_bars_container = Control.new()
		custom_bars_container.name = "CustomBarsContainer"
		custom_bars_container.mouse_filter = MOUSE_FILTER_IGNORE
		get_parent().add_child(custom_bars_container)

	var vscroll = get_v_scroll_bar()
	var hscroll = get_h_scroll_bar()

	if use_custom_vertical_scroll:
		if not custom_vbar:
			custom_vbar = VScrollBar.new()
			if not  Engine.is_editor_hint():
				custom_vbar.value_changed.connect(_on_custom_vbar_value_change)
			custom_bars_container.add_child(custom_vbar)

	if use_custom_horizontal_scroll:
		if not custom_hbar:
			custom_hbar = HScrollBar.new()
			if not  Engine.is_editor_hint():
				custom_hbar.value_changed.connect(_on_custom_hbar_value_change)
			custom_bars_container.add_child(custom_hbar)

	if custom_vbar:
		for property in vscroll.get_property_list():
			if property.name in ["modulate", "mouse_filter", "position", "size"]: continue
			if property.name != "script":
				custom_vbar.set(property.name, vscroll.get(property.name))
		
		custom_vbar.modulate.a = 1.0
		custom_vbar.mouse_filter = Control.MOUSE_FILTER_STOP
		custom_vbar.position = custom_vscroll_offset
		custom_vbar.set_deferred("size", custom_vscroll_size)
	
	if custom_hbar:
		for property in hscroll.get_property_list():
			if property.name in ["modulate", "mouse_filter", "position", "size"]: continue
			if property.name != "script":
				custom_hbar.set(property.name, hscroll.get(property.name))
		
		custom_hbar.modulate.a = 1.0
		custom_hbar.mouse_filter = Control.MOUSE_FILTER_STOP
		custom_hbar.position = custom_hscroll_offset
		custom_hbar.set_deferred("size", custom_hscroll_size)
	
	if use_custom_vertical_scroll:
		vscroll.modulate.a = 0.0
		vscroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	else:
		vscroll.modulate.a = 1.0
		vscroll.mouse_filter = Control.MOUSE_FILTER_STOP
	
	if use_custom_horizontal_scroll:
		hscroll.modulate.a = 0.0
		hscroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	else:
		hscroll.modulate.a = 1.0
		hscroll.mouse_filter = Control.MOUSE_FILTER_STOP

	_sync_proxy_values()


func _sync_proxy_values() -> void:
	if not child: return

	var vscroll = get_v_scroll_bar()
	var hscroll = get_h_scroll_bar()
	
	if custom_vbar:
		custom_vbar.min_value = vscroll.min_value
		custom_vbar.max_value = vscroll.max_value
		custom_vbar.page = vscroll.page
		custom_vbar.visible = vscroll.visible 
		custom_vbar.set_value_no_signal(-child.position.y)

	if custom_hbar:
		custom_hbar.min_value = hscroll.min_value
		custom_hbar.max_value = hscroll.max_value
		custom_hbar.page = hscroll.page
		custom_hbar.visible = hscroll.visible
		custom_hbar.set_value_no_signal(-child.position.x)


func _synchronize_bars(full_properties: bool = false) -> void:
	if custom_vbar:
		var vscroll = get_v_scroll_bar()
		if full_properties:
			for property in vscroll.get_property_list():
				custom_vbar.set(property.name, vscroll.get(property.name))
		else:
			custom_vbar.min_value = vscroll.min_value
			custom_vbar.max_value = vscroll.max_value
			custom_vbar.step = vscroll.step
			custom_vbar.page = vscroll.page
			
		#custom_vbar.value = vscroll.value
		custom_vbar.set_value_no_signal(-child.position.y)
		custom_vbar.position = custom_vscroll_offset
		custom_vbar.size = custom_vscroll_size
		custom_vbar.modulate.a = 1.0
		custom_vbar.mouse_filter = Control.MOUSE_FILTER_STOP
		
		vscroll.modulate.a = 0.0
		vscroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	if custom_hbar:
		var hscroll = get_h_scroll_bar()
		if full_properties:
			for property in hscroll.get_property_list():
				custom_hbar.set(property.name, hscroll.get(property.name))
		else:
			custom_hbar.min_value = hscroll.min_value
			custom_hbar.max_value = hscroll.max_value
			custom_hbar.step = hscroll.step
			custom_hbar.page = hscroll.page
		
		#custom_hbar.value = hscroll.value
		custom_hbar.set_value_no_signal(-child.position.x)
		custom_hbar.position = custom_hscroll_offset
		custom_hbar.size = custom_hscroll_size
		custom_hbar.modulate.a = 1.0
		custom_hbar.mouse_filter = Control.MOUSE_FILTER_STOP
		
		hscroll.modulate.a = 0.0
		hscroll.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _set_custom_vscroll_size(value: Vector2) -> void:
	custom_vscroll_size = value
	if is_node_ready():
		if Engine.is_editor_hint():
			call_deferred("_initialize_proxy_bars")
		_update_scrollbar_positions()


func _set_custom_vscroll_offset(value: Vector2) -> void:
	custom_vscroll_offset = value
	if is_node_ready():
		if Engine.is_editor_hint():
			call_deferred("_initialize_proxy_bars")
		_update_scrollbar_positions()


func _set_custom_hscroll_size(value: Vector2) -> void:
	custom_hscroll_size = value
	if is_node_ready():
		if Engine.is_editor_hint():
			call_deferred("_initialize_proxy_bars")
		_update_scrollbar_positions()


func _set_custom_hscroll_offset(value: Vector2) -> void:
	custom_hscroll_offset = value
	if is_node_ready():
		if Engine.is_editor_hint():
			call_deferred("_initialize_proxy_bars")
		_update_scrollbar_positions()


func _on_custom_vbar_value_change(value: float) -> void:
	scroll_vertical = value


func _on_custom_hbar_value_change(value: float) -> void:
	scroll_horizontal = value


func _on_child_item_rect_changed() -> void:
	if not movement_enabled:
		child.position = saved_position


func _sync_child_to_scrollbar() -> void:
	if not child:
		return
	
	var h = get_h_scroll_bar()
	var v = get_v_scroll_bar()
	
	var pos = Vector2()
	pos.x = -h.value if h and h.visible else 0
	pos.y = -v.value if v and v.visible else 0
	
	child.position = Vector2i(pos)
	current_position = pos
	target_position = pos
	saved_position = child.position
	movement_enabled = false
	#is_animating = false


func _on_scrollbar_changed(_value: float) -> void:
	if child:
		var h = get_h_scroll_bar()
		var v = get_v_scroll_bar()
		
		current_position = target_position
		target_position.x = -h.value if h and h.visible else 0
		target_position.y = -v.value if v and v.visible else 0
		
		_start_animation()
		
		_update_scrollbar_positions()


func _on_scrollbar_scrolled() -> void:
	if Engine.is_editor_hint():
		await RenderingServer.frame_post_draw

	current_position = child.position
	_update_scrollbar_positions()
	_synchronize_bars()


func _start_animation() -> void:
	elapsed_time = 0.0
	is_animating = true


func _process(delta: float) -> void:
	if not child: return
	
	if busy:
		if is_animating:
			elapsed_time = scroll_duration
		busy = false
		return
	
	movement_enabled = true
	child.position = saved_position
	
	if not curve or not visible or not child:
		return
	
	if dragging_middle_mouse:
		return
	
	if is_animating:
		elapsed_time += delta
		var progress = clamp(elapsed_time / scroll_duration, 0.0, 1.0)
		var eased_progress = curve.sample(progress)
		var new_position = current_position.lerp(target_position, eased_progress)
		
		child.position = Vector2i(new_position)
		
		if progress >= 1.0:
			current_position = target_position
			child.position = Vector2i(target_position)
			is_animating = false
		
	_sync_proxy_values()
		
	saved_position = child.position
	movement_enabled = false


func _update_scrollbar_positions() -> void:
	_sync_proxy_values()


func set_h_scroll(value: int) -> void:
	var h = get_h_scroll_bar()
	if h and h.visible:
		h.value = value


func set_v_scroll(value: int) -> void:
	var v = get_v_scroll_bar()
	if v and v.visible:
		v.value = value


func is_h_scroll_visible() -> bool:
	return get_h_scroll_bar().visible


func is_v_scroll_visible() -> bool:
	return get_v_scroll_bar().visible


func bring_focus_target_into_view(instant: bool = true, instant_smooth: bool = true) -> void:
	if not is_inside_tree(): 
		return
	
	var target = single_target_focus if single_target_focus and is_instance_valid(single_target_focus) \
		else get_viewport().gui_get_focus_owner()
	
	if not target:
		return

	_bring_control_into_view(target, instant, instant_smooth)


func bring_target_into_view(target: Control, instant: bool = true, instant_smooth: bool = true) -> void:
	if not is_inside_tree(): 
		return
	
	if not target:
		return
	
	_bring_control_into_view(target, instant, instant_smooth)


func _on_focus_changed(control: Control) -> void:
	if not control or not is_instance_valid(control) or busy:
		return
	
	# Verificar si el control enfocado es descendiente de este ScrollContainer
	if not _is_descendant_of_container(control):
		return
	
	# Si hay un target específico, solo manejar ese
	if single_target_focus and is_instance_valid(single_target_focus):
		if control == single_target_focus:
			bring_focus_target_into_view(false)
	else:
		# Manejar cualquier control enfocado dentro del container
		_bring_control_into_view(control, false)


func _is_descendant_of_container(control: Control) -> bool:
	if not control or not is_instance_valid(control):
		return false
	
	var current = control
	while current:
		if current == self:
			return true
		# Verificar también si es el hijo directo del ScrollContainer (el contenido)
		if current == child:
			return true
		current = current.get_parent()
	
	return false


func _bring_control_into_view(target: Control, instant: bool = true, instant_smooth: bool = true) -> void:
	if not target or not is_instance_valid(target) or not visible:
		return
	
	var parent_cursor = target.get_parent()
	while parent_cursor and parent_cursor != self:
		if parent_cursor is ScrollContainer or parent_cursor.has_method("_bring_control_into_view"):
			return 
		parent_cursor = parent_cursor.get_parent()

	var target_rect = target.get_global_rect()
	var container_rect = get_global_rect()

	var local_target_pos = target_rect.position - container_rect.position
	var local_target_end = local_target_pos + target_rect.size
	
	var h = get_h_scroll_bar()
	var v = get_v_scroll_bar()
	
	var new_h_scroll = scroll_horizontal
	var new_v_scroll = scroll_vertical
	
	# Calcular scroll horizontal con offset
	if h and h.visible:
		if local_target_pos.x < focus_scroll_offset.x:
			new_h_scroll += local_target_pos.x - focus_scroll_offset.x
		elif local_target_end.x > container_rect.size.x - focus_scroll_offset.x:
			new_h_scroll += local_target_end.x - (container_rect.size.x - focus_scroll_offset.x)
		
		new_h_scroll = clamp(new_h_scroll, h.min_value, h.max_value - h.page)
	
	# Calcular scroll vertical con offset
	if v and v.visible:
		if local_target_pos.y < focus_scroll_offset.y:
			new_v_scroll += local_target_pos.y - focus_scroll_offset.y
		elif local_target_end.y > container_rect.size.y - focus_scroll_offset.y:
			new_v_scroll += local_target_end.y - (container_rect.size.y - focus_scroll_offset.y)
		
		new_v_scroll = clamp(new_v_scroll, v.min_value, v.max_value - v.page)

	if new_h_scroll != scroll_horizontal or new_v_scroll != scroll_vertical:
		if instant and instant_smooth:
			# Suavizado sutil y rápido
			var original_duration = scroll_duration
			scroll_duration = instant_scroll_duration
			
			current_position = child.position
			target_position = Vector2(-new_h_scroll if h and h.visible else 0, 
									   -new_v_scroll if v and v.visible else 0)
			_start_animation()
			
			scroll_duration = original_duration
		elif instant:
			busy = true
			h.set_deferred("value", new_h_scroll)
			v.set_deferred("value", new_v_scroll)
			_sync_child_to_scrollbar.call_deferred()
			child.position = target_position
			#call_deferred("_set_instant_scroll", new_h_scroll, new_v_scroll)
		else:
			# Scroll suavizado normal - actualizar los scrollbars y dejar que _on_scrollbar_changed inicie la animación
			if h and h.visible:
				h.value = new_h_scroll
			if v and v.visible:
				v.value = new_v_scroll


func _set_instant_scroll(h_value: int, v_value: int) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var h = get_h_scroll_bar()
	var v = get_v_scroll_bar()
	if h and h.visible:
		h.value = h_value
	if v and v.visible:
		v.value = v_value
	_sync_child_to_scrollbar()


func update_scroll(offset: Vector2, force_scroll: bool = false) -> void:
	smooth_scroll_by_delta(offset.y, offset.x, force_scroll)
	saved_position = target_position


func fast_scrolling() -> void:
	if not visible or not child: 
		return

	_sync_child_to_scrollbar()
	is_animating = false


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton:
		if event.is_pressed():
			if event.button_index == MOUSE_BUTTON_MIDDLE:
				dragging_middle_mouse = true
				is_animating = false
				get_viewport().set_input_as_handled()
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN or event.button_index == MOUSE_BUTTON_WHEEL_UP:
				if get_global_rect().has_point(get_global_mouse_position()):
					var v = get_v_scroll_bar()
					if v and v.visible:
						var scroll_delta = wheel_scroll_speed
						scroll_delta *= 1 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1
						var new_value = clamp(v.value + scroll_delta, v.min_value, v.max_value - v.page)
						v.value = new_value
					get_viewport().set_input_as_handled()
		elif not event.is_pressed():
			if event.button_index == MOUSE_BUTTON_MIDDLE:
				dragging_middle_mouse = false
				get_viewport().set_input_as_handled()

	elif dragging_middle_mouse and event is InputEventMouseMotion:
		set_h_scroll(get_h_scroll() - event.relative.x)
		set_v_scroll(get_v_scroll() - event.relative.y)
		
		var h = get_h_scroll_bar()
		var v = get_v_scroll_bar()
		var pos = Vector2()
		pos.x = -h.value if h and h.visible else 0
		pos.y = -v.value if v and v.visible else 0

		child.position = Vector2i(pos)
		current_position = pos
		target_position = pos
		
		get_viewport().set_input_as_handled()


func reset_scroll() -> void:
	var h = get_h_scroll_bar()
	var v = get_v_scroll_bar()
	if h and h.visible:
		h.value = 0
	if v and v.visible:
		v.value = 0
	
	_sync_child_to_scrollbar()
	is_animating = false


func smooth_scroll_by_delta(delta_v: float, delta_h: float = 0.0, force_scroll: bool = false) -> void:
	if not child or not visible and not force_scroll:
		return

	var h = get_h_scroll_bar()
	var v = get_v_scroll_bar()

	if h and h.visible:
		var new_h = clamp(h.value + delta_h, h.min_value, h.max_value - h.page)
		h.value = new_h
	
	if v and v.visible:
		var new_v = clamp(v.value + delta_v, v.min_value, v.max_value - v.page)
		v.value = new_v


func smooth_scroll_to(scroll_position: Vector2) -> void:
	var h = get_h_scroll_bar()
	var v = get_v_scroll_bar()
	
	if h and h.visible:
		h.value = clamp(scroll_position.x, h.min_value, h.max_value - h.page)
	if v and v.visible:
		v.value = clamp(scroll_position.y, v.min_value, v.max_value - v.page)


func set_focus_target(target: Control) -> void:
	single_target_focus = target


func clear_focus_target() -> void:
	single_target_focus = null


func _validate_property(property: Dictionary) -> void:
	if not use_custom_vertical_scroll:
		if property.name in ["custom_vscroll_size", "custom_vscroll_offset"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR
	
	if not use_custom_horizontal_scroll:
		if property.name in ["custom_hscroll_size", "custom_hscroll_offset"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR
