@tool
class_name MapEventCanvasGenerator
extends Control


#region VARIABLES
var generator: Node
var tile_size: Vector2 = Vector2(32, 32)
var dragged_event_index: int = -1
var drag_position: Vector2 = Vector2.ZERO
var hover_grid_pos: Vector2i = Vector2i(-1, -1)
var is_valid_hover: bool = false
var is_grid_visible: bool = false

var event_preview_textures: Dictionary = {}
var default_fallback_icon: Texture2D = preload("uid://b01uavgk22xq")

var grid_layer: Control
var cursor_layer: Control

var editor_undo_redo: Object = null

enum HoverMode { NONE, EVENT, GROUND, DECORATOR }
var current_hover_mode: HoverMode = HoverMode.NONE

var dragged_dec_dict: Dictionary = {}
var dragged_dec_root: Vector2i = Vector2i(-1, -1)
var dragged_dec_layer: TileMapLayer = null

var _last_carved_pos: Vector2i = Vector2i(-1, -1)
#endregion



#region LIFECYCLE & SETUP
## Creates temporary sub-canvases for optimized separated drawing layers
func _enter_tree() -> void:
	if not Engine.is_editor_hint(): return
	_ensure_layers()


## Verifies and regenerates temporary canvases if they were unexpectedly destroyed by the editor
func _ensure_layers() -> void:
	if not is_inside_tree(): return
	
	if not is_instance_valid(grid_layer):
		grid_layer = Control.new()
		grid_layer.name = "GridLayer"
		grid_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		grid_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		grid_layer.draw.connect(_on_grid_draw)
		add_child(grid_layer)
		
	if not is_instance_valid(cursor_layer):
		cursor_layer = Control.new()
		cursor_layer.name = "CursorLayer"
		cursor_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cursor_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		cursor_layer.draw.connect(_on_cursor_draw)
		add_child(cursor_layer)



## Cleans up temporary canvases
func _exit_tree() -> void:
	if is_instance_valid(grid_layer):
		grid_layer.queue_free()
	if is_instance_valid(cursor_layer):
		cursor_layer.queue_free()



## Connects the canvas to the main generator and adjusts its bounding box
func setup(_generator: Node, _tile_size: Vector2 = Vector2(32, 32)) -> void:
	generator = _generator
	tile_size = _tile_size
	
	if generator:
		size = Vector2(generator.map_width * tile_size.x, generator.map_height * tile_size.y)
		
	_ensure_layers()
	queue_redraw()



## Toggles grid visibility when selected from the plugin
func set_grid_visible(state: bool) -> void:
	is_grid_visible = state
	_ensure_layers()
	
	if is_instance_valid(grid_layer):
		grid_layer.queue_redraw()
	if is_instance_valid(cursor_layer):
		cursor_layer.queue_redraw()
#endregion



#region DRAWING LAYERS
## LAYER 1: Base Canvas. Draws ONLY the placed events (frozen in place)
func _draw() -> void:
	if not generator or not "current_map_events" in generator: return
	
	custom_minimum_size = Vector2(
		generator.map_width * tile_size.x,
		generator.map_height * tile_size.y
	)
	size = custom_minimum_size
		
	var events: Array = generator.current_map_events
	var color_border: Color = Color(1, 1, 1, 0.90)
	var color_fill: Color = Color(0, 0, 0, 0.65)
	
	for i in range(events.size()):
		if i == dragged_event_index: continue
			
		var ev: MapPlacedEvent = events[i]
		if not ev: continue
			
		var template: RPGEvent = generator.event_placer.get_template_from_uid(ev.template_uid)
		if not template: continue
			
		var real_pos: Vector2 = Vector2(ev.tile.x * tile_size.x, ev.tile.y * tile_size.y)
		var rect: Rect2 = Rect2(real_pos + Vector2(1, 1), tile_size - Vector2(2, 2))
		
		draw_rect(rect, color_border, false, 2)
		draw_rect(rect, color_fill, true)
		_draw_event_graphic(template, rect, color_border.a, self)



