@tool
class_name SmoothScrollContainer
extends ScrollContainer

## Duration of the smooth scroll animation
@export var scroll_duration: float = 0.25

## Curve used for the scroll animation easing
@export var curve: Curve = preload("res://addons/CustomControls/Resources/Curves/default_smooth_curve.tres")

## Control node to focus on exclusively
@export var single_target_focus: Control = null

## Speed of scrolling when using the mouse wheel
@export var wheel_scroll_speed: float = 30.0

## Offset applied when scrolling to a focused element
@export var focus_scroll_offset: Vector2 = Vector2(0, 64)

## Duration of the scroll when triggered instantly
@export var instant_scroll_duration: float = 0.1

## Minimum length for the custom vertical grabber
@export var custom_vscroll_min_grabber_size: int = 24 : set = _set_custom_vscroll_min_grabber_size

## Minimum length for the custom horizontal grabber
@export var custom_hscroll_min_grabber_size: int = 24 : set = _set_custom_hscroll_min_grabber_size

@export_group("Custom Vertical Scrollbar")

## Z-index for the custom vertical scrollbar
@export var custom_vertical_bar_z_index: int = 0

## Toggle to enable or disable the custom vertical scrollbar
@export var use_custom_vertical_scroll: bool = false:
	set(value):
		use_custom_vertical_scroll = value
		if is_node_ready():
			_build_custom_bars()
		notify_property_list_changed()

## Size of the custom vertical scrollbar
@export var custom_vscroll_size: Vector2 = Vector2(12, 200) : set = _set_custom_vscroll_size

## Offset position for the custom vertical scrollbar
@export var custom_vscroll_offset: Vector2 = Vector2(0, 0) : set = _set_custom_vscroll_offset

## Scene instantiated inside the custom vertical grabber
@export var custom_scene_for_vertical_bar: PackedScene

@export_group("Custom Horizontal Scrollbar")

## Z-index for the custom horizontal scrollbar
@export var custom_horizontal_bar_z_index: int = 0

## Toggle to enable or disable the custom horizontal scrollbar
@export var use_custom_horizontal_scroll: bool = false:
	set(value):
		use_custom_horizontal_scroll = value
		if is_node_ready():
			_build_custom_bars()
		notify_property_list_changed()

## Size of the custom horizontal scrollbar
@export var custom_hscroll_size: Vector2 = Vector2(200, 12) : set = _set_custom_hscroll_size

## Offset position for the custom horizontal scrollbar
@export var custom_hscroll_offset: Vector2 = Vector2(0, 0) : set = _set_custom_hscroll_offset

## Scene instantiated inside the custom horizontal grabber
@export var custom_scene_for_horizontal_bar: PackedScene

var busy: bool = false
var elapsed_time: float = 0.0
var is_animating: bool = false
var dragging_middle_mouse: bool = false
var current_position: Vector2 = Vector2.ZERO
var target_position: Vector2 = Vector2.ZERO
var movement_enabled: bool = true
var saved_position: Vector2

var custom_bars_container: Control
var custom_vbar_bg: Panel
var custom_vbar_grabber: Panel
var custom_hbar_bg: Panel
var custom_hbar_grabber: Panel

var is_dragging_v: bool = false
var is_dragging_h: bool = false
var is_hovering_v: bool = false
var is_hovering_h: bool = false
var drag_start_mouse: Vector2 = Vector2.ZERO
var drag_start_value: Vector2 = Vector2.ZERO

@onready var child = get_child(0) if get_child_count() > 0 else null


