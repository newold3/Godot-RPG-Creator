@tool
extends EditorPlugin

var current_canvas: PaintableCanvas
var is_painting: bool = false
var is_erasing: bool = false
var is_hovering_canvas: bool = false



func _handles(object: Object) -> bool:
	return object is PaintableCanvas



func _edit(object: Object) -> void:
	current_canvas = object as PaintableCanvas
	update_overlays()



func _make_visible(visible: bool) -> void:
	if not visible and current_canvas:
		current_canvas.update_preview(Vector2.ZERO, false, false)
		current_canvas = null
		is_hovering_canvas = false
		update_overlays()



func _forward_canvas_draw_over_viewport(overlay: Control) -> void:
	if current_canvas == null or not is_hovering_canvas:
		return
		
	var font: Font = ThemeDB.fallback_font
	var text: String = "        Paintable Canvas\n-------------------------------------\nCtrl + L-Click: Paint\nCtrl + R-Click: Erase\nShift + Wheel: Brush Size\nCtrl + Mid Click: Clear"
	var font_size: int = 22
	
	var text_size: Vector2 = font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var padding: Vector2 = Vector2(10.0, 10.0)
	var margin: Vector2 = Vector2(20.0, 20.0)
	
	var overlay_size: Vector2 = overlay.get_size()
	var bg_size: Vector2 = text_size + (padding * 2.0)
	var bg_pos: Vector2 = overlay_size - bg_size - margin
	
	var bg_rect: Rect2 = Rect2(bg_pos, bg_size)
	overlay.draw_rect(bg_rect, Color(0.0, 0.0, 0.0, 0.6))
	
	var text_pos: Vector2 = bg_pos + padding
	text_pos.y += font.get_ascent(font_size)
	prints(font, text_pos, text, font_size)
	overlay.draw_multiline_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)



func _forward_canvas_gui_input(event: InputEvent) -> bool:
	if current_canvas == null or not current_canvas.is_visible_in_tree():
		return false
		
	var mouse_pos: Vector2 = current_canvas.get_local_mouse_position()
	var canvas_rect: Rect2 = Rect2(Vector2.ZERO, current_canvas.size)
	var current_hover: bool = canvas_rect.has_point(mouse_pos)
	
	if is_hovering_canvas != current_hover:
		is_hovering_canvas = current_hover
		update_overlays()
		
	var ctrl_pressed: bool = Input.is_key_pressed(KEY_CTRL)
	var shift_pressed: bool = Input.is_key_pressed(KEY_SHIFT)
	
	var key_event := event as InputEventKey
	if key_event and (key_event.keycode == KEY_CTRL or key_event.keycode == KEY_SHIFT):
		var show_brush: bool = (is_hovering_canvas and (ctrl_pressed or shift_pressed)) or is_painting or is_erasing
		current_canvas.update_preview(mouse_pos, show_brush, is_erasing)
		return false
		
	var mouse_event := event as InputEventMouseButton
	if mouse_event:
		if mouse_event.button_index == MOUSE_BUTTON_MIDDLE and mouse_event.pressed:
			if ctrl_pressed:
				current_canvas.clear_history()
				return true
			return false
			
		if mouse_event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			if shift_pressed:
				if mouse_event.pressed:
					if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
						current_canvas.brush_size = mini(current_canvas.brush_size + 5, 200)
					else:
						current_canvas.brush_size = maxi(current_canvas.brush_size - 5, 1)
						
					var show_brush: bool = (is_hovering_canvas and (ctrl_pressed or shift_pressed)) or is_painting or is_erasing
					current_canvas.update_preview(mouse_pos, show_brush, is_erasing)
				return true
			return false
			
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if mouse_event.pressed:
				if is_hovering_canvas and ctrl_pressed:
					is_painting = true
					current_canvas.begin_stroke(mouse_pos, true)
					current_canvas.update_preview(mouse_pos, true, false)
					return true
			else:
				if is_painting:
					is_painting = false
					current_canvas.end_stroke()
					var show_brush: bool = is_hovering_canvas and (ctrl_pressed or shift_pressed)
					current_canvas.update_preview(mouse_pos, show_brush, false)
					return true
					
		if mouse_event.button_index == MOUSE_BUTTON_RIGHT:
			if mouse_event.pressed:
				if is_hovering_canvas and ctrl_pressed:
					is_erasing = true
					current_canvas.begin_stroke(mouse_pos, false)
					current_canvas.update_preview(mouse_pos, true, true)
					return true
			else:
				if is_erasing:
					is_erasing = false
					current_canvas.end_stroke()
					var show_brush: bool = is_hovering_canvas and (ctrl_pressed or shift_pressed)
					current_canvas.update_preview(mouse_pos, show_brush, true)
					return true
					
	var motion_event := event as InputEventMouseMotion
	if motion_event:
		if is_painting:
			current_canvas.continue_stroke(mouse_pos, true)
			current_canvas.update_preview(mouse_pos, true, false)
			return true
		elif is_erasing:
			current_canvas.continue_stroke(mouse_pos, false)
			current_canvas.update_preview(mouse_pos, true, true)
			return true
		else:
			var show_brush: bool = is_hovering_canvas and (ctrl_pressed or shift_pressed)
			current_canvas.update_preview(mouse_pos, show_brush, false)
			return false
			
	return false
