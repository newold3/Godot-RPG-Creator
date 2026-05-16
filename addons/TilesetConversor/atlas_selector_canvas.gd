@tool
class_name AtlasSelectorCanvas
extends Control

#region ATLAS_CANVAS

## Reference to the ScrollContainer holding the Canvas
@export var scroll_container: ScrollContainer

## Width and height of a single grid cell
@export var tile_size: Vector2i = Vector2i(32, 32)

## Type of the autotile currently selected in the UI
@export var current_autotile_type: AutotileType = AutotileType.EXTENDED

## Color of the grid lines
@export var grid_color: Color = Color(1.0, 1.0, 1.0, 0.3)

## Color of the blinking selection cursor
@export var cursor_color: Color = Color(1.0, 0.8, 0.0, 0.8)

## Reference to the UI Label used to display the current hovered tile coordinate
@export var info_label: Label

## Reference to the UI Label used to display contextual help per mode
@export var help_label: Label


enum AutotileType {
	EXTENDED,
	COMPACT,
	WALL,
	SINGLE
}

var current_texture: Texture2D
var grid_canvas: Control
var cursor_canvas: Control
var blink_timer: Timer

var is_cursor_visible: bool = true
var is_mouse_inside: bool = false
var snapped_mouse_pos: Vector2i = Vector2i.ZERO

var is_panning: bool = false
var _has_dragged_while_panning: bool = false
var zoom_level: float = 1.0

var is_selecting_multiple: bool = false
var drag_start_pos: Vector2i = Vector2i.ZERO
var drag_end_pos: Vector2i = Vector2i.ZERO
var is_animation_mode: bool = false


signal autotile_selected(rect: Rect2i)

signal single_tiles_selected(rects: Array[Rect2i])

signal autotile_anim_frame_selected(rect: Rect2i)



## Initializes the canvas layers, signals, and the blink timer
func _ready() -> void:
	if is_instance_valid(scroll_container):
		scroll_container.resized.connect(_on_scroll_container_resized)
		
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
		
	grid_canvas = Control.new()
	grid_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	grid_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid_canvas.draw.connect(_on_grid_canvas_draw)
	add_child(grid_canvas)
	
	cursor_canvas = Control.new()
	cursor_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	cursor_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cursor_canvas.draw.connect(_on_cursor_canvas_draw)
	add_child(cursor_canvas)
	
	blink_timer = Timer.new()
	blink_timer.wait_time = 0.4
	blink_timer.autostart = true
	blink_timer.timeout.connect(_on_blink_timer_timeout)
	add_child(blink_timer)
	
	_update_help_text()



## Draws the main underlying atlas texture strictly scaled to the zoom level
func _draw() -> void:
	if current_texture:
		var tex_size: Vector2 = current_texture.get_size()
		draw_texture_rect(current_texture, Rect2(Vector2.ZERO, tex_size * zoom_level), false)



## Draws the grid lines applying a transform to keep coordinate logic simple
func _on_grid_canvas_draw() -> void:
	if not current_texture or tile_size.x <= 0 or tile_size.y <= 0:
		return
		
	var tex_size: Vector2 = current_texture.get_size()
	var exact_scale: Vector2 = Vector2(zoom_level, zoom_level)
	
	grid_canvas.draw_set_transform(Vector2.ZERO, 0.0, exact_scale)
	
	for x in range(0, int(tex_size.x) + 1, tile_size.x):
		grid_canvas.draw_line(Vector2(x, 0), Vector2(x, tex_size.y), grid_color, 1.0 / zoom_level)
		
	for y in range(0, int(tex_size.y) + 1, tile_size.y):
		grid_canvas.draw_line(Vector2(0, y), Vector2(tex_size.x, y), grid_color, 1.0 / zoom_level)
		
	grid_canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)