## Initializes the scroll container and prepares custom proxy panels
func _ready() -> void:
	if child:
		child.item_rect_changed.connect(_on_child_item_rect_changed)
		var vscroll = get_v_scroll_bar()
		var hscroll = get_h_scroll_bar()
		vscroll.scrolling.connect(_on_scrollbar_scrolled)
		vscroll.value_changed.connect(_on_scrollbar_changed)
		vscroll.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		vscroll.z_index = custom_vertical_bar_z_index
		vscroll.draw.connect(_on_scrollbar_scrolled)
		hscroll.scrolling.connect(_on_scrollbar_scrolled)
		hscroll.value_changed.connect(_on_scrollbar_changed)
		hscroll.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		hscroll.z_index = custom_horizontal_bar_z_index
		hscroll.draw.connect(_on_scrollbar_scrolled)
		get_viewport().gui_focus_changed.connect(_on_focus_changed)
		call_deferred("_sync_child_to_scrollbar")
		call_deferred("_build_custom_bars")


## Creates the custom UI panels to act as isolated scrollbars
func _build_custom_bars() -> void:
	if not custom_bars_container:
		custom_bars_container = Control.new()
		custom_bars_container.name = "CustomBarsContainer"
		custom_bars_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		get_parent().add_child(custom_bars_container)
	if use_custom_vertical_scroll:
		if not custom_vbar_bg:
			custom_vbar_bg = Panel.new()
			custom_vbar_grabber = Panel.new()
			custom_bars_container.add_child(custom_vbar_bg)
			custom_vbar_bg.add_child(custom_vbar_grabber)
			custom_vbar_bg.mouse_filter = Control.MOUSE_FILTER_STOP
			custom_vbar_grabber.mouse_filter = Control.MOUSE_FILTER_STOP
			custom_vbar_grabber.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			custom_vbar_grabber.clip_contents = true
			if not Engine.is_editor_hint():
				custom_vbar_bg.gui_input.connect(_on_v_bg_gui_input)
				custom_vbar_grabber.gui_input.connect(_on_v_grabber_gui_input)
				custom_vbar_grabber.mouse_entered.connect(_on_v_grabber_mouse_entered)
				custom_vbar_grabber.mouse_exited.connect(_on_v_grabber_mouse_exited)
		if custom_scene_for_vertical_bar and custom_vbar_grabber.get_child_count() == 0:
			var instance = custom_scene_for_vertical_bar.instantiate()
			if instance is Control:
				instance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
				instance.mouse_filter = Control.MOUSE_FILTER_IGNORE
				instance.focus_mode = Control.FOCUS_NONE
				custom_vbar_grabber.add_child(instance)
	elif custom_vbar_bg:
		custom_vbar_bg.queue_free()
		custom_vbar_bg = null
		custom_vbar_grabber = null
		get_v_scroll_bar().modulate.a = 1.0
		get_v_scroll_bar().mouse_filter = Control.MOUSE_FILTER_STOP
	if use_custom_horizontal_scroll:
		if not custom_hbar_bg:
			custom_hbar_bg = Panel.new()
			custom_hbar_grabber = Panel.new()
			custom_bars_container.add_child(custom_hbar_bg)
			custom_hbar_bg.add_child(custom_hbar_grabber)
			custom_hbar_bg.mouse_filter = Control.MOUSE_FILTER_STOP
			custom_hbar_grabber.mouse_filter = Control.MOUSE_FILTER_STOP
			custom_hbar_grabber.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			custom_hbar_grabber.clip_contents = true
			if not Engine.is_editor_hint():
				custom_hbar_bg.gui_input.connect(_on_h_bg_gui_input)
				custom_hbar_grabber.gui_input.connect(_on_h_grabber_gui_input)
				custom_hbar_grabber.mouse_entered.connect(_on_h_grabber_mouse_entered)
				custom_hbar_grabber.mouse_exited.connect(_on_h_grabber_mouse_exited)
		if custom_scene_for_horizontal_bar and custom_hbar_grabber.get_child_count() == 0:
			var instance = custom_scene_for_horizontal_bar.instantiate()
			if instance is Control:
				instance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
				instance.mouse_filter = Control.MOUSE_FILTER_IGNORE
				instance.focus_mode = Control.FOCUS_NONE
				custom_hbar_grabber.add_child(instance)
	elif custom_hbar_bg:
		custom_hbar_bg.queue_free()
		custom_hbar_bg = null
		custom_hbar_grabber = null
		get_h_scroll_bar().modulate.a = 1.0
		get_h_scroll_bar().mouse_filter = Control.MOUSE_FILTER_STOP
	_sync_custom_bars()