## LAYER 2: Grid Sub-canvas. Draws the grid lines only when selected
func _on_grid_draw() -> void:
	if not is_grid_visible or not generator: return
	
	var grid_color: Color = Color(1.0, 0.467, 0.18, 0.298)
	
	for x in range(generator.map_width + 1):
		grid_layer.draw_line(Vector2(x * tile_size.x, 0), Vector2(x * tile_size.x, generator.map_height * tile_size.y), grid_color)
		
	for y in range(generator.map_height + 1):
		grid_layer.draw_line(Vector2(0, y * tile_size.y), Vector2(generator.map_width * tile_size.x, y * tile_size.y), grid_color)



## LAYER 3: Cursor Sub-canvas. Draws hovers and the dragged event (updates constantly)
func _on_cursor_draw() -> void:
	if not is_grid_visible or hover_grid_pos.x < 0 or hover_grid_pos.y < 0: return
	
	var snap_pos: Vector2 = Vector2(hover_grid_pos.x * tile_size.x, hover_grid_pos.y * tile_size.y)
	var valid_color: Color = Color(0.2, 1.0, 0.2, 0.5) if is_valid_hover else Color(1.0, 0.2, 0.2, 0.5)
	var color_border: Color = Color(1, 1, 1, 0.90)
	var color_fill: Color = Color(0, 0, 0, 0.65)
	
	if Input.is_key_pressed(KEY_CTRL):
		cursor_layer.draw_rect(Rect2(snap_pos, tile_size), Color(0.2, 0.8, 1.0, 0.5), true)
		cursor_layer.draw_rect(Rect2(snap_pos, tile_size), Color(0.2, 0.8, 1.0, 0.9), false, 2)
		return
	elif Input.is_key_pressed(KEY_ALT):
		cursor_layer.draw_rect(Rect2(snap_pos, tile_size), Color(0.8, 0.2, 1.0, 0.5), true)
		cursor_layer.draw_rect(Rect2(snap_pos, tile_size), Color(0.8, 0.2, 1.0, 0.9), false, 2)
		return
		
	if dragged_event_index != -1:
		cursor_layer.draw_rect(Rect2(snap_pos, tile_size), valid_color, true)
		
		var ev: MapPlacedEvent = generator.current_map_events[dragged_event_index]
		var template: RPGEvent = generator.event_placer.get_template_from_uid(ev.template_uid)
		
		if template:
			var drag_rect: Rect2 = Rect2(drag_position - (tile_size / 2.0) + Vector2(1, 1), tile_size - Vector2(2, 2))
			cursor_layer.draw_rect(drag_rect, color_border, false, 2)
			cursor_layer.draw_rect(drag_rect, color_fill, true)
			_draw_event_graphic(template, drag_rect, color_border.a, cursor_layer)
			
	elif not dragged_dec_dict.is_empty():
		var dec_size: Vector2i = dragged_dec_dict.get("size", Vector2i(1, 1))
		var total_size: Vector2 = Vector2(dec_size.x * tile_size.x, dec_size.y * tile_size.y)
		
		if dragged_dec_root != Vector2i(-1, -1):
			var orig_pos: Vector2 = Vector2(dragged_dec_root.x * tile_size.x, dragged_dec_root.y * tile_size.y)
			var orig_rect: Rect2 = Rect2(orig_pos, total_size)
			cursor_layer.draw_rect(orig_rect, Color(0, 0, 0, 0.6), true)
			cursor_layer.draw_rect(orig_rect, Color(1, 0.6, 0.2, 0.8), false, 2)
			
		var snap_rect: Rect2 = Rect2(snap_pos, total_size)
		cursor_layer.draw_rect(snap_rect, valid_color, true)
		
		var visual_rect: Rect2 = Rect2(drag_position - (total_size / 2.0), total_size)
		cursor_layer.draw_rect(visual_rect, color_border, false, 2)
		cursor_layer.draw_rect(visual_rect, color_fill, true)
		
		if is_instance_valid(dragged_dec_layer) and dragged_dec_layer.tile_set:
			var ts: TileSet = dragged_dec_layer.tile_set
			var s_id: int = dragged_dec_dict["data"].get("source_id", -1)
			var base_coords: Vector2i = dragged_dec_dict["data"].get("atlas_coords", Vector2i(0,0))
			
			if dec_size == dragged_dec_dict["data"].get("alt_atlas_size", Vector2i(1,1)):
				base_coords = dragged_dec_dict["data"].get("alt_atlas_coords", base_coords)
				
			if ts.has_source(s_id):
				var source: TileSetSource = ts.get_source(s_id)
				if source is TileSetAtlasSource:
					var modulate_color: Color = Color(1, 1, 1, 0.9)
					for dy in range(dec_size.y):
						for dx in range(dec_size.x):
							var target_coord: Vector2i = base_coords + Vector2i(dx, dy)
							if source.has_tile(target_coord):
								var region: Rect2 = source.get_tile_texture_region(target_coord)
								var dest_rect: Rect2 = Rect2(visual_rect.position + Vector2(dx * tile_size.x, dy * tile_size.y), tile_size)
								cursor_layer.draw_texture_rect_region(source.texture, dest_rect, region, modulate_color)
								
	else:
		if current_hover_mode == HoverMode.DECORATOR:
			var dec_info: Dictionary = _find_decorator_under_cursor(hover_grid_pos)
			if not dec_info.is_empty():
				var dec_size: Vector2i = dec_info.get("size", Vector2i(1, 1))
				var root: Vector2i = dec_info.get("root", hover_grid_pos)
				var root_pos: Vector2 = Vector2(root.x * tile_size.x, root.y * tile_size.y)
				var total_size: Vector2 = Vector2(dec_size.x * tile_size.x, dec_size.y * tile_size.y)
				cursor_layer.draw_rect(Rect2(root_pos, total_size), Color(1, 0.8, 0.2, 0.4), true)
				cursor_layer.draw_rect(Rect2(root_pos, total_size), Color(1, 0.8, 0.2, 0.9), false, 2)
		else:
			cursor_layer.draw_rect(Rect2(snap_pos, tile_size), Color(1, 1, 1, 0.2), true)
			cursor_layer.draw_rect(Rect2(snap_pos, tile_size), Color(1, 1, 1, 0.8), false, 1)
			
		if generator and "current_map_events" in generator:
			var current_id: int = 1
			for ev in generator.current_map_events:
				if ev is MapPlacedEvent:
					if ev.tile == hover_grid_pos:
						var template: RPGEvent = generator.event_placer.get_template_from_uid(ev.template_uid)
						if template:
							_draw_hover_tooltip(current_id, template)
						break
					current_id += 1
					
		_draw_interaction_tooltip()


