@tool
extends EditorPlugin


#region VARIABLES

var active_layer: TileMapLayer
var cached_tileset: TileSet
var cached_cells: Dictionary = {}
var drag_path: Array[Vector2i] = []
var was_pressed: bool = false
var was_right_pressed: bool = false
var was_shift_pressed: bool = false
var was_alt_pressed: bool = false
var was_ctrl_pressed: bool = false
var shape_selector_1: OptionButton
var shape_selector_2: OptionButton
var large_tile_checkbox_1: CheckBox
var large_tile_checkbox_2: CheckBox
var toolbar_1: Container
var toolbar_2: Container
var rect_button_1: BaseButton
var rect_button_2: BaseButton

#endregion



## Initializes the UI components and sets up shape selectors and large tile toggles
func _enter_tree() -> void:
	shape_selector_1 = OptionButton.new()
	shape_selector_1.name = "TilemapPaintMode"
	shape_selector_1.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	shape_selector_1.theme = load("res://addons/CustomControls/Resources/Themes/editor_buitton_themes.tres")
	
	shape_selector_1.add_item("🖌️ Tilemap Paint Mode")
	shape_selector_1.add_item("📏 Paint Line")
	shape_selector_1.add_item("▲ Paint Triangle")
	shape_selector_1.add_item("■ Paint Square")
	shape_selector_1.add_item("⬟ Paint Pentagon")
	shape_selector_1.add_item("⬢ Paint Hexagon")
	shape_selector_1.add_item("⬣ Paint Heptagon")
	shape_selector_1.add_item("⯄ Paint Octagon")
	shape_selector_1.add_item("⬟ Paint Nonagon")
	shape_selector_1.add_item("⬢ Paint Decagon")
	shape_selector_1.add_item("⬣ Paint Hendecagon")
	shape_selector_1.add_item("⯄ Paint Dodecagon")
	shape_selector_1.add_item("● Paint Circle")
	shape_selector_1.add_item("♥ Paint Heart")
	shape_selector_1.add_item("★ Paint Star")
	shape_selector_1.add_item("◆ Paint Diamond")
	
	shape_selector_1.item_selected.connect(_on_shape_selected_1)
	shape_selector_1.visibility_changed.connect(
		func():
			if shape_selector_1.visible:
				CustomTooltipManager.plugin_replace_all_tooltips_with_custom(shape_selector_1)
	)
	shape_selector_1.hide()
	shape_selector_1.tooltip_text = tr("Changes the way the tilemap is painted.\nSHIFT: Keep 1:1 ratio.\nCTRL: Draw from center.\nALT: Draw hollow shape.\nRight Click: Erase using shape.")
	CustomTooltipManager.plugin_replace_all_tooltips_with_custom.call_deferred(shape_selector_1)
	
	large_tile_checkbox_1 = CheckBox.new()
	large_tile_checkbox_1.name = "LargeTileFix"
	large_tile_checkbox_1.text = "𝄜"
	large_tile_checkbox_1.tooltip_text = "Enable/disable large tile fix"
	large_tile_checkbox_1.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	large_tile_checkbox_1.button_pressed = false
	large_tile_checkbox_1.toggled.connect(_on_large_tile_toggled_1)
	large_tile_checkbox_1.visibility_changed.connect(
		func():
			if large_tile_checkbox_1.visible:
				CustomTooltipManager.plugin_replace_all_tooltips_with_custom(large_tile_checkbox_1)
	)
	large_tile_checkbox_1.hide()
	
	shape_selector_2 = OptionButton.new()
	shape_selector_2.name = "TilemapPaintMode"
	shape_selector_2.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	shape_selector_2.theme = load("res://addons/CustomControls/Resources/Themes/editor_buitton_themes.tres")
	
	shape_selector_2.add_item("🖌️ Tilemap Paint Mode")
	shape_selector_2.add_item("📏 Paint Line")
	shape_selector_2.add_item("▲ Paint Triangle")
	shape_selector_2.add_item("■ Paint Square")
	shape_selector_2.add_item("⬟ Paint Pentagon")
	shape_selector_2.add_item("⬢ Paint Hexagon")
	shape_selector_2.add_item("⬣ Paint Heptagon")
	shape_selector_2.add_item("⯄ Paint Octagon")
	shape_selector_2.add_item("⬟ Paint Nonagon")
	shape_selector_2.add_item("⬢ Paint Decagon")
	shape_selector_2.add_item("⬣ Paint Hendecagon")
	shape_selector_2.add_item("⯄ Paint Dodecagon")
	shape_selector_2.add_item("● Paint Circle")
	shape_selector_2.add_item("♥ Paint Heart")
	shape_selector_2.add_item("★ Paint Star")
	shape_selector_2.add_item("◆ Paint Diamond")
	
	shape_selector_2.item_selected.connect(_on_shape_selected_2)
	shape_selector_2.visibility_changed.connect(
		func():
			if shape_selector_2.visible:
				CustomTooltipManager.plugin_replace_all_tooltips_with_custom(shape_selector_2)
	)
	shape_selector_2.hide()
	shape_selector_2.tooltip_text = tr("Changes the way the tilemap is painted.\nSHIFT: Keep 1:1 ratio.\nCTRL: Draw from center.\nALT: Draw hollow shape.\nRight Click: Erase using shape.")
	CustomTooltipManager.plugin_replace_all_tooltips_with_custom.call_deferred(shape_selector_2)
	
	large_tile_checkbox_2 = CheckBox.new()
	large_tile_checkbox_2.name = "LargeTileFix"
	large_tile_checkbox_2.text = "𝄜"
	large_tile_checkbox_2.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	large_tile_checkbox_2.tooltip_text = "Enable/disable large tile fix"
	large_tile_checkbox_2.button_pressed = false
	large_tile_checkbox_2.toggled.connect(_on_large_tile_toggled_2)
	large_tile_checkbox_2.visibility_changed.connect(
		func():
			if large_tile_checkbox_2.visible:
				CustomTooltipManager.plugin_replace_all_tooltips_with_custom(large_tile_checkbox_2)
	)
	
	large_tile_checkbox_2.hide()
	
	var refresh_selection = func():
		var selection: EditorSelection = EditorInterface.get_selection()
		var selected_nodes: Array[Node] = selection.get_selected_nodes()
		if not selected_nodes.is_empty():
			selection.clear()
			for node in selected_nodes:
				selection.add_node(node)
				
	refresh_selection.call_deferred()