## Draws the blinking selection cursor applying a transform and validity checks
func _on_cursor_canvas_draw() -> void:
	if not current_texture or not is_mouse_inside:
		return
		
	var exact_scale: Vector2 = Vector2(zoom_level, zoom_level)
	cursor_canvas.draw_set_transform(Vector2.ZERO, 0.0, exact_scale)
	
	var active_color: Color = cursor_color
	if is_animation_mode:
		active_color = Color(0.2, 1.0, 0.4, 0.8)
		
	if is_selecting_multiple and current_autotile_type == AutotileType.SINGLE and not is_animation_mode:
		var start_tile: Vector2i = drag_start_pos / tile_size
		var end_tile: Vector2i = drag_end_pos / tile_size
		var min_x: int = mini(start_tile.x, end_tile.x)
		var min_y: int = mini(start_tile.y, end_tile.y)
		var max_x: int = maxi(start_tile.x, end_tile.x)
		var max_y: int = maxi(start_tile.y, end_tile.y)
		
		var rect_pos: Vector2 = Vector2(min_x, min_y) * Vector2(tile_size)
		var rect_size: Vector2 = Vector2(max_x - min_x + 1, max_y - min_y + 1) * Vector2(tile_size)
		var drag_rect: Rect2 = Rect2(rect_pos, rect_size)
		
		var drag_color: Color = Color(0.2, 0.8, 1.0, 0.8)
		cursor_canvas.draw_rect(drag_rect, drag_color, false, 2.0 / zoom_level)
		cursor_canvas.draw_rect(drag_rect, drag_color * Color(1.0, 1.0, 1.0, 0.2), true)
		
	elif is_cursor_visible:
		var dimensions: Vector2i = _get_cursor_dimensions()
		var cursor_size: Vector2 = Vector2(dimensions) * Vector2(tile_size)
		var rect: Rect2 = Rect2(Vector2(snapped_mouse_pos), cursor_size)
		
		if _is_valid_cursor_position(snapped_mouse_pos, dimensions):
			cursor_canvas.draw_rect(rect, active_color, false, 2.0 / zoom_level)
			cursor_canvas.draw_rect(rect, active_color * Color(1.0, 1.0, 1.0, 0.2), true)
		else:
			var error_color: Color = Color(1.0, 0.0, 0.0, 0.8)
			cursor_canvas.draw_rect(rect, error_color, false, 2.0 / zoom_level)
			cursor_canvas.draw_rect(rect, error_color * Color(1.0, 1.0, 1.0, 0.2), true)
			
	cursor_canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)



## Handles user inputs perfectly matching the reference panning, zoom logic, and new selections
func _gui_input(event: InputEvent) -> void:
	if not current_texture:
		return
		
	var tex_size: Vector2 = current_texture.get_size()
	
	if event is InputEventMouseMotion:
		if is_panning and is_instance_valid(scroll_container):
			_has_dragged_while_panning = true
			var new_size: Vector2 = tex_size * zoom_level
			var max_scroll_x: float = maxf(0.0, new_size.x - scroll_container.size.x)
			var max_scroll_y: float = maxf(0.0, new_size.y - scroll_container.size.y)
			
			scroll_container.scroll_horizontal = int(clamp(scroll_container.scroll_horizontal - event.relative.x, 0.0, max_scroll_x))
			scroll_container.scroll_vertical = int(clamp(scroll_container.scroll_vertical - event.relative.y, 0.0, max_scroll_y))
			
		var local_pos: Vector2 = event.position
		var scaled_pos: Vector2 = local_pos / zoom_level
		
		if is_selecting_multiple and not is_animation_mode:
			drag_end_pos = _get_snapped_pos_from_scaled(scaled_pos)
			cursor_canvas.queue_redraw()
		else:
			_update_cursor_position(scaled_pos)
			
	elif event is InputEventMouseButton:
		var scaled_pos: Vector2 = event.position / zoom_level
		var current_snapped: Vector2i = _get_snapped_pos_from_scaled(scaled_pos)
		
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			if event.pressed:
				is_panning = true
				_has_dragged_while_panning = false
			else:
				is_panning = false
				if not _has_dragged_while_panning:
					_update_zoom(1.0, scaled_pos)
					
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.ctrl_pressed and event.pressed:
			_update_zoom(zoom_level + 0.25, scaled_pos)
			get_viewport().set_input_as_handled()
			
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.ctrl_pressed and event.pressed:
			_update_zoom(zoom_level - 0.25, scaled_pos)
			get_viewport().set_input_as_handled()
			
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if is_animation_mode:
					snapped_mouse_pos = current_snapped
					_try_extract_selection(true)
				elif current_autotile_type == AutotileType.SINGLE:
					is_selecting_multiple = true
					drag_start_pos = current_snapped
					drag_end_pos = current_snapped
					cursor_canvas.queue_redraw()
				else:
					snapped_mouse_pos = current_snapped
					_try_extract_selection(false)
			else:
				if is_selecting_multiple:
					is_selecting_multiple = false
					_try_extract_multiple_selection()
					cursor_canvas.queue_redraw()



## Toggles the cursor visibility to create a blink effect
func _on_blink_timer_timeout() -> void:
	is_cursor_visible = !is_cursor_visible
	cursor_canvas.queue_redraw()



## Flags the cursor to be drawn when mouse enters the control limits
func _on_mouse_entered() -> void:
	is_mouse_inside = true
	cursor_canvas.queue_redraw()



