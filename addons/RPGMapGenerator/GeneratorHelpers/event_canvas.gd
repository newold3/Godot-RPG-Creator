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
	
	if dragged_event_index != -1:
		cursor_layer.draw_rect(Rect2(snap_pos, tile_size), valid_color, true)
		
		var ev: MapPlacedEvent = generator.current_map_events[dragged_event_index]
		var template: RPGEvent = generator.event_placer.get_template_from_uid(ev.template_uid)
		
		if template:
			var color_border: Color = Color(1, 1, 1, 0.90)
			var color_fill: Color = Color(0, 0, 0, 0.65)
			var drag_rect: Rect2 = Rect2(drag_position - (tile_size / 2.0) + Vector2(1, 1), tile_size - Vector2(2, 2))
			
			cursor_layer.draw_rect(drag_rect, color_border, false, 2)
			cursor_layer.draw_rect(drag_rect, color_fill, true)
			_draw_event_graphic(template, drag_rect, color_border.a, cursor_layer)
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
	
	if event is InputEventMouseMotion:
		hover_grid_pos = grid_pos
		drag_position = mouse_pos
		
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
		else:
			if is_instance_valid(cursor_layer):
				cursor_layer.queue_redraw()
			return true
			
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.is_pressed():
				for i in range(generator.current_map_events.size()):
					var ev: MapPlacedEvent = generator.current_map_events[i]
					if ev and ev.tile == grid_pos:
						dragged_event_index = i
						is_valid_hover = true
						queue_redraw()
						if is_instance_valid(cursor_layer):
							cursor_layer.queue_redraw()
						return true
			else:
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
					
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.is_pressed():
			for i in range(generator.current_map_events.size()):
				var ev: MapPlacedEvent = generator.current_map_events[i]
				if ev and ev.tile == grid_pos:
					generator.request_event_deletion(i)
					return true
					
	return false



## Retrieves the library wrapper to check for placement rules during dragging
func _get_generator_event_rules(uid: int) -> MapGeneratorEvent:
	if generator.events_library:
		for ev in generator.events_library.events:
			if ev.event and ev.event._uniq_id == uid:
				return ev
	return null
#endregion