## Cleans up the UI when the plugin is disabled
func _exit_tree() -> void:
	if is_instance_valid(shape_selector_1):
		if shape_selector_1.get_parent():
			shape_selector_1.get_parent().remove_child(shape_selector_1)
		shape_selector_1.queue_free()
		
	if is_instance_valid(large_tile_checkbox_1):
		if large_tile_checkbox_1.get_parent():
			large_tile_checkbox_1.get_parent().remove_child(large_tile_checkbox_1)
		large_tile_checkbox_1.queue_free()
		
	if is_instance_valid(shape_selector_2):
		if shape_selector_2.get_parent():
			shape_selector_2.get_parent().remove_child(shape_selector_2)
		shape_selector_2.queue_free()
		
	if is_instance_valid(large_tile_checkbox_2):
		if large_tile_checkbox_2.get_parent():
			large_tile_checkbox_2.get_parent().remove_child(large_tile_checkbox_2)
		large_tile_checkbox_2.queue_free()



## Binds the plugin to the active TileMapLayer in the editor
func _handles(object: Object) -> bool:
	return object is TileMapLayer



## Activates the supervisor and caches the initial state of the map
func _edit(object: Object) -> void:
	active_layer = object
	if is_instance_valid(active_layer):
		cached_tileset = active_layer.tile_set
		
	_cache_layer()


## Manages dynamic injection of custom buttons into their respective native TileMap toolbars
func _make_visible(visible: bool) -> void:
	if visible:
		rect_button_1 = null
		rect_button_2 = null
		toolbar_1 = null
		toolbar_2 = null
		_find_tilemap_tools(EditorInterface.get_base_control())
		
		if is_instance_valid(toolbar_1) and is_instance_valid(rect_button_1):
			if shape_selector_1.get_parent() != toolbar_1:
				if shape_selector_1.get_parent():
					shape_selector_1.get_parent().remove_child(shape_selector_1)
				toolbar_1.add_child(shape_selector_1)
				toolbar_1.move_child(shape_selector_1, rect_button_1.get_index())
			shape_selector_1.show()
			
			if large_tile_checkbox_1.get_parent() != toolbar_1:
				if large_tile_checkbox_1.get_parent():
					large_tile_checkbox_1.get_parent().remove_child(large_tile_checkbox_1)
				toolbar_1.add_child(large_tile_checkbox_1)
				toolbar_1.move_child(large_tile_checkbox_1, shape_selector_1.get_index() + 1)
			large_tile_checkbox_1.show()
			
		if is_instance_valid(toolbar_2) and is_instance_valid(rect_button_2):
			if shape_selector_2.get_parent() != toolbar_2:
				if shape_selector_2.get_parent():
					shape_selector_2.get_parent().remove_child(shape_selector_2)
				toolbar_2.add_child(shape_selector_2)
				toolbar_2.move_child(shape_selector_2, rect_button_2.get_index())
			shape_selector_2.show()
			
			if large_tile_checkbox_2.get_parent() != toolbar_2:
				if large_tile_checkbox_2.get_parent():
					large_tile_checkbox_2.get_parent().remove_child(large_tile_checkbox_2)
				toolbar_2.add_child(large_tile_checkbox_2)
				toolbar_2.move_child(large_tile_checkbox_2, shape_selector_2.get_index() + 1)
			large_tile_checkbox_2.show()
	else:
		if is_instance_valid(shape_selector_1):
			shape_selector_1.hide()
			if shape_selector_1.get_parent():
				shape_selector_1.get_parent().remove_child(shape_selector_1)
				
		if is_instance_valid(large_tile_checkbox_1):
			large_tile_checkbox_1.hide()
			if large_tile_checkbox_1.get_parent():
				large_tile_checkbox_1.get_parent().remove_child(large_tile_checkbox_1)
				
		if is_instance_valid(shape_selector_2):
			shape_selector_2.hide()
			if shape_selector_2.get_parent():
				shape_selector_2.get_parent().remove_child(shape_selector_2)
				
		if is_instance_valid(large_tile_checkbox_2):
			large_tile_checkbox_2.hide()
			if large_tile_checkbox_2.get_parent():
				large_tile_checkbox_2.get_parent().remove_child(large_tile_checkbox_2)
				
		active_layer = null
		cached_tileset = null
		cached_cells.clear()
		drag_path.clear()
		rect_button_1 = null
		rect_button_2 = null
		toolbar_1 = null
		toolbar_2 = null
		update_overlays()


