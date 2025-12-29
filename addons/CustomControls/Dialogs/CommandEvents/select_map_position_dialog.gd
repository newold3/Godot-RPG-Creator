@tool
extends Window


var tile_size: Vector2i
var offset: Vector2i
var cursor_position: Vector2i = Vector2i(INF, 0)
var hover_position: Vector2i = Vector2i(-1, -1)
var tile_selected: Vector2i = Vector2i(INF, 0)
var map_id: int

var restrict_position_to_terrain: PackedStringArray = []
var highlight_terrains_index: int = -1

var current_map: RPGMap

var busy: bool = false

# Multi-selection variables
var multiselection_enabled: bool = false
var tiles_selected: Array[Vector2i] = []
var selection_start: Vector2i = Vector2i(-1, -1)
var is_dragging_selection: bool = false
var drag_threshold: int = 8

const MIN_ZOOM: Vector2 = Vector2.ONE * 0.5
const MAX_ZOOM: Vector2 = Vector2(5, 5)


@onready var cursor_canvas: Control = %CursorCanvas
@onready var map_container: SubViewport = %MapContainer
@onready var main_canvas: TextureRect = %MainCanvas


static var position_and_size: Dictionary = {}


signal cell_selected(map_id: int, cell_position: Vector2i)
signal cells_selected(map_id: int, cells_positions: Array[Vector2i])


func _ready() -> void:
	%MainCanvasContainer.visible = false
	close_requested.connect(_end_dialog)
	main_canvas.texture = map_container.get_texture()
	main_canvas.draw.connect(_draw_grid)
	cursor_canvas.gui_input.connect(_on_cursor_canvas_gui_input)
	cursor_canvas.draw.connect(_draw_cursor)
	cursor_canvas.mouse_exited.connect(_hide_cursor)
	
	if RPGDialogFunctions.there_are_any_dialog_open():
		main_canvas.texture = %MapContainer.get_texture()
		
	fill_map_list()
	set_initial_size_an_position()
	_hide_cursor()


func set_terrain_restrictions(terrains: PackedStringArray) -> void:
	restrict_position_to_terrain = terrains
	var node = %TerrainAllowed
	node.clear()
	
	node.add_item(tr("View Allowed Terrains"))
	if terrains.is_empty():
		node.add_item(tr("All"))
	else:
		for terrain in terrains:
			node.add_item(terrain)
	
	node.select(0)


func _process(delta: float) -> void:
	%HoverCell.text = str(hover_position)
	_set_select_cell_text()
	%TerrainName.text = "(" + _get_tile_terrain_name(hover_position) + ")" 


func _set_select_cell_text() -> void:
	if multiselection_enabled:
		if tiles_selected.size() > 1:
			var min_x = tiles_selected[0].x
			var min_y = tiles_selected[0].y
			var max_x = tiles_selected[0].x
			var max_y = tiles_selected[0].y
			
			for tile in tiles_selected:
				min_x = mini(min_x, tile.x)
				min_y = mini(min_y, tile.y)
				max_x = maxi(max_x, tile.x)
				max_y = maxi(max_y, tile.y)
			
			var width = max_x - min_x
			var height = max_y - min_y
			%SelectedCell.text = "From (%s, %s) To (%s, %s)" % [min_x, min_y, min_x + width, min_y + height]
		elif tiles_selected.size() == 1:
			%SelectedCell.text = str(Vector2i(tiles_selected[0]))
		else:
			%SelectedCell.text = str(Vector2i(tile_selected))
	else:
		%SelectedCell.text = str(tile_selected)


func hide_map_list() -> void:
	%MapListContainer.visible = false


func show_map_list() -> void:
	%MapListContainer.visible = true


func set_initial_size_an_position() -> void:
	var start_position = position_and_size.get("position", null)
	if start_position != null:
		position = start_position
	var start_size = position_and_size.get("size", null)
	if start_size != null:
		size = start_size


func select_initial_map() -> void:
	busy = true
	while !is_node_ready():
		await RenderingServer.frame_post_draw
	var node = %MapList
	if node.get_item_count() > 0:
		node.select(0)
		node.ensure_current_is_visible()
		await get_tree().process_frame
		node.item_selected.emit(0)
	%MainCanvasContainer.visible = true
	busy = false