## Helper function to draw interaction hints near the cursor below the main tooltip
func _draw_interaction_tooltip() -> void:
	if current_hover_mode == HoverMode.NONE or dragged_event_index != -1 or not dragged_dec_dict.is_empty(): return
	
	var hint_text: String = ""
	if current_hover_mode == HoverMode.EVENT:
		hint_text = "Left click to move event, Right Click to delete event"
	elif current_hover_mode == HoverMode.GROUND:
		hint_text = "Left Click to place player, Right Click to place goal"
	elif current_hover_mode == HoverMode.DECORATOR:
		hint_text = "Left click to move decoration"
		
	if hint_text.is_empty(): return
	
	var font: Font = ThemeDB.fallback_font
	var font_size: int = 12
	var text_size: Vector2 = font.get_string_size(hint_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	
	var padding: Vector2 = Vector2(8, 6)
	var tooltip_pos: Vector2 = cursor_layer.get_local_mouse_position() + Vector2(15, 45)
	
	var bg_rect: Rect2 = Rect2(tooltip_pos, text_size + padding * 2)
	
	cursor_layer.draw_rect(bg_rect, Color(0.1, 0.1, 0.1, 0.9), true)
	cursor_layer.draw_rect(bg_rect, Color(0.6, 0.6, 0.6, 0.5), false, 1.0)
	
	var text_pos: Vector2 = tooltip_pos + padding + Vector2(0, font.get_ascent(font_size))
	cursor_layer.draw_string(font, text_pos, hint_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)


## Helper function to draw a tooltip with the event's dynamic ID and Name floating near the cursor
func _draw_hover_tooltip(event_id: int, template: RPGEvent) -> void:
	var tooltip_text: String = str(event_id) + ": " + str(template.name)
	
	var font: Font = ThemeDB.fallback_font
	var font_size: int = 14
	var text_size: Vector2 = font.get_string_size(tooltip_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	
	var padding: Vector2 = Vector2(8, 6)
	var tooltip_pos: Vector2 = cursor_layer.get_local_mouse_position() + Vector2(15, 15)
	
	var bg_rect: Rect2 = Rect2(tooltip_pos, text_size + padding * 2)
	
	cursor_layer.draw_rect(bg_rect, Color(0.1, 0.1, 0.1, 0.9), true)
	cursor_layer.draw_rect(bg_rect, Color(0.6, 0.6, 0.6, 0.5), false, 1.0)
	
	var text_pos: Vector2 = tooltip_pos + padding + Vector2(0, font.get_ascent(font_size))
	cursor_layer.draw_string(font, text_pos, tooltip_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)



## Helper function to draw graphics on any target canvas layer
func _draw_event_graphic(event: Resource, base_rect: Rect2, alpha: float, target_canvas: CanvasItem) -> void:
	if not event.has_method("get_active_page") or event.pages.size() == 0: return
		
	var page = event.get_active_page()
	if not page: return
		
	var tex_to_draw: Texture2D = null
	var cache_key: String = ""
	
	match page.character_type:
		0:
			if ResourceLoader.exists(page.character_path):
				cache_key = "lpc_" + page.character_path
				if cache_key in event_preview_textures:
					tex_to_draw = event_preview_textures[cache_key]
				else:
					var res = ResourceLoader.load(page.character_path)
					if res and ResourceLoader.exists(res.get("event_preview")):
						tex_to_draw = ResourceLoader.load(res.event_preview)
						event_preview_textures[cache_key] = tex_to_draw
		1:
			if ResourceLoader.exists(page.character_path):
				cache_key = "img_" + page.character_path
				if cache_key in event_preview_textures:
					tex_to_draw = event_preview_textures[cache_key]
				else:
					tex_to_draw = ResourceLoader.load(page.character_path)
					event_preview_textures[cache_key] = tex_to_draw
		2:
			var preview_path = page.character_path.get_basename() + "_preview.png"
			cache_key = "scn_" + preview_path
			if cache_key in event_preview_textures:
				tex_to_draw = event_preview_textures[cache_key]
			else:
				if ResourceLoader.exists(preview_path): tex_to_draw = ResourceLoader.load(preview_path)
				else: tex_to_draw = default_fallback_icon
				event_preview_textures[cache_key] = tex_to_draw

	if tex_to_draw:
		var draw_rect: Rect2 = base_rect
		draw_rect.position += Vector2(1, 1)
		draw_rect.size -= Vector2(2, 2)
		var tex_color: Color = page.modulate
		tex_color.a = alpha
		
		if page.character_type != 1:
			target_canvas.draw_texture_rect(tex_to_draw, draw_rect, false, tex_color)
		else:
			if page.get("character_region") and page.character_region.has_area():
				target_canvas.draw_texture_rect_region(tex_to_draw, draw_rect, page.character_region, tex_color)
			else:
				target_canvas.draw_texture_rect(tex_to_draw, draw_rect, false, tex_color)
#endregion



#region INTERACTION
## Intercepts inputs forwarded by the editor plugin. Returns true to consume the event.
func process_editor_input(event: InputEvent) -> bool:
	if not is_grid_visible or not generator or not "current_map_events" in generator: return false
		
	var mouse_pos: Vector2 = get_local_mouse_position()
	var grid_pos: Vector2i = Vector2i(floor(mouse_pos.x / tile_size.x), floor(mouse_pos.y / tile_size.y))
	
	var is_valid_ground: bool = false
	if generator.layer_ground_base and generator.layer_ground_base.get_cell_source_id(grid_pos) != -1:
		if not generator.layer_walls or generator.layer_walls.get_cell_source_id(grid_pos) == -1:
			is_valid_ground = true
			
	if event is InputEventMouseMotion:
		hover_grid_pos = grid_pos
		drag_position = mouse_pos
		current_hover_mode = HoverMode.NONE
		
		if event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			if Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_ALT):
				_handle_carving_action(grid_pos, Input.is_key_pressed(KEY_CTRL))
				return true
				
		if dragged_event_index != -1:
			var grid_data: Dictionary = generator.call("_read_initial_grid")
			var ev: MapPlacedEvent = generator.current_map_events[dragged_event_index]
			var gen_ev = _get_generator_event_rules(ev.template_uid)
			
			if gen_ev:
				is_valid_hover = generator.event_placer.is_tile_valid_for_event_placement(hover_grid_pos, grid_data["grid"], gen_ev)
			else:
				is_valid_hover = false
				
			if is_instance_valid(cursor_layer):
				cursor_layer.queue_redraw()
			return true
			
		elif not dragged_dec_dict.is_empty():
			var grid_data: Dictionary = generator.call("_read_initial_grid")
			
			if generator.environment_placer.has_method("is_valid_for_decorator"):
				is_valid_hover = generator.environment_placer.is_valid_for_decorator(hover_grid_pos, dragged_dec_dict["data"], grid_data["grid"], generator.map_width, generator.map_height, dragged_dec_root)
			else:
				is_valid_hover = false
				
			if is_instance_valid(cursor_layer):
				cursor_layer.queue_redraw()
			return true
			
		else:
			var hovering_event: bool = false
			for ev in generator.current_map_events:
				if ev is MapPlacedEvent and ev.tile == grid_pos:
					hovering_event = true
					break
					
			if hovering_event:
				current_hover_mode = HoverMode.EVENT
			elif not _find_decorator_under_cursor(grid_pos).is_empty():
				current_hover_mode = HoverMode.DECORATOR
			elif is_valid_ground:
				current_hover_mode = HoverMode.GROUND
				
			if is_instance_valid(cursor_layer):
				cursor_layer.queue_redraw()
			return true
			
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.is_pressed():
				if Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_ALT):
					_handle_carving_action(grid_pos, Input.is_key_pressed(KEY_CTRL))
					return true
					
				for i in range(generator.current_map_events.size()):
					var ev: MapPlacedEvent = generator.current_map_events[i]
					if ev and ev.tile == grid_pos:
						dragged_event_index = i
						is_valid_hover = true
						queue_redraw()
						if is_instance_valid(cursor_layer):
							cursor_layer.queue_redraw()
						return true
						
				var dec_info: Dictionary = _find_decorator_under_cursor(grid_pos)
				if not dec_info.is_empty():
					dragged_dec_dict = dec_info
					dragged_dec_root = dec_info["root"]
					dragged_dec_layer = dec_info["layer"]
					is_valid_hover = true
					queue_redraw()
					if is_instance_valid(cursor_layer):
						cursor_layer.queue_redraw()
					return true
						
				if is_valid_ground:
					if generator.player:
						_move_debug_marker(generator.player, grid_pos, "Move Player Start")
						return true
						
			else:
				_last_carved_pos = Vector2i(-1, -1)
				
				if dragged_event_index != -1:
					if is_valid_hover:
						var ev: MapPlacedEvent = generator.current_map_events[dragged_event_index]
						if ev and ev.tile != hover_grid_pos:
							var ur = editor_undo_redo
							if not ur and generator and "editor_undo_redo" in generator:
								ur = generator.editor_undo_redo
								
							if ur:
								ur.create_action("Move Map Event")
								ur.add_do_property(ev, "tile", hover_grid_pos)
								ur.add_undo_property(ev, "tile", ev.tile)
								ur.add_do_method(self, "queue_redraw")
								ur.add_undo_method(self, "queue_redraw")
								if is_instance_valid(cursor_layer):
									ur.add_do_method(cursor_layer, "queue_redraw")
									ur.add_undo_method(cursor_layer, "queue_redraw")
								ur.commit_action()
							else:
								ev.tile = hover_grid_pos
								
					dragged_event_index = -1
					queue_redraw()
					if is_instance_valid(cursor_layer):
						cursor_layer.queue_redraw()
					return true
					
				elif not dragged_dec_dict.is_empty():
					if is_valid_hover and hover_grid_pos != dragged_dec_root:
						_move_decorator_action(dragged_dec_dict, dragged_dec_root, hover_grid_pos, dragged_dec_layer)
						
					dragged_dec_dict.clear()
					dragged_dec_root = Vector2i(-1, -1)
					dragged_dec_layer = null
					queue_redraw()
					if is_instance_valid(cursor_layer):
						cursor_layer.queue_redraw()
					return true
					
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.is_pressed():
			for i in range(generator.current_map_events.size()):
				var ev: MapPlacedEvent = generator.current_map_events[i]
				if ev and ev.tile == grid_pos:
					generator.request_event_deletion(i)
					return true
					
			if is_valid_ground:
				if generator.goal:
					_move_debug_marker(generator.goal, grid_pos, "Move Goal Marker")
					return true
					
	return false