## Handles clicks on the custom vertical background to jump to a scroll position
func _on_v_bg_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
			var vscroll = get_v_scroll_bar()
			var click_y = custom_vbar_bg.get_local_mouse_position().y
			var bg_style = vscroll.get_theme_stylebox("scroll", "VScrollBar")
			var bg_m_top = bg_style.get_margin(SIDE_TOP) if bg_style else 0.0
			var bg_m_bottom = bg_style.get_margin(SIDE_BOTTOM) if bg_style else 0.0
			var grabber_h = custom_vbar_grabber.size.y
			var track_height = custom_vbar_bg.size.y - bg_m_top - bg_m_bottom
			var available_track = track_height - grabber_h
			var usable_click_y = clamp(click_y - bg_m_top - (grabber_h / 2.0), 0.0, available_track)
			var ratio = usable_click_y / available_track if available_track > 0 else 0.0
			var scroll_range = (vscroll.max_value - vscroll.min_value) - vscroll.page
			if scroll_range > 0:
				scroll_vertical = vscroll.min_value + (ratio * scroll_range)


## Handles clicks on the custom horizontal background to jump to a scroll position
func _on_h_bg_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
			var hscroll = get_h_scroll_bar()
			var click_x = custom_hbar_bg.get_local_mouse_position().x
			var bg_style = hscroll.get_theme_stylebox("scroll", "HScrollBar")
			var bg_m_left = bg_style.get_margin(SIDE_LEFT) if bg_style else 0.0
			var bg_m_right = bg_style.get_margin(SIDE_RIGHT) if bg_style else 0.0
			var grabber_w = custom_hbar_grabber.size.x
			var track_width = custom_hbar_bg.size.x - bg_m_left - bg_m_right
			var available_track = track_width - grabber_w
			var usable_click_x = clamp(click_x - bg_m_left - (grabber_w / 2.0), 0.0, available_track)
			var ratio = usable_click_x / available_track if available_track > 0 else 0.0
			var scroll_range = (hscroll.max_value - hscroll.min_value) - hscroll.page
			if scroll_range > 0:
				scroll_horizontal = hscroll.min_value + (ratio * scroll_range)


## Calculates effective margins combining internal style margins and expand margins
func _get_style_margins(style: StyleBox) -> Dictionary:
	var m = {"top": 0.0, "bottom": 0.0, "left": 0.0, "right": 0.0}
	if not style:
		return m
	if style is StyleBoxTexture:
		m.top = style.texture_margin_top + style.expand_margin_top
		m.bottom = style.texture_margin_bottom + style.expand_margin_bottom
		m.left = style.texture_margin_left + style.expand_margin_left
		m.right = style.texture_margin_right + style.expand_margin_right
	elif style is StyleBoxFlat:
		m.top = style.border_width_top + style.expand_margin_top
		m.bottom = style.border_width_bottom + style.expand_margin_bottom
		m.left = style.border_width_left + style.expand_margin_left
		m.right = style.border_width_right + style.expand_margin_right
	return m