func set_start_map(map_path: String, _tile_selected: Vector2i) -> void:
	busy = true
	while !is_node_ready():
		await RenderingServer.frame_post_draw
	var node = %MapList
	var map_found = false
	for i in range(0, node.get_item_count(), 1):
		if node.get_item_metadata(i) == map_path:
			node.select(i)
			node.ensure_current_is_visible()
			await get_tree().process_frame
			node.item_selected.emit(i)
			await get_tree().process_frame
			set_tile_selected(_tile_selected)
			map_found = true
			break
	
	if not map_found:
		select_initial_map()
	else:
		%MainCanvasContainer.visible = true
	busy = false


func set_tile_selected(_tile_selected: Vector2i) -> void:
	while busy:
		await RenderingServer.frame_post_draw
		
	tile_selected = _tile_selected
	
	if map_container.get_child_count() > 0:
		var map: RPGMap = map_container.get_child(0)
		var rect = map.get_used_rect(false)
		rect.position -= Vector2i(map.position)
		var p = (rect.position - Vector2i.ONE) / map.tile_size
		var s = rect.size / map.tile_size

		if Rect2i(p, s).has_point(_tile_selected):
			tile_selected = _tile_selected
		else:
			tile_selected = Vector2i(p.x + (s.x * 0.5), p.y + (s.y * 0.5))

	var real_pos = Vector2i(tile_selected) * tile_size - offset + Vector2i(%SmoothScrollContainer.size * 0.5)
	for child in %CursorCanvas.get_children():
		child.queue_free()
	var c = Control.new()
	c.custom_minimum_size = tile_size
	c.position = real_pos
	cursor_canvas.add_child(c)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	if is_instance_valid(c):
		%SmoothScrollContainer.bring_target_into_view(c, true,  false)
		cursor_canvas.queue_redraw()


func set_tiles_selected(_tiles_selected: Array[Vector2i]) -> void:
	while busy:
		await RenderingServer.frame_post_draw
		
	if _tiles_selected.is_empty():
		return
	
	tiles_selected = _tiles_selected
	
	if map_container.get_child_count() > 0:
		var map: RPGMap = map_container.get_child(0)
		var rect = map.get_used_rect(false)
		rect.position -= Vector2i(map.position)
		var p = (rect.position - Vector2i.ONE) / map.tile_size
		var s = rect.size / map.tile_size
		
		# Validar que todos los tiles estén dentro del mapa
		var all_valid = true
		for tile in tiles_selected:
			if not Rect2i(p, s).has_point(tile):
				all_valid = false
				break
		
		if not all_valid:
			tiles_selected.clear()
			return
			
	# Calcular centro del rectángulo de selección para scrollear
	var _tile_selected = tiles_selected[int(tiles_selected.size() / 2)]
	var min_x = tiles_selected[0].x
	var min_y = tiles_selected[0].y
	var max_x = tiles_selected[0].x
	var max_y = tiles_selected[0].y
	
	for tile in tiles_selected:
		min_x = mini(min_x, tile.x)
		min_y = mini(min_y, tile.y)
		max_x = maxi(max_x, tile.x)
		max_y = maxi(max_y, tile.y)
	
	var center_x = min_x + (max_x - min_x) / 2
	var center_y = min_y + (max_y - min_y) / 2

	cursor_canvas.queue_redraw()
	
	_set_select_cell_text()
	
	await RenderingServer.frame_post_draw
	set_tile_selected(Vector2i(center_x, center_y))


func fill_map_list() -> void:
	while !is_node_ready():
		await RenderingServer.frame_post_draw
	var node: ItemList = %MapList
	node.clear()
	
	var test_map_id = 8017326834547071
	

	for id: int in RPGMapsInfo.map_infos.map_ids.values():
		if id == test_map_id: continue
		
		var map: String = RPGMapsInfo.map_infos.get_map_name_from_id(id) 
		var path: String = RPGMapsInfo.map_infos.get_path_from_id(id)
		node.add_item(map)
		node.set_item_metadata(-1, path)


