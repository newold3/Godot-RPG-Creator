@tool
class_name IneditorMapEditorCanvas
extends RefCounted


var map: RPGMap

var event_canvas: Node2D
var extraction_event_canvas: Node2D
var keot_canvas: Node2D
var enemy_spawn_canvas: Node2D
var event_region_canvas: Node2D
var cursor_canvas: Node2D
var passability_canvas: Node2D
var grid_canvas: Node2D

var event_preview_textures: Dictionary = {}
var extraction_event_preview_textures: Dictionary = {}
var hexagon_cache: Dictionary = {}


func _init(p_map: RPGMap) -> void:
	map = p_map


func build_canvases(refresh_events: bool = false) -> void:
	# Add events canvas
	event_canvas = Node2D.new()
	event_canvas.z_index = 100
	event_canvas.draw.connect(_on_event_canvas_draw)
	map.draw.connect(event_canvas.queue_redraw)
	map.add_child(event_canvas)
	
	# Add extraction event canvas
	extraction_event_canvas = Node2D.new()
	extraction_event_canvas.z_index = 100
	extraction_event_canvas.draw.connect(_on_extraction_event_canvas_draw)
	map.draw.connect(extraction_event_canvas.queue_redraw)
	map.add_child(extraction_event_canvas)
	
	# Add keots canvas
	keot_canvas = Node2D.new()
	keot_canvas.z_index = 100
	keot_canvas.modulate.a = 0.4
	keot_canvas.draw.connect(_on_keot_canvas_draw)
	map.draw.connect(keot_canvas.queue_redraw)
	map.add_child(keot_canvas)
	
	# Add grid canvas
	grid_canvas = Node2D.new()
	grid_canvas.z_index = 50
	grid_canvas.draw.connect(_on_grid_canvas_draw)
	map.draw.connect(grid_canvas.queue_redraw)
	map.add_child(grid_canvas)

	if refresh_events:
		map.queue_redraw()
	else:
		# Add enemy spawn canvas
		enemy_spawn_canvas = Node2D.new()
		enemy_spawn_canvas.z_index = 100
		enemy_spawn_canvas.draw.connect(_on_enemy_spawn_canvas_draw)
		map.draw.connect(enemy_spawn_canvas.queue_redraw)
		map.add_child(enemy_spawn_canvas)
		# Add event region canvas
		event_region_canvas = Node2D.new()
		event_region_canvas.z_index = 100
		event_region_canvas.draw.connect(_on_event_region_canvas_draw)
		map.draw.connect(event_region_canvas.queue_redraw)
		map.add_child(event_region_canvas)
	
	# Add Cursor Canvas
	cursor_canvas = Node2D.new()
	cursor_canvas.z_index = 200
	cursor_canvas.draw.connect(_draw_cursor_highlight)
	map.add_child(cursor_canvas)
	
	# Add passability canvas
	passability_canvas = Node2D.new()
	passability_canvas.z_index = 150
	passability_canvas.draw.connect(_on_passability_canvas_draw)
	map.draw.connect(passability_canvas.queue_redraw)
	map.add_child(passability_canvas)