## Synchronizes sizes and positions considering the effective margins of the styles
func _sync_custom_bars() -> void:
	if use_custom_vertical_scroll and custom_vbar_bg and custom_vbar_grabber:
		var vscroll = get_v_scroll_bar()
		var v_state = "grabber"
		if is_dragging_v:
			v_state = "grabber_pressed"
		elif is_hovering_v:
			v_state = "grabber_highlight"
		var bg_style = vscroll.get_theme_stylebox("scroll", "VScrollBar")
		var grabber_style = vscroll.get_theme_stylebox(v_state, "VScrollBar")
		custom_vbar_bg.add_theme_stylebox_override("panel", bg_style)
		custom_vbar_grabber.add_theme_stylebox_override("panel", grabber_style)
		var bg_m = _get_style_margins(bg_style)
		var grabber_m = _get_style_margins(grabber_style)
		var effective_bg_size = Vector2(custom_vscroll_size.x + bg_m.left + bg_m.right, custom_vscroll_size.y + bg_m.top + bg_m.bottom)
		custom_vbar_bg.size = effective_bg_size
		custom_vbar_bg.position = custom_vscroll_offset - Vector2(bg_m.left, bg_m.top)
		var bg_min_y = bg_style.get_minimum_size().y if bg_style else 0.0
		var grabber_min_y = grabber_style.get_minimum_size().y if grabber_style else 0.0
		var absolute_min_y = max(grabber_min_y, float(custom_vscroll_min_grabber_size))
		var area = custom_vscroll_size.y - bg_min_y
		var max_val = vscroll.max_value
		var min_val = vscroll.min_value
		var page_val = vscroll.page
		var range_val = max_val - min_val
		var grabber_height = absolute_min_y
		if range_val > 0 and page_val > 0:
			grabber_height = (page_val / range_val) * area
		grabber_height = max(grabber_height, absolute_min_y)
		var scroll_range = range_val - page_val
		var offset_ratio = 0.0
		if scroll_range > 0:
			offset_ratio = (vscroll.value - min_val) / scroll_range
		var grabber_offset = offset_ratio * (area - grabber_height)
		var bg_top_margin = bg_style.get_margin(SIDE_TOP) if bg_style else 0.0
		var effective_grabber_size = Vector2(custom_vscroll_size.x + grabber_m.left + grabber_m.right, grabber_height + grabber_m.top + grabber_m.bottom)
		custom_vbar_grabber.size = effective_grabber_size
		custom_vbar_grabber.position = Vector2((bg_m.left - grabber_m.left), bg_top_margin + grabber_offset + (bg_m.top - grabber_m.top))
		vscroll.modulate.a = 0.0
		vscroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_vbar_bg.visible = vscroll.visible
	if use_custom_horizontal_scroll and custom_hbar_bg and custom_hbar_grabber:
		var hscroll = get_h_scroll_bar()
		var h_state = "grabber"
		if is_dragging_h:
			h_state = "grabber_pressed"
		elif is_hovering_h:
			h_state = "grabber_highlight"
		var bg_style = hscroll.get_theme_stylebox("scroll", "HScrollBar")
		var grabber_style = hscroll.get_theme_stylebox(h_state, "HScrollBar")
		custom_hbar_bg.add_theme_stylebox_override("panel", bg_style)
		custom_hbar_grabber.add_theme_stylebox_override("panel", grabber_style)
		var bg_m = _get_style_margins(bg_style)
		var grabber_m = _get_style_margins(grabber_style)
		var effective_bg_size = Vector2(custom_hscroll_size.x + bg_m.left + bg_m.right, custom_hscroll_size.y + bg_m.top + bg_m.bottom)
		custom_hbar_bg.size = effective_bg_size
		custom_hbar_bg.position = custom_hscroll_offset - Vector2(bg_m.left, bg_m.top)
		var bg_min_x = bg_style.get_minimum_size().x if bg_style else 0.0
		var grabber_min_x = grabber_style.get_minimum_size().x if grabber_style else 0.0
		var absolute_min_x = max(grabber_min_x, float(custom_hscroll_min_grabber_size))
		var area = custom_hscroll_size.x - bg_min_x
		var max_val = hscroll.max_value
		var min_val = hscroll.min_value
		var page_val = hscroll.page
		var range_val = max_val - min_val
		var grabber_width = absolute_min_x
		if range_val > 0 and page_val > 0:
			grabber_width = (page_val / range_val) * area
		grabber_width = max(grabber_width, absolute_min_x)
		var scroll_range = range_val - page_val
		var offset_ratio = 0.0
		if scroll_range > 0:
			offset_ratio = (hscroll.value - min_val) / scroll_range
		var grabber_offset = offset_ratio * (area - grabber_width)
		var bg_left_margin = bg_style.get_margin(SIDE_LEFT) if bg_style else 0.0
		var effective_grabber_size = Vector2(grabber_width + grabber_m.left + grabber_m.right, custom_hscroll_size.y + grabber_m.top + grabber_m.bottom)
		custom_hbar_grabber.size = effective_grabber_size
		custom_hbar_grabber.position = Vector2(bg_left_margin + grabber_offset + (bg_m.left - grabber_m.left), (bg_m.top - grabber_m.top))
		hscroll.modulate.a = 0.0
		hscroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_hbar_bg.visible = hscroll.visible


