@tool
extends MarginContainer

#region exports
@export_category("Tabs")

@export var default_tabs: Array[String] :
	set(value):
		default_tabs = value
		if is_inside_tree():
			force_refresh_tabs_timer = 0.1

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


@export_category("Container Data")
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
## Stylebox used to draw the tab, this replaces the texture
@export var stylebox_tab_selected: StyleBox :
	set(value):
		stylebox_tab_selected = value
		if value and not value.changed.is_connected(update_tabs):
			value.changed.connect(update_tabs)
		update_tabs()
## Stylebox used to draw the tab, this replaces the texture
@export var stylebox_tab_unselected: StyleBox :
	set(value):
		stylebox_tab_unselected = value
		if value and not value.changed.is_connected(update_tabs):
			value.changed.connect(update_tabs)
		update_tabs()
## Stylebox used to draw the tab, this replaces the texture
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
var button_left_rect: Rect2
var button_right_rect: Rect2
var button_left_disabled: bool = false
var button_right_disabled: bool = true
var offset: float = 0.0
var tabs_data: Array[Dictionary] # Dictionary = {"rect" : rect2, "index" : int, "visible" : bool, "text" : String}

var force_refresh_tabs_timer: float = 0.0


## Name for each tab. If a tab does not have a name defined here, the default name will be used.
var tabs_names: Array = []


signal tab_changed(index: int)


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
				clear()
				for tab in default_tabs:
					add_tab(tab)
				refresh()
		
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if current_button_pressed == 0 and !button_left_disabled:
			move_tabs(delta, 1)
		elif current_button_pressed == 1 and !button_right_disabled:
			move_tabs(delta, -1)


func move_tabs(delta: float, direction: int) -> void:
	if tabs_data.size() == 0:
		return
	var width = size.x - arrow_buttons_size.x * 2 + separator
	offset += tabs_movement_speed * delta * direction
	if offset >= 0:
		offset = 0
		button_left_disabled = true
		button_right_disabled = false
	else:
		button_left_disabled = false
		var x = -(tabs_data[-1].rect.position.x + tabs_data[-1].rect.size.x) + width - (arrow_buttons_size.x + separator)
		if offset < x:
			offset = x
			button_right_disabled = true
		else:
			button_right_disabled = false
	
	for data in tabs_data:
		var rect = data.rect
		rect.position.x += offset
		if rect.position.x + rect.size.x < 0:
			data.visible = false
		elif rect.position.x + rect.size.x >= width:
			data.visible = false
		else:
			data.visible = true
	
	queue_redraw()


func _on_gui_input(event: InputEvent) -> void:
	if using_arrows:
		if event is InputEventMouseMotion:
			mouse_hover_button_index = -1
			tab_hover_index = -1
			if button_left_rect.has_point(event.position):
				mouse_hover_button_index = 0
				mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			elif button_right_rect.has_point(event.position):
				mouse_hover_button_index = 1
				mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			elif current_button_pressed == -1:
				tab_hover_index = -1
				for data in tabs_data:
					var rect = data.rect
					rect.position.x += offset
					if rect.has_point(event.position):
						tab_hover_index = data.index
						mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
						break
			queue_redraw()
		elif event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT:
				current_button_pressed = -1
				if  event.is_pressed():
					if button_left_rect.has_point(event.position):
						current_button_pressed = 0
						mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
					elif button_right_rect.has_point(event.position):
						current_button_pressed = 1
						mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
					else:
						for data in tabs_data:
							var rect = data.rect
							rect.position.x += offset
							if rect.has_point(event.position):
								selected_tab = data.index
								tab_changed.emit(selected_tab)
								break
				queue_redraw()
			elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
				move_tabs(get_process_delta_time(), 1)
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				move_tabs(get_process_delta_time(), -1)
				
	else:
		if event is InputEventMouseMotion:
			mouse_hover_button_index = -1
			tab_hover_index = -1
			for data in tabs_data:
				var rect = data.rect
				rect.position.x += offset
				if rect.has_point(event.position):
					tab_hover_index = data.index
					mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
					break
			queue_redraw()
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			current_button_pressed = -1
			for data in tabs_data:
				var rect = data.rect
				rect.position.x += offset
				if rect.has_point(event.position):
					selected_tab = data.index
					tab_changed.emit(selected_tab)
					break
			queue_redraw()


func refresh():
	update_tabs(tabs_data.size(), selected_tab)


func clear() -> void:
	tabs_data.clear()
	tabs_names.clear()


func update_tabs(current_tabs: int = 0, index: int = 0, force_selection: bool = false) -> void:
	tabs_data.clear()
	if default_tabs:
		for i in default_tabs.size():
			var tab_text: String = default_tabs[i]
			add_tab(tab_text, i)
	else:
		for i in current_tabs:
			var tab_text: String = tab_name_base + " " + str(i + 1) if tabs_names.size() <= i else tabs_names[i]
			add_tab(tab_text, i)
	
	move_tabs(0, 0)
	
	select(index, force_selection)