func _handle_carving_action(grid_pos: Vector2i, is_door: bool) -> void:
	if grid_pos == _last_carved_pos: 
		return
		
	if not generator.layer_walls: 
		return
		
	var s_id: int = generator.layer_walls.get_cell_source_id(grid_pos)
	if s_id == -1: 
		return
		
	_last_carved_pos = grid_pos
	var ur: Object = editor_undo_redo
	
	if not ur and generator and "editor_undo_redo" in generator:
		ur = generator.editor_undo_redo
		
	if is_door:
		var door_data: Dictionary = generator.carve_door_tile
		var has_door: bool = door_data.get("atlas_id", -1) != -1
		
		if ur:
			ur.create_action("Carve Door/Hole")
			ur.add_do_method(generator.layer_walls, "set_cell", grid_pos, door_data.get("atlas_id", -1), door_data.get("tile_id", Vector2i(-1, -1)), 0 if has_door else -1)
			ur.add_do_method(generator, "update_collisions_from_tilemap")
			
			ur.add_undo_method(generator, "update_collisions_from_tilemap")
			ur.add_undo_method(generator.layer_walls, "set_cell", grid_pos, s_id, generator.layer_walls.get_cell_atlas_coords(grid_pos), 0)
			ur.commit_action()
		else:
			generator.layer_walls.set_cell(grid_pos, door_data.get("atlas_id", -1), door_data.get("tile_id", Vector2i(-1, -1)), 0 if has_door else -1)
			generator.update_collisions_from_tilemap()
			
	else:
		var window_data: Dictionary = generator.carve_window_tile
		if window_data.get("atlas_id", -1) == -1: 
			return
			
		if ur:
			ur.create_action("Carve Window")
			ur.add_do_method(generator.layer_walls, "set_cell", grid_pos, window_data.get("atlas_id", -1), window_data.get("tile_id", Vector2i(-1, -1)), 0)
			ur.add_do_method(generator, "update_collisions_from_tilemap")
			
			ur.add_undo_method(generator, "update_collisions_from_tilemap")
			ur.add_undo_method(generator.layer_walls, "set_cell", grid_pos, s_id, generator.layer_walls.get_cell_atlas_coords(grid_pos), 0)
			ur.commit_action()
		else:
			generator.layer_walls.set_cell(grid_pos, window_data.get("atlas_id", -1), window_data.get("tile_id", Vector2i(-1, -1)), 0)
			generator.update_collisions_from_tilemap()


func _find_decorator_under_cursor(grid_pos: Vector2i) -> Dictionary:
	var layers: Array = [generator.layer_environment, generator.layer_ground_detail]
	
	for l in layers:
		if not is_instance_valid(l): 
			continue
			
		var s_id: int = l.get_cell_source_id(grid_pos)
		if s_id == -1: 
			continue
			
		var a_crd: Vector2i = l.get_cell_atlas_coords(grid_pos)
		
		for dec in generator.decorator_data:
			var ref_id: int = dec.get("source_id", -1)
			if s_id != ref_id: 
				continue
				
			var base_coords: Vector2i = dec.get("atlas_coords", Vector2i(-1,-1))
			var alt_coords: Vector2i = dec.get("alt_atlas_coords", Vector2i(-1,-1))
			var size: Vector2i = dec.get("atlas_size", Vector2i(1,1))
			var alt_size: Vector2i = dec.get("alt_atlas_size", Vector2i(1,1))
			
			var root_pos: Vector2i = Vector2i(-1, -1)
			var used_size: Vector2i = size
			var used_base: Vector2i = base_coords
			
			var diff: Vector2i = a_crd - base_coords
			if diff.x >= 0 and diff.x < size.x and diff.y >= 0 and diff.y < size.y:
				root_pos = grid_pos - diff
				
			if root_pos == Vector2i(-1,-1) and alt_coords != Vector2i(-1,-1):
				diff = a_crd - alt_coords
				if diff.x >= 0 and diff.x < alt_size.x and diff.y >= 0 and diff.y < alt_size.y:
					root_pos = grid_pos - diff
					used_size = alt_size
					used_base = alt_coords
					
			if root_pos != Vector2i(-1,-1):
				var valid_match: bool = true
				for dy in range(used_size.y):
					for dx in range(used_size.x):
						var check_pos: Vector2i = root_pos + Vector2i(dx, dy)
						var expect_crd: Vector2i = used_base + Vector2i(dx, dy)
						if l.get_cell_source_id(check_pos) != ref_id or l.get_cell_atlas_coords(check_pos) != expect_crd:
							valid_match = false
							break
					if not valid_match:
						break
						
				if valid_match:
					return {"data": dec, "root": root_pos, "layer": l, "size": used_size}
					
	return {}


func _move_decorator_action(dec_info: Dictionary, old_root: Vector2i, new_root: Vector2i, target_layer: TileMapLayer) -> void:
	var ur: Object = editor_undo_redo
	if not ur and generator and "editor_undo_redo" in generator:
		ur = generator.editor_undo_redo
		
	var s_id: int = dec_info["data"].get("source_id", -1)
	var size: Vector2i = dec_info["size"]
	var base_coords: Vector2i = dec_info["data"].get("atlas_coords", Vector2i(0,0))
	
	if size == dec_info["data"].get("alt_atlas_size", Vector2i(1,1)):
		base_coords = dec_info["data"].get("alt_atlas_coords", base_coords)
		
	if ur:
		ur.create_action("Move Decoration")
		
		for dy in range(size.y):
			for dx in range(size.x):
				var old_cell: Vector2i = old_root + Vector2i(dx, dy)
				var new_cell: Vector2i = new_root + Vector2i(dx, dy)
				
				ur.add_do_method(target_layer, "set_cell", old_cell, -1, Vector2i(-1, -1), -1)
				ur.add_undo_method(target_layer, "set_cell", new_cell, -1, Vector2i(-1, -1), -1)
				
		for dy in range(size.y):
			for dx in range(size.x):
				var new_cell: Vector2i = new_root + Vector2i(dx, dy)
				var old_cell: Vector2i = old_root + Vector2i(dx, dy)
				var target_coord: Vector2i = base_coords + Vector2i(dx, dy)
				
				ur.add_do_method(target_layer, "set_cell", new_cell, s_id, target_coord, 0)
				ur.add_undo_method(target_layer, "set_cell", old_cell, s_id, target_coord, 0)
				
		ur.commit_action()
	else:
		for dy in range(size.y):
			for dx in range(size.x):
				var old_cell: Vector2i = old_root + Vector2i(dx, dy)
				
				target_layer.set_cell(old_cell, -1, Vector2i(-1, -1), -1)
				
		for dy in range(size.y):
			for dx in range(size.x):
				var new_cell: Vector2i = new_root + Vector2i(dx, dy)
				var target_coord: Vector2i = base_coords + Vector2i(dx, dy)
				
				target_layer.set_cell(new_cell, s_id, target_coord, 0)


## Retrieves the library wrapper to check for placement rules during dragging
func _get_generator_event_rules(uid: int) -> MapGeneratorEvent:
	if generator.events_library:
		for ev in generator.events_library.events:
			if ev.event and ev.event._uniq_id == uid:
				return ev
	return null


func _move_debug_marker(marker: Node2D, grid_pos: Vector2i, action_name: String) -> void:
	var new_pos: Vector2 = generator.layer_ground_base.to_global(generator.layer_ground_base.map_to_local(grid_pos))
	var ur = editor_undo_redo
	
	if not ur and generator and "editor_undo_redo" in generator:
		ur = generator.editor_undo_redo
		
	if ur:
		ur.create_action(action_name)
		ur.add_do_property(marker, "global_position", new_pos)
		ur.add_undo_property(marker, "global_position", marker.global_position)
		ur.commit_action()
	else:
		marker.global_position = new_pos
#endregion