## Sets the minimum size of the custom vertical grabber
func _set_custom_vscroll_min_grabber_size(value: int) -> void:
	custom_vscroll_min_grabber_size = value
	if is_node_ready():
		_sync_custom_bars()


## Sets the minimum size of the custom horizontal grabber
func _set_custom_hscroll_min_grabber_size(value: int) -> void:
	custom_hscroll_min_grabber_size = value
	if is_node_ready():
		_sync_custom_bars()


## Handles mouse enter event for the vertical grabber
func _on_v_grabber_mouse_entered() -> void:
	is_hovering_v = true
	_sync_custom_bars()


## Handles mouse exit event for the vertical grabber
func _on_v_grabber_mouse_exited() -> void:
	is_hovering_v = false
	_sync_custom_bars()


## Handles mouse enter event for the horizontal grabber
func _on_h_grabber_mouse_entered() -> void:
	is_hovering_h = true
	_sync_custom_bars()


## Handles mouse exit event for the horizontal grabber
func _on_h_grabber_mouse_exited() -> void:
	is_hovering_h = false
	_sync_custom_bars()


## Handles drag input specifically for the custom vertical grabber
func _on_v_grabber_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.is_pressed():
				is_dragging_v = true
				drag_start_mouse.y = get_global_mouse_position().y
				drag_start_value.y = scroll_vertical
				_sync_custom_bars()
			else:
				is_dragging_v = false
				_sync_custom_bars()
	elif event is InputEventMouseMotion and is_dragging_v:
		var vscroll = get_v_scroll_bar()
		var bg_style = vscroll.get_theme_stylebox("scroll", "VScrollBar")
		var bg_min_y = bg_style.get_minimum_size().y if bg_style else 0.0
		var track_height = custom_vscroll_size.y - bg_min_y
		var max_val = vscroll.max_value
		var min_val = vscroll.min_value
		var page_val = vscroll.page
		var grabber_style = vscroll.get_theme_stylebox("grabber_pressed", "VScrollBar")
		var grabber_m = _get_style_margins(grabber_style)
		var raw_grabber_height = custom_vbar_grabber.size.y - grabber_m.top - grabber_m.bottom
		var available_track = track_height - raw_grabber_height
		var scroll_range = (max_val - min_val) - page_val
		if available_track > 0:
			var mouse_delta = get_global_mouse_position().y - drag_start_mouse.y
			var value_delta = (mouse_delta / available_track) * scroll_range
			scroll_vertical = clamp(drag_start_value.y + value_delta, min_val, max_val - page_val)


## Handles drag input specifically for the custom horizontal grabber
func _on_h_grabber_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.is_pressed():
				is_dragging_h = true
				drag_start_mouse.x = get_global_mouse_position().x
				drag_start_value.x = scroll_horizontal
				_sync_custom_bars()
			else:
				is_dragging_h = false
				_sync_custom_bars()
	elif event is InputEventMouseMotion and is_dragging_h:
		var hscroll = get_h_scroll_bar()
		var bg_style = hscroll.get_theme_stylebox("scroll", "HScrollBar")
		var bg_min_x = bg_style.get_minimum_size().x if bg_style else 0.0
		var track_width = custom_hscroll_size.x - bg_min_x
		var max_val = hscroll.max_value
		var min_val = hscroll.min_value
		var page_val = hscroll.page
		var grabber_style = hscroll.get_theme_stylebox("grabber_pressed", "HScrollBar")
		var grabber_m = _get_style_margins(grabber_style)
		var raw_grabber_width = custom_hbar_grabber.size.x - grabber_m.left - grabber_m.right
		var available_track = track_width - raw_grabber_width
		var scroll_range = (max_val - min_val) - page_val
		if available_track > 0:
			var mouse_delta = get_global_mouse_position().x - drag_start_mouse.x
			var value_delta = (mouse_delta / available_track) * scroll_range
			scroll_horizontal = clamp(drag_start_value.x + value_delta, min_val, max_val - page_val)