## Handles selection on the first dropdown and synchronizes the second one
func _on_shape_selected_1(index: int) -> void:
	if is_instance_valid(shape_selector_2) and shape_selector_2.selected != index:
		shape_selector_2.selected = index
		
	if index > 0:
		_force_rect_tool()



## Handles selection on the second dropdown and synchronizes the first one
func _on_shape_selected_2(index: int) -> void:
	if is_instance_valid(shape_selector_1) and shape_selector_1.selected != index:
		shape_selector_1.selected = index
		
	if index > 0:
		_force_rect_tool()



## Syncs the first large tile checkbox with the second
func _on_large_tile_toggled_1(toggled: bool) -> void:
	if is_instance_valid(large_tile_checkbox_2) and large_tile_checkbox_2.button_pressed != toggled:
		large_tile_checkbox_2.button_pressed = toggled



## Syncs the second large tile checkbox with the first
func _on_large_tile_toggled_2(toggled: bool) -> void:
	if is_instance_valid(large_tile_checkbox_1) and large_tile_checkbox_1.button_pressed != toggled:
		large_tile_checkbox_1.button_pressed = toggled



## Recursively deep searches the editor UI to locate the TileMap panel
func _find_tilemap_tools(node: Node) -> void:
	if node.name == "TileMap":
		_search_inside_tilemap(node)
		return
		
	for child in node.get_children():
		_find_tilemap_tools(child)
		if rect_button_1 != null and rect_button_2 != null:
			return



## Scans inside the TileMap panel intercepting C++ signals to identify the native tools
func _search_inside_tilemap(node: Node) -> void:
	if node is BaseButton and node.toggle_mode:
		var is_tilemap_tool: bool = false
		
		for conn in node.pressed.get_connections():
			var method: String = str(conn.callable.get_method())
			if method == "_update_toolbar" or "update_toolbar" in method:
				is_tilemap_tool = true
				break
				
		if is_tilemap_tool:
			var p: Node = node.get_parent()
			if p is BoxContainer:
				var tools: Array[BaseButton] = []
				for child in p.get_children():
					if child is BaseButton and child.toggle_mode:
						tools.append(child)
						
				var idx: int = tools.find(node)
				var is_tiles_paint: bool = (tools.size() == 5 and idx == 3)
				var is_terrain_paint: bool = (tools.size() == 4 and idx == 2)
				
				if is_tiles_paint or is_terrain_paint:
					if rect_button_1 == null:
						rect_button_1 = node
						toolbar_1 = p
					elif rect_button_2 == null and node != rect_button_1:
						rect_button_2 = node
						toolbar_2 = p
					return
					
	for child in node.get_children():
		_search_inside_tilemap(child)


## Forces the selection of the currently active/visible native Draw Rect tool
func _force_rect_tool() -> void:
	if is_instance_valid(rect_button_1) and rect_button_1.is_visible_in_tree():
		if not rect_button_1.button_pressed:
			rect_button_1.button_pressed = true
			rect_button_1.toggled.emit(true)
	elif is_instance_valid(rect_button_2) and rect_button_2.is_visible_in_tree():
		if not rect_button_2.button_pressed:
			rect_button_2.button_pressed = true
			rect_button_2.toggled.emit(true)