func _on_event_canvas_draw() -> void:
	event_preview_textures.clear()
	var ids = [
		"player_start_position",
		"land_transport_start_position",
		"sea_transport_start_position",
		"air_transport_start_position",
	]
	var color = Color(1, 1, 1, 0.90) if map.editing_events else Color(1, 1, 1, 0.30)
	for id in ids:
		var data: RPGMapPosition = RPGSYSTEM.database.system.get(id)
		if data:
			if data.map_id == map.internal_id:
				var pos = data.position
				var icon = map.editor_icons.get(id)
				var real_pos = Vector2i(map.map_to_local(Vector2i(pos.x, pos.y)))
				event_canvas.draw_texture(icon, real_pos, color)
				if map.current_start_position == data:
					var rect = Rect2i(real_pos + Vector2i.ONE, map.tile_size - Vector2i(2, 2))
					event_canvas.draw_rect(rect, Color.DARK_ORANGE, false, 2)

	if (Engine.is_editor_hint() and map.events) or map.preview_map_only_enabled:
		var obj = map.events.get_events()
		if not obj:
			return
		
		var used_rect = map.get_used_rect()
		var color1: Color = Color.WHITE
		var color2: Color = Color.BLACK
		var color3: Color = Color.DARK_ORANGE
		var color4: Color = Color(0.839, 0.208, 0.063, 0.098)
		
		if map.editing_events:
			color1.a = 0.90
			color2.a = 0.65
		else:
			color1.a = 0.30
			color2.a = 0.20
		
		for event: RPGEvent in obj:
			if not event:
				continue

			var real_pos = Vector2i(map.map_to_local(Vector2i(event.x, event.y)))
			var rect = Rect2i(real_pos + Vector2i.ONE, map.tile_size - Vector2i(2, 2))
			
			if used_rect.intersects(rect):
				event_canvas.draw_rect(rect, color1, false, 2)
				event_canvas.draw_rect(rect, color2, true)
			
				if event == map.current_event and map.editing_events:
					event_canvas.draw_rect(rect, color3, false, 2)
			else:
				event_canvas.draw_rect(rect, color1, false, 2)
				event_canvas.draw_rect(rect, color4, true)
				
			if event.pages.size() > 0:
				var page: RPGEventPage = event.get_active_page()
				var tex_to_draw: Texture2D = null
				var cache_key: String = ""
				
				match page.character_type:
					0: # LPC Character
						if ResourceLoader.exists(page.character_path):
							cache_key = "lpc_" + page.character_path
							if cache_key in event_preview_textures:
								tex_to_draw = event_preview_textures[cache_key]
							else:
								var res: RPGLPCCharacter = ResourceLoader.load(page.character_path)
								if res and ResourceLoader.exists(res.event_preview):
									tex_to_draw = ResourceLoader.load(res.event_preview)
									event_preview_textures[cache_key] = tex_to_draw
					1: # Custom Image
						if ResourceLoader.exists(page.character_path):
							cache_key = "img_" + page.character_path
							if cache_key in event_preview_textures:
								tex_to_draw = event_preview_textures[cache_key]
							else:
								tex_to_draw = ResourceLoader.load(page.character_path)
								event_preview_textures[cache_key] = tex_to_draw
					2: # Custom Scene
						var preview_path = page.character_path.get_basename() + "_preview.png"
						cache_key = "scn_" + preview_path
						if cache_key in event_preview_textures:
							tex_to_draw = event_preview_textures[cache_key]
						else:
							if ResourceLoader.exists(preview_path):
								tex_to_draw = ResourceLoader.load(preview_path)
							else:
								tex_to_draw = preload("uid://ccgbok1pihel5")
							event_preview_textures[cache_key] = tex_to_draw

				if tex_to_draw:
					var draw_rect = rect
					draw_rect.position += Vector2i.ONE
					draw_rect.size -= Vector2i(2, 2)
					var tex_color = page.modulate
					tex_color.a = color1.a
					event_canvas.draw_texture_rect(tex_to_draw, draw_rect, false, tex_color)