## Sets the size of the custom vertical scrollbar
func _set_custom_vscroll_size(value: Vector2) -> void:
	custom_vscroll_size = value
	if is_node_ready():
		if Engine.is_editor_hint():
			call_deferred("_build_custom_bars")
		_sync_custom_bars()


## Sets the offset position of the custom vertical scrollbar
func _set_custom_vscroll_offset(value: Vector2) -> void:
	custom_vscroll_offset = value
	if is_node_ready():
		if Engine.is_editor_hint():
			call_deferred("_build_custom_bars")
		_sync_custom_bars()


## Sets the size of the custom horizontal scrollbar
func _set_custom_hscroll_size(value: Vector2) -> void:
	custom_hscroll_size = value
	if is_node_ready():
		if Engine.is_editor_hint():
			call_deferred("_build_custom_bars")
		_sync_custom_bars()


## Sets the offset position of the custom horizontal scrollbar
func _set_custom_hscroll_offset(value: Vector2) -> void:
	custom_hscroll_offset = value
	if is_node_ready():
		if Engine.is_editor_hint():
			call_deferred("_build_custom_bars")
		_sync_custom_bars()


## Restores child position if movement is disabled upon rect changes
func _on_child_item_rect_changed() -> void:
	if not movement_enabled:
		child.position = saved_position


## Syncs child node position based on current scrollbar values
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


## Starts animation when the scrollbar value is changed manually
func _on_scrollbar_changed(_value: float) -> void:
	if child:
		var h = get_h_scroll_bar()
		var v = get_v_scroll_bar()
		current_position = target_position
		target_position.x = -h.value if h and h.visible else 0
		target_position.y = -v.value if v and v.visible else 0
		_start_animation()
		_sync_custom_bars()


## Updates custom visual panels when native bars scroll via code or wheel
func _on_scrollbar_scrolled() -> void:
	if Engine.is_editor_hint():
		await RenderingServer.frame_post_draw
	current_position = child.position
	_sync_custom_bars()


## Triggers the beginning of the scrolling animation
func _start_animation() -> void:
	elapsed_time = 0.0
	is_animating = true


## Processes animation and interaction per frame
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
	_sync_custom_bars()
	saved_position = child.position
	movement_enabled = false


## Safely sets the horizontal scrollbar value if visible
func set_h_scroll(value: int) -> void:
	var h = get_h_scroll_bar()
	if h and h.visible:
		h.value = value


## Safely sets the vertical scrollbar value if visible
func set_v_scroll(value: int) -> void:
	var v = get_v_scroll_bar()
	if v and v.visible:
		v.value = value


## Checks if the horizontal scrollbar is currently visible
func is_h_scroll_visible() -> bool:
	return get_h_scroll_bar().visible


## Checks if the vertical scrollbar is currently visible
func is_v_scroll_visible() -> bool:
	return get_v_scroll_bar().visible


## Centers the globally defined focus target on screen
func bring_focus_target_into_view(instant: bool = true, instant_smooth: bool = true) -> void:
	if not is_inside_tree(): 
		return
	var target = single_target_focus if single_target_focus and is_instance_valid(single_target_focus) \
		else get_viewport().gui_get_focus_owner()
	if not target:
		return
	_bring_control_into_view(target, instant, instant_smooth)