## Spies on the global mouse state to detect drag operations and tracks the exact path of the brush
func _process(_delta: float) -> void:
	if not is_instance_valid(active_layer):
		return
		
	if active_layer.tile_set != cached_tileset:
		cached_tileset = active_layer.tile_set
		
		var selection: EditorSelection = EditorInterface.get_selection()
		selection.clear()
		
		var reselect = func():
			if is_instance_valid(active_layer):
				selection.add_node(active_layer)
				
		reselect.call_deferred()
		return
		
	if cached_tileset == null:
		return
		
	var is_left: bool = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var is_right: bool = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	var is_shift: bool = Input.is_key_pressed(KEY_SHIFT)
	var is_alt: bool = Input.is_key_pressed(KEY_ALT)
	var is_ctrl: bool = Input.is_key_pressed(KEY_CTRL)
	
	if is_shift != was_shift_pressed or is_alt != was_alt_pressed or is_ctrl != was_ctrl_pressed:
		was_shift_pressed = is_shift
		was_alt_pressed = is_alt
		was_ctrl_pressed = is_ctrl
		if was_pressed or was_right_pressed:
			update_overlays()
			
	if (is_left or is_right) and not (was_pressed or was_right_pressed):
		was_pressed = is_left
		was_right_pressed = is_right
		_cache_layer()
		drag_path.clear()
		
		var map_pos: Vector2i = active_layer.local_to_map(active_layer.get_local_mouse_position())
		drag_path.append(map_pos)
		update_overlays()
		
	elif (is_left and was_pressed) or (is_right and was_right_pressed):
		var map_pos: Vector2i = active_layer.local_to_map(active_layer.get_local_mouse_position())
		
		if drag_path.is_empty() or drag_path.back() != map_pos:
			drag_path.append(map_pos)
			update_overlays()
			
	elif not is_left and not is_right and (was_pressed or was_right_pressed):
		var was_erasing: bool = was_right_pressed
		was_pressed = false
		was_right_pressed = false
		
		var is_rect_active: bool = false
		if is_instance_valid(rect_button_1) and rect_button_1.is_visible_in_tree() and rect_button_1.button_pressed:
			is_rect_active = true
		elif is_instance_valid(rect_button_2) and rect_button_2.is_visible_in_tree() and rect_button_2.button_pressed:
			is_rect_active = true
			
		if is_rect_active and is_instance_valid(shape_selector_1) and shape_selector_1.selected > 0:
			_apply_shape_fill(was_erasing)
		else:
			_apply_surgical_cleanup()
			
		update_overlays()


## Draws a real-time 1:1 cell preview of the shape over the 2D viewport while dragging
func _forward_canvas_draw_over_viewport(overlay: Control) -> void:
	if not is_instance_valid(active_layer) or drag_path.is_empty() or not (was_pressed or was_right_pressed):
		return
		
	if not is_instance_valid(shape_selector_1) or shape_selector_1.selected <= 0:
		return
		
	var is_rect_active: bool = false
	if is_instance_valid(rect_button_1) and rect_button_1.is_visible_in_tree() and rect_button_1.button_pressed:
		is_rect_active = true
	elif is_instance_valid(rect_button_2) and rect_button_2.is_visible_in_tree() and rect_button_2.button_pressed:
		is_rect_active = true
		
	if not is_rect_active:
		return
		
	var target_cells: Array[Vector2i] = _get_shape_cells()
	var canvas_transform: Transform2D = active_layer.get_viewport_transform() * active_layer.get_global_transform()
	var size: Vector2 = Vector2(active_layer.tile_set.tile_size)
	
	var color: Color = Color(0.9, 0.2, 0.2, 0.5) if was_right_pressed else Color(0.2, 0.6, 1.0, 0.5)
	var colors: PackedColorArray = PackedColorArray([color, color, color, color])
	
	for cell in target_cells:
		var local_pos: Vector2 = active_layer.map_to_local(cell)
		var top_left: Vector2 = local_pos - (size / 2.0)
		
		var p1: Vector2 = canvas_transform * top_left
		var p2: Vector2 = canvas_transform * (top_left + Vector2(size.x, 0))
		var p3: Vector2 = canvas_transform * (top_left + size)
		var p4: Vector2 = canvas_transform * (top_left + Vector2(0, size.y))
		
		overlay.draw_polygon(PackedVector2Array([p1, p2, p3, p4]), colors)