func add_tab(tab_text: String, index: int = -1) -> void:
	var font: Font = current_font if current_font else get_theme_default_font()
	var s: int = font_size if font_size else get_theme_default_font_size()
	var align = HORIZONTAL_ALIGNMENT_CENTER
	var width = size.x - arrow_buttons_size.x * 2 + separator
	var offset = 0
	custom_minimum_size = minimum_tab_size
	using_arrows = false
	

	var current_x = 0
	if tabs_data.size() > 0:
		for i in tabs_data.size():
			var current_text_width = font.get_string_size(tabs_data[i].text, align, -1, s).x
			current_text_width += tab_name_margins * 2
			current_text_width = max(current_text_width, minimum_tab_size.x)
			current_x += current_text_width
	var rect = Rect2(Vector2(current_x, 0), Vector2.ZERO)

	var current_text_size = font.get_string_size(tab_text, align, -1, s)
	current_text_size.x += tab_name_margins * 2
	current_text_size.x = max(current_text_size.x, minimum_tab_size.x)
	current_text_size.y = max(current_text_size.y, minimum_tab_size.y)
	custom_minimum_size.x = max(current_text_size.x, custom_minimum_size.x)
	rect.size = current_text_size
	
	tabs_data.append({
		"rect" : rect,
		"index": index if index != -1 else tabs_data.size(),
		"visible": rect.position.x + rect.size.x < width,
		"text": tab_text.strip_edges()
	})
	
	if !using_arrows and !tabs_data[-1].visible:
		using_arrows = true
	
	if using_arrows:
		button_left_rect = Rect2(Vector2(width, 0), arrow_buttons_size)
		button_right_rect = Rect2(Vector2(width + arrow_buttons_size.x  + separator, 0), arrow_buttons_size)
	
	if tabs_names.size() < tabs_data.size():
		tabs_names.resize(tabs_data.size())
		tabs_names[-1] = tab_text


func _on_tab_changed(_index: int) -> void:
	ensure_current_is_visible()


func select(index: int, force_selection: bool = false) -> void:
	var last_index = selected_tab
	selected_tab = index
	ensure_current_is_visible()
	if last_index != selected_tab or force_selection:
		tab_changed.emit(selected_tab)


func ensure_current_is_visible() -> void:
	if selected_tab < tabs_data.size():
		var selected = tabs_data[selected_tab]
		var rect = selected.rect
		rect.position.x += offset
		if rect.position.x < 0:
			offset -= rect.position.x
		else:
			var width = size.x - arrow_buttons_size.x * 2 + separator
			var tab_right_edge = rect.position.x + rect.size.x
			if tab_right_edge > width:
				offset -= tab_right_edge - width
		
		move_tabs(0, 0)
		queue_redraw()


func _draw() -> void:
	draw_rect(get_rect(), background_color)
	
	var font: Font = current_font if current_font else get_theme_default_font()
	var s: int = font_size if font_size else get_theme_default_font_size()
	var align = HORIZONTAL_ALIGNMENT_CENTER
	var color: Color
	var outline_color: Color
	var texture: Variant
	var rect: Rect2
	var offset_y: int

	for data in tabs_data:
		var data_pass: bool = false
		var draw_partial_mode: bool = false
		if data.visible:
			data_pass = true
		elif data.rect.position.x + offset < button_left_rect.position.x - 5 and data.rect.position.x + offset + data.rect.size.x >= button_left_rect.position.x - 5:
			data_pass = true
			draw_partial_mode = true

		if data_pass:
			if data.index != selected_tab:
				if tab_hover_index == data.index:
					texture = tab_hover if not stylebox_tab_hover else stylebox_tab_hover
				else:
					texture = tab_unselected if not stylebox_tab_unselected else stylebox_tab_unselected
				color = unselected_color
				outline_color = unselected_outline_color
				offset_y = text_unselected_offset_y
			else:
				color = selected_color
				texture = tab_selected if not stylebox_tab_selected else stylebox_tab_selected
				outline_color = selected_outline_color
				offset_y = text_selected_offset_y
			rect = data.rect
			if draw_partial_mode:
				var x = button_left_rect.position.x - (rect.position.x + offset) - 5
				if x > 0:
					rect.size.x = x
				else:
					continue
			rect.position.x += offset
			if texture is Texture:
				draw_texture_rect(texture, rect, false)
			elif texture is StyleBox:
				(texture as StyleBox).draw(get_canvas_item(), rect)
			var p = data.rect.position
			p.x += tab_name_margins + offset
			p.y += font.get_ascent() + offset_y
			var width: int
			if !draw_partial_mode:
				width = data.rect.size.x - (tab_name_margins * 2)
			else:
				width = button_left_rect.position.x - p.x - 5 - tab_name_margins
				if width < 0:
					width = 1
			draw_string(font, p, data.text, align, width, s, color)
			if font_size > 0:
				draw_string_outline(font, p, data.text, align, width, s, font_size, color)
	
	if using_arrows:
		if button_left_disabled:
			texture = arrow_left_disabled
		elif mouse_hover_button_index == 0:
			texture = arrow_left_hover
		else:
			texture = arrow_left_normal
		rect = button_left_rect
		rect.position.y += arrows_offset_y
		draw_texture_rect(texture, rect, false)
		if button_right_disabled:
			texture = arrow_right_disabled
		elif mouse_hover_button_index == 1:
			texture = arrow_right_hover
		else:
			texture = arrow_right_normal
		rect = button_right_rect
		rect.position.y += arrows_offset_y
		draw_texture_rect(texture, rect, false)
	
	if clip_tabs:
		RenderingServer.canvas_item_set_clip(get_canvas_item(),true)
	else:
		RenderingServer.canvas_item_set_clip(get_canvas_item(),false)
