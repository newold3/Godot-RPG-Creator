@tool
extends Window

enum SnapMode {SNAP_NONE, SNAP_PIXEL, SNAP_GRID, SNAP_COLUMNS_AND_ROWS, SNAP_AUTO_CROP}

const HANDLES = preload("res://addons/CustomControls/Images/handles.png")

var handle_rects = {
	"top_left": Rect2i(0, 0, 20, 20),
	"top": Rect2i(20, 0, 20, 20),
	"top_right": Rect2i(40, 0, 20, 20),
	"left": Rect2i(0, 20, 20, 20),
	"right": Rect2i(40, 20, 20, 20),
	"bottom_left": Rect2i(0, 40, 20, 20),
	"bottom": Rect2i(20, 40, 20, 20),
	"bottom_right": Rect2i(40, 40, 20, 20),
}

var edited_object: Object
var draw_ofs: Vector2 = Vector2.ZERO
var rect: Rect2
var moving: bool = false
var drawing_rect: bool = false
var mouse_start: Vector2 = Vector2.ZERO
var draw_rect_start: Vector2 = Vector2.ZERO
var busy: bool = false
var snap_mode: int = SnapMode.SNAP_NONE
var draw_zoom: float = 1.0
var snap_offset: Vector2i = Vector2i.ZERO
var snap_separation: Vector2i = Vector2i.ZERO
var snap_step: Vector2i = Vector2i(32, 32)
var column_and_rows: Vector2i = Vector2i(1, 1)

var backup_snap_options = {
	"snap_step": Vector2i(32, 32),
	"snap_offset": Vector2i.ZERO,
	"snap_separation": Vector2i.ZERO
}

var resizing_rect: bool = false
var current_resize: String
var resize_rect_start: Rect2 = Rect2()
var resize_mouse_start_tex: Vector2 = Vector2.ZERO
var resize_start_tl_cell: Vector2i = Vector2i.ZERO
var resize_start_br_cell: Vector2i = Vector2i.ZERO
var moving_rect: bool = false
var rect_start_pos: Vector2
var mouse_start_pos: Vector2
var auto_crop_rects: Array[Rect2] = []
var just_warped: bool = false

@onready var texture_preview: Control = %EditedTexture
@onready var grid: Control = %Grid
@onready var hscroll: HScrollBar = %HScrollBar
@onready var vscroll: VScrollBar = %VScrollBar

signal updated()
signal region_changed(region: Rect2)


#region Lifecycle Methods

## Initializes the dialog and connects signals.
func _ready():
	close_requested.connect(queue_free)
	
	grid.gui_input.connect(_on_grid_gui_input)
	hscroll.value_changed.connect(_scroll_changed)
	vscroll.value_changed.connect(_scroll_changed)
	texture_preview.draw.connect(_on_texture_preview_draw)
	grid.draw.connect(_on_grid_draw)
	texture_preview.resized.connect(update_cursor)
	updated.connect(
		func():
			update_cursor()
			texture_preview.queue_redraw()
			grid.queue_redraw()
	)
	set_default_values()


## Sets default values for the region editor based on the FileCache.
func set_default_values() -> void:
	var options = FileCache.options.get("region_dialog_options", {})
	snap_mode = options.get("snap_mode", SnapMode.SNAP_GRID)
	draw_zoom = options.get("draw_zoom", 1.0)
	snap_offset = options.get("snap_offset", Vector2i.ZERO)
	snap_separation = options.get("snap_separation", Vector2i.ZERO)
	snap_step = options.get("snap_step", Vector2i(32, 32))
	column_and_rows = options.get("column_and_rows", Vector2i.ONE)
	var merge_close_rects = options.get("merge_close_rects", true)
	var epsilon_val = options.get("epsilon_value", 2.0)
	
	if not FileCache.options.has("region_dialog_options"):
		FileCache.options.region_dialog_options = {
			"snap_mode": snap_mode,
			"draw_zoom": draw_zoom,
			"snap_offset": snap_offset,
			"snap_separation": snap_separation,
			"snap_step": snap_step,
			"column_and_rows": column_and_rows,
			"merge_close_rects": merge_close_rects,
			"epsilon_value": epsilon_val,
		}
	
	backup_snap_options.snap_step = snap_step
	backup_snap_options.snap_offset = snap_offset
	backup_snap_options.snap_separation = snap_separation
	
	var current_mode_index = snap_mode
	updated.emit()
	
	busy = true
	%Columns.value = column_and_rows.x
	%Rows.value = column_and_rows.y
	%OffsetX.value = snap_offset.x
	%OffsetY.value = snap_offset.y
	%StepX.value = snap_step.x
	%StepY.value = snap_step.y
	%SeparationX.value = snap_separation.x
	%SeparationY.value = snap_separation.y
	%AdjustmentMode.select(current_mode_index)
	%MergeCloseCheckBox.button_pressed = merge_close_rects
	%MergeCloseCheckBox.visible = (snap_mode == SnapMode.SNAP_AUTO_CROP)
	%EpsilonSpinBox.value = epsilon_val
	%EpsilonLabel.visible = (snap_mode == SnapMode.SNAP_AUTO_CROP)
	%EpsilonSpinBox.visible = (snap_mode == SnapMode.SNAP_AUTO_CROP)
	busy = false

	%AdjustmentMode.item_selected.emit.call_deferred(current_mode_index)