## Calculates the bounding box for the shape based on the start and end of the drag path
func _get_current_bounds() -> Dictionary:
	if drag_path.is_empty():
		return {"rect": Rect2i(), "start": Vector2i.ZERO, "end": Vector2i.ZERO}
		
	var start_pos: Vector2i = drag_path[0]
	var end_pos: Vector2i = drag_path.back()
	var is_shift: bool = Input.is_key_pressed(KEY_SHIFT)
	var is_ctrl: bool = Input.is_key_pressed(KEY_CTRL)
	
	if is_ctrl:
		var diff_x: int = abs(end_pos.x - start_pos.x)
		var diff_y: int = abs(end_pos.y - start_pos.y)
		
		if is_shift:
			var max_diff: int = maxi(diff_x, diff_y)
			diff_x = max_diff
			diff_y = max_diff
			
		var min_pos: Vector2i = start_pos - Vector2i(diff_x, diff_y)
		var max_pos: Vector2i = start_pos + Vector2i(diff_x, diff_y)
		
		return {
			"rect": Rect2i(min_pos, max_pos - min_pos + Vector2i.ONE),
			"start": start_pos,
			"end": end_pos
		}
	else:
		if is_shift:
			var diff_x: int = end_pos.x - start_pos.x
			var diff_y: int = end_pos.y - start_pos.y
			var max_diff: int = maxi(abs(diff_x), abs(diff_y))
			
			var dir_x: int = 1 if diff_x >= 0 else -1
			var dir_y: int = 1 if diff_y >= 0 else -1
			
			end_pos = start_pos + Vector2i(dir_x * max_diff, dir_y * max_diff)
			
		var min_pos: Vector2i = Vector2i(mini(start_pos.x, end_pos.x), mini(start_pos.y, end_pos.y))
		var max_pos: Vector2i = Vector2i(maxi(start_pos.x, end_pos.x), maxi(start_pos.y, end_pos.y))
		
		return {
			"rect": Rect2i(min_pos, max_pos - min_pos + Vector2i.ONE),
			"start": start_pos,
			"end": end_pos
		}



## Interpolates a straight line between two grid coordinates using Bresenham's algorithm
func _get_line_cells(start: Vector2i, end: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var x0: int = start.x
	var y0: int = start.y
	var x1: int = end.x
	var y1: int = end.y
	
	var dx: int = abs(x1 - x0)
	var dy: int = abs(y1 - y0)
	var sx: int = 1 if x0 < x1 else -1
	var sy: int = 1 if y0 < y1 else -1
	var err: int = dx - dy
	
	while true:
		cells.append(Vector2i(x0, y0))
		
		if x0 == x1 and y0 == y1:
			break
			
		var e2: int = 2 * err
		
		if e2 > -dy:
			err -= dy
			x0 += sx
			
		if e2 < dx:
			err += dx
			y0 += sy
			
	return cells



## Calculates the cells that fall inside the selected geometric shape bounds
func _get_shape_cells() -> Array[Vector2i]:
	var target_cells: Array[Vector2i] = []
	
	if drag_path.is_empty() or not is_instance_valid(shape_selector_1) or shape_selector_1.selected <= 0:
		return target_cells
		
	var bounds: Dictionary = _get_current_bounds()
	var rect: Rect2i = bounds["rect"]
	var start_pos: Vector2i = bounds["start"]
	var end_pos: Vector2i = bounds["end"]
	var shape_idx: int = shape_selector_1.selected
	var invert_y: float = -1.0 if end_pos.y < start_pos.y else 1.0
	
	if rect.size == Vector2i.ZERO and shape_idx != 1:
		return target_cells
		
	if shape_idx == 1:
		target_cells = _get_line_cells(start_pos, end_pos)
	else:
		var center: Vector2 = Vector2(rect.position) + (Vector2(rect.size) / 2.0)
		var radius: Vector2 = Vector2(rect.size) / 2.0
		
		if shape_idx == 3:
			for x in range(rect.position.x, rect.end.x):
				for y in range(rect.position.y, rect.end.y):
					target_cells.append(Vector2i(x, y))
					
		elif shape_idx == 12:
			for x in range(rect.position.x, rect.end.x):
				for y in range(rect.position.y, rect.end.y):
					var p: Vector2 = Vector2(x, y) + Vector2(0.5, 0.5)
					var dx: float = (p.x - center.x) / maxf(radius.x, 0.0001)
					var dy: float = (p.y - center.y) / maxf(radius.y, 0.0001)
					
					if (dx * dx) + (dy * dy) <= 1.0:
						target_cells.append(Vector2i(x, y))
						
		elif shape_idx == 13:
			var polygon: PackedVector2Array = PackedVector2Array()
			var steps: int = 64
			
			for i in range(steps):
				var t: float = TAU * i / float(steps)
				var st: float = sin(t)
				var hx: float = st * st * st
				var raw_y: float = 13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t)
				var hy: float = (raw_y + 2.5) / 14.5
				polygon.append(center + Vector2(hx * radius.x, -hy * radius.y * invert_y))
				
			for x in range(rect.position.x, rect.end.x):
				for y in range(rect.position.y, rect.end.y):
					var p: Vector2 = Vector2(x, y) + Vector2(0.5, 0.5)
					
					if Geometry2D.is_point_in_polygon(p, polygon):
						target_cells.append(Vector2i(x, y))
						
		elif shape_idx == 14:
			var polygon: PackedVector2Array = PackedVector2Array()
			
			for i in range(10):
				var r_mult: float = 1.0 if i % 2 == 0 else 0.5
				var angle: float = -PI / 2.0 + (TAU * i / 10.0)
				polygon.append(center + Vector2(cos(angle) * radius.x * r_mult, sin(angle) * radius.y * invert_y * r_mult))
				
			for x in range(rect.position.x, rect.end.x):
				for y in range(rect.position.y, rect.end.y):
					var p: Vector2 = Vector2(x, y) + Vector2(0.5, 0.5)
					
					if Geometry2D.is_point_in_polygon(p, polygon):
						target_cells.append(Vector2i(x, y))
						
		elif shape_idx == 15:
			for x in range(rect.position.x, rect.end.x):
				for y in range(rect.position.y, rect.end.y):
					var p: Vector2 = Vector2(x, y) + Vector2(0.5, 0.5)
					var dx: float = abs((p.x - center.x) / maxf(radius.x, 0.0001))
					var dy: float = abs((p.y - center.y) / maxf(radius.y, 0.0001))
					
					if dx + dy <= 1.0:
						target_cells.append(Vector2i(x, y))
						
		else:
			var sides: int = shape_idx + 1
			var polygon: PackedVector2Array = PackedVector2Array()
			
			for i in range(sides):
				var angle: float = -PI / 2.0 + (TAU * i / float(sides))
				polygon.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y * invert_y))
				
			for x in range(rect.position.x, rect.end.x):
				for y in range(rect.position.y, rect.end.y):
					var p: Vector2 = Vector2(x, y) + Vector2(0.5, 0.5)
					
					if Geometry2D.is_point_in_polygon(p, polygon):
						target_cells.append(Vector2i(x, y))
						
	if Input.is_key_pressed(KEY_ALT) and shape_idx > 1:
		var hollow_cells: Array[Vector2i] = []
		var cell_dict: Dictionary = {}
		
		for cell in target_cells:
			cell_dict[cell] = true
			
		for cell in target_cells:
			var is_border: bool = false
			var neighbors: Array[Vector2i] = [
				cell + Vector2i(1, 0), cell + Vector2i(-1, 0),
				cell + Vector2i(0, 1), cell + Vector2i(0, -1),
				cell + Vector2i(1, 1), cell + Vector2i(-1, -1),
				cell + Vector2i(1, -1), cell + Vector2i(-1, 1)
			]
			
			for n in neighbors:
				if not cell_dict.has(n):
					is_border = true
					break
					
			if is_border:
				hollow_cells.append(cell)
				
		target_cells = hollow_cells
		
	return target_cells


