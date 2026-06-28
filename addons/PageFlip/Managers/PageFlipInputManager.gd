class_name PageFlipInputManager extends RefCounted

## Reference to the main book node.
var book: Node2D


## Initializes the input manager.
func _init(book_node: Node2D) -> void:
	book = book_node


#region Input Calculations
## Calculates the raw mathematical curve offset at a specific X coordinate.
func _calculate_raw_curve_offset(px: float, w: float, is_left: bool) -> float:
	var dist = 0.0
	
	if is_left:
		dist = (w - px) / w
	else:
		dist = px / w
		
	var out_dist = 1.0 - dist
	var curve = 0.0
	var outer_curve = 0.0
	
	if dist < book.spine_curl_width and book.spine_curl_width > 0:
		var n = 1.0 - (dist / book.spine_curl_width)
		curve = n * n
		
	if out_dist < book.outer_droop_width and book.outer_droop_width > 0:
		var n = 1.0 - (out_dist / book.outer_droop_width)
		outer_curve = n * n
		
	return (curve * book.spine_curl_intensity) + (outer_curve * book.outer_droop_intensity)


## Computes the perspective offset for a parent local position (VisualsContainer coordinates).
func _get_perspective_offset_for_pos(parent_local_pos: Vector2) -> Vector2:
	var bw = book.target_page_size.x * 2.0
	var bh = book.target_page_size.y
	
	var norm_x = 0.5
	if bw > 0:
		norm_x = (parent_local_pos.x + bw * 0.5) / bw
	var norm_y = 0.5
	if bh > 0:
		norm_y = (parent_local_pos.y + bh * 0.5) / bh
	
	var factor = book._current_expansion_factor
	var tl = book.open_top_left.lerp(book.closed_top_left, factor)
	var tr = book.open_top_right.lerp(book.closed_top_right, factor)
	var bl = book.open_bottom_left.lerp(book.closed_bottom_left, factor)
	var br = book.open_bottom_right.lerp(book.closed_bottom_right, factor)
	
	var top_offset = tl.lerp(tr, norm_x)
	var bottom_offset = bl.lerp(br, norm_x)
	var final_offset = top_offset.lerp(bottom_offset, norm_y)
	
	return final_offset


## Reverses the perspective bilinear warp using fixed-point iteration.
func _deform_perspective_pos_back(deformed_parent_pos: Vector2) -> Vector2:
	var flat_pos = deformed_parent_pos
	for i in range(4):
		var offset = _get_perspective_offset_for_pos(flat_pos)
		flat_pos = deformed_parent_pos - offset
	return flat_pos


## Reverses the curvature math to convert a viewport position back into global screen space.
func viewport_to_global_curved(viewport_pos: Vector2, is_left: bool) -> Vector2:
	var w = book.page_width
	var px = clampf(viewport_pos.x, 0.0, w)
	
	var polygon: Polygon2D = book.static_left if is_left else book.static_right
	var sub_x = 8
	
	if polygon and polygon.get("subdivision_x") != null:
		sub_x = polygon.get("subdivision_x")
		
	var step_x = w / float(sub_x)
	var segment_idx = clampi(int(px / step_x), 0, sub_x - 1)
	
	var px0 = segment_idx * step_x
	var px1 = (segment_idx + 1) * step_x
	
	var curve0 = _calculate_raw_curve_offset(px0, w, is_left)
	var curve1 = _calculate_raw_curve_offset(px1, w, is_left)
	
	var t = 0.0
	
	if step_x > 0:
		t = (px - px0) / step_x
		
	var total_curve_offset = lerp(curve0, curve1, t)
	var current_curve_factor = book._get_curve_factor_for_spread(float(book.current_spread))
	total_curve_offset *= current_curve_factor
	
	var local_polygon_pos = Vector2.ZERO
	local_polygon_pos.x = viewport_pos.x
	local_polygon_pos.y = viewport_pos.y + total_curve_offset - (book.target_page_size.y / 2.0)

	var global_pos = polygon.to_global(local_polygon_pos)
	if book.visuals_container is Node2D:
		var parent_pos = book.visuals_container.to_local(global_pos)
		var offset = _get_perspective_offset_for_pos(parent_pos)
		global_pos += offset
	return global_pos
#endregion