func _on_extraction_event_canvas_draw() -> void:
	extraction_event_preview_textures.clear()
	var used_rect = map.get_used_rect()
	var color1: Color = Color.WHITE
	var color2: Color = Color.BLACK
	var color3: Color = Color.DARK_ORANGE
	var color4: Color = Color(0.839, 0.208, 0.063, 0.098)
	var color5: Color = Color.WHITE
	var fill_polygon_color: Color = Color.BLACK
	var inner_border_polygon: Color = Color.GRAY
	var outer_border_polygon: Color = Color.WHITE
	
	if map.editing_extraction_events:
		color1.a = 0.90
		color2.a = 0.65
		color5.a = 1.0
		fill_polygon_color.a = 0.65
		inner_border_polygon.a = 0.90
		outer_border_polygon.a = 0.90
	else:
		color1.a = 0.30
		color2.a = 0.20
		color5.a = 0.20
		fill_polygon_color.a = 0.20
		inner_border_polygon.a = 0.30
		outer_border_polygon.a = 0.30
	
	var font = ThemeDB.fallback_font
	var text_size = 22
	var align = HORIZONTAL_ALIGNMENT_LEFT
	var profession_icon_size = Vector2i(18, 18)

	for event in map.extraction_events:
		var real_pos = Vector2i(map.map_to_local(Vector2i(event.x, event.y)))
		var rect = Rect2i(real_pos + Vector2i.ONE, map.tile_size - Vector2i(2, 2))
		
		if used_rect.intersects(rect):
			if event == map.current_extraction_event and map.editing_extraction_events:
				extraction_event_canvas.draw_rect(rect, color3, false, 2)
			
		var p = _get_extraction_item_shape(Vector2i(event.x, event.y), 1.0)
		extraction_event_canvas.draw_colored_polygon(p.fill_polygon, fill_polygon_color)
		extraction_event_canvas.draw_polyline(p.inner_border, inner_border_polygon, 1.0)
		extraction_event_canvas.draw_polyline(p.outer_border, outer_border_polygon, 1.0)
		
		var scene_path = event.scene_path.get_basename() + "_preview" + ".png"
		if ResourceLoader.exists(scene_path):
			var contents: Texture
			if scene_path in extraction_event_preview_textures:
				contents = extraction_event_preview_textures[scene_path]
			else:
				contents = ResourceLoader.load(scene_path)
				extraction_event_preview_textures[scene_path] = contents
			var contents_rect = Rect2i(
				(Vector2i(event.x, event.y) * map.tile_size) + Vector2i(8, 8),
				map.tile_size - Vector2i(16, 16)
			)
			extraction_event_canvas.draw_texture_rect(contents, contents_rect, false, color5)
		
		var profession_id = event.required_profession
		if profession_id >= 1 and RPGSYSTEM.database.professions.size() > profession_id:
			var profession = RPGSYSTEM.database.professions[profession_id]
			if ResourceLoader.exists(profession.icon.path):
				var contents: Texture
				var texture_id = profession.icon.path + "_" + str(profession.icon.region)
				if texture_id in extraction_event_preview_textures:
					contents = extraction_event_preview_textures[texture_id]
				else:
					contents = profession.icon.get_texture()
					extraction_event_preview_textures[texture_id] = contents
				if contents:
					var icon_rect = Rect2i(
						(Vector2i(event.x, event.y) * map.tile_size) - profession_icon_size / 2,
						profession_icon_size
					)
					extraction_event_canvas.draw_texture_rect(contents, icon_rect, false, color5)
		
		var text = str(str(event.current_level))
		var level_str_size: Vector2i = font.get_string_size(text, align, -1, text_size)
		var text_offset: Vector2i = map.tile_size + Vector2i(0, font.get_ascent())
		var text_position = Vector2i(event.x, event.y) * map.tile_size + text_offset - level_str_size / 2
		extraction_event_canvas.draw_string_outline(font, text_position, text, align, -1, text_size, 8, color2)
		extraction_event_canvas.draw_string(font, text_position, text, align, -1, text_size, color1)


func _get_extraction_item_shape(p_tile_position: Vector2i, p_margin: float = 2.0) -> Dictionary:
	var offset = Vector2(p_tile_position.x * map.tile_size.x, p_tile_position.y * map.tile_size.y)
	var cache_key = str(map.tile_size) + "_" + str(p_margin)
	hexagon_cache.clear()
	
	if not hexagon_cache.has(cache_key):
		var polygon_data = _get_extraction_item_shape_polygon(p_margin)
		hexagon_cache[cache_key] = polygon_data
	
	var polygon = hexagon_cache[cache_key].duplicate(true)
	
	for i: int in polygon.fill_polygon.size():
		polygon.fill_polygon[i] += offset
	for i: int in polygon.outer_border.size():
		polygon.outer_border[i] += offset
	for i: int in polygon.inner_border.size():
		polygon.inner_border[i] += offset
		
	return polygon