## Caches the current state of the TileMapLayer cells to use as a clean background reference
func _cache_layer() -> void:
	cached_cells.clear()
	
	if not is_instance_valid(active_layer) or active_layer.tile_set == null:
		return
		
	for pos in active_layer.get_used_cells():
		var source: int = active_layer.get_cell_source_id(pos)
		var coord: Vector2i = active_layer.get_cell_atlas_coords(pos)
		var alt: int = active_layer.get_cell_alternative_tile(pos)
		cached_cells[pos] = {"source": source, "coord": coord, "alt": alt}



## Reconstructs the stroke filtering overlapping giant tiles while respecting the exact drag path
func _apply_surgical_cleanup() -> void:
	if is_instance_valid(large_tile_checkbox_1) and not large_tile_checkbox_1.button_pressed:
		return
		
	if not is_instance_valid(active_layer) or active_layer.tile_set == null or drag_path.is_empty():
		return
		
	var tileset: TileSet = active_layer.tile_set
	var brush_data: Dictionary = {}
	
	for pos in drag_path:
		var current_source: int = active_layer.get_cell_source_id(pos)
		var current_coord: Vector2i = active_layer.get_cell_atlas_coords(pos)
		
		if not cached_cells.has(pos) or cached_cells[pos]["coord"] != current_coord:
			if current_source != -1:
				var source: TileSetSource = tileset.get_source(current_source)
				
				if source is TileSetAtlasSource:
					var size: Vector2i = source.get_tile_size_in_atlas(current_coord)
					if size.x > 1 or size.y > 1:
						brush_data = {
							"source": current_source,
							"coord": current_coord,
							"alt": active_layer.get_cell_alternative_tile(pos),
							"size": size
						}
						break
						
	if brush_data.is_empty():
		return
		
	var valid_anchors: Dictionary = {}
	var size: Vector2i = brush_data["size"]
	
	for pos in drag_path:
		var overlaps: bool = false
		for v_pos in valid_anchors.keys():
			var rect1: Rect2i = Rect2i(pos, size)
			var rect2: Rect2i = Rect2i(v_pos, size)
			if rect1.intersects(rect2):
				overlaps = true
				break
				
		if not overlaps:
			valid_anchors[pos] = true
			
	var current_cells: Array[Vector2i] = active_layer.get_used_cells()
	var smudge_cells: Dictionary = {}
	
	for pos in current_cells:
		if not cached_cells.has(pos) or cached_cells[pos]["coord"] != active_layer.get_cell_atlas_coords(pos):
			var c_source: int = active_layer.get_cell_source_id(pos)
			var c_coord: Vector2i = active_layer.get_cell_atlas_coords(pos)
			var c_alt: int = active_layer.get_cell_alternative_tile(pos)
			smudge_cells[pos] = {"source": c_source, "coord": c_coord, "alt": c_alt}
			
	for pos in cached_cells.keys():
		if not current_cells.has(pos):
			smudge_cells[pos] = {"source": -1, "coord": Vector2i(-1, -1), "alt": -1}
			
	var all_affected: Dictionary = {}
	
	for pos in smudge_cells.keys():
		all_affected[pos] = true
		
	for pos in valid_anchors.keys():
		all_affected[pos] = true
		
	var undo_redo: EditorUndoRedoManager = get_undo_redo()
	undo_redo.create_action("Surgical Giant Tile Clean")
	
	for pos in all_affected.keys():
		var do_data: Dictionary = {"source": -1, "coord": Vector2i(-1, -1), "alt": -1}
		if valid_anchors.has(pos):
			do_data = {"source": brush_data["source"], "coord": brush_data["coord"], "alt": brush_data["alt"]}
		elif cached_cells.has(pos):
			do_data = cached_cells[pos]
			
		undo_redo.add_do_method(active_layer, "set_cell", pos, do_data["source"], do_data["coord"], do_data["alt"])
		
		var undo_data: Dictionary = {"source": -1, "coord": Vector2i(-1, -1), "alt": -1}
		if smudge_cells.has(pos):
			undo_data = smudge_cells[pos]
		elif cached_cells.has(pos):
			undo_data = cached_cells[pos]
			
		undo_redo.add_undo_method(active_layer, "set_cell", pos, undo_data["source"], undo_data["coord"], undo_data["alt"])
		
	undo_redo.commit_action()
	_cache_layer()