## Saves the current configuration to FileCache before closing.
func _save_config() -> void:
	FileCache.options.region_dialog_options = {
		"snap_mode": snap_mode,
		"draw_zoom": draw_zoom,
		"snap_offset": snap_offset,
		"snap_separation": snap_separation,
		"snap_step": snap_step,
		"column_and_rows": column_and_rows,
		"merge_close_rects": %MergeCloseCheckBox.button_pressed,
		"epsilon_value": %EpsilonSpinBox.value,
	}


#endregion


#region Public API

## Configures the editor with the given object and region.
func edit(object: Object, region: Rect2):
	edited_object = object
	if region.has_area():
		rect = region
		var texture = _get_texture()
		if texture and rect.has_area():
			var texture_size = texture.get_size()
			
			var columns = texture_size.x / rect.size.x
			var rows = texture_size.y / rect.size.y
			
			var is_divisible_x = abs(columns - round(columns)) < 0.001
			var is_divisible_y = abs(rows - round(rows)) < 0.001
			
			if is_divisible_x and is_divisible_y and columns >= 1 and rows >= 1:
				var int_columns = int(round(columns))
				var int_rows = int(round(rows))
				
				# Update internal variables directly to ensure synchronization
				column_and_rows = Vector2i(int_columns, int_rows)
				snap_step = Vector2i(max(1, int(rect.size.x)), max(1, int(rect.size.y)))
				snap_offset = Vector2i.ZERO
				snap_separation = Vector2i.ZERO
				
				FileCache.options.region_dialog_options.column_and_rows = column_and_rows
				FileCache.options.region_dialog_options.snap_step = snap_step
				FileCache.options.region_dialog_options.snap_offset = snap_offset
				FileCache.options.region_dialog_options.snap_separation = snap_separation
				
				%OffsetX.set_deferred("value", 0)
				%OffsetY.set_deferred("value", 0)
				%StepX.set_deferred("value", rect.size.x)
				%StepY.set_deferred("value", rect.size.y)
				%Columns.set_deferred("value", int_columns)
				%Rows.set_deferred("value", int_rows)
				
				_on_adjustment_mode_item_selected(3)
			else:
				_on_adjustment_mode_item_selected(1)

			if rect:
				var region_center = rect.position + rect.size / 2
				region_center.x = snappedi(region_center.x, snap_step.x)
				region_center.y = snappedi(region_center.y, snap_step.y)
				draw_ofs = region_center - texture_size / 2
				
				if is_instance_valid(self):
					call_deferred("force_change_draw_offset", Vector2.ZERO)
		else:
			_on_adjustment_mode_item_selected(1)
		
	updated.emit()
	center_and_fit_texture()


#endregion


#region Rendering Methods

## Draws the grid lines based on the snap settings.
func _on_grid_draw() -> void:
	var grid_size = grid.size
	var line_color = Color(1, 1, 1, 0.08)
	
	var texture = _get_texture()
	if not texture:
		return
	
	var tex_size = texture.get_size()
	var draw_size = tex_size * draw_zoom
	var preview_size = texture_preview.size

	if (snap_mode == SnapMode.SNAP_GRID or snap_mode == SnapMode.SNAP_COLUMNS_AND_ROWS) and draw_zoom > 0.35:
		var cell_total = Vector2(snap_step.x + snap_separation.x, snap_step.y + snap_separation.y)
		var cell_total_draw = cell_total * draw_zoom
		
		if cell_total_draw.x < 2.0 and cell_total_draw.y < 2.0:
			return
		
		var start_position = (preview_size - draw_size) / 2 - draw_ofs * draw_zoom + snap_offset * draw_zoom
		var lines = PackedVector2Array()
		
		if cell_total_draw.x >= 2.0:
			var cells_right = int(ceil((grid_size.x - start_position.x) / cell_total_draw.x)) + 1
			var cells_left = int(ceil(start_position.x / cell_total_draw.x)) + 1
			
			cells_right = min(cells_right, 500)
			cells_left = min(cells_left, 500)
			
			for i in range(-cells_left, cells_right + 1):
				var x = start_position.x + i * cell_total_draw.x
				if x >= 0 and x <= grid_size.x:
					lines.append(Vector2(x, 0))
					lines.append(Vector2(x, grid_size.y))
		
		if cell_total_draw.y >= 2.0:
			var cells_down = int(ceil((grid_size.y - start_position.y) / cell_total_draw.y)) + 1
			var cells_up = int(ceil(start_position.y / cell_total_draw.y)) + 1
			
			cells_down = min(cells_down, 500)
			cells_up = min(cells_up, 500)
			
			for j in range(-cells_up, cells_down + 1):
				var y = start_position.y + j * cell_total_draw.y
				if y >= 0 and y <= grid_size.y:
					lines.append(Vector2(0, y))
					lines.append(Vector2(grid_size.x, y))
		
		if lines.size() > 0:
			grid.draw_multiline(lines, line_color, 1.0)


