@tool
extends MarginContainer


#region exports
@export_category("Tabs")


@export var default_tabs: Array[String] :
	set(value):
		default_tabs = value
		if is_inside_tree():
			force_refresh_tabs_timer = 0.1


@export_category("Drag and Drop")


@export var allow_drag_and_drop: bool = false


@export var style_drag_from: Variant :
	set(value):
		style_drag_from = value
		queue_redraw()


@export var style_drag_to: Variant :
	set(value):
		style_drag_to = value
		queue_redraw()


@export var drag_threshold: float = 10.0


@export_category("Text Data")


@export_subgroup("Font")
@export var current_font: Font :
	set(value):
		current_font = value
		update_tabs()


@export var font_size: int :
	set(value):
		font_size = value
		update_tabs()


@export var font_outline_size: int :
	set(value):
		font_outline_size = value
		update_tabs()


@export_subgroup("Current Tab Selected Text Color")
@export var selected_color: Color :
	set(value):
		selected_color = value
		update_tabs()


@export var selected_outline_color: Color :
	set(value):
		selected_outline_color = value
		update_tabs()


@export_subgroup("Unselected Tab Text Color")
@export var unselected_color: Color :
	set(value):
		unselected_color = value
		update_tabs()


@export var unselected_outline_color: Color :
	set(value):
		unselected_outline_color = value
		update_tabs()


@export_subgroup("Tab Hover Text Color")
@export var hover_color: Color :
	set(value):
		hover_color = value
		update_tabs()


@export var hover_outline_color: Color :
	set(value):
		hover_outline_color = value
		update_tabs()


@export var current_tab_unselected_text_outline_color: Color :
	set(value):
		current_tab_unselected_text_outline_color = value
		update_tabs()


@export_category("Container Layout")
enum TabAlignment { LEFT, CENTER, RIGHT, FILL }


@export var alignment: TabAlignment = TabAlignment.LEFT :
	set(value):
		alignment = value
		update_tabs()


@export var smart_row_balance: bool = false :
	set(value):
		smart_row_balance = value
		update_tabs()


@export var max_rows: int = 1 :
	set(value):
		max_rows = max(1, value)
		update_tabs()


@export var tabs_movement_speed: float = 500


@export var tab_name_base: String :
	set(value):
		tab_name_base = value
		update_tabs()


@export var tab_name_margins: int :
	set(value):
		tab_name_margins = value
		update_tabs()


@export var separator: int = 2 :
	set(value):
		separator = value
		update_tabs()


@export var minimum_tab_size: Vector2 = Vector2(120, 32) :
	set(value):
		minimum_tab_size = value
		update_tabs()


@export var arrow_buttons_size: Vector2 = Vector2(26, 26) :
	set(value):
		arrow_buttons_size = value
		update_tabs()


@export var background_color: Color :
	set(value):
		background_color = value
		queue_redraw()


@export var text_selected_offset_y: int :
	set(value):
		text_selected_offset_y = value
		queue_redraw()


@export var text_unselected_offset_y: int :
	set(value):
		text_unselected_offset_y = value
		queue_redraw()


@export var arrows_offset_y: int :
	set(value):
		arrows_offset_y = value
		queue_redraw()


@export var clip_tabs: bool = true


@export_category("Button Textures")


@export var tab_selected: Texture :
	set(value):
		tab_selected = value
		update_tabs()


@export var tab_unselected: Texture :
	set(value):
		tab_unselected = value
		update_tabs()


@export var tab_hover: Texture :
	set(value):
		tab_hover = value
		update_tabs()


@export var stylebox_tab_selected: StyleBox :
	set(value):
		stylebox_tab_selected = value
		if value and not value.changed.is_connected(update_tabs):
			value.changed.connect(update_tabs)
		update_tabs()


@export var stylebox_tab_unselected: StyleBox :
	set(value):
		stylebox_tab_unselected = value
		if value and not value.changed.is_connected(update_tabs):
			value.changed.connect(update_tabs)
		update_tabs()


@export var stylebox_tab_hover: StyleBox :
	set(value):
		stylebox_tab_hover = value
		if value and not value.changed.is_connected(update_tabs):
			value.changed.connect(update_tabs)
		update_tabs()