#region Input Event Handling
## Translates global inputs into localized inputs pushed directly to a specific viewport.
func _inject_event_to_viewport(viewport: SubViewport, polygon: Polygon2D, event: InputEvent) -> Control.CursorShape:
	var mouse_pos = book.get_global_mouse_position()
	
	var flat_mouse_pos = mouse_pos
	if book.visuals_container is Node2D:
		var parent_pos = book.visuals_container.to_local(mouse_pos)
		var flat_parent_pos = _deform_perspective_pos_back(parent_pos)
		flat_mouse_pos = book.visuals_container.to_global(flat_parent_pos)
		
	var new_mouse_pos = polygon.to_local(flat_mouse_pos)
	
	var is_left = (polygon == book.static_left)
	var w = book.page_width
	var px = clampf(new_mouse_pos.x, 0.0, w)
	
	var sub_x = 8
	
	if book.dynamic_poly and book.dynamic_poly.get("subdivision_x") != null:
		sub_x = book.dynamic_poly.get("subdivision_x")
		
	var step_x = w / float(sub_x)
	var segment_idx = clampi(int(px / step_x), 0, sub_x - 1)
	
	var px0 = segment_idx * step_x
	var px1 = (segment_idx + 1) * step_x
	
	var curve0 = _calculate_raw_curve_offset(px0, w, is_left)
	var curve1 = _calculate_raw_curve_offset(px1, w, is_left)
	
	var t = 0.0
	
	if step_x > 0:
		t = (px - px0) / step_x
		
	var total_curve_offset = lerp(curve0, curve1, t)
	
	var current_curve_factor = book._get_curve_factor_for_spread(float(book.current_spread))
	total_curve_offset *= current_curve_factor
	
	new_mouse_pos.y -= total_curve_offset
	new_mouse_pos.y += book.target_page_size.y / 2.0

	var ev = event.duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
	ev.position = new_mouse_pos
	ev.global_position = new_mouse_pos

	if not book._active_viewports_state.get(viewport, false):
		viewport.notify_mouse_entered()
		book._active_viewports_state[viewport] = true

	viewport.push_input(ev, true)
	
	var node = viewport.gui_get_hovered_control()
	
	if node is Control:
		return node.get_default_cursor_shape()
		
	return Control.CURSOR_ARROW


## Clears the viewport input state.
func _reset_viewport_input_state() -> void:
	for viewport in book._active_viewports_state:
		if is_instance_valid(viewport):
			viewport.notify_mouse_exited()
	
	book._active_viewports_state.clear()


## Handles standard inputs passed directly down the tree.
func process_input(event: InputEvent) -> void:
	if not book._active_interactive_is_left and not book._active_interactive_is_right:
		if not book._active_viewports_state.is_empty():
			_reset_viewport_input_state()
		return

	if event is InputEventMouse or event is InputEventMouseMotion:
		var cursor_l = Control.CURSOR_ARROW
		var cursor_r = Control.CURSOR_ARROW
		
		if book._active_interactive_is_left:
			book._slot_1.physics_object_picking = true
			cursor_l = _inject_event_to_viewport(book._slot_1, book.static_left, event)
		elif book._active_viewports_state.has(book._slot_1):
			book._slot_1.physics_object_picking = false
			book._slot_1.notify_mouse_exited()
			book._active_viewports_state.erase(book._slot_1)
			
		if book._active_interactive_is_right:
			book._slot_2.physics_object_picking = true
			cursor_r = _inject_event_to_viewport(book._slot_2, book.static_right, event)
		elif book._active_viewports_state.has(book._slot_2):
			book._slot_2.physics_object_picking = false
			book._slot_2.notify_mouse_exited()
			book._active_viewports_state.erase(book._slot_2)
			
		var outside_book = false
		var hovered = book.get_viewport().gui_get_hovered_control()
		if hovered and hovered != book:
			if not book.is_ancestor_of(hovered) and not hovered.is_ancestor_of(book):
				outside_book = true
				
		if not outside_book:
			if cursor_l != Control.CURSOR_ARROW:
				DisplayServer.cursor_set_shape.call_deferred(cursor_l)
			elif cursor_r != Control.CURSOR_ARROW:
				DisplayServer.cursor_set_shape.call_deferred(cursor_r)
			else:
				DisplayServer.cursor_set_shape.call_deferred(DisplayServer.CURSOR_ARROW)

	elif event is InputEventKey:
		if book._active_interactive_is_left:
			book._slot_1.push_input(event.duplicate(true))
		if book._active_interactive_is_right:
			book._slot_2.push_input(event.duplicate(true))


## Triggers unhandled inputs such as navigation keys.
func process_unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
		
	if not book.visible or book.is_animating or book.disabled:
		return
	
	if event.is_action_pressed("ui_cancel") and book.close_condition == book.CloseCondition.ON_CANCEL_INPUT:
		book._perform_close_action()
		book.get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("ui_right"):
		book.next_page()
		book.get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_left"):
		book.prev_page()
		book.get_viewport().set_input_as_handled()

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var local_pos = book.visuals_container.get_local_mouse_position()
		local_pos.y /= book.visuals_container.scale.y
		
		if local_pos.x > -book.page_width / 2.0:
			book.next_page()
			book.get_viewport().set_input_as_handled()
		else:
			book.prev_page()
			book.get_viewport().set_input_as_handled()
#endregion