## Draws the texture preview and auto crop rects if applicable.
func _on_texture_preview_draw():
	var texture = _get_texture()
	if not texture:
		return
	
	var preview_size = texture_preview.size
	var tex_size = texture.get_size()
	var draw_size = tex_size * draw_zoom
	var offset = (preview_size - draw_size) / 2 - draw_ofs * draw_zoom
	var texture_rect = Rect2(offset, draw_size)
	
	texture_preview.draw_texture_rect(texture, texture_rect, false)
	texture_preview.draw_rect(Rect2(offset, draw_size), Color(1, 1, 1, 0.4), false)
	
	if snap_mode == SnapMode.SNAP_AUTO_CROP:
		for r in auto_crop_rects:
			var scaled_rect = Rect2(offset + r.position * draw_zoom, r.size * draw_zoom)
			var color = Color(0.1, 0.8, 0.1, 0.6) if r == rect else Color(1.0, 0.9, 0.1, 0.3)
			texture_preview.draw_rect(scaled_rect, color, false, 1.5)


## Updates the cursor size and visibility based on the current selection.
func update_cursor() -> void:
	if not is_instance_valid(self) or not is_node_ready():
		return
	var texture = _get_texture()
	if not texture or not rect:
		%Cursor.visible = false
		return
	
	var preview_size = texture_preview.size
	var tex_size = texture.get_size()
	var draw_size = tex_size * draw_zoom
	var offset = (preview_size - draw_size) / 2 - draw_ofs * draw_zoom
	
	%Cursor.visible = true
	%Cursor.position = offset + rect.position * draw_zoom
	%Cursor.size = rect.size * draw_zoom
	
	var is_auto_crop = (snap_mode == SnapMode.SNAP_AUTO_CROP)
	
	for child in %Cursor.get_children():
		if child is Control:
			child.visible = not is_auto_crop
			
	var shape = Control.CURSOR_ARROW if is_auto_crop else Control.CURSOR_CROSS
	texture_preview.mouse_default_cursor_shape = shape
	grid.mouse_default_cursor_shape = shape
	%Cursor.mouse_default_cursor_shape = shape


#endregion


#region Interaction Handling

## Main input handler for the grid area.
func _on_grid_gui_input(event: InputEvent):
	if event is InputEventMouseButton:
		if event.is_pressed():
			if event.button_index == MOUSE_BUTTON_RIGHT:
				var p = _screen_to_texture(event.position)
				if rect.has_point(p):
					moving_rect = true
					rect_start_pos = rect.position
					mouse_start_pos = p
			else:
				var previous_zoom = draw_zoom
				var texture = _get_texture()
				var tex_size = texture.get_size()
				var mouse_pos = texture_preview.get_local_mouse_position()
				
				if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
					draw_zoom = max(0.1, draw_zoom - 0.1)
				elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
					draw_zoom = min(10.0, draw_zoom + 0.1)
				elif event.button_index == MOUSE_BUTTON_MIDDLE:
					moving = true
				elif event.button_index == MOUSE_BUTTON_LEFT:
					if event.double_click:
						var tex_pos = _screen_to_texture(mouse_pos)
						if rect.has_area() and rect.has_point(tex_pos):
							_on_ok_button_pressed()
							return
							
					if snap_mode == SnapMode.SNAP_AUTO_CROP:
						var tex_pos = _screen_to_texture(mouse_pos)
						for r in auto_crop_rects:
							if r.has_point(tex_pos):
								rect = r
								updated.emit()
								break
					else:
						_start_drag(mouse_pos)
				
				if previous_zoom != draw_zoom:
					var preview_size = texture_preview.size
					var center_old = (preview_size - tex_size * previous_zoom) / 2
					var center_new = (preview_size - tex_size * draw_zoom) / 2
					var world_pos = draw_ofs + (mouse_pos - center_old) / previous_zoom
					var new_draw_ofs = world_pos - (mouse_pos - center_new) / draw_zoom
					var offset_delta = draw_ofs - new_draw_ofs
					force_change_draw_offset(offset_delta)
					updated.emit()
		
		elif not event.is_pressed() and event.button_index == MOUSE_BUTTON_RIGHT:
			moving_rect = false

		elif moving:
			moving = false
		
		elif drawing_rect:
			_end_drag()
	
	elif event is InputEventMouseMotion and moving_rect:
		var mouse_tex = _screen_to_texture(event.position)
		var delta = mouse_tex - mouse_start_pos
		var new_pos = rect_start_pos + delta

		if snap_mode == SnapMode.SNAP_COLUMNS_AND_ROWS:
			var cell_total = Vector2i(snap_step.x + snap_separation.x, snap_step.y + snap_separation.y)
			var tl_cell = _pos_to_cell(new_pos)
			new_pos = Vector2(snap_offset + tl_cell * cell_total)

		rect.position = new_pos
		updated.emit()
		texture_preview.queue_redraw()

	elif event is InputEventMouseMotion and moving:
		if just_warped:
			just_warped = false
		else:
			force_change_draw_offset(event.relative / draw_zoom)

	elif event is InputEventMouseMotion and drawing_rect:
		_update_drag(event.position)