func _get_extraction_item_shape_polygon(p_margin: float = 0.0) -> Dictionary:
	var center = Vector2(map.tile_size.x / 2.0, map.tile_size.y / 2.0)
	var max_radius_x = (map.tile_size.x - p_margin * 2) / 2.0
	var max_radius_y = (map.tile_size.y - p_margin * 2) / 2.0
	var radius = min(max_radius_x, max_radius_y / sin(PI / 3.0))
	
	var result: Dictionary = {}
	result.fill_polygon = _get_hexagon_vertices(center, radius)
	result.outer_border = result.fill_polygon.duplicate()
	result.outer_border.append(result.outer_border[0])
	result.inner_border = _get_hexagon_vertices(center, radius - 1)
	result.inner_border.append(result.inner_border[0])
	
	return result


func _get_hexagon_vertices(center: Vector2, radius: float) -> PackedVector2Array:
	var vertices = PackedVector2Array()
	for i in range(6):
		var angle = i * PI / 3.0
		var x = center.x + radius * cos(angle)
		var y = center.y + radius * sin(angle)
		vertices.append(Vector2(x, y))
	return vertices


func _on_enemy_spawn_canvas_draw() -> void:
	if not map.editing_enemy_spawn_region and not map.force_show_regions:
		return
	
	for i in map.regions.size():
		var region = map.regions[i]
		if region == map.current_enemy_spawn_region:
			continue
		if region.rect.has_area():
			var c1 = region.color
			if map.current_enemy_spawn_region and map.current_enemy_spawn_region.id == region.id:
				c1 = Color(0.09, 0.047, 0.047, 0.267)
			var c2 = c1.darkened(0.4)
			if map.region_selected and map.region_selected.id == region.id:
				c2 = Color.ORANGE
			
			if map.editing_enemy_spawn_region:
				c1.a = 0.75
				c2.a = 0.90
			elif map.force_show_regions:
				if map.editing_event_region:
					c1.a *= 0.25
					c2.a *= 0.15
				else:
					c1.a *= 0.45
					c2.a *= 0.45
				
			var real_rect = region.rect
			real_rect.position *= map.tile_size
			real_rect.size *= map.tile_size
			enemy_spawn_canvas.draw_rect(real_rect, c1, true)
			enemy_spawn_canvas.draw_rect(real_rect, c2, false, 2)
			
			var font = ThemeDB.fallback_font
			var text_size = ThemeDB.fallback_font_size
			var text_position = Vector2(real_rect.position) + Vector2(22, 22)
			var align = HORIZONTAL_ALIGNMENT_LEFT
			var text = region.name
			if text.is_empty():
				text = "Spawn Region #%s" % (i + 1)
			while text_size > 8 and font.get_string_size(text, align, -1, text_size).x > real_rect.size.x - 22:
				text_size -= 1
			
			var c = Color.WHITE if map.editing_enemy_spawn_region else Color(0.80, 0.80, 0.80, 0.45)
			if map.editing_event_region: 
				c.a = 0.15
			enemy_spawn_canvas.draw_string(font, text_position, text, align, real_rect.size.x - 22, text_size, c)
	
	if (not map.force_show_regions or map.editing_enemy_spawn_region) and map.current_enemy_spawn_region and map.current_enemy_spawn_region.rect.has_area():
		var c1 = map.current_enemy_spawn_region.color
		if map.editing_enemy_spawn_region:
			c1.a = 0.75
		elif map.force_show_regions and map.editing_event_region:
			c1.a *= 0.10
		else:
			c1.a *= 0.45
			
		var c2 = c1.darkened(0.4)
		var real_rect = map.current_enemy_spawn_region.rect
		real_rect.position *= map.tile_size
		real_rect.size *= map.tile_size
		enemy_spawn_canvas.draw_rect(real_rect, c1, true)
		enemy_spawn_canvas.draw_rect(real_rect, c2, false, 2)