@export var arrow_left_disabled: Texture :
	set(value):
		arrow_left_disabled = value
		update_tabs()


@export var arrow_left_normal: Texture :
	set(value):
		arrow_left_normal = value
		update_tabs()


@export var arrow_left_hover: Texture :
	set(value):
		arrow_left_hover = value
		update_tabs()


@export var arrow_right_disabled: Texture :
	set(value):
		arrow_right_disabled = value
		update_tabs()


@export var arrow_right_normal: Texture :
	set(value):
		arrow_right_normal = value
		update_tabs()


@export var arrow_right_hover: Texture :
	set(value):
		arrow_right_hover = value
		update_tabs()
#endregion


var selected_tab: int = 3
var mouse_hover_button_index: int = -1
var tab_hover_index: int = -1
var current_button_pressed: int = -1
var using_arrows: bool = false
var arrow_on_left: bool = false
var button_left_rect: Rect2
var button_right_rect: Rect2
var button_left_disabled: bool = false
var button_right_disabled: bool = true
var offset: float = 0.0
var tabs_data: Array[Dictionary]
var force_refresh_tabs_timer: float = 0.0
var dragging_tab_index: int = -1
var potential_drop_index: int = -1
var is_dragging: bool = false
var drag_start_position: Vector2 = Vector2.ZERO
var tabs_names: Array = []


signal tab_changed(index: int)
signal tabs_changed(from: int, to: int)


func _ready() -> void:
	item_rect_changed.connect(refresh)
	gui_input.connect(_on_gui_input)
	mouse_exited.connect(_on_mouse_exited)
	tab_changed.connect(_on_tab_changed)


func _on_mouse_exited() -> void:
	mouse_hover_button_index = -1
	tab_hover_index = -1
	queue_redraw()


func _process(delta: float) -> void:
	if force_refresh_tabs_timer > 0.0:
		force_refresh_tabs_timer -= delta
		if force_refresh_tabs_timer <= 0:
			if not default_tabs.is_empty():
				create_tabs(PackedStringArray(default_tabs))


	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if current_button_pressed == 0 and !button_left_disabled:
			move_tabs(delta, 1)
		elif current_button_pressed == 1 and !button_right_disabled:
			move_tabs(delta, -1)


	if is_dragging and using_arrows and allow_drag_and_drop:
		var m_x = get_local_mouse_position().x
		var arrow_w = (arrow_buttons_size.x * 2 + separator)
		var visible_width = size.x - arrow_w
		if m_x < 50 and !button_left_disabled:
			move_tabs(delta, 1)
		elif m_x > visible_width - 50 and !button_right_disabled:
			move_tabs(delta, -1)