## Hides the cursor and cleans the external label when mouse leaves
func _on_mouse_exited() -> void:
	is_mouse_inside = false
	is_selecting_multiple = false
	
	if is_instance_valid(info_label):
		info_label.text = ""
		info_label.visible = false
		
	cursor_canvas.queue_redraw()



## Calculates the minimum dynamic zoom ensuring it fits inside the scroll container
func _get_min_zoom() -> float:
	if not current_texture or not is_instance_valid(scroll_container):
		return 1.0
		
	var tex_size: Vector2 = current_texture.get_size()
	
	if tex_size.x == 0 or tex_size.y == 0:
		return 1.0
		
	var available: Vector2 = scroll_container.size
	
	if available.x <= 0 or available.y <= 0:
		return 1.0
		
	var scale_x: float = available.x / tex_size.x
	var scale_y: float = available.y / tex_size.y
	
	return maxf(scale_x, scale_y)



## Updates the zoom level adjusting the size and focusing via scroll bars
func _update_zoom(new_zoom: float, focus_local_pos: Vector2 = Vector2(-1, -1), force_update: bool = false) -> void:
	if not current_texture: return
	
	var min_z: float = _get_min_zoom()
	var old_zoom: float = zoom_level
	
	zoom_level = clampf(new_zoom, min_z, min_z + 5.0)
	
	if zoom_level == old_zoom and not force_update:
		return
		
	var tex_size: Vector2 = current_texture.get_size()
	var focus: Vector2 = focus_local_pos
	
	if focus == Vector2(-1, -1) and is_instance_valid(scroll_container):
		var visible_center: Vector2 = Vector2(scroll_container.scroll_horizontal, scroll_container.scroll_vertical) + (scroll_container.size / 2.0)
		focus = visible_center / old_zoom
		
	var zoom_diff: float = zoom_level - old_zoom
	var target_scroll_x: float = scroll_container.scroll_horizontal + (focus.x * zoom_diff) if is_instance_valid(scroll_container) else 0.0
	var target_scroll_y: float = scroll_container.scroll_vertical + (focus.y * zoom_diff) if is_instance_valid(scroll_container) else 0.0
	var new_size: Vector2 = tex_size * zoom_level
	
	custom_minimum_size = new_size
	size = new_size
	
	if is_instance_valid(scroll_container):
		var h_bar: ScrollBar = scroll_container.get_h_scroll_bar()
		var v_bar: ScrollBar = scroll_container.get_v_scroll_bar()
		
		if h_bar: h_bar.max_value = maxf(h_bar.max_value, new_size.x)
		if v_bar: v_bar.max_value = maxf(v_bar.max_value, new_size.y)
		
		var max_scroll_x: float = maxf(0.0, new_size.x - scroll_container.size.x)
		var max_scroll_y: float = maxf(0.0, new_size.y - scroll_container.size.y)
		
		scroll_container.scroll_horizontal = int(clamp(target_scroll_x, 0.0, max_scroll_x))
		scroll_container.scroll_vertical = int(clamp(target_scroll_y, 0.0, max_scroll_y))
		
	queue_redraw()
	grid_canvas.queue_redraw()
	cursor_canvas.queue_redraw()



## Enforces the minimum zoom level dynamically when the container is resized
func _on_scroll_container_resized() -> void:
	if not current_texture:
		return
		
	var min_z: float = _get_min_zoom()
	
	if zoom_level < min_z:
		_update_zoom(min_z, Vector2(-1, -1), true)



## Computes the snapped position purely from a scaled coordinate
func _get_snapped_pos_from_scaled(scaled_local_mouse_pos: Vector2) -> Vector2i:
	var tile_coord: Vector2i = Vector2i(
		floor(scaled_local_mouse_pos.x / tile_size.x),
		floor(scaled_local_mouse_pos.y / tile_size.y)
	)
	
	return tile_coord * tile_size



## Updates the snapped position of the cursor and the info label
func _update_cursor_position(scaled_local_mouse_pos: Vector2) -> void:
	var new_snapped_pos: Vector2i = _get_snapped_pos_from_scaled(scaled_local_mouse_pos)
	
	if is_instance_valid(info_label):
		var tile_coord: Vector2i = new_snapped_pos / tile_size
		info_label.text = "Tile " + str(tile_coord.x) + ", " + str(tile_coord.y)
		info_label.visible = true
		
	if new_snapped_pos != snapped_mouse_pos:
		snapped_mouse_pos = new_snapped_pos
		is_cursor_visible = true
		blink_timer.start()
		cursor_canvas.queue_redraw()



## Verifies if a given snapped position and dimensions are fully inside the texture bounds
func _is_valid_cursor_position(pos: Vector2i, dimensions: Vector2i) -> bool:
	if not current_texture:
		return false
		
	var cursor_size_px: Vector2i = dimensions * tile_size
	var rect: Rect2i = Rect2i(pos, cursor_size_px)
	var tex_rect: Rect2i = Rect2i(Vector2i.ZERO, current_texture.get_size())
	
	return tex_rect.encloses(rect)



## Emits the corresponding selection signal if the current cursor bounds are valid
func _try_extract_selection(force_anim: bool) -> void:
	var dimensions: Vector2i = _get_cursor_dimensions()
	
	if _is_valid_cursor_position(snapped_mouse_pos, dimensions):
		var cursor_size_px: Vector2i = dimensions * tile_size
		var selection_rect: Rect2i = Rect2i(snapped_mouse_pos, cursor_size_px)
		
		if force_anim:
			autotile_anim_frame_selected.emit(selection_rect)
		elif current_autotile_type == AutotileType.SINGLE:
			var rects: Array[Rect2i] = [selection_rect]
			single_tiles_selected.emit(rects)
		else:
			autotile_selected.emit(selection_rect)



## Processes the multiple drag selection and extracts valid single tiles
func _try_extract_multiple_selection() -> void:
	var start_tile: Vector2i = drag_start_pos / tile_size
	var end_tile: Vector2i = drag_end_pos / tile_size
	var min_x: int = mini(start_tile.x, end_tile.x)
	var min_y: int = mini(start_tile.y, end_tile.y)
	var max_x: int = maxi(start_tile.x, end_tile.x)
	var max_y: int = maxi(start_tile.y, end_tile.y)
	
	var rects: Array[Rect2i] = []
	
	for x in range(min_x, max_x + 1):
		for y in range(min_y, max_y + 1):
			var pos: Vector2i = Vector2i(x, y) * tile_size
			if _is_valid_cursor_position(pos, Vector2i(1, 1)):
				rects.append(Rect2i(pos, tile_size))
				
	if rects.size() > 0:
		single_tiles_selected.emit(rects)



## Loads a new texture into the canvas and resets dimensions correctly via math
func set_texture(tex: Texture2D) -> void:
	current_texture = tex
	zoom_level = _get_min_zoom()
	_update_zoom(zoom_level, Vector2.ZERO, true)



## Clears the canvas, resets dimensions, and halts background processes
func clear() -> void:
	current_texture = null
	
	custom_minimum_size = Vector2.ZERO
	size = Vector2.ZERO
	
	zoom_level = 1.0
	is_panning = false
	_has_dragged_while_panning = false
	is_mouse_inside = false
	snapped_mouse_pos = Vector2i.ZERO
	is_selecting_multiple = false
	
	if is_instance_valid(blink_timer):
		blink_timer.stop()
		is_cursor_visible = false
		
	if is_instance_valid(info_label):
		info_label.text = ""
		
	queue_redraw()
	grid_canvas.queue_redraw()
	cursor_canvas.queue_redraw()



## Updates the working grid dimensions and autotile type dynamically from the parent window
func update_grid_and_mode(new_tile_size: Vector2i, new_mode: AutotileType) -> void:
	tile_size = new_tile_size
	current_autotile_type = new_mode
	
	_update_help_text()
	queue_redraw()
	grid_canvas.queue_redraw()
	cursor_canvas.queue_redraw()



## Refreshes the external help label describing the current allowed mouse actions
func _update_help_text() -> void:
	if not is_instance_valid(help_label):
		return
		
	if is_animation_mode:
		help_label.text = "ANIMATION MODE: Click to add current selection as an animation frame"
	else:
		match current_autotile_type:
			AutotileType.SINGLE:
				help_label.text = "Click and drag to select standalone tiles (CTRL Toggled Animation)"
			AutotileType.EXTENDED, AutotileType.COMPACT, AutotileType.WALL:
				help_label.text = "Click to extract a standard autotile (CTRL Toggled Animation)"



## Returns the expected column and row count for the current autotile type
func _get_cursor_dimensions() -> Vector2i:
	match current_autotile_type:
		AutotileType.EXTENDED:
			return Vector2i(3, 4)
		AutotileType.COMPACT:
			return Vector2i(2, 3)
		AutotileType.WALL:
			return Vector2i(2, 2)
		AutotileType.SINGLE:
			return Vector2i(1, 1)
	return Vector2i(1, 1)

#endregion