## Extracts the drawn tile data and replaces the freehand stroke with the selected geometric shape
func _apply_shape_fill(is_erasing: bool = false) -> void:
	if not is_instance_valid(active_layer) or drag_path.is_empty():
		return
		
	var brush_data: Dictionary = {"source": -1, "coord": Vector2i(-1, -1), "alt": -1, "size": Vector2i(1, 1)}
	var is_terrain_mode: bool = is_instance_valid(shape_selector_2) and shape_selector_2.is_visible_in_tree()
	var terrain_set: int = -1
	var terrain_id: int = -1
	
	if not is_erasing:
		var found_brush: bool = false
		for pos in drag_path:
			var current_source: int = active_layer.get_cell_source_id(pos)
			var current_coord: Vector2i = active_layer.get_cell_atlas_coords(pos)
			
			if not cached_cells.has(pos) or cached_cells[pos]["coord"] != current_coord:
				if current_source != -1:
					brush_data = {
						"source": current_source,
						"coord": current_coord,
						"alt": active_layer.get_cell_alternative_tile(pos),
						"size": Vector2i(1, 1)
					}
					
					var source: TileSetSource = active_layer.tile_set.get_source(current_source)
					if source is TileSetAtlasSource:
						brush_data["size"] = source.get_tile_size_in_atlas(current_coord)
						
						if is_instance_valid(large_tile_checkbox_1) and not large_tile_checkbox_1.button_pressed:
							brush_data["size"] = Vector2i(1, 1)
							
						var t_data: TileData = source.get_tile_data(current_coord, brush_data["alt"])
						if t_data and t_data.terrain_set != -1:
							terrain_set = t_data.terrain_set
							terrain_id = t_data.terrain
							
					found_brush = true
					break
					
		if not found_brush:
			return
	else:
		if is_terrain_mode:
			for pos in drag_path:
				if cached_cells.has(pos) and cached_cells[pos]["source"] != -1:
					var source: TileSetSource = active_layer.tile_set.get_source(cached_cells[pos]["source"])
					if source is TileSetAtlasSource:
						var t_data: TileData = source.get_tile_data(cached_cells[pos]["coord"], cached_cells[pos]["alt"])
						if t_data and t_data.terrain_set != -1:
							terrain_set = t_data.terrain_set
							break
							
	var target_cells: Array[Vector2i] = _get_shape_cells()
	var current_cells: Array[Vector2i] = active_layer.get_used_cells()
	var smudge_cells: Dictionary = {}
	
	for pos in current_cells:
		if not cached_cells.has(pos) or cached_cells[pos]["coord"] != active_layer.get_cell_atlas_coords(pos):
			var c_source: int = active_layer.get_cell_source_id(pos)
			var c_coord: Vector2i = active_layer.get_cell_atlas_coords(pos)
			var c_alt: int = active_layer.get_cell_alternative_tile(pos)
			smudge_cells[pos] = {"source": c_source, "coord": c_coord, "alt": c_alt}
			
	for pos in cached_cells.keys():
		if not current_cells.has(pos):
			smudge_cells[pos] = {"source": -1, "coord": Vector2i(-1, -1), "alt": -1}
			
	if is_terrain_mode and terrain_set != -1:
		for pos in smudge_cells.keys():
			if cached_cells.has(pos):
				active_layer.set_cell(pos, cached_cells[pos]["source"], cached_cells[pos]["coord"], cached_cells[pos]["alt"])
			else:
				active_layer.set_cell(pos, -1, Vector2i(-1, -1), -1)
				
		var terrain_to_apply: int = -1 if is_erasing else terrain_id
		active_layer.set_cells_terrain_connect(target_cells, terrain_set, terrain_to_apply, true)
		
		var all_changed_cells: Dictionary = {}
		var new_used_cells: Array[Vector2i] = active_layer.get_used_cells()
		
		for pos in new_used_cells:
			if not cached_cells.has(pos) or cached_cells[pos]["coord"] != active_layer.get_cell_atlas_coords(pos) or cached_cells[pos]["source"] != active_layer.get_cell_source_id(pos):
				all_changed_cells[pos] = true
				
		for pos in cached_cells.keys():
			if not new_used_cells.has(pos):
				all_changed_cells[pos] = true
				
		var undo_redo: EditorUndoRedoManager = get_undo_redo()
		undo_redo.create_action("Draw Geometric Shape (Terrain)")
		
		for pos in all_changed_cells.keys():
			var new_source: int = active_layer.get_cell_source_id(pos)
			var new_coord: Vector2i = active_layer.get_cell_atlas_coords(pos)
			var new_alt: int = active_layer.get_cell_alternative_tile(pos)
			
			var old_data: Dictionary = {"source": -1, "coord": Vector2i(-1, -1), "alt": -1}
			if cached_cells.has(pos):
				old_data = cached_cells[pos]
				
			undo_redo.add_do_method(active_layer, "set_cell", pos, new_source, new_coord, new_alt)
			undo_redo.add_undo_method(active_layer, "set_cell", pos, old_data["source"], old_data["coord"], old_data["alt"])
			
		undo_redo.commit_action()
		_cache_layer()
		return
		
	var valid_anchors: Dictionary = {}
	if brush_data["size"].x > 1 or brush_data["size"].y > 1:
		var size: Vector2i = brush_data["size"]
		for pos in target_cells:
			var overlaps: bool = false
			for v_pos in valid_anchors.keys():
				var rect1: Rect2i = Rect2i(pos, size)
				var rect2: Rect2i = Rect2i(v_pos, size)
				if rect1.intersects(rect2):
					overlaps = true
					break
			if not overlaps:
				valid_anchors[pos] = true
	else:
		for pos in target_cells:
			valid_anchors[pos] = true
			
	var all_affected: Dictionary = {}
	
	for pos in smudge_cells.keys():
		all_affected[pos] = true
		
	for pos in target_cells:
		all_affected[pos] = true
		
	var undo_redo_standard: EditorUndoRedoManager = get_undo_redo()
	undo_redo_standard.create_action("Draw Geometric Shape")
	
	for pos in all_affected.keys():
		var do_data: Dictionary = {"source": -1, "coord": Vector2i(-1, -1), "alt": -1}
		
		if valid_anchors.has(pos):
			if not is_erasing:
				do_data = {"source": brush_data["source"], "coord": brush_data["coord"], "alt": brush_data["alt"]}
		elif pos in target_cells:
			pass
		elif cached_cells.has(pos):
			do_data = cached_cells[pos]
			
		undo_redo_standard.add_do_method(active_layer, "set_cell", pos, do_data["source"], do_data["coord"], do_data["alt"])
		
		var undo_data: Dictionary = {"source": -1, "coord": Vector2i(-1, -1), "alt": -1}
		
		if smudge_cells.has(pos):
			undo_data = smudge_cells[pos]
		elif cached_cells.has(pos):
			undo_data = cached_cells[pos]
			
		undo_redo_standard.add_undo_method(active_layer, "set_cell", pos, undo_data["source"], undo_data["coord"], undo_data["alt"])
		
	undo_redo_standard.commit_action()
	_cache_layer()