func move_tabs(delta: float, direction: int) -> void:
	if tabs_data.size() == 0:
		return
		
	if not using_arrows:
		offset = 0.0
		for data in tabs_data:
			data.visible = true
		queue_redraw()
		return
		
	var arrow_w = (arrow_buttons_size.x * 2 + separator)
	var visible_width = size.x - arrow_w
	offset += tabs_movement_speed * delta * direction
	
	if offset >= 0:
		offset = 0
		button_left_disabled = true
		button_right_disabled = false
	else:
		button_left_disabled = false
		var last_tab = tabs_data[-1]
		var max_x = last_tab.rect.position.x + last_tab.rect.size.x
		var start_x = arrow_w + separator if arrow_on_left else 0.0
		var limit_x = start_x + visible_width
		
		var min_offset = limit_x - max_x
		if min_offset > 0: min_offset = 0
		
		if offset <= min_offset:
			offset = min_offset
			button_right_disabled = true
		else:
			button_right_disabled = false
	
	for data in tabs_data:
		if data.get("row", 1) < max_rows:
			data.visible = true
			continue
			
		var rect = data.rect
		rect.position.x += offset
		
		var left_bound = arrow_w + separator if arrow_on_left else 0.0
		var right_bound = size.x if arrow_on_left else size.x - arrow_w
		
		if rect.position.x + rect.size.x <= left_bound + 0.1:
			data.visible = false
		elif rect.position.x >= right_bound - 0.1:
			data.visible = false
		else:
			data.visible = true
	
	queue_redraw()


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		mouse_hover_button_index = -1
		tab_hover_index = -1
		potential_drop_index = -1
		
		if using_arrows:
			if button_left_rect.has_point(event.position):
				mouse_hover_button_index = 0
				mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			elif button_right_rect.has_point(event.position):
				mouse_hover_button_index = 1
				mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
				
		if mouse_hover_button_index == -1:
			for data in tabs_data:
				var rect = data.rect
				if data.get("row", 1) == max_rows and using_arrows:
					rect.position.x += offset
				if rect.has_point(event.position):
					tab_hover_index = data.index
					mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
					if is_dragging: potential_drop_index = data.index
					break
		
		if dragging_tab_index != -1 and allow_drag_and_drop and !is_dragging:
			if event.position.distance_to(drag_start_position) > drag_threshold:
				is_dragging = true
		
		if is_dragging: mouse_default_cursor_shape = Control.CURSOR_MOVE
		queue_redraw()


	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.is_pressed():
				current_button_pressed = -1
				drag_start_position = event.position
				if using_arrows:
					if button_left_rect.has_point(event.position):
						current_button_pressed = 0
						return
					elif button_right_rect.has_point(event.position):
						current_button_pressed = 1
						return
				
				for data in tabs_data:
					var rect = data.rect
					if data.get("row", 1) == max_rows and using_arrows:
						rect.position.x += offset
					if rect.has_point(event.position):
						dragging_tab_index = data.index
						break
			else:
				if is_dragging and dragging_tab_index != -1 and allow_drag_and_drop:
					if potential_drop_index != -1 and potential_drop_index != dragging_tab_index:
						tabs_changed.emit(dragging_tab_index, potential_drop_index)
				elif dragging_tab_index != -1:
					selected_tab = dragging_tab_index
					tab_changed.emit(selected_tab)
				
				dragging_tab_index = -1
				potential_drop_index = -1
				is_dragging = false
				current_button_pressed = -1
				queue_redraw()
				
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.is_pressed():
			move_tabs(0.1, 1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.is_pressed():
			move_tabs(0.1, -1)


func refresh():
	update_tabs(tabs_data.size(), selected_tab)


func clear() -> void:
	tabs_data.clear()
	tabs_names.clear()


func update_tabs(current_tabs: int = 0, index: int = 0, force_selection: bool = false) -> void:
	tabs_data.clear()
	using_arrows = false
	
	if default_tabs:
		for i in default_tabs.size():
			_register_tab_data(default_tabs[i], i)
	else:
		for i in current_tabs:
			var tab_text: String = tab_name_base + " " + str(i + 1) if tabs_names.size() <= i else tabs_names[i]
			_register_tab_data(tab_text, i)
			
	_calculate_tab_positions()
	move_tabs(0, 0)
	select(index, force_selection)


func create_tabs(_tabs: PackedStringArray) -> void:
	default_tabs = PackedStringArray(_tabs)
	clear()
	update_tabs()


func _register_tab_data(tab_text: String, index: int) -> void:
	var font: Font = current_font if current_font else get_theme_default_font()
	var s: int = font_size if font_size else get_theme_default_font_size()
	var current_text_size = font.get_string_size(tab_text, HORIZONTAL_ALIGNMENT_CENTER, -1, s)
	current_text_size.x += tab_name_margins * 2
	current_text_size.x = max(current_text_size.x, minimum_tab_size.x)
	current_text_size.y = max(current_text_size.y, minimum_tab_size.y)
	
	tabs_data.append({
		"index": index,
		"text": tab_text.strip_edges(),
		"size": current_text_size,
		"rect": Rect2(),
		"visible": true,
		"row": 1
	})
	
	if tabs_names.size() < tabs_data.size():
		tabs_names.resize(tabs_data.size())
		tabs_names[tabs_data.size() - 1] = tab_text


func _calculate_tab_positions() -> void:
	if tabs_data.is_empty(): return
	var container_width = size.x
	
	if smart_row_balance and max_rows > 1:
		var total_width: float = 0.0
		for data in tabs_data: total_width += data.size.x
		var ideal_row_width = total_width / max_rows
		var current_row_width: float = 0.0
		var current_row = 1
		for data in tabs_data:
			var exceeds_ideal = current_row_width + (data.size.x / 2.0) > ideal_row_width
			var exceeds_hard = current_row_width + data.size.x > container_width
			if (exceeds_ideal or exceeds_hard) and current_row < max_rows:
				current_row += 1
				current_row_width = 0.0
			data.row = current_row
			current_row_width += data.size.x
	else:
		var current_x: float = 0.0
		var current_row = 1
		for data in tabs_data:
			if current_x + data.size.x > container_width and current_row < max_rows:
				current_x = 0.0
				current_row += 1
			data.row = current_row
			current_x += data.size.x
			
	var row_widths = {}
	var tabs_per_row = {}
	for i in range(1, max_rows + 1):
		row_widths[i] = 0.0
		tabs_per_row[i] = 0
	for data in tabs_data:
		row_widths[data.row] += data.size.x
		tabs_per_row[data.row] += 1
		
	arrow_on_left = (alignment == TabAlignment.RIGHT)
	using_arrows = (row_widths.get(max_rows, 0) > container_width)
	if not using_arrows: offset = 0.0
		
	var arrow_w = (arrow_buttons_size.x * 2 + separator)
	var current_y: float = 0.0
	var last_processed_row = 0
	var current_x: float = 0.0
	var remaining_space_for_fill: float = 0.0
	var remaining_tabs_for_fill: int = 0
	
	for data in tabs_data:
		if data.row != last_processed_row:
			last_processed_row = data.row
			current_y = (data.row - 1) * minimum_tab_size.y
			var current_available_width = container_width
			if data.row == max_rows and using_arrows:
				current_available_width = container_width - arrow_w - separator
				
			var free_space = current_available_width - row_widths[data.row]
			if free_space < 0: free_space = 0
			remaining_space_for_fill = free_space
			remaining_tabs_for_fill = tabs_per_row[data.row]
			
			match alignment:
				TabAlignment.LEFT, TabAlignment.FILL: current_x = 0.0
				TabAlignment.CENTER: current_x = free_space / 2.0
				TabAlignment.RIGHT: current_x = 0.0
				
			if data.row == max_rows and using_arrows and arrow_on_left:
				current_x += arrow_w + separator
				
		if alignment == TabAlignment.FILL and remaining_tabs_for_fill > 0:
			var extra = remaining_space_for_fill / remaining_tabs_for_fill
			data.size.x += extra
			remaining_space_for_fill -= extra
			remaining_tabs_for_fill -= 1
			
		data.rect = Rect2(Vector2(current_x, current_y), data.size)
		current_x += data.size.x
		
		if data.row == max_rows and using_arrows:
			var left_safe = arrow_w + separator if arrow_on_left else 0.0
			var right_safe = container_width if arrow_on_left else container_width - arrow_w
			data.visible = (data.rect.position.x >= left_safe - 0.1 and data.rect.position.x + data.rect.size.x <= right_safe + 0.1)
		else:
			data.visible = true
			
	if using_arrows:
		var arrow_y = (max_rows - 1) * minimum_tab_size.y
		var arrow_x = 0.0 if arrow_on_left else container_width - arrow_w
		button_left_rect = Rect2(Vector2(arrow_x, arrow_y), arrow_buttons_size)
		button_right_rect = Rect2(Vector2(arrow_x + arrow_buttons_size.x + separator, arrow_y), arrow_buttons_size)
		
	custom_minimum_size.y = max_rows * minimum_tab_size.y


func _on_tab_changed(_index: int) -> void:
	ensure_current_is_visible()


func select(index: int, force_selection: bool = false) -> void:
	var last_index = selected_tab
	selected_tab = index
	ensure_current_is_visible()
	if last_index != selected_tab or force_selection:
		tab_changed.emit(selected_tab)


func ensure_current_is_visible() -> void:
	if not using_arrows:
		offset = 0.0
		queue_redraw()
		return
		
	if selected_tab < tabs_data.size():
		var selected = tabs_data[selected_tab]
		if selected.get("row", 1) < max_rows: return 
		var arrow_w = (arrow_buttons_size.x * 2 + separator)
		var left_bound = arrow_w + separator if arrow_on_left else 0.0
		var right_bound = size.x if arrow_on_left else size.x - arrow_w
		
		var rect = selected.rect
		rect.position.x += offset
		if rect.position.x < left_bound - 0.1:
			offset += left_bound - rect.position.x
		elif rect.position.x + rect.size.x > right_bound + 0.1:
			offset -= (rect.position.x + rect.size.x) - right_bound
		
		move_tabs(0, 0)
		queue_redraw()


func _draw() -> void:
	draw_rect(get_rect(), background_color)
	var font: Font = current_font if current_font else get_theme_default_font()
	var s: int = font_size if font_size else get_theme_default_font_size()
	var align = HORIZONTAL_ALIGNMENT_CENTER
	var arrow_w = (arrow_buttons_size.x * 2 + separator)
	
	for data in tabs_data:
		var is_last_row = data.get("row", 1) == max_rows
		var rect = data.rect
		if is_last_row and using_arrows: rect.position.x += offset
		
		var safe_rect = get_rect()
		if is_last_row and using_arrows:
			var left_safe = arrow_w + separator if arrow_on_left else 0.0
			var right_safe = size.x if arrow_on_left else size.x - arrow_w
			if rect.position.x + rect.size.x <= left_safe + 0.1 or rect.position.x >= right_safe - 0.1: continue
			
			var draw_x = max(rect.position.x, left_safe)
			var draw_right = min(rect.position.x + rect.size.x, right_safe)
			if draw_right <= draw_x: continue
			rect.position.x = draw_x
			rect.size.x = draw_right - draw_x

		var texture = tab_selected if data.index == selected_tab else (tab_hover if tab_hover_index == data.index else tab_unselected)
		var style = stylebox_tab_selected if data.index == selected_tab else (stylebox_tab_hover if tab_hover_index == data.index else stylebox_tab_unselected)
		var color = selected_color if data.index == selected_tab else (hover_color if tab_hover_index == data.index else unselected_color)
		var out_color = selected_outline_color if data.index == selected_tab else (hover_outline_color if tab_hover_index == data.index else unselected_outline_color)
		var off_y = text_selected_offset_y if data.index == selected_tab else text_unselected_offset_y

		if style is StyleBox: style.draw(get_canvas_item(), rect)
		elif texture is Texture: draw_texture_rect(texture, rect, false)
		
		if is_dragging and allow_drag_and_drop:
			if dragging_tab_index == data.index and style_drag_from: _draw_drag_style(style_drag_from, rect)
			elif potential_drop_index == data.index and style_drag_to: _draw_drag_style(style_drag_to, rect)

		var p = Vector2(rect.position.x + tab_name_margins, rect.position.y + font.get_ascent() + off_y)
		var text_w = rect.size.x - (tab_name_margins * 2)
		if text_w > 0:
			draw_string(font, p, data.text, align, text_w, s, color)
			if font_size > 0: draw_string_outline(font, p, data.text, align, text_w, s, font_outline_size, out_color)
	
	if using_arrows:
		var tex_l = arrow_left_disabled if button_left_disabled else (arrow_left_hover if mouse_hover_button_index == 0 else arrow_left_normal)
		var tex_r = arrow_right_disabled if button_right_disabled else (arrow_right_hover if mouse_hover_button_index == 1 else arrow_right_normal)
		var rl = button_left_rect
		var rr = button_right_rect
		rl.position.y += arrows_offset_y
		rr.position.y += arrows_offset_y
		draw_texture_rect(tex_l, rl, false)
		draw_texture_rect(tex_r, rr, false)
	
	RenderingServer.canvas_item_set_clip(get_canvas_item(), clip_tabs)


func _draw_drag_style(style: Variant, rect: Rect2) -> void:
	if style is StyleBox: style.draw(get_canvas_item(), rect)
	elif style is Texture: draw_texture_rect(style, rect, false)