## Input handler for the drag handles of the selection cursor.
func _on_cursor_handle_gui_input(event: InputEvent, button_id: String) -> void:
	if snap_mode == SnapMode.SNAP_AUTO_CROP:
		return
		
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.is_pressed():
			resizing_rect = true
			current_resize = button_id
			resize_rect_start = rect

			if snap_mode == SnapMode.SNAP_GRID or snap_mode == SnapMode.SNAP_COLUMNS_AND_ROWS:
				resize_start_tl_cell = _pos_to_cell(resize_rect_start.position)
				resize_start_br_cell = _pos_to_cell(resize_rect_start.position + resize_rect_start.size)
		else:
			resizing_rect = false

	elif event is InputEventMouseMotion and resizing_rect:
		_update_rect_size(texture_preview.get_local_mouse_position())
	
	else:
		_on_grid_gui_input(event)


## Handles scrollbars value changes to pan the view.
func _scroll_changed(value: float):
	if busy: return
	
	var texture = _get_texture()
	if texture:
		var tex_size = texture.get_size()
		var preview_size = texture_preview.size

		var minx = -((preview_size.x / 2) + tex_size.x * draw_zoom) / draw_zoom
		var maxx = -minx
		var miny = -((preview_size.y / 2) + tex_size.y * draw_zoom) / draw_zoom
		var maxy = -miny
		var real_x = remap(hscroll.value, hscroll.min_value, hscroll.max_value - hscroll.page, minx, maxx)
		var real_y = remap(vscroll.value, vscroll.min_value, vscroll.max_value - vscroll.page, miny, maxy)
		
		draw_ofs.x = real_x
		draw_ofs.y = real_y
		updated.emit()


## Offsets the drawing view by a delta amount.
func force_change_draw_offset(off: Vector2) -> void:
	draw_ofs -= off
	
	if off:
		var p1 = texture_preview.get_local_mouse_position()
		var p2 = p1
		if p1.x < 0:
			p2.x += texture_preview.size.x
		elif p1.x > texture_preview.size.x:
			p2.x = 0
		if p1.y < 0:
			p2.y += texture_preview.size.y
		elif p1.y > texture_preview.size.y:
			p2.y = 0
		if p2 != p1:
			texture_preview.warp_mouse(p2)
			just_warped = true
	
	var texture = _get_texture()
	if texture:
		var tex_size = texture.get_size()
		var preview_size = texture_preview.size
		var minx = -((preview_size.x / 2) + tex_size.x * draw_zoom) / draw_zoom
		var maxx = -minx
		var miny = -((preview_size.y / 2) + tex_size.y * draw_zoom) / draw_zoom
		var maxy = -miny
		draw_ofs = clamp(draw_ofs, Vector2(minx, miny), Vector2(maxx, maxy))
		var real_x = remap(draw_ofs.x, minx, maxx, hscroll.min_value, hscroll.max_value - hscroll.page)
		var real_y = remap(draw_ofs.y, miny, maxy, vscroll.min_value, vscroll.max_value - vscroll.page)
		busy = true
		hscroll.value = real_x
		vscroll.value = real_y
		busy = false

	updated.emit()


## Start a selection rectangle drag operation.
func _start_drag(screen_position: Vector2):
	var texture = _get_texture()
	if not texture:
		return
	var preview_size = texture_preview.size
	var tex_size = texture.get_size()
	var offset = (preview_size - tex_size * draw_zoom) / 2 - draw_ofs * draw_zoom
	draw_rect_start = (screen_position - offset) / draw_zoom
	drawing_rect = true