func _on_map_list_item_selected(index: int) -> void:
	# Delete old map
	for child in map_container.get_children():
		map_container.remove_child(child)
		child.queue_free()
	
	# Reset Selection
	var old_tile_selected = tile_selected
	reset()
	
	# Add new map
	var map_path = %MapList.get_item_metadata(index)
	
	if not ResourceLoader.exists(map_path):
		printerr("Error Loading Map. Map no found (%s)" % map_path)
		return
	
	var map: RPGMap = ResourceLoader.load(map_path).instantiate()
	map.preview_map_only_enabled = true
	var rect = map.get_used_rect(false)

	map.position -= Vector2(rect.position)
	disable_cameras_in_node(map)
	map_container.size = rect.size
	map_container.add_child(map)
	var s = rect.size
	cursor_canvas.custom_minimum_size = s
	cursor_canvas.size = s
	%MainCanvasContainer.custom_minimum_size = s
	%MainCanvasContainer.size = s
	
	# Select old tile selected if is in map else vector2i.ZERO
	set_tile_selected(old_tile_selected)
	
	# set grid
	tile_size = map.tile_size
	offset = rect.position
	map_id = map.internal_id
	
	current_map = map
	
	cursor_position = Vector2i(INF, 0)
	
	main_canvas.size = Vector2.ZERO
	main_canvas.queue_redraw()


func disable_cameras_in_node(node: Node) -> void:
	if node is Camera2D:
		node.enabled = false
	for child in node.get_children():
		disable_cameras_in_node(child)


func _on_cursor_canvas_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if %SmoothScrollContainer.dragging_middle_mouse:
			%SmoothScrollContainer.update_scroll(-event.relative, true)
			get_viewport().set_input_as_handled()
		
		var mouse_position = event.position
		var new_cursor_position = Vector2i(
			floor((mouse_position.x + offset.x) / tile_size.x),
			floor((mouse_position.y + offset.y) / tile_size.y)
		)
		hover_position = new_cursor_position
		
		if new_cursor_position != cursor_position:
			cursor_position = new_cursor_position
			cursor_canvas.queue_redraw()
		
		# Multi-selection: actualizar visualmente mientras se arrastra
		if is_dragging_selection:
			var preview_tiles = _get_tiles_in_rect(selection_start, cursor_position)
			if preview_tiles.size() > 0:
				tiles_selected = preview_tiles
				_set_select_cell_text()
			cursor_canvas.queue_redraw()
	
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if multiselection_enabled:
			# Iniciar selección múltiple
			if event.is_double_click():
				_on_ok_button_pressed()
			elif tiles_selected.size() > 0 and event.is_ctrl_pressed():
				_on_ok_button_pressed()
			else:
				selection_start = cursor_position
				is_dragging_selection = true
				get_viewport().set_input_as_handled()
		elif event.is_double_click():
			_on_ok_button_pressed()
		else:
			# Single selection mode
			var back_tile_selected = tile_selected
			tile_selected = cursor_position
			if restrict_position_to_terrain and !is_valid_terrain():
				tile_selected = back_tile_selected
			else:
				cursor_canvas.queue_redraw()
	
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and !event.pressed:
		# Finalizar selección múltiple
		if multiselection_enabled and is_dragging_selection:
			tiles_selected = _get_tiles_in_rect(selection_start, cursor_position)
			is_dragging_selection = false
			selection_start = Vector2i(-1, -1)
			cursor_canvas.queue_redraw()
			get_viewport().set_input_as_handled()
	
	elif event is InputEventMouseButton and !event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Finalizar arrastre cuando se suelta el botón
		if multiselection_enabled and is_dragging_selection:
			tiles_selected = _get_tiles_in_rect(selection_start, cursor_position)
			is_dragging_selection = false
			selection_start = Vector2i(-1, -1)
			cursor_canvas.queue_redraw()
			get_viewport().set_input_as_handled()
	
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.is_ctrl_pressed():
		zoom_down()
		get_viewport().set_input_as_handled()
	
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP and event.is_ctrl_pressed():
		get_viewport().set_input_as_handled()
		zoom_up()
	
	if event is InputEventMouseButton:
		if event.is_pressed():
			if event.button_index == MOUSE_BUTTON_MIDDLE:
				%SmoothScrollContainer.dragging_middle_mouse = true
				get_viewport().set_input_as_handled()
		elif %SmoothScrollContainer.dragging_middle_mouse:
			%SmoothScrollContainer.dragging_middle_mouse = false
			get_viewport().set_input_as_handled()


