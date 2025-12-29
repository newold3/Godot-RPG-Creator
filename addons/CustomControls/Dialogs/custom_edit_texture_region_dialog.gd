@tool
extends Window

enum SnapMode {SNAP_NONE, SNAP_PIXEL, SNAP_GRID, SNAP_COLUMNS_AND_ROWS}

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


@onready var texture_preview: Control = %EditedTexture
@onready var grid: Control = %Grid
@onready var hscroll: HScrollBar = %HScrollBar
@onready var vscroll: VScrollBar = %VScrollBar

signal updated()
signal region_changed(region: Rect2)


func _ready():
	close_requested.connect(queue_free)
	
	grid.gui_input.connect(_on_grid_gui_input)
	hscroll.value_changed.connect(_scroll_changed)
	vscroll.value_changed.connect(_scroll_changed)
	texture_preview.draw.connect(_on_texture_preview_draw)
	grid.draw.connect(_on_grid_draw)
	updated.connect(
		func():
			texture_preview.queue_redraw()
			grid.queue_redraw()
	)
	set_default_values()


func _save_config() -> void:
	FileCache.options.region_dialog_options = {
		"snap_mode": snap_mode,
		"draw_zoom": draw_zoom,
		"snap_offset": snap_offset,
		"snap_separation": snap_separation,
		"snap_step": snap_step,
		"column_and_rows": column_and_rows,
	}