func _on_event_region_canvas_draw() -> void:
	if not map.editing_event_region and not map.force_show_regions:
		return

	for i in map.event_regions.size():
		var region = map.event_regions[i]
		if region == map.current_event_region:
			continue
		if region.rect.has_area():
			var c1 = region.color
			if map.current_event_region and map.current_event_region.id == region.id:
				c1 = Color(0.09, 0.047, 0.047, 0.267)
			var c2 = c1.darkened(0.4)
			if map.event_region_selected and map.event_region_selected.id == region.id:
				c2 = Color.ORANGE
			
			if map.editing_event_region:
				c1.a = 0.75
				c2.a = 0.90
			elif map.force_show_regions:
				if map.editing_enemy_spawn_region:
					c1.a *= 0.25
					c2.a *= 0.15
				else:
					c1.a *= 0.45
					c2.a *= 0.45
				
			var real_rect = region.rect
			real_rect.position *= map.tile_size
			real_rect.size *= map.tile_size
			event_region_canvas.draw_rect(real_rect, c1, true)
			event_region_canvas.draw_rect(real_rect, c2, false, 2)
			
			var font = ThemeDB.fallback_font
			var text_size = ThemeDB.fallback_font_size
			var text_position = Vector2(real_rect.position) + Vector2(22, 22)
			var align = HORIZONTAL_ALIGNMENT_LEFT
			var text = region.name
			if text.is_empty():
				text = "Event Region #%s" % (i + 1)
			while text_size > 8 and font.get_string_size(text, align, -1, text_size).x > real_rect.size.x - 22:
				text_size -= 1
				
			var c = Color.WHITE if map.editing_event_region else Color(0.80, 0.80, 0.80, 0.45)
			if map.editing_enemy_spawn_region: 
				c.a = 0.15
			event_region_canvas.draw_string(font, text_position, text, align, real_rect.size.x - 22, text_size, c)
	
	if (not map.force_show_regions or map.editing_event_region) and map.current_event_region and map.current_event_region.rect.has_area():
		var c1 = map.current_event_region.color
		if map.editing_event_region:
			c1.a = 0.75
		elif map.force_show_regions and map.editing_enemy_spawn_region:
			c1.a *= 0.10
		else:
			c1.a *= 0.45
			
		var c2 = c1.darkened(0.4)
		var real_rect = map.current_event_region.rect
		real_rect.position *= map.tile_size
		real_rect.size *= map.tile_size
		event_region_canvas.draw_rect(real_rect, c1, true)
		event_region_canvas.draw_rect(real_rect, c2, false, 2)