## Updates the drawn rectangle coordinates based on mouse position.
func _update_drag(screen_position: Vector2):
	if not drawing_rect:
		return
	var texture = _get_texture()
	if not texture:
		return
	
	var preview_size = texture_preview.size
	var tex_size = texture.get_size()
	var offset = (preview_size - tex_size * draw_zoom) / 2 - draw_ofs * draw_zoom
	var current_pos = (screen_position - offset) / draw_zoom
	
	match snap_mode:
		SnapMode.SNAP_NONE, SnapMode.SNAP_PIXEL:
			var top_left = Vector2(
				min(draw_rect_start.x, current_pos.x),
				min(draw_rect_start.y, current_pos.y)
			)
			var bottom_right = Vector2(
				max(draw_rect_start.x, current_pos.x),
				max(draw_rect_start.y, current_pos.y)
			)
			rect = Rect2(top_left, bottom_right - top_left)
			
		SnapMode.SNAP_GRID, SnapMode.SNAP_COLUMNS_AND_ROWS:
			var cell_total = snap_step + snap_separation
			var cell_total_f = Vector2(
				float(cell_total.x) if cell_total.x > 0 else 1.0,
				float(cell_total.y) if cell_total.y > 0 else 1.0
			)
			
			var cell_index_start = Vector2i(
				floor((draw_rect_start.x - snap_offset.x) / cell_total_f.x),
				floor((draw_rect_start.y - snap_offset.y) / cell_total_f.y)
			)
			var cell_index_current = Vector2i(
				floor((current_pos.x - snap_offset.x) / cell_total_f.x),
				floor((current_pos.y - snap_offset.y) / cell_total_f.y)
			)
			
			var cell_start = snap_offset + Vector2i(cell_index_start) * cell_total
			var cell_current = snap_offset + Vector2i(cell_index_current) * cell_total
			
			var top_left = Vector2(
				min(cell_start.x, cell_current.x),
				min(cell_start.y, cell_current.y)
			)
			var bottom_right = Vector2(
				max(cell_start.x, cell_current.x) + snap_step.x,
				max(cell_start.y, cell_current.y) + snap_step.y
			)
			
			rect = Rect2(top_left, bottom_right - top_left)
	
	updated.emit()


## Ends a selection rectangle drag operation.
func _end_drag():
	drawing_rect = false
	updated.emit()


## Resizes the current region rect from handle input.
func _update_rect_size(screen_position: Vector2) -> void:
	if not resizing_rect:
		return

	var texture = _get_texture()
	if not texture:
		return

	var mouse_tex = _screen_to_texture(screen_position)

	if snap_mode == SnapMode.SNAP_NONE or snap_mode == SnapMode.SNAP_PIXEL:
		var mx = int(floor(mouse_tex.x + 0.5))
		var my = int(floor(mouse_tex.y + 0.5))

		var orig_tl = resize_rect_start.position
		var orig_br = resize_rect_start.position + resize_rect_start.size

		var new_tl = orig_tl
		var new_br = orig_br

		if current_resize in ["left", "top_left", "bottom_left"]:
			if mx > orig_br.x:
				new_tl.x = orig_br.x
				new_br.x = mx
			else:
				new_tl.x = min(mx, orig_br.x - 1)

		elif current_resize in ["right", "top_right", "bottom_right"]:
			if mx < orig_tl.x:
				new_tl.x = mx
				new_br.x = orig_tl.x
			else:
				new_br.x = max(mx, orig_tl.x + 1)

		if current_resize in ["top", "top_left", "top_right"]:
			if my > orig_br.y:
				new_tl.y = orig_br.y
				new_br.y = my
			else:
				new_tl.y = min(my, orig_br.y - 1)

		elif current_resize in ["bottom", "bottom_left", "bottom_right"]:
			if my < orig_tl.y:
				new_tl.y = my
				new_br.y = orig_tl.y
			else:
				new_br.y = max(my, orig_tl.y + 1)

		rect = Rect2(new_tl, new_br - new_tl)

	else:
		var cell_total = Vector2(snap_step.x + snap_separation.x, snap_step.y + snap_separation.y)
		var mouse_cell = _pos_to_cell(mouse_tex)

		var tl = resize_start_tl_cell
		var br = resize_start_br_cell

		if current_resize in ["left", "top_left", "bottom_left"]:
			if mouse_cell.x > br.x - 1:
				var tmp = tl.x
				tl.x = br.x - 1
				br.x = mouse_cell.x + 1
			else:
				tl.x = min(mouse_cell.x, br.x - 1)

		elif current_resize in ["right", "top_right", "bottom_right"]:
			if mouse_cell.x < tl.x:
				var tmp = br.x
				br.x = tl.x + 1
				tl.x = mouse_cell.x
			else:
				br.x = max(mouse_cell.x + 1, tl.x + 1)

		if current_resize in ["top", "top_left", "top_right"]:
			if mouse_cell.y > br.y - 1:
				tl.y = br.y - 1
				br.y = mouse_cell.y + 1
			else:
				tl.y = min(mouse_cell.y, br.y - 1)

		elif current_resize in ["bottom", "bottom_left", "bottom_right"]:
			if mouse_cell.y < tl.y:
				br.y = tl.y + 1
				tl.y = mouse_cell.y
			else:
				br.y = max(mouse_cell.y + 1, tl.y + 1)

		rect.position = Vector2(snap_offset) + Vector2(tl.x * cell_total.x, tl.y * cell_total.y)
		rect.size = Vector2((br.x - tl.x) * cell_total.x, (br.y - tl.y) * cell_total.y)

	updated.emit()
	texture_preview.queue_redraw()


func _on_ok_button_pressed() -> void:
	_save_config()
	region_changed.emit(rect)
	queue_free()


func _on_cancel_button_pressed() -> void:
	_save_config()
	queue_free()


#endregion


#region Auto Crop System

## Recalculates transparent sections generating isolated bounding boxes for direct selection.
func _calculate_auto_crop_rects() -> void:
	auto_crop_rects.clear()
	var tex = _get_texture()
	if not tex: return
	var img = tex.get_image()
	if not img: return

	var bitmap = BitMap.new()
	bitmap.create_from_image_alpha(img)
	
	var rect_full = Rect2(0, 0, img.get_width(), img.get_height())
	var epsilon = %EpsilonSpinBox.value if has_node("%EpsilonSpinBox") else 2.0
	var polygons = bitmap.opaque_to_polygons(rect_full, epsilon)
	
	for poly in polygons:
		if poly.size() == 0: continue
		
		var min_x = poly[0].x
		var min_y = poly[0].y
		var max_x = poly[0].x
		var max_y = poly[0].y
		
		for pt in poly:
			if pt.x < min_x: min_x = pt.x
			if pt.x > max_x: max_x = pt.x
			if pt.y < min_y: min_y = pt.y
			if pt.y > max_y: max_y = pt.y
			
		var r = Rect2(min_x, min_y, max_x - min_x, max_y - min_y)
		if r.has_area():
			var is_duplicate = false
			for existing in auto_crop_rects:
				if existing.encloses(r):
					is_duplicate = true
					break
			if not is_duplicate:
				auto_crop_rects.append(r)

	if %MergeCloseCheckBox.button_pressed:
		# Merge close rectangles (islands of pixels within 5 pixels of each other) using an optimized O(N^2) pass
		var temp_rects = auto_crop_rects.duplicate()
		var final_rects: Array[Rect2] = []
		var merge_threshold = 5.0
		while temp_rects.size() > 0:
			var current = temp_rects.pop_front()
			var merged = true
			while merged:
				merged = false
				var j = 0
				while j < temp_rects.size():
					if current.grow(merge_threshold).intersects(temp_rects[j]):
						current = current.merge(temp_rects[j])
						temp_rects.remove_at(j)
						merged = true
					else:
						j += 1
			final_rects.append(current)
		
		auto_crop_rects = final_rects




## Expands over connected opaque pixels retrieving its bounding area coordinates.
func _flood_fill_rect(img: Image, visited: PackedByteArray, start_x: int, start_y: int, width: int, height: int) -> Rect2:
	var min_x = start_x
	var min_y = start_y
	var max_x = start_x
	var max_y = start_y

	var stack_x = PackedInt32Array([start_x])
	var stack_y = PackedInt32Array([start_y])
	visited[start_y * width + start_x] = 1

	while stack_x.size() > 0:
		var cx = stack_x[stack_x.size() - 1]
		var cy = stack_y[stack_y.size() - 1]
		stack_x.remove_at(stack_x.size() - 1)
		stack_y.remove_at(stack_y.size() - 1)

		if cx < min_x: min_x = cx
		if cx > max_x: max_x = cx
		if cy < min_y: min_y = cy
		if cy > max_y: max_y = cy

		for dy in range(-1, 2):
			for dx in range(-1, 2):
				if dx == 0 and dy == 0: 
					continue
				
				var nx = cx + dx
				var ny = cy + dy
				
				if nx >= 0 and nx < width and ny >= 0 and ny < height:
					var n_idx = ny * width + nx
					if visited[n_idx] == 0:
						visited[n_idx] = 1
						if img.get_pixel(nx, ny).a > 0.0:
							stack_x.append(nx)
							stack_y.append(ny)

	return Rect2(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)


#endregion


#region Utilities & Data Transformation

## Triggered when the combo box changes modifying the internal adjustment tool state.
func _on_adjustment_mode_item_selected(index: int) -> void:
	if snap_mode == SnapMode.SNAP_GRID:
		backup_snap_options.snap_step = snap_step
		backup_snap_options.snap_offset = snap_offset
		backup_snap_options.snap_separation = snap_separation

	snap_mode = SnapMode[SnapMode.keys()[index]]
	
	FileCache.options.region_dialog_options.snap_mode = snap_mode
	var bak_step = FileCache.options.region_dialog_options.snap_step
	var bak_offset = FileCache.options.region_dialog_options.snap_offset
	var bak_separation = FileCache.options.region_dialog_options.snap_separation
	%Columns.suffix = " px"
	%Rows.suffix = " px"
	
	match snap_mode:
		SnapMode.SNAP_NONE, SnapMode.SNAP_PIXEL, SnapMode.SNAP_AUTO_CROP:
			%GridContainer.visible = false
			%StepX.set_value_no_signal(1)
			%StepY.set_value_no_signal(1)
			%OffsetX.set_value_no_signal(0)
			%OffsetY.set_value_no_signal(0)
			%SeparationX.set_value_no_signal(0)
			%SeparationY.set_value_no_signal(0)
			
		SnapMode.SNAP_GRID:
			%GridContainer.visible = true
			%StepContainer.visible = true
			%ColumnAndRowContainer.visible = false
			%StepX.value = FileCache.options.region_dialog_options.snap_step.x
			%StepY.value = FileCache.options.region_dialog_options.snap_step.y
			%OffsetX.value = snap_offset.x
			%OffsetY.value = snap_offset.y
			%SeparationX.value = FileCache.options.region_dialog_options.snap_separation.x
			%SeparationY.value = FileCache.options.region_dialog_options.snap_separation.y
			
			%StepX.apply()
			%StepY.apply()
			
		SnapMode.SNAP_COLUMNS_AND_ROWS:
			%GridContainer.visible = true
			%StepContainer.visible = false
			%ColumnAndRowContainer.visible = true
			%Columns.suffix = ""
			%Rows.suffix = ""
			
			var c = FileCache.options.region_dialog_options.column_and_rows.x
			var r = FileCache.options.region_dialog_options.column_and_rows.y
			if c <= 0: c = 1
			if r <= 0: r = 1
			
			%Columns.set_value_no_signal(c)
			%Rows.set_value_no_signal(r)
			%OffsetX.set_value_no_signal(snap_offset.x)
			%OffsetY.set_value_no_signal(snap_offset.y)
			%SeparationX.set_value_no_signal(0)
			%SeparationY.set_value_no_signal(0)
	
			%Columns.apply()
			%Rows.apply()
			
			_recalculate_step_from_grid()
	
	grid.queue_redraw()
	
	if snap_mode != SnapMode.SNAP_COLUMNS_AND_ROWS:
		FileCache.options.region_dialog_options.snap_step = bak_step
		FileCache.options.region_dialog_options.snap_offset = bak_offset
		FileCache.options.region_dialog_options.snap_separation = bak_separation

	size.x = 0
	
	var is_auto_crop = (snap_mode == SnapMode.SNAP_AUTO_CROP)
	%MergeCloseCheckBox.visible = is_auto_crop
	%EpsilonLabel.visible = is_auto_crop
	%EpsilonSpinBox.visible = is_auto_crop
	if is_auto_crop:
		_calculate_auto_crop_rects()
		texture_preview.queue_redraw()
		
	updated.emit()


func _on_merge_close_check_box_toggled(button_pressed: bool) -> void:
	if snap_mode == SnapMode.SNAP_AUTO_CROP:
		_calculate_auto_crop_rects()
		updated.emit()


func _on_epsilon_spin_box_value_changed(value: float) -> void:
	if snap_mode == SnapMode.SNAP_AUTO_CROP:
		_calculate_auto_crop_rects()
		updated.emit()


## Updates snap_step based on current column_and_rows and texture size.
func _recalculate_step_from_grid() -> void:
	var texture = _get_texture()
	if not texture or column_and_rows.x == 0 or column_and_rows.y == 0:
		return
		
	snap_step.x = max(1, int(texture.get_width() / column_and_rows.x))
	snap_step.y = max(1, int(texture.get_height() / column_and_rows.y))
	FileCache.options.region_dialog_options.snap_step = snap_step


func _on_offset_x_value_changed(value: float) -> void:
	snap_offset.x = value
	FileCache.options.region_dialog_options.snap_offset.x = snap_offset.x
	updated.emit()


func _on_offset_y_value_changed(value: float) -> void:
	snap_offset.y = value
	FileCache.options.region_dialog_options.snap_offset.y = snap_offset.y
	updated.emit()


## Transforms internal column variables fitting the current division ratios.
func _adjust_columns_and_rows() -> void:
	var texture = _get_texture()
	if not texture:
		return
		
	var width = texture.get_width()
	var height = texture.get_height()
	
	var columns = int((width + snap_separation.x) / (snap_step.x + snap_separation.x + 0.00000000000000001))
	var rows = int((height + snap_separation.y) / (snap_step.y + snap_separation.y + 0.00000000000000001))
	
	column_and_rows = Vector2i(columns, rows)
	FileCache.options.region_dialog_options.column_and_rows = column_and_rows