## Centers a specific given target control on screen
func bring_target_into_view(target: Control, instant: bool = true, instant_smooth: bool = true) -> void:
	if not is_inside_tree(): 
		return
	if not target:
		return
	_bring_control_into_view(target, instant, instant_smooth)


## Intercepts focus changes to scroll elements into view
func _on_focus_changed(control: Control) -> void:
	if not control or not is_instance_valid(control) or busy:
		return
	if not _is_descendant_of_container(control):
		return
	if single_target_focus and is_instance_valid(single_target_focus):
		if control == single_target_focus:
			bring_focus_target_into_view(false)
	else:
		_bring_control_into_view(control, false)


## Validates if the given control is a child of this container
func _is_descendant_of_container(control: Control) -> bool:
	if not control or not is_instance_valid(control):
		return false
	var current = control
	while current:
		if current == self:
			return true
		if current == child:
			return true
		current = current.get_parent()
	return false


## Calculates required scroll to ensure the target is completely visible
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
	if h and h.visible:
		if local_target_pos.x < focus_scroll_offset.x:
			new_h_scroll += local_target_pos.x - focus_scroll_offset.x
		elif local_target_end.x > container_rect.size.x - focus_scroll_offset.x:
			new_h_scroll += local_target_end.x - (container_rect.size.x - focus_scroll_offset.x)
		new_h_scroll = clamp(new_h_scroll, h.min_value, h.max_value - h.page)
	if v and v.visible:
		if local_target_pos.y < focus_scroll_offset.y:
			new_v_scroll += local_target_pos.y - focus_scroll_offset.y
		elif local_target_end.y > container_rect.size.y - focus_scroll_offset.y:
			new_v_scroll += local_target_end.y - (container_rect.size.y - focus_scroll_offset.y)
		new_v_scroll = clamp(new_v_scroll, v.min_value, v.max_value - v.page)
	if new_h_scroll != scroll_horizontal or new_v_scroll != scroll_vertical:
		if instant and instant_smooth:
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
		else:
			if h and h.visible:
				h.value = new_h_scroll
			if v and v.visible:
				v.value = new_v_scroll


## Handles instant scroll updates ensuring frame renders first
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


## Updates scroll position applying an offset manually
func update_scroll(offset: Vector2, force_scroll: bool = false) -> void:
	smooth_scroll_by_delta(offset.y, offset.x, force_scroll)
	saved_position = target_position


## Syncs scroll state immediately bypassing animations
func fast_scrolling() -> void:
	if not visible or not child: 
		return
	_sync_child_to_scrollbar()
	is_animating = false


## Processes middle click dragging and wheel events
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


## Resets scrollbars and child position to zero
func reset_scroll() -> void:
	var h = get_h_scroll_bar()
	var v = get_v_scroll_bar()
	if h and h.visible:
		h.value = 0
	if v and v.visible:
		v.value = 0
	_sync_child_to_scrollbar()
	is_animating = false


## Modifies the scroll value by applying a delta difference
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


## Updates the scroll values forcing clamp inside limits
func smooth_scroll_to(scroll_position: Vector2) -> void:
	var h = get_h_scroll_bar()
	var v = get_v_scroll_bar()
	if h and h.visible:
		h.value = clamp(scroll_position.x, h.min_value, h.max_value - h.page)
	if v and v.visible:
		v.value = clamp(scroll_position.y, v.min_value, v.max_value - v.page)


## Registers a control to track focus exclusively
func set_focus_target(target: Control) -> void:
	single_target_focus = target


## Removes the previously set focus target reference
func clear_focus_target() -> void:
	single_target_focus = null


## Validates exported properties hiding them from the inspector if unused
func _validate_property(property: Dictionary) -> void:
	if not use_custom_vertical_scroll:
		if property.name in ["custom_vscroll_size", "custom_vscroll_offset"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR
	if not use_custom_horizontal_scroll:
		if property.name in ["custom_hscroll_size", "custom_hscroll_offset"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR
