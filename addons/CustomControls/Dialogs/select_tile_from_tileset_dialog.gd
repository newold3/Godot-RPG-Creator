@tool
extends Window


#region EXPORTS
## Reference to the Canvas (TextureRect/Control) where the grid is drawn
@export var canvas: Control

## Reference to the ScrollContainer holding the Canvas
@export var scroll_container: ScrollContainer

## Reference to the ItemList displaying available atlases
@export var atlas_list: ItemList

## Reference to the ItemList displaying added decorators
@export var data_list: ItemList

## Reference to the TextureRect displaying the actual atlas image
@export var current_atlas: TextureRect

## Reference to the Cancel button
@export var cancel_button: Button

## Reference to the OK button
@export var ok_button: Button

## Reference to the Delete button for items
@export var delete_button: Button

## Reference to the button that toggles alternative tile picking mode
@export var alt_mode_button: Button

## Reference to the SpinBox setting the appearance percentage
@export var appear_percent_spinbox: SpinBox

## Reference to the SpinBox setting the appearance percentage
@export var max_quantity_spinbox: SpinBox

## Reference to the SpinBox setting the probability of choosing the alternative tile
@export var alt_chance_spinbox: SpinBox

## Reference to the OptionButton setting the placement mode
@export var placement_mode_option: OptionButton

## Reference to the WallPositions setting the wall position
@export var environment_position: OptionButton

@export var is_detail_tile: CheckBox

## Reference to the UI Label used to display the current coordinates and status
@export var info_label: Label

## Reference to the CheckBox that disables the decorator for generation
@export var is_tile_disabled: CheckBox

## Defines the height of the physical “footprint.”
## Usage: Determines how many tiles from the base upward block the path and require floor validation.
@export var footprint_height: SpinBox

## Defines the required clearance (Left).
## Usage: If a value is greater than 0, the generator will invalidate the position if it encounters a wall within that distance in that specific direction.
@export var wall_margin_left: SpinBox

## Defines the required clearance (Right).
## Usage: If a value is greater than 0, the generator will invalidate the position if it encounters a wall within that distance in that specific direction.
@export var wall_margin_right: SpinBox 

## Defines the required clearance (Top).
## Usage: If a value is greater than 0, the generator will invalidate the position if it encounters a wall within that distance in that specific direction.
@export var wall_margin_top: SpinBox 

## Defines the required clearance (Bottom).
## Usage: If a value is greater than 0, the generator will invalidate the position if it encounters a wall within that distance in that specific direction.
@export var wall_margin_bottom: SpinBox 
#endregion


#region VARIABLES
var cache: Dictionary
var original_data: Array
var current_data: Array
var current_texture: String

var hovered_coord: Vector2i = Vector2i(-1, -1)
var drag_start_coord: Vector2i = Vector2i(-1, -1)
var is_dragging_selection: bool = false

var selected_rect: Rect2i = Rect2i(-1, -1, 0, 0)
var alt_selected_rect: Rect2i = Rect2i(-1, -1, 0, 0)
var ghost_focus: Control

var is_picking_alternative: bool = false
var _blink_time: float = 0.0
var is_panning: bool = false
var _has_dragged_while_panning: bool = false
var zoom_level: float = 1.0
var _is_syncing: bool = false

var single_mode_enabled: bool = false
#endregion

#region Signals
signal tile_selected(atlas_id: int, tile_id: Vector2i)
#endregion



## Initializes the dialog, connects signals, and prepares visual helper nodes
func _ready() -> void:
	close_requested.connect(queue_free)
	
	current_atlas.self_modulate = Color.TRANSPARENT
	current_atlas.set_anchors_preset(Control.PRESET_TOP_LEFT, true)
	canvas.set_anchors_preset(Control.PRESET_TOP_LEFT, true)
	
	canvas.mouse_filter = Control.MOUSE_FILTER_PASS
	canvas.draw.connect(_on_canvas_draw)
	canvas.item_rect_changed.connect(canvas.queue_redraw)
	canvas.gui_input.connect(_on_canvas_input)
	canvas.mouse_exited.connect(_on_canvas_mouse_exited)
	
	scroll_container.get_h_scroll_bar().value_changed.connect(_on_scroll_changed)
	scroll_container.get_v_scroll_bar().value_changed.connect(_on_scroll_changed)
	scroll_container.resized.connect(_on_scroll_container_resized)
	
	cancel_button.pressed.connect(_on_cancel_button_pressed)
	ok_button.pressed.connect(_on_ok_button_pressed)
	delete_button.pressed.connect(_delete_selected_item)
	alt_mode_button.toggled.connect(_on_alt_mode_toggled)
	
	atlas_list.item_selected.connect(_on_atlas_list_item_selected)
	
	data_list.allow_reselect = true
	data_list.item_selected.connect(_on_data_list_item_selected)
	data_list.gui_input.connect(_on_data_list_gui_input)
	
	appear_percent_spinbox.value_changed.connect(_on_appear_percent_changed)
	alt_chance_spinbox.value_changed.connect(_on_alt_chance_changed)
	max_quantity_spinbox.value_changed.connect(_on_max_quantity_changed)
	
	footprint_height.value_changed.connect(_on_footprint_height_value_changed)
	wall_margin_left.value_changed.connect(_on_margin_left_value_changed)
	wall_margin_right.value_changed.connect(_on_margin_right_value_changed)
	wall_margin_top.value_changed.connect(_on_margin_top_value_changed)
	wall_margin_bottom.value_changed.connect(_on_margin_bottom_value_changed)
	
	if is_instance_valid(placement_mode_option):
		placement_mode_option.item_selected.connect(_on_placement_mode_changed)
	else:
		push_warning("MapGenerator: placement_mode_option no está asignado en el Inspector.")
		
	if is_instance_valid(environment_position):
		environment_position.item_selected.connect(_on_environment_positions_item_selected)
	else:
		push_warning("MapGenerator: environment_position no está asignado en el Inspector.")
	
	is_detail_tile.toggled.connect(_on_detail_tile_toggled)
	
	if is_tile_disabled:
		is_tile_disabled.toggled.connect(_on_is_tile_disabled_toggled)
	
	ghost_focus = Control.new()
	ghost_focus.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(ghost_focus)
			
	if Engine.is_editor_hint():
		var base_theme: Theme = EditorInterface.get_editor_theme()
		delete_button.icon = base_theme.get_icon("Remove", "EditorIcons")
		alt_mode_button.icon = base_theme.get_icon("ColorPick", "EditorIcons")
	
	%RightColumn.propagate_call("set_disabled", [true])



## Recalculates the layout and visibility for single tile selection mode
func set_single_mode(value: bool = true) -> void:
	single_mode_enabled = value
	
	if has_node("%RightColumn"):
		%RightColumn.visible = !value
		
	if not is_inside_tree():
		await ready
		
	await get_tree().process_frame
	await get_tree().process_frame
	
	_on_scroll_container_resized(true)



## Animates the blinking cursor effect for selected tiles
func _process(delta: float) -> void:
	if selected_rect.position != Vector2i(-1, -1):
		_blink_time += delta * 6.0
		canvas.queue_redraw()



## Parses the TileSet to cache atlas data and copies existing decorators for editing
func set_data(tileset: TileSet, _current_data: Array = [], initial_tile: Dictionary = {}) -> void:
	original_data = _current_data
	current_data = _current_data.duplicate(true)
	
	cache = {
		"tile_size": tileset.tile_size,
		"atlases": {}
	}

	for i in range(tileset.get_source_count()):
		var source_id: int = tileset.get_source_id(i)
		var source: TileSetSource = tileset.get_source(source_id)

		if not source is TileSetAtlasSource:
			continue
		
		var atlas_source: TileSetAtlasSource = source as TileSetAtlasSource
		var texture: Texture2D = atlas_source.texture
		
		if not texture:
			continue
			
		var atlas_path: String = texture.resource_path
		var atlas_data: Dictionary = {
			"source_id": source_id,
			"texture": texture,
			"tile_ids": []
		}
		
		for j in range(atlas_source.get_tiles_count()):
			var coords: Vector2i = atlas_source.get_tile_id(j)
			atlas_data["tile_ids"].append(coords)
			
		cache["atlases"][atlas_path] = atlas_data
	
	refresh()
	
	if not initial_tile.is_empty() and initial_tile.get("atlas_id", -1) != -1:
		_select_initial_tile(initial_tile)
	elif data_list.get_item_count() > 0:
		data_list.select(0)
		_on_data_list_item_selected.call_deferred(0)



## Helper that finds and selects an atlas and tile coordinate from external data
func _select_initial_tile(initial_tile: Dictionary) -> void:
	var target_id = initial_tile.atlas_id
	var target_coords = initial_tile.tile_id
	var atlas_path_found: String = ""
	
	for path in cache["atlases"]:
		if cache["atlases"][path]["source_id"] == target_id:
			atlas_path_found = path
			break
			
	if atlas_path_found != "":
		for i in range(atlas_list.get_item_count()):
			if atlas_list.get_item_metadata(i) == atlas_path_found:
				atlas_list.select(i)
				_on_atlas_list_item_selected(i)
				break
		
		selected_rect = Rect2i(target_coords, Vector2i(1, 1))
		
		for i in range(data_list.get_item_count()):
			var item = data_list.get_item_metadata(i)
			if int(item["source_id"]) == target_id and item["atlas_coords"] == target_coords:
				data_list.select(i)
				_on_data_list_item_selected.call_deferred(i)
				break
		
		_focus_tile_in_canvas.call_deferred(target_coords, Vector2i(1, 1))
		canvas.queue_redraw()



func _focus_tile_in_canvas(target_coords: Vector2i, target_size: Vector2i, alt_coords: Vector2i = Vector2i(-1, -1)) -> void:
	
	if is_instance_valid(scroll_container) and is_instance_valid(ghost_focus):
		var tile_size: Vector2i = cache["tile_size"]
		ghost_focus.custom_minimum_size = Vector2(target_size * tile_size) * zoom_level
		ghost_focus.size = Vector2(target_size * tile_size) * zoom_level
		
		if alt_coords != Vector2i(-1, -1):
			ghost_focus.position = Vector2(alt_coords.x * tile_size.x, alt_coords.y * tile_size.y) * zoom_level
			scroll_container.bring_target_into_view.call_deferred(ghost_focus)
			
		ghost_focus.position = Vector2(target_coords.x * tile_size.x, target_coords.y * tile_size.y) * zoom_level
		scroll_container.bring_target_into_view.call_deferred(ghost_focus)



## Updates all UI lists and forces the canvas to refresh its view
func refresh() -> void:
	_fill_atlas_list()
	_fill_data_list()
	canvas.queue_redraw()



## Populates the atlas list from cached data and auto-selects the first entry
func _fill_atlas_list() -> void:
	atlas_list.clear()
	
	for atlas_path in cache["atlases"]:
		var atlas_data: Dictionary = cache["atlases"][atlas_path]
		var source_id: int = atlas_data["source_id"]
		var idx: int = atlas_list.add_item("Atlas " + str(source_id))
		atlas_list.set_item_metadata(idx, atlas_path)
	
	if atlas_list.get_item_count() > 0:
		atlas_list.select(0)
		_on_atlas_list_item_selected(0)



## Populates the decorator list and ensures labels reflect multi-tile info
func _fill_data_list() -> void:
	data_list.clear()
	
	for item in current_data:
		var s: Vector2i = item.get("atlas_size", Vector2i(1, 1))
		var text: String = "Atlas " + str(item["source_id"]) + " | " + str(item["atlas_coords"])
		if s != Vector2i(1, 1): text += " [" + str(s.x) + "x" + str(s.y) + "]"
		
		var alt_coord: Vector2i = item.get("alt_atlas_coords", Vector2i(-1, -1))
		if alt_coord != Vector2i(-1, -1):
			text += " (Alt: " + str(alt_coord) + ")"
			
		var idx: int = data_list.add_item(text)
		data_list.set_item_metadata(idx, item)
		
		var is_enabled: bool = item.get("enabled", true)
		if not is_enabled:
			data_list.set_item_custom_bg_color(idx, Color(0.8, 0.2, 0.2, 0.3))
		else:
			data_list.set_item_custom_bg_color(idx, Color(0, 0, 0, 0))



## Updates the fixed UI label text based on current selection and hover states
func _update_info_label() -> void:
	if not is_instance_valid(info_label): return
	
	info_label.visible = true
	
	if hovered_coord == Vector2i(-1, -1):
		info_label.visible = false
		info_label.text = ""
		return
		
	if is_panning:
		info_label.text = "Scrolling..."
		return
		
	if is_dragging_selection:
		var min_c: Vector2i = Vector2i(mini(drag_start_coord.x, hovered_coord.x), mini(drag_start_coord.y, hovered_coord.y))
		var max_c: Vector2i = Vector2i(maxi(drag_start_coord.x, hovered_coord.x), maxi(drag_start_coord.y, hovered_coord.y))
		var sc: Vector2i = max_c - min_c + Vector2i(1, 1)
		info_label.text = "Rect: " + str(sc.x) + "x" + str(sc.y)
	elif is_picking_alternative:
		info_label.text = "PICK ALT: " + str(hovered_coord)
	else:
		info_label.text = "Tile: " + str(hovered_coord)



## Calculates the minimum dynamic zoom ensuring it covers small textures or fits large ones
func _get_min_zoom() -> float:
	if current_texture.is_empty() or not cache["atlases"].has(current_texture):
		return 1.0
		
	var tex_size: Vector2 = cache["atlases"][current_texture]["texture"].get_size()
	
	if tex_size.x == 0 or tex_size.y == 0:
		return 1.0
		
	var available: Vector2 = scroll_container.size
	
	if available.x <= 0 or available.y <= 0:
		return 1.0
		
	var scale_x: float = available.x / tex_size.x
	var scale_y: float = available.y / tex_size.y
	
	return maxf(scale_x, scale_y)



## Enforces the minimum zoom level dynamically when the container is resized or maximized
func _on_scroll_container_resized(force_update: bool = false) -> void:
	if current_texture.is_empty():
		return
		
	var min_z: float = _get_min_zoom()
	
	if zoom_level < min_z or force_update:
		_update_zoom(min_z, Vector2(-1, -1), force_update)



## Draws the exact texture and scaled grid, completely ignoring container stretch logic
func _on_canvas_draw() -> void:
	if current_texture.is_empty() or not cache["atlases"].has(current_texture):
		return
		
	var tex: Texture2D = cache["atlases"][current_texture]["texture"]
	var tile_size: Vector2i = cache["tile_size"]
	var tex_size: Vector2 = tex.get_size()
	
	if tex_size.x == 0 or tex_size.y == 0:
		return
		
	var exact_scale: Vector2 = Vector2(zoom_level, zoom_level)
	
	# Dibujamos nosotros mismos la textura para asegurar que se ancla en 0,0 al tamaño exacto
	canvas.draw_texture_rect(tex, Rect2(Vector2.ZERO, tex_size * zoom_level), false)
	
	var cols: int = int(tex_size.x / tile_size.x)
	var rows: int = int(tex_size.y / tile_size.y)
	var grid_color: Color = Color(1, 1, 1, 0.3)
	
	canvas.draw_set_transform(Vector2.ZERO, 0.0, exact_scale)
	
	for x in range(cols + 1):
		canvas.draw_line(Vector2(x * tile_size.x, 0), Vector2(x * tile_size.x, tex_size.y), grid_color)
		
	for y in range(rows + 1):
		canvas.draw_line(Vector2(0, y * tile_size.y), Vector2(tex_size.x, y * tile_size.y), grid_color)
		
	if is_dragging_selection and drag_start_coord != Vector2i(-1, -1) and hovered_coord != Vector2i(-1, -1):
		var min_c: Vector2i = Vector2i(mini(drag_start_coord.x, hovered_coord.x), mini(drag_start_coord.y, hovered_coord.y))
		var max_c: Vector2i = Vector2i(maxi(drag_start_coord.x, hovered_coord.x), maxi(drag_start_coord.y, hovered_coord.y))
		var size_c: Vector2i = max_c - min_c + Vector2i(1, 1)
		
		var drag_rect: Rect2 = Rect2(Vector2(min_c.x * tile_size.x, min_c.y * tile_size.y), Vector2(size_c.x * tile_size.x, size_c.y * tile_size.y))
		var drag_color: Color = Color(1.0, 1.0, 0.2, 0.4) if not is_picking_alternative else Color(0.2, 0.6, 1.0, 0.5)
		canvas.draw_rect(drag_rect, drag_color)
	elif hovered_coord != Vector2i(-1, -1):
		var hl_rect: Rect2 = Rect2(Vector2(hovered_coord.x * tile_size.x, hovered_coord.y * tile_size.y), Vector2(tile_size))
		var hl_color: Color = Color(1.0, 1.0, 0.2, 0.4) if not is_picking_alternative else Color(0.2, 0.6, 1.0, 0.5)
		canvas.draw_rect(hl_rect, hl_color)
		
	if selected_rect.position != Vector2i(-1, -1):
		var blink_alpha: float = (sin(_blink_time) + 1.0) * 0.5 * 0.4 + 0.2
		var sel_draw_rect: Rect2 = Rect2(Vector2(selected_rect.position.x * tile_size.x, selected_rect.position.y * tile_size.y), Vector2(selected_rect.size.x * tile_size.x, selected_rect.size.y * tile_size.y))
		canvas.draw_rect(sel_draw_rect, Color(0.2, 1.0, 0.2, blink_alpha))
		canvas.draw_rect(sel_draw_rect, Color(0.2, 1.0, 0.2, 0.8), false, 2.0 / zoom_level)
		
		if alt_selected_rect.position != Vector2i(-1, -1):
			var alt_draw_rect: Rect2 = Rect2(Vector2(alt_selected_rect.position.x * tile_size.x, alt_selected_rect.position.y * tile_size.y), Vector2(alt_selected_rect.size.x * tile_size.x, alt_selected_rect.size.y * tile_size.y))
			canvas.draw_rect(alt_draw_rect, Color(0.2, 0.6, 1.0, blink_alpha))
			canvas.draw_rect(alt_draw_rect, Color(0.2, 0.6, 1.0, 0.8), false, 2.0 / zoom_level)
			
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)



## Manages mouse motion, clicks, multi-select dragging, panning and zooming
func _on_canvas_input(event: InputEvent) -> void:
	if current_texture.is_empty() or not cache["atlases"].has(current_texture):
		return
		
	var tex_size: Vector2 = cache["atlases"][current_texture]["texture"].get_size()
	
	if tex_size.x == 0 or tex_size.y == 0:
		return
		
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
		var tile_size: Vector2i = cache["tile_size"]
		var new_coord: Vector2i = Vector2i(-1, -1)
		
		if scaled_pos.x >= 0 and scaled_pos.y >= 0 and scaled_pos.x < tex_size.x and scaled_pos.y < tex_size.y:
			new_coord = Vector2i(int(scaled_pos.x) / tile_size.x, int(scaled_pos.y) / tile_size.y)
			
		if new_coord != hovered_coord:
			hovered_coord = new_coord
			canvas.queue_redraw()
			if has_method("_update_info_label"): call("_update_info_label")
			
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			if event.pressed:
				is_panning = true
				_has_dragged_while_panning = false
			else:
				is_panning = false
				if not _has_dragged_while_panning:
					_update_zoom(1.0, event.position / zoom_level)
					
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.ctrl_pressed and event.pressed:
			_update_zoom(zoom_level + 0.25, event.position / zoom_level)
			get_viewport().set_input_as_handled()
			
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.ctrl_pressed and event.pressed:
			_update_zoom(zoom_level - 0.25, event.position / zoom_level)
			get_viewport().set_input_as_handled()
			
		elif event.button_index == MOUSE_BUTTON_LEFT:
			var atlas_data: Dictionary = cache["atlases"][current_texture]
			
			if event.pressed:
				if single_mode_enabled:
					var atlas_id: int = atlas_data["source_id"]
					var tile_id: Vector2i = hovered_coord
					_select_single_tile(atlas_id, tile_id)
					return
					
				var can_select: bool = false
				if hovered_coord in atlas_data["tile_ids"]:
					can_select = true
				else:
					for item in current_data:
						if item["source_id"] == atlas_data["source_id"]:
							var item_coords: Vector2i = item["atlas_coords"]
							var item_size: Vector2i = item.get("atlas_size", Vector2i(1, 1))
							var item_rect := Rect2i(item_coords, item_size)
							if item_rect.has_point(hovered_coord):
								can_select = true
								break
								
				if can_select:
					is_dragging_selection = true
					drag_start_coord = hovered_coord
					canvas.queue_redraw()
					if has_method("_update_info_label"): call("_update_info_label")
			else:
				if is_dragging_selection and hovered_coord != Vector2i(-1, -1):
					is_dragging_selection = false
					var min_c: Vector2i = Vector2i(mini(drag_start_coord.x, hovered_coord.x), mini(drag_start_coord.y, hovered_coord.y))
					var max_c: Vector2i = Vector2i(maxi(drag_start_coord.x, hovered_coord.x), maxi(drag_start_coord.y, hovered_coord.y))
					var final_rect: Rect2i = Rect2i(min_c, max_c - min_c + Vector2i(1, 1))
					
					if is_picking_alternative:
						_apply_alternative_tile(final_rect)
					else:
						_add_new_decorator(atlas_data, final_rect)
				else:
					is_dragging_selection = false
				if has_method("_update_info_label"): call("_update_info_label")


func _select_single_tile(atlas_id: int, tile_id: Vector2i) -> void:
	tile_selected.emit(atlas_id, tile_id)
	queue_free()

## Updates the zoom level purely through math, forcing the custom smooth container to sync instantly
func _update_zoom(new_zoom: float, focus_local_pos: Vector2 = Vector2(-1, -1), force_update: bool = false) -> void:
	var min_z: float = _get_min_zoom()
	var old_zoom: float = zoom_level
	
	zoom_level = clampf(new_zoom, min_z, min_z + 5.0)
	
	if zoom_level == old_zoom and not force_update: 
		return
		
	var tex_size: Vector2 = cache["atlases"][current_texture]["texture"].get_size()
	var focus: Vector2 = focus_local_pos
	
	if focus == Vector2(-1, -1):
		var visible_center = Vector2(scroll_container.scroll_horizontal, scroll_container.scroll_vertical) + (scroll_container.size / 2.0)
		focus = visible_center / old_zoom
		
	var zoom_diff: float = zoom_level - old_zoom
	var target_scroll_x: float = scroll_container.scroll_horizontal + (focus.x * zoom_diff)
	var target_scroll_y: float = scroll_container.scroll_vertical + (focus.y * zoom_diff)
	var new_size: Vector2 = tex_size * zoom_level
	
	current_atlas.custom_minimum_size = new_size
	current_atlas.size = new_size
	canvas.custom_minimum_size = new_size
	canvas.size = new_size
	
	var h_bar: ScrollBar = scroll_container.get_h_scroll_bar()
	var v_bar: ScrollBar = scroll_container.get_v_scroll_bar()
	
	if h_bar: h_bar.max_value = maxf(h_bar.max_value, new_size.x)
	if v_bar: v_bar.max_value = maxf(v_bar.max_value, new_size.y)
	
	var max_scroll_x: float = maxf(0.0, new_size.x - scroll_container.size.x)
	var max_scroll_y: float = maxf(0.0, new_size.y - scroll_container.size.y)
	
	scroll_container.scroll_horizontal = int(clamp(target_scroll_x, 0.0, max_scroll_x))
	scroll_container.scroll_vertical = int(clamp(target_scroll_y, 0.0, max_scroll_y))
	
	if scroll_container.has_method("fast_scrolling"):
		scroll_container.fast_scrolling()
	elif scroll_container.has_method("fast_scrolling"):
		scroll_container.fast_scrolling()
		
	canvas.queue_redraw()



## Updates active texture, scales minimum sizes, and cleans selection states when an atlas is selected
func _on_atlas_list_item_selected(index: int) -> void:
	current_texture = atlas_list.get_item_metadata(index)
	var atlas_data: Dictionary = cache["atlases"][current_texture]
	var tex: Texture2D = atlas_data["texture"]
	
	if is_instance_valid(scroll_container):
		if scroll_container.has_method("reset_scroll"):
			scroll_container.reset_scroll()
			
	zoom_level = _get_min_zoom()
	
	current_atlas.texture = null
	current_atlas.custom_minimum_size = Vector2.ZERO
	current_atlas.size = Vector2.ZERO
	
	current_atlas.texture = tex
	var tex_size: Vector2 = tex.get_size()
	
	var new_size: Vector2 = tex_size * zoom_level
	current_atlas.custom_minimum_size = new_size
	current_atlas.size = new_size
	canvas.custom_minimum_size = new_size
	canvas.size = new_size
	
	if not _is_syncing:
		data_list.deselect_all()
		hovered_coord = Vector2i(-1, -1)
		selected_rect = Rect2i(-1, -1, 0, 0)
		alt_selected_rect = Rect2i(-1, -1, 0, 0)
		_disable_alt_mode()
		
	if not is_inside_tree():
		await ready
		
	await get_tree().process_frame
	
	if is_instance_valid(scroll_container):
		if scroll_container.has_method("fast_reposition"):
			scroll_container.fast_reposition()
			
	_update_zoom(_get_min_zoom(), Vector2.ZERO, true)
	
	if is_instance_valid(canvas):
		canvas.queue_redraw()


## Helper function to safely select an OptionButton item by its ID, preventing Index desyncs
func _select_option_by_id(option_btn: OptionButton, target_id: int) -> void:
	if not is_instance_valid(option_btn): return
	
	for i in range(option_btn.get_item_count()):
		if option_btn.get_item_id(i) == target_id:
			option_btn.select(i)
			return
			
	# Fallback si el ID no existe en la lista
	if option_btn.get_item_count() > 0:
		option_btn.select(0)


## Syncs the UI inputs and smartly focuses the canvas on the selected multi-tile bounds
func _on_data_list_item_selected(index: int, _loop: int = 1) -> void:
	_is_syncing = true
	var item: Dictionary = data_list.get_item_metadata(index)
	var target_source_id: int = int(item.get("source_id", -1))
	var target_coords: Vector2i = item.get("atlas_coords", Vector2i.ZERO)
	var target_size: Vector2i = item.get("atlas_size", Vector2i(1, 1))
	var alt_coords: Vector2i = item.get("alt_atlas_coords", Vector2i(-1, -1))
	var alt_size: Vector2i = item.get("alt_atlas_size", Vector2i(1, 1))
	
	appear_percent_spinbox.set_value_no_signal(float(item.get("appear_percent", 100.0)))
	alt_chance_spinbox.set_value_no_signal(float(item.get("alt_chance_percent", 50.0)))
	max_quantity_spinbox.set_value_no_signal(float(item.get("max_quantity", 5)))
	
	footprint_height.set_value_no_signal(float(item.get("footprint_height", 0)))
	
	var margins = item.get("wall_margins")
	if typeof(margins) == TYPE_VECTOR4I or typeof(margins) == TYPE_VECTOR4:
		wall_margin_left.set_value_no_signal(float(margins.x))
		wall_margin_right.set_value_no_signal(float(margins.z))
		wall_margin_top.set_value_no_signal(float(margins.y))
		wall_margin_bottom.set_value_no_signal(float(margins.w))
	else:
		wall_margin_left.set_value_no_signal(0.0)
		wall_margin_right.set_value_no_signal(0.0)
		wall_margin_top.set_value_no_signal(0.0)
		wall_margin_bottom.set_value_no_signal(0.0)
	
	if is_tile_disabled:
		is_tile_disabled.set_pressed_no_signal(not item.get("enabled", true))
		
	var is_detail: bool = item.get("is_detail", false)
	is_detail_tile.set_pressed_no_signal(is_detail)
	
	if is_detail:
		_select_option_by_id(placement_mode_option, 1)
		if is_instance_valid(placement_mode_option):
			placement_mode_option.set_disabled(true)
	else:
		_select_option_by_id(placement_mode_option, int(item.get("placement_mode", 0)))
		if is_instance_valid(placement_mode_option):
			placement_mode_option.set_disabled(false)
			
	_select_option_by_id(environment_position, int(item.get("environment_position", 0)))
		
	for i in range(atlas_list.get_item_count()):
		var atlas_path: String = atlas_list.get_item_metadata(i)
		if int(cache["atlases"][atlas_path]["source_id"]) == target_source_id:
			if atlas_list.get_selected_items().is_empty() or atlas_list.get_selected_items()[0] != i:
				atlas_list.select(i)
				_on_atlas_list_item_selected(i)
				atlas_list.ensure_current_is_visible()
			break
			
	selected_rect = Rect2i(target_coords, target_size)
	alt_selected_rect = Rect2i(alt_coords, alt_size)
	canvas.queue_redraw()
	
	_focus_tile_in_canvas.call_deferred(target_coords, target_size, alt_coords)
	
	_is_syncing = false
	%RightColumn.propagate_call("set_disabled", [false])
	
	if is_instance_valid(data_list):
		data_list.ensure_current_is_visible()
	
	if _loop > 0:
		await get_tree().process_frame
		await get_tree().process_frame
		if is_instance_valid(self):
			_on_data_list_item_selected.call_deferred(index, _loop - 1)


## Toggles the picking mode for alternative tiles safely
func _on_alt_mode_toggled(toggled_on: bool) -> void:
	if toggled_on and data_list.get_selected_items().is_empty():
		alt_mode_button.set_pressed_no_signal(false)
		is_picking_alternative = false
		%CanvasHelp.text = tr("Click to select any tile")
		return
		
	%CanvasHelp.text = tr("Click a tile to use it as an alternative")
	is_picking_alternative = toggled_on
	canvas.queue_redraw()



## Safely disables the alternative picking mode
func _disable_alt_mode() -> void:
	is_picking_alternative = false
	alt_mode_button.set_pressed_no_signal(false)
	%CanvasHelp.text = tr("Click to select any tile")
	canvas.queue_redraw()



## Helper to update the alternative multi-tile bounds of the currently selected decorator
func _apply_alternative_tile(rect: Rect2i) -> void:
	var selected = data_list.get_selected_items()
	if selected.is_empty(): return
	
	var idx = selected[0]
	current_data[idx]["alt_atlas_coords"] = rect.position
	current_data[idx]["alt_atlas_size"] = rect.size
	
	_disable_alt_mode()
	_fill_data_list()
	data_list.select(idx)
	_on_data_list_item_selected.call_deferred(idx)



## Helper to add a new multi-tile decorator entry ensuring no identical duplicates are created
func _add_new_decorator(atlas_data: Dictionary, rect: Rect2i) -> void:
	var exists_idx: int = -1
	
	for i in range(current_data.size()):
		var item = current_data[i]
		if item["source_id"] != atlas_data["source_id"]:
			continue
			
		var item_coords: Vector2i = item["atlas_coords"]
		var item_size: Vector2i = item.get("atlas_size", Vector2i(1, 1))
		var item_rect := Rect2i(item_coords, item_size)
		
		if rect.size == Vector2i(1, 1):
			if item_rect.has_point(rect.position):
				exists_idx = i
				break
		else:
			if item_coords == rect.position and item_size == rect.size:
				exists_idx = i
				break
				
	if exists_idx == -1:
		var new_item: Dictionary = {
			"source_id": atlas_data["source_id"],
			"atlas_coords": rect.position,
			"atlas_size": rect.size,
			"alt_atlas_coords": Vector2i(-1, -1),
			"alt_atlas_size": Vector2i(1, 1),
			"appear_percent": 3,
			"alt_chance_percent": 25.0,
			"placement_mode": 0,
			"environment_position": 0,
			"max_quantity": 5,
			"is_detail": false,
			"enabled": true,
			"footprint_height": 0,
			"wall_margins": Vector4i(0, 0, 0, 0)
		}
		current_data.append(new_item)
		_fill_data_list()
		data_list.select(current_data.size() - 1)
		_on_data_list_item_selected.call_deferred(current_data.size() - 1)
	else:
		data_list.select(exists_idx)
		_on_data_list_item_selected.call_deferred(exists_idx)
		if is_instance_valid(data_list):
			data_list.ensure_current_is_visible()


## Removes the selected item and smartly selects the next available neighbor
func _delete_selected_item() -> void:
	var selected = data_list.get_selected_items()
	if selected.is_empty(): return
	
	%RightColumn.propagate_call("set_disabled", [true])
	
	var idx = selected[0]
	current_data.remove_at(idx)
	_fill_data_list()
	
	if data_list.get_item_count() > 0:
		var next_idx = clamp(idx, 0, data_list.get_item_count() - 1)
		data_list.select(next_idx)
		_on_data_list_item_selected.call_deferred(next_idx)
	else:
		selected_rect = Rect2i(-1, -1, 0, 0)
		alt_selected_rect = Rect2i(-1, -1, 0, 0)
		canvas.queue_redraw()