func _on_step_x_value_changed(value: float) -> void:
	snap_step.x = value
	FileCache.options.region_dialog_options.snap_step.x = snap_step.x
	_adjust_columns_and_rows()
	updated.emit()


func _on_step_y_value_changed(value: float) -> void:
	snap_step.y = value
	FileCache.options.region_dialog_options.snap_step.y = snap_step.y
	_adjust_columns_and_rows()
	updated.emit()


func _on_separation_x_value_changed(value: float) -> void:
	snap_separation.x = value
	FileCache.options.region_dialog_options.snap_separation.x = snap_separation.x
	updated.emit()


func _on_separation_y_value_changed(value: float) -> void:
	snap_separation.y = value
	FileCache.options.region_dialog_options.snap_separation.y = snap_separation.y
	updated.emit()


## Refreshes the separation attributes synchronizing the configuration state.
func _adjust_snap() -> void:
	var texture = _get_texture()
	if not texture:
		return
		
	var width = texture.get_width()
	var height = texture.get_height()
	
	var snap_x = width / column_and_rows.x
	var snap_y = height / column_and_rows.y
	
	snap_separation = Vector2i(snap_x, snap_y)
	FileCache.options.region_dialog_options.snap_separation = snap_separation


func _on_columns_value_changed(value: float) -> void:
	if value <= 0:
		value = 1
	column_and_rows.x = value
	FileCache.options.region_dialog_options.column_and_rows.x = column_and_rows.x
	
	var texture = _get_texture()
	if not texture:
		return
	
	snap_step.x = max(1, int(texture.get_width() / value))
	FileCache.options.region_dialog_options.snap_step.x = snap_step.x
	
	updated.emit()


func _on_rows_value_changed(value: float) -> void:
	if value <= 0:
		value = 1
	column_and_rows.y = value
	FileCache.options.region_dialog_options.column_and_rows.y = column_and_rows.y
	
	var texture = _get_texture()
	if not texture:
		return
	
	snap_step.y = max(1, int(texture.get_height() / value))
	FileCache.options.region_dialog_options.snap_step.y = snap_step.y
	
	updated.emit()


## Retrieves the reference texture mapped towards the edition display.
func _get_texture() -> Texture:
	if edited_object is AtlasTexture:
		return edited_object.atlas
	if edited_object is Texture:
		return edited_object
	return null


## Computes mouse location coordinates translating towards internal view structures.
func _screen_to_texture(screen_pos: Vector2) -> Vector2:
	var texture = _get_texture()
	if not texture:
		return Vector2.ZERO
	var tex_size = texture.get_size()
	var preview_size = texture_preview.size
	var offset = (preview_size - tex_size * draw_zoom) / 2 - draw_ofs * draw_zoom
	return (screen_pos - offset) / draw_zoom


## Converts positional maps fitting them exactly inside local matrix boundaries.
func _pos_to_cell(tex_pos: Vector2) -> Vector2i:
	var cell_total_x = float(snap_step.x + snap_separation.x)
	var cell_total_y = float(snap_step.y + snap_separation.y)

	if cell_total_x <= 0.0:
		cell_total_x = 1.0
	if cell_total_y <= 0.0:
		cell_total_y = 1.0

	var EPS = 1e-6
	var cx = int(floor((tex_pos.x - snap_offset.x + EPS) / cell_total_x))
	var cy = int(floor((tex_pos.y - snap_offset.y + EPS) / cell_total_y))

	var texture = _get_texture()
	if texture:
		var max_cx = max(0, int(floor((texture.get_width() - snap_offset.x + EPS) / cell_total_x)))
		var max_cy = max(0, int(floor((texture.get_height() - snap_offset.y + EPS) / cell_total_y)))
		cx = clamp(cx, 0, max_cx)
		cy = clamp(cy, 0, max_cy)

	return Vector2i(cx, cy)


## Calculates zoom and offset to fit the texture entirely centered within the preview canvas.
func center_and_fit_texture() -> void:
	var texture = _get_texture()
	if not texture: return
	var tex_size = texture.get_size()
	var canvas_size = texture_preview.size
	if canvas_size.x <= 0 or canvas_size.y <= 0:
		# If canvas is not yet laid out, defer calculation
		call_deferred("center_and_fit_texture")
		return
	
	# Calculate optimal zoom to fit with some margin (e.g. 24 pixels margin)
	var margin = 24.0
	var available_w = max(10.0, canvas_size.x - margin * 2.0)
	var available_h = max(10.0, canvas_size.y - margin * 2.0)
	
	var zoom_x = available_w / tex_size.x
	var zoom_y = available_h / tex_size.y
	var optimal_zoom = min(zoom_x, zoom_y)
	
	draw_zoom = clamp(optimal_zoom, 0.1, 10.0)
	draw_ofs = Vector2.ZERO
	
	updated.emit()


#endregion