func set_default_values() -> void:
	var options = FileCache.options.get("region_dialog_options", {})
	snap_mode = options.get("snap_mode", SnapMode.SNAP_GRID)
	draw_zoom = options.get("draw_zoom", 1.0)
	snap_offset = options.get("snap_offset", Vector2i.ZERO)
	snap_separation = options.get("snap_separation", Vector2i.ZERO)
	snap_step = options.get("snap_separation", Vector2i(32, 32))
	column_and_rows = options.get("column_and_rows", Vector2i.ONE)
	
	if not FileCache.options.has("region_dialog_options"):
		FileCache.options.region_dialog_options = {
			"snap_mode": snap_mode,
			"draw_zoom": draw_zoom,
			"snap_offset": snap_offset,
			"snap_separation": snap_separation,
			"snap_step": snap_step,
			"column_and_rows": column_and_rows,
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
	busy = false

	%AdjustmentMode.item_selected.emit.call_deferred(current_mode_index)

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
				snap_step = Vector2i(rect.size)
				snap_offset = Vector2i.ZERO
				snap_separation = Vector2i.ZERO
				
				# Update UI components
				%OffsetX.set_deferred("value", 0)
				%OffsetY.set_deferred("value", 0)
				%StepX.set_deferred("value", rect.size.x)
				%StepY.set_deferred("value", rect.size.y)
				%Columns.set_deferred("value", int_columns)
				%Rows.set_deferred("value", int_rows)
				
				#%AdjustmentMode.select(3) # SnapMode.SNAP_COLUMNS_AND_ROWS
				# Force the mode update logic
				_on_adjustment_mode_item_selected(3)
			else:
				#%AdjustmentMode.select(1) # SnapMode.SNAP_PIXEL
				_on_adjustment_mode_item_selected(1)

			if rect:
				var region_center = rect.position + rect.size / 2
				region_center.x = snappedi(region_center.x, snap_step.x)
				region_center.y = snappedi(region_center.y, snap_step.y)
				draw_ofs = region_center - texture_size / 2
				await get_tree().process_frame
				force_change_draw_offset(Vector2.ZERO)
		
		else:
			#%AdjustmentMode.select(1) # SnapMode.SNAP_PIXEL
			_on_adjustment_mode_item_selected(1)
		
	updated.emit()


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
		# Effective size of each cell (content + separation)
		var cell_total = Vector2(snap_step.x + snap_separation.x, snap_step.y + snap_separation.y)
		var cell_total_draw = cell_total * draw_zoom
		
		# Optimization: Don't draw if cells are too small
		if cell_total_draw.x < 2.0 and cell_total_draw.y < 2.0:
			return
		
		# Start position centering the texture
		var start_position = (preview_size - draw_size) / 2 - draw_ofs * draw_zoom + snap_offset * draw_zoom
		
		var lines = PackedVector2Array()
		
		# Draw vertical lines (columns)
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
		
		# Draw horizontal lines (rows)
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
	
	if rect:
		%Cursor.visible = true
		%Cursor.position = offset + rect.position * draw_zoom
		%Cursor.size = rect.size * draw_zoom
	else:
		%Cursor.visible = false


func _get_texture() -> Texture:
	if edited_object is AtlasTexture:
		return edited_object.atlas
	if edited_object is Texture:
		return edited_object
	return null


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
		force_change_draw_offset(event.relative / draw_zoom)

	elif event is InputEventMouseMotion and drawing_rect:
		_update_drag(event.position)


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


func _start_drag(screen_position: Vector2):
	var texture = _get_texture()
	if not texture:
		return
	var preview_size = texture_preview.size
	var tex_size = texture.get_size()
	var offset = (preview_size - tex_size * draw_zoom) / 2 - draw_ofs * draw_zoom
	draw_rect_start = (screen_position - offset) / draw_zoom
	drawing_rect = true


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
			
			var cell_index_start = Vector2i(
				floor((draw_rect_start.x - snap_offset.x) / cell_total.x),
				floor((draw_rect_start.y - snap_offset.y) / cell_total.y)
			)
			var cell_index_current = Vector2i(
				floor((current_pos.x - snap_offset.x) / cell_total.x),
				floor((current_pos.y - snap_offset.y) / cell_total.y)
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


func _end_drag():
	drawing_rect = false
	updated.emit()


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
		SnapMode.SNAP_NONE, SnapMode.SNAP_PIXEL:
			%GridContainer.visible = false
			%StepX.value = 1
			%StepY.value = 1
			%OffsetX.value = 0
			%OffsetY.value = 0
			%SeparationX.value = 0
			%SeparationY.value = 0
			
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
			%Columns.value = FileCache.options.region_dialog_options.column_and_rows.x
			%Rows.value = FileCache.options.region_dialog_options.column_and_rows.y
			%OffsetX.value = snap_offset.x
			%OffsetY.value = snap_offset.y
			%SeparationX.value = 0
			%SeparationY.value = 0
	
			%Columns.apply()
			%Rows.apply()
			
			# Ensure internal data is updated with the new columns/rows
			_recalculate_step_from_grid()
	
	grid.queue_redraw()
	
	# Only restore backup values if we are NOT in Col/Rows mode to avoid overwriting calculation
	if snap_mode != SnapMode.SNAP_COLUMNS_AND_ROWS:
		FileCache.options.region_dialog_options.snap_step = bak_step
		FileCache.options.region_dialog_options.snap_offset = bak_offset
		FileCache.options.region_dialog_options.snap_separation = bak_separation

	size.x = 0
	updated.emit()


func _recalculate_step_from_grid() -> void:
	# Updates snap_step based on current column_and_rows and texture size
	var texture = _get_texture()
	if not texture or column_and_rows.x == 0 or column_and_rows.y == 0:
		return
		
	snap_step.x = texture.get_width() / column_and_rows.x
	snap_step.y = texture.get_height() / column_and_rows.y
	FileCache.options.region_dialog_options.snap_step = snap_step


func _on_offset_x_value_changed(value: float) -> void:
	snap_offset.x = value
	FileCache.options.region_dialog_options.snap_offset.x = snap_offset.x
	updated.emit()


func _on_offset_y_value_changed(value: float) -> void:
	snap_offset.y = value
	FileCache.options.region_dialog_options.snap_offset.y = snap_offset.y
	updated.emit()


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
	column_and_rows.x = value
	FileCache.options.region_dialog_options.column_and_rows.x = column_and_rows.x
	
	var texture = _get_texture()
	if not texture:
		return
	
	snap_step.x = texture.get_width() / value
	FileCache.options.region_dialog_options.snap_step.x = snap_step.x
	
	updated.emit()


func _on_rows_value_changed(value: float) -> void:
	column_and_rows.y = value
	FileCache.options.region_dialog_options.column_and_rows.y = column_and_rows.y
	
	var texture = _get_texture()
	if not texture:
		return
	
	snap_step.y = texture.get_height() / value
	FileCache.options.region_dialog_options.snap_step.y = snap_step.y
	
	updated.emit()


func _on_ok_button_pressed() -> void:
	_save_config()
	region_changed.emit(rect)
	queue_free()


func _on_cancel_button_pressed() -> void:
	_save_config()
	queue_free()


func _on_cursor_handle_gui_input(event: InputEvent, button_id: String) -> void:
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


func _screen_to_texture(screen_pos: Vector2) -> Vector2:
	var texture = _get_texture()
	if not texture:
		return Vector2.ZERO
	var tex_size = texture.get_size()
	var preview_size = texture_preview.size
	var offset = (preview_size - tex_size * draw_zoom) / 2 - draw_ofs * draw_zoom
	return (screen_pos - offset) / draw_zoom


func _pos_to_cell(tex_pos: Vector2) -> Vector2i:
	var cell_total_x = float(snap_step.x + snap_separation.x)
	var cell_total_y = float(snap_step.y + snap_separation.y)

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