func _on_passability_canvas_draw() -> void:
	if not Engine.is_editor_hint() or (not map.editing_events and not map.editing_extraction_events):
		return

	var used_rect: Rect2i = map.get_ingame_rect()
	var mark: String = "❌"
	var font: Font = ThemeDB.fallback_font
	var font_size: int = int(map.tile_size.x * 0.7) 
	var text_size: Vector2 = font.get_string_size(mark, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var ascent: float = font.get_ascent(font_size)
	var descent: float = font.get_descent(font_size)
	var total_height: float = ascent + descent

	var vertical_correction: float = -1.0
	var final_offset: Vector2 = Vector2(
		(map.tile_size.x - text_size.x) / 2.0,
		(map.tile_size.y - total_height) / 2.0 + ascent + vertical_correction
	)

	for x in range(used_rect.position.x, used_rect.end.x):
		for y in range(used_rect.position.y, used_rect.end.y):
			var tile_pos := Vector2i(x, y)
			if map.is_tile_block(tile_pos, false):
				var draw_pos: Vector2 = Vector2(tile_pos * map.tile_size)
				passability_canvas.draw_string(font, draw_pos + final_offset, mark, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color(1, 1, 1, 0.3))


func _on_keot_canvas_draw() -> void:
	if Engine.is_editor_hint() and not map._baked_keot_data.is_empty():
		for tile: Vector2i in map._baked_keot_data.keys():
			var keot_rect = Rect2i((Vector2i(tile.x, tile.y) * map.tile_size), map.tile_size)
			if "keot_tile" in map.editor_icons:
				# Aquí forzamos el Alfa a 0.4 directamente en la textura
				keot_canvas.draw_texture_rect(map.editor_icons.keot_tile, keot_rect, false, Color(1, 1, 1, 0.3))


func _draw_cursor_highlight() -> void:
	if not map.grid_gradient or not Engine.is_editor_hint() or not cursor_canvas:
		return
	
	if (not map.editing_events and not map.editing_extraction_events and not map.editing_enemy_spawn_region and not map.editing_event_region):
		return

	var local_mouse: Vector2 = map.get_local_mouse_position()
	var mouse_grid_x: int = int(local_mouse.x / map.tile_size.x)
	var mouse_grid_y: int = int(local_mouse.y / map.tile_size.y)
	
	var start_x: int = mouse_grid_x - map.cursor_radius
	var end_x: int = mouse_grid_x + map.cursor_radius
	var start_y: int = mouse_grid_y - map.cursor_radius
	var end_y: int = mouse_grid_y + map.cursor_radius

	for x in range(start_x, end_x + 1):
		for y in range(start_y, end_y + 1):
			var dist_x: int = abs(x - mouse_grid_x)
			var dist_y: int = abs(y - mouse_grid_y)
			var distance: int = max(dist_x, dist_y)
			
			var sample_pos: float = float(distance) / float(map.cursor_radius)
			var color: Color = map.grid_gradient.sample(sample_pos)
			
			var draw_pos: Vector2 = Vector2(x * map.tile_size.x, y * map.tile_size.y)
			var rect: Rect2 = Rect2(draw_pos, map.tile_size)
			
			cursor_canvas.draw_rect(rect, color, false)


func _on_grid_canvas_draw() -> void:
	var rect: Rect2 = map.get_used_rect()
	if !rect.has_area():
		return

	if !Engine.is_editor_hint() or (!map.editing_events and !map.editing_extraction_events and !map.editing_enemy_spawn_region and !map.editing_event_region):
		return

	var start_x: float = rect.position.x * map.tile_size.x
	var start_y: float = rect.position.y * map.tile_size.y
	var end_x: float = (rect.position.x + rect.size.x) * map.tile_size.x
	var end_y: float = (rect.position.y + rect.size.y) * map.tile_size.y

	for x in range(rect.size.x + 1):
		var x_pos: float = start_x + (x * map.tile_size.x)
		grid_canvas.draw_line(Vector2(x_pos, start_y), Vector2(x_pos, end_y), map.grid_color)

	for y in range(rect.size.y + 1):
		var y_pos: float = start_y + (y * map.tile_size.y)
		grid_canvas.draw_line(Vector2(start_x, y_pos), Vector2(end_x, y_pos), map.grid_color)



func set_child_opacity(node: Node, original_modulate: bool = false) -> void:
	for child in node.get_children():
		if map.shadow_manager and child == map.shadow_manager.get_editor_shadow_canvas():
			continue
			
		var is_canvas = false
		is_canvas = child == event_canvas or child == extraction_event_canvas or child == enemy_spawn_canvas or child == event_region_canvas or child == keot_canvas or child == cursor_canvas or child == passability_canvas or child == grid_canvas
			
		if "modulate" in child and not is_canvas:
			if original_modulate:
				if child.has_meta("original_opacity"):
					child.modulate.a = child.get_meta("original_opacity")
			else:
				if !child.has_meta("original_opacity"):
					child.set_meta("original_opacity", child.modulate.a)
				child.modulate.a = map.children_opacity
		
		for other_node in child.get_children():
			set_child_opacity(other_node, original_modulate)