## Captures key events on the data list to enable deletion via keyboard
func _on_data_list_gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_DELETE or event.keycode == KEY_BACKSPACE:
			_delete_selected_item()
			get_viewport().set_input_as_handled()



## Clears hover states and releases drag/panning when mouse leaves the drawing area
func _on_canvas_mouse_exited() -> void:
	hovered_coord = Vector2i(-1, -1)
	canvas.queue_redraw()
	if has_method("_update_info_label"): call("_update_info_label")



## Forces redraw when scrolling to maintain coordinate text position
func _on_scroll_changed(_value: float) -> void:
	canvas.queue_redraw()



## Closes the window discarding current modifications
func _on_cancel_button_pressed() -> void:
	queue_free()



## Commits changes back to the original array and closes the window
func _on_ok_button_pressed() -> void:
	original_data.clear()
	if not current_data.is_empty():
		original_data.append_array(current_data)
	queue_free()



## Updates the appear_percent value of the currently selected decorator
func _on_appear_percent_changed(value: float) -> void:
	if _is_syncing: return
	var selected = data_list.get_selected_items()
	if not selected.is_empty():
		current_data[selected[0]]["appear_percent"] = value



## Updates the alt_chance_percent value of the currently selected decorator
func _on_alt_chance_changed(value: float) -> void:
	if _is_syncing: return
	var selected = data_list.get_selected_items()
	if not selected.is_empty():
		current_data[selected[0]]["alt_chance_percent"] = value



## Updates the placement_mode value of the currently selected decorator via its exact ID
func _on_placement_mode_changed(index: int) -> void:
	if _is_syncing or not is_instance_valid(placement_mode_option): return
	
	var selected = data_list.get_selected_items()
	if not selected.is_empty():
		current_data[selected[0]]["placement_mode"] = placement_mode_option.get_item_id(index)


func _on_max_quantity_changed(value: float) -> void:
	if _is_syncing: return
	var selected = data_list.get_selected_items()
	if not selected.is_empty():
		current_data[selected[0]]["max_quantity"] = value


func _on_detail_tile_toggled(is_toggled: bool) -> void:
		if _is_syncing: return
		
		var selected = data_list.get_selected_items()
		if not selected.is_empty():
			var item: Dictionary = current_data[selected[0]]
			item["is_detail"] = is_toggled
			
			if is_toggled:
				_select_option_by_id(placement_mode_option, 1)
				if is_instance_valid(placement_mode_option):
					placement_mode_option.set_disabled(true)
			else:
				_select_option_by_id(placement_mode_option, int(item.get("placement_mode", 0)))
				if is_instance_valid(placement_mode_option):
					placement_mode_option.set_disabled(false)


func _on_h_box_container_2_dragged(_offset: int) -> void:
	_on_scroll_container_resized(true)


## Updates the environment_position value of the currently selected decorator via its exact ID
func _on_environment_positions_item_selected(index: int) -> void:
	if _is_syncing or not is_instance_valid(environment_position): return
	
	var selected = data_list.get_selected_items()
	if not selected.is_empty():
		current_data[selected[0]]["environment_position"] = environment_position.get_item_id(index)


## Updates the enabled status of the currently selected decorator inverting the logic
func _on_is_tile_disabled_toggled(is_toggled: bool) -> void:
	if _is_syncing: return
	
	var selected = data_list.get_selected_items()
	if not selected.is_empty():
		var idx: int = selected[0]
		
		var is_enabled: bool = not is_toggled
		current_data[idx]["enabled"] = is_enabled
		
		if is_enabled:
			data_list.set_item_custom_bg_color(idx, Color(0, 0, 0, 0))
		else:
			data_list.set_item_custom_bg_color(idx, Color(0.8, 0.2, 0.2, 0.3))


func _on_footprint_height_value_changed(value: float) -> void:
	if _is_syncing: return
	var selected = data_list.get_selected_items()
	if not selected.is_empty():
		var idx: int = selected[0]
		current_data[idx]["footprint_height"] = value


func _on_margin_left_value_changed(value: float) -> void:
	if _is_syncing: return
	var selected = data_list.get_selected_items()
	if not selected.is_empty():
		var idx: int = selected[0]
		current_data[idx]["wall_margins"].x = value


func _on_margin_right_value_changed(value: float) -> void:
	if _is_syncing: return
	var selected = data_list.get_selected_items()
	if not selected.is_empty():
		var idx: int = selected[0]
		current_data[idx]["wall_margins"].z = value


func _on_margin_top_value_changed(value: float) -> void:
	if _is_syncing: return
	var selected = data_list.get_selected_items()
	if not selected.is_empty():
		var idx: int = selected[0]
		current_data[idx]["wall_margins"].y = value


func _on_margin_bottom_value_changed(value: float) -> void:
	if _is_syncing: return
	var selected = data_list.get_selected_items()
	if not selected.is_empty():
		var idx: int = selected[0]
		current_data[idx]["wall_margins"].w = value