func _get_tiles_in_rect(start: Vector2i, end: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	
	var min_x = min(start.x, end.x)
	var max_x = max(start.x, end.x)
	var min_y = min(start.y, end.y)
	var max_y = max(start.y, end.y)
	
	for x in range(min_x, max_x + 1):
		for y in range(min_y, max_y + 1):
			var tile = Vector2i(x, y)
			
			# Validar restricciones de terreno si aplica
			if restrict_position_to_terrain.size() > 0:
				if !_is_valid_tile_for_terrain(tile):
					continue
			
			result.append(tile)
	
	return result


func _is_valid_tile_for_terrain(tile: Vector2i) -> bool:
	if current_map:
		return current_map.can_move_over_terrain(tile, restrict_position_to_terrain)
	return false


func is_valid_terrain() -> bool:
	if current_map:
		return current_map.can_move_over_terrain(tile_selected, restrict_position_to_terrain)
	
	return false


func reset() -> void:
	tile_selected = Vector2i(INF, 0)
	cursor_position = Vector2i(INF, 0)
	tiles_selected.clear()
	selection_start = Vector2i(-1, -1)
	is_dragging_selection = false
	cursor_canvas.queue_redraw()
	
	main_canvas.scale = Vector2.ONE
	main_canvas.pivot_offset = Vector2.ZERO
	%MainCanvasContainer.custom_minimum_size = Vector2.ZERO
	%MainCanvasContainer.size = %MainCanvasContainer.custom_minimum_size


func _draw_cursor() -> void:
	# Dibujar tiles seleccionados en modo multi-selection
	if multiselection_enabled and tiles_selected.size() > 0:
		for tile: Vector2i in tiles_selected:
			var rect = Rect2(
				tile * tile_size - offset,
				tile_size
			)
			cursor_canvas.draw_rect(rect, Color.GREEN, false, 2)
			cursor_canvas.draw_rect(rect, Color(0, 1, 0, 0.3), true)
	
	# Dibujar área de arrastre mientras se selecciona
	if multiselection_enabled and is_dragging_selection and selection_start != Vector2i(-1, -1):
		var min_x = min(selection_start.x, cursor_position.x)
		var max_x = max(selection_start.x, cursor_position.x)
		var min_y = min(selection_start.y, cursor_position.y)
		var max_y = max(selection_start.y, cursor_position.y)
		
		var rect = Rect2(
			Vector2i(min_x, min_y) * tile_size - offset,
			Vector2i(max_x - min_x + 1, max_y - min_y + 1) * tile_size
		)
		cursor_canvas.draw_rect(rect, Color.YELLOW, false, 2)
		cursor_canvas.draw_rect(rect, Color(1, 1, 0, 0.15), true)
	
	# Dibujar single selection (modo normal)
	if not multiselection_enabled and tile_selected.x != INF:
		var rect = Rect2(
			tile_selected * tile_size - offset,
			tile_size
		)
		cursor_canvas.draw_rect(rect, Color.BLUE, false)
		cursor_canvas.draw_rect(rect, Color(0.011, 0.426, 0.676, 0.4), true)

	if cursor_position.x == INF:
		return

	# Dibujar cursor hover
	var rect = Rect2(
		cursor_position * tile_size - offset,
		tile_size
	)
	
	cursor_canvas.draw_rect(rect, Color(1, 1, 1, 0.8), false)
	cursor_canvas.draw_rect(rect, Color(1, 1, 1, 0.4), true)


func _hide_cursor() -> void:
	cursor_position.x = INF
	cursor_canvas.queue_redraw()


func _draw_grid() -> void:
	if !tile_size or !main_canvas.texture:
		return
		
	var canvas: Control = main_canvas
	var color = Color(0.871, 0.675, 0.374, 0.85)
	
	var offset_x = fmod(offset.x, tile_size.x)
	var offset_y = fmod(offset.y, tile_size.y)
	var start_x = -offset_x
	var start_y = -offset_y
	
	# Draw vertical lines
	var ix = start_x
	while ix < canvas.size.x:
		canvas.draw_line(Vector2(ix, 0), Vector2(ix, canvas.size.y), color)
		ix += tile_size.x

	# Draw horizontal lines
	var iy = start_y
	while iy < canvas.size.y:
		canvas.draw_line(Vector2(0, iy), Vector2(canvas.size.x, iy), color)
		iy += tile_size.y
	
	# Draw highlights
	if highlight_terrains_index >= 0 and restrict_position_to_terrain.size() > highlight_terrains_index:
		var target_terrain = restrict_position_to_terrain[highlight_terrains_index].to_lower()
		var color_terrain_background = Color(1.0, 0.0, 0.0, 0.12)
		var color_terrain_background_unavailable = Color(0.0, 0.0, 0.0, 0.85)
		var color_terrain_border = Color(0.0, 0.0, 0.0, 0.45)
		var color_terrain_border_size = 2
		
		var target_is_all = target_terrain == "all"
		var target_starts_with_wildcard = target_terrain.begins_with("*")
		var target_starts_with_negation = target_terrain.begins_with("^")
		var wildcard_pattern = target_terrain.substr(1) if target_starts_with_wildcard or target_starts_with_negation else ""
		
		offset_x = offset.x
		offset_y = offset.y

		for x in range(0, canvas.size.x, tile_size.x):
			for y in range(0, int(canvas.size.y), tile_size.y):
				var tile = Vector2i(
					floor((x + offset_x) / tile_size.x),
					floor((y + offset_y) / tile_size.y)
				)
				var terrain_name = _get_tile_terrain_name(tile).to_lower()
				var rect = Rect2(x, y, tile_size.x, tile_size.y)
				
				var is_match = target_is_all or \
					(target_starts_with_wildcard and terrain_name.contains(wildcard_pattern)) or \
					(target_starts_with_negation and not terrain_name.contains(wildcard_pattern)) or \
					(terrain_name == target_terrain)
				
				canvas.draw_rect(rect, color_terrain_background if is_match else color_terrain_background_unavailable)
				canvas.draw_rect(rect, color_terrain_border, false, color_terrain_border_size)
					

func _on_ok_button_pressed() -> void:
	if multiselection_enabled and tiles_selected.size() > 0:
		cells_selected.emit(map_id, tiles_selected)
	elif tile_selected.x != INF and map_id:
		cell_selected.emit(map_id, tile_selected)
	_end_dialog()


func _on_cancel_button_pressed() -> void:
	_end_dialog()


func _end_dialog() -> void:
	position_and_size.position = position
	position_and_size.size = size
	queue_free()


func _get_tile_terrain_name(tile: Vector2i) -> String:
	var terrain_name = current_map.get_tile_terrain_name(tile) if current_map else ""
	
	return str(terrain_name)


func zoom_down() -> void:
	_zoom(-Vector2(0.1, 0.1))


func zoom_up() -> void:
	_zoom(Vector2(0.1, 0.1))


func _zoom(mod: Vector2) -> void:
	var scroll_container = %SmoothScrollContainer
	var main_canvas_container = %MainCanvasContainer
	
	var mouse_position = main_canvas.get_local_mouse_position()
	var viewport_size = scroll_container.size
	var previous_scale = main_canvas.scale
	
	# Calculate new scale
	var new_scale = (main_canvas.scale + mod).clamp(MIN_ZOOM, MAX_ZOOM)
	
	# Si no hay cambio en la escala, salir
	if new_scale == previous_scale:
		return
	
	# Calculate new size
	var new_size = main_canvas.texture.get_size() * new_scale
	
	# Punto focal en coordenadas de contenido (antes del zoom)
	var focal_point = (mouse_position + Vector2(scroll_container.scroll_horizontal, scroll_container.scroll_vertical)) / previous_scale
	
	# Actualizar escala y tamaño
	main_canvas.scale = new_scale
	main_canvas_container.custom_minimum_size = new_size
	main_canvas_container.size = new_size
	
	# Calcular la nueva posición de scroll para mantener el punto focal
	var new_scroll_pos = focal_point * new_scale - mouse_position
	
	# Actualizar posición de scroll
	scroll_container.scroll_horizontal = new_scroll_pos.x
	scroll_container.scroll_vertical = new_scroll_pos.y
	
	# Limitar los valores de scroll
	scroll_container.scroll_horizontal = clamp(scroll_container.scroll_horizontal, 0, max(0, new_size.x - viewport_size.x))
	scroll_container.scroll_vertical = clamp(scroll_container.scroll_vertical, 0, max(0, new_size.y - viewport_size.y))


func set_layer_mode(layer_id: int = -1) -> void:
	while busy:
		await RenderingServer.frame_post_draw
		
	%SelectedCellTitle.text = tr("Selected cell/s:")
	%TopContainer.visible = false
	multiselection_enabled = true
	tiles_selected.clear()
		
	if layer_id != -1:
		if current_map:
			var layers = []
			for node in current_map.get_children():
				if node is TileMapLayer:
					layers.append(node)
			
			if layers.size() > layer_id:
				for i in layers.size():
					var layer = layers[i]
					if i == layer_id:
						layer.modulate = Color.WHITE
					else:
						layer.modulate = Color(3.0, 3.0, 3.0, 0.3)


func _on_terrain_allowed_item_selected(index: int) -> void:
	highlight_terrains_index = index
	if index == 0:
		highlight_terrains_index = -1
	else:
		highlight_terrains_index = index - 1
	main_canvas.queue_redraw()
