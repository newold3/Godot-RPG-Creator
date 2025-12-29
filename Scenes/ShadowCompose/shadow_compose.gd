@tool
extends Node2D

@export var shadow_component: ShadowComponent :
	set(value):
		if shadow_component and shadow_component.shadow_updated.is_connected(update):
			shadow_component.shadow_updated.disconnect(update)
		shadow_component = value
		if shadow_component:
			if Engine.is_editor_hint():
				if not shadow_component.shadow_updated.is_connected(update):
					shadow_component.shadow_updated.connect(update)
				if is_node_ready():
					shadow_component.shadow_updated.emit()
			elif is_node_ready():
				update()


@export var shadow_data: Array :
	set(value):
		value.sort_custom(
			func(a: Dictionary, b: Dictionary):
				return a.position.y < b.position.y
		)
		shadow_data = value
		if is_node_ready():
			need_refresh = true


var need_refresh: bool = false
var current_map_rect: Rect2 = Rect2()
var main_offset: Vector2
var in_editor_map: RPGMap

var current_drawing_shadows = {
	"tiles": [],
	"masks": []
}

const EXTRA_MARGIN: int = 400


func _ready() -> void:
	set_process(false)
	var viewport_size = get_viewport().size
	%ShadowSubViewport.size = viewport_size
	%MaskSubViewport.size = viewport_size
	%ShadowFinalMix.size = viewport_size
	%ShadowFinal.size = viewport_size
	%Canvas1.draw.connect(_on_canvas1_draw) # Draw Shadows
	%Canvas2.draw.connect(_on_canvas2_draw) # Draw Shadows
	update()
	await get_tree().process_frame
	set_process(true)


func synchronizes_cameras() -> void:
	set_viewport_size()
	var main_camera: Camera2D = GameManager.get_camera()
	if main_camera:
		var camera_center = main_camera.get_screen_center_position()
		var camera_zoom = main_camera.zoom
		var viewport_size = get_viewport_rect().size

		var adjusted_position = camera_center - (viewport_size * 0.5 / camera_zoom)
		%Canvas1.position = -adjusted_position
		%Canvas2.position = -adjusted_position
		%Shadows.global_position = adjusted_position


func clear_map_repeating() -> void:
	%Canvas1Parallax.repeat_times = 1
	%Canvas1Parallax.repeat_size = Vector2.ZERO
	%Canvas2Parallax.repeat_times = 1
	%Canvas2Parallax.repeat_size = Vector2.ZERO


func enable_map_repeating() -> void:
	%Canvas1Parallax.repeat_times = 4
	%Canvas2Parallax.repeat_times = 4


# Function called from rpg map in the function _perform_shadow_update
func set_current_map_rect(rect: Rect2) -> void:
	if rect != null:
		current_map_rect = rect
	else:
		current_map_rect = Rect2()

	if %Canvas1Parallax.repeat_times != 1:
		%Canvas1Parallax.repeat_size = current_map_rect.size
		%Canvas2Parallax.repeat_size = current_map_rect.size
	set_viewport_size()


func set_viewport_size() -> void:
	var viewport_size = get_viewport_rect().size
	var camera_zoom = GameManager.get_camera_zoom()
	viewport_size /= camera_zoom
	%ShadowSubViewport.size = viewport_size
	%MaskSubViewport.size = viewport_size
	%ShadowFinalMix.size = viewport_size
	%ShadowFinal.size = viewport_size


@warning_ignore("unused_parameter")
func _process(delta: float) -> void:
	if need_refresh:
		refresh_all()
		need_refresh = false

	if not Engine.is_editor_hint():
		synchronizes_cameras()


func update():
	if shadow_component:
		var mat: ShaderMaterial = %ShadowLayer.get_material()
		mat.set_shader_parameter("blur_size", shadow_component.blur_size)
		mat.set_shader_parameter("overlay_color", shadow_component.shadow_color)
		
		%Shadows.z_index = shadow_component.shadow_z_index
		%Shadows.get_material().blend_mode = shadow_component.shadow_blend_type

	need_refresh = true


func get_editor_visible_rect() -> Rect2:
	var viewport_transform = get_viewport().get_final_transform()
	var viewport_rect = get_viewport().get_visible_rect()

	var inverse_transform = viewport_transform.affine_inverse()
	var top_left = inverse_transform * Vector2.ZERO
	var bottom_right = inverse_transform * viewport_rect.size
	var zoom = 1.0 / viewport_transform.get_scale().x

	return Rect2(top_left, bottom_right - top_left).grow(32 * zoom)


func get_visible_area_with_margin(margin: float) -> Rect2:
	var main_camera: Camera2D
	if Engine.is_editor_hint():
		main_camera = get_viewport().get_camera_2d()
	else:
		main_camera = GameManager.get_camera()
	if main_camera == null and not in_editor_map:
		return Rect2()
	elif in_editor_map:
		return get_editor_visible_rect()
	if not main_camera: return Rect2()
	var camera_center = main_camera.get_screen_center_position()
	var camera_zoom = main_camera.zoom
	@warning_ignore("incompatible_ternary")
	var viewport_size = get_viewport_rect().size if Engine.is_editor_hint() else get_window().content_scale_size

	var visible_area = Rect2()
	visible_area.size = viewport_size * camera_zoom
	visible_area.position = camera_center - (visible_area.size * 0.5)

	visible_area = visible_area.grow(margin)

	return visible_area


func get_screen_tiles_size(current_map: RPGMap) -> Vector2i:
	var main_camera: Camera2D = get_viewport().get_camera_2d()
	if main_camera == null and not in_editor_map:
		return Vector2i.ZERO
	elif in_editor_map:
		return Vector2i(get_editor_visible_rect().size)
		
	var tile_size = current_map.tile_size
	var tiles = Vector2(ceil(Vector2(get_viewport().size) / Vector2(tile_size)))
	tiles += tiles * 0.85
	tiles /= main_camera.zoom
	return Vector2i(tiles)


func refresh_all() -> void:
	var main_camera: Camera2D = GameManager.get_camera()
	if not main_camera:
		main_camera = get_viewport().get_camera_2d()
	if main_camera:
		var z = min(main_camera.zoom.x, main_camera.zoom.y)
		if z < 2.0:
			%Shadows.modulate.a = max(0, remap(z, 2.0, 0.8, 1.0, 0.0))
			var hide_shadows = %Shadows.modulate.a <= 0.08
			if hide_shadows:
				%Shadows.modulate.a = 0.0
				return
		else:
			%Shadows.modulate.a = 1.0
	set_drawing_textures()
	%Canvas1.queue_redraw()
	%Canvas2.queue_redraw()
	%ShadowSubViewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	%MaskSubViewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	%ShadowFinalMix.render_target_update_mode = SubViewport.UPDATE_ONCE
	%ShadowFinal.render_target_update_mode = SubViewport.UPDATE_ONCE
	%ShadowSubViewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	%MaskSubViewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	%ShadowFinalMix.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	%ShadowFinal.render_target_update_mode = SubViewport.UPDATE_ALWAYS


func _calculate_alpha_by_distance_squared(pos1: Vector2, pos2: Vector2, max_distance_squared: float = 100000.0, invert: bool = false) -> float:
	var distance_squared = pos1.distance_squared_to(pos2)
	
	var normalized_distance = 1.0 - (1.0 / distance_squared * max_distance_squared)
	
	if invert:
		return 1.0 - normalized_distance
	else:
		return normalized_distance


func _encode_y_position_as_alpha(world_y: float, reference_height: float) -> float:
	var normalized = clamp(world_y / reference_height, 0.006, 1.0)
	return normalized


func _get_shadow_visibility(dn: RPGDayNightComponent) -> float:
	var h := dn.current_hour
	var min_alpha = 0.12
	var max_alpha = 1.0

	if h >= 8.0 and h < 18.0:
		return max_alpha

	if h >= 18.0 and h < 23.9:
		return remap(h, 18.0, 23.9, max_alpha, min_alpha)

	if h >= 23.9 or h < 5.0:
		return min_alpha

	if h >= 5.0 and h < 8.0:
		return remap(h, 5.0, 8.0, min_alpha, max_alpha)

	return max_alpha


func set_drawing_textures() -> void:
	current_drawing_shadows.tiles.clear()
	current_drawing_shadows.masks.clear()

	var current_map: RPGMap

	if in_editor_map:
		current_map = in_editor_map
	else:
		current_map = GameManager.current_map

	var day_night_data = DayNightManager.get_data()
	@warning_ignore("incompatible_ternary")
	var using_data = shadow_component if (not day_night_data or not DayNightManager.is_enabled()) else day_night_data
	var start_id = "shadow_" if using_data == day_night_data else ""

	if not using_data or not current_map or (not GameManager.current_player and not in_editor_map):
		return

	if using_data is RPGDayNightComponent:
		var mat: ShaderMaterial = %ShadowLayer.get_material()
		#if not mat.has_meta("original_shadow_color"):
			#mat.set_meta("original_shadow_color", mat.get_shader_parameter("overlay_color"))
		#var shadow_color = mat.get_meta("original_shadow_color")
		#shadow_color.a *= using_data.shadow_opacity
		var visibility := _get_shadow_visibility(using_data)
		var shadow_color = RPGSYSTEM.database.system.day_night_config.shadow_color
		shadow_color.a *= visibility
		mat.set_shader_parameter("overlay_color", shadow_color)
		var sk = using_data[start_id + "dynamic_skew"]
		var sun_angle = -sk * PI
		var sun_direction := Vector2(sin(sun_angle), cos(sun_angle)).normalized()
		mat.set_shader_parameter("shadow_direction", sun_direction)

	var screen_tiles_size = get_screen_tiles_size(current_map) / 2
	var player_current_tile: Vector2i
	if in_editor_map:
		player_current_tile = Vector2i()
	else:
		if GameManager.current_player.is_on_vehicle and GameManager.current_player.current_vehicle:
			player_current_tile = Vector2i(GameManager.current_player.current_vehicle.global_position) / current_map.tile_size
		else:
			player_current_tile = Vector2i(GameManager.current_player.global_position) / current_map.tile_size

	var map_rect: Rect2 = current_map.get_used_rect(false)
	var viewport_size: Vector2i = map_rect.size
	var map_tiles = viewport_size / current_map.tile_size
	var screen_mid_size = screen_tiles_size * 0.5
	var screen_height = float(viewport_size.y)
	if screen_height < get_viewport_rect().size.y:
		screen_height = get_viewport_rect().size.y

	var distance_from_edges = {
		"left": player_current_tile.x - 5,
		"right": map_tiles.x - player_current_tile.x - 5,
		"up": player_current_tile.y - 5,
		"down": map_tiles.y - player_current_tile.y - 5,
	}

	if current_map.infinite_horizontal_scroll:
		distance_from_edges.extra_left = 0 if distance_from_edges.left > screen_mid_size.x else ceil(screen_mid_size.x - distance_from_edges.left)
		distance_from_edges.extra_right = 0 if distance_from_edges.right > screen_mid_size.x else ceil(screen_mid_size.x - distance_from_edges.right)
	else:
		distance_from_edges.extra_left = 0
		distance_from_edges.extra_right = 0

	if current_map.infinite_vertical_scroll:
		distance_from_edges.extra_up = 0 if distance_from_edges.up > screen_mid_size.y else ceil(screen_mid_size.y - distance_from_edges.up)
		distance_from_edges.extra_down = 0 if distance_from_edges.down > screen_mid_size.y else ceil(screen_mid_size.y - distance_from_edges.down)
	else:
		distance_from_edges.extra_up = 0
		distance_from_edges.extra_down = 0

	var screen_rect = Rect2() if not in_editor_map else get_visible_area_with_margin(EXTRA_MARGIN)

	for data: Dictionary in shadow_data:
		if ("texture" in data and not is_instance_valid(data.texture)) or \
			("main_node" in data and not is_instance_valid(data.main_node)) or \
			("main_texture" in data and not is_instance_valid(data.main_texture)) or \
			not "cell" in data:
			continue

		var tile_cell = data.cell
		var inside_main_map = (
			tile_cell.x >= player_current_tile.x - screen_tiles_size.x and
			tile_cell.x <= player_current_tile.x + screen_tiles_size.x and
			tile_cell.y >= player_current_tile.y - screen_tiles_size.y and
			tile_cell.y <= player_current_tile.y + screen_tiles_size.y
		)

		var inside_extra_tiles = false

		if distance_from_edges.extra_left > 0 and tile_cell.x >= map_tiles.x - distance_from_edges.extra_left:
			inside_extra_tiles = true
		if distance_from_edges.extra_right > 0 and tile_cell.x < distance_from_edges.extra_right:
			inside_extra_tiles = true
		if distance_from_edges.extra_up > 0 and tile_cell.y >= map_tiles.y - distance_from_edges.extra_up:
			inside_extra_tiles = true
		if distance_from_edges.extra_down > 0 and tile_cell.y < distance_from_edges.extra_down:
			inside_extra_tiles = true

		if not inside_main_map and not inside_extra_tiles:
			if not screen_rect:
				var alpha = _calculate_alpha_by_distance_squared(GameManager.current_player.global_position, data.position)
				if not GameManager.current_player or alpha <= 0:
					continue
				else:
					data.shadow_alpha = alpha
			elif in_editor_map:
				var data_offset = data.get("offset", Vector2.ZERO)
				if not screen_rect.has_point(data.position - data_offset):
					continue

		if "main_texture" in data and (
				not is_instance_valid(data.main_texture) or
				data.main_texture.has_meta("_disable_shadow")
		):
			continue

		# --- COMPOSITE SPRITES ---
		if data.has("sprites") and data.has("main_node") and not data.sprites.is_empty():
			var m_scale = data.main_node.scale
			var m_rot = data.main_node.rotation
			
			var sk = using_data[start_id + "dynamic_skew"]
			var elongation = using_data[start_id + "elongation"]
			var base_pos = data.position
			
			var alpha_depth = _encode_y_position_as_alpha(base_pos.y + map_rect.position.y, screen_height)
			var color = Color(alpha_depth, 1.0, 1.0, 0.11)
			var mask_color = color

			for sprite in data.sprites:
				if not is_instance_valid(sprite) or not is_instance_valid(sprite.texture):
					continue
				
				var region = sprite.region_rect
				var tex_size = sprite.texture.get_size()
				
				var uv_min = region.position / tex_size
				var uv_max = (region.position + region.size) / tex_size
				
				var final_uvs = [
					Vector2(uv_min.x, uv_min.y),
					Vector2(uv_max.x, uv_min.y),
					Vector2(uv_max.x, uv_max.y),
					Vector2(uv_min.x, uv_max.y)
				]

				var w_half = region.size.x / 2.0
				var h_half = region.size.y / 2.0
				var sprite_pos = sprite.position

				var local_points = [
					Vector2(-w_half, -h_half),
					Vector2(w_half, -h_half),
					Vector2(w_half, h_half),
					Vector2(-w_half, h_half)
				]
				
				var final_points = []
				var final_colors = []
				
				var feet_offset: int = data.get("feet_offset", 0)
				for i in local_points.size():
					var p = local_points[i]
					p += sprite_pos
					var trans_p = p * m_scale
					trans_p = trans_p.rotated(m_rot)
					trans_p.x += trans_p.y * sk
					
					if typeof(elongation) == TYPE_VECTOR2:
						trans_p *= elongation
					else:
						trans_p *= Vector2(1.0, elongation)

					if feet_offset and "feet_offset" in data:
						if i == 3:
							trans_p.x += feet_offset
						if i == 2:
							trans_p.x -= feet_offset
					trans_p += base_pos
					
					final_points.append(trans_p)
					final_colors.append(color)

				current_drawing_shadows.tiles.append({
					"main_texture": data.get("main_texture", null),
					"type": "polygon",
					"points": final_points,
					"colors": final_colors,
					"uvs": final_uvs,
					"texture": sprite.texture,
					"sprite_scale": Vector2.ONE,
					"force_draw": true
				})
				
				current_drawing_shadows.masks.append({
					"main_texture": data.get("main_texture", null),
					"texture": sprite.texture,
					"position": sprite.global_position - Vector2(GameManager.current_map.tile_size), # Pasamos la posición corregida
					"sprite_scale": sprite.scale,
					"color": mask_color,
					"region": region
				})


		# --- SINGLE TEXTURE ---
		else:
			var st: Texture = data.texture
			if not is_instance_valid(st):
				continue

			var p = data.position
			var alpha_depth = _encode_y_position_as_alpha(p.y, screen_height)
			var color = Color(alpha_depth, 1.0, 1.0, 0.1)

			var half_width = st.get_width() / 2.0
			var height = st.get_height()

			# Base points (Feet)
			var p1_x = -half_width
			var p2_x = half_width
			
			var p1 = Vector2(p1_x, 0)
			var p2 = Vector2(p2_x, 0)
			
			var feet_offset: int = data.get("feet_offset", 0)
			if feet_offset:
				p1.x += feet_offset
				p2.x -= feet_offset
			
			# Top points (Head) - Keep original width or scale proportionally? 
			# Usually keeping original width looks better (trapezoid shadow).
			var p3 = Vector2(half_width, -height)
			var p4 = Vector2(-half_width, -height)

			var elongation = using_data[start_id + "elongation"]
			p3 *= elongation
			p4 *= elongation

			var sk = using_data[start_id + "dynamic_skew"]
			p1.x += p1.y * sk
			p2.x += p2.y * sk
			p3.x += p3.y * sk
			p4.x += p4.y * sk

			var scale_factor = data.get("scale", Vector2.ONE)
			var sprite_scale = data.get("sprite_scale", Vector2.ONE)
			var total_scale = scale_factor * sprite_scale

			if total_scale != Vector2.ONE:
				p1 *= total_scale
				p2 *= total_scale
				p3 *= total_scale
				p4 *= total_scale

			var texture_height = st.get_height()
			var base_y = texture_height + shadow_component.offset.y
			var base_offset_y = base_y + data.position.y

			p1.y += base_offset_y
			p2.y += base_offset_y
			p3.y += base_offset_y
			p4.y += base_offset_y

			var texture_width_half = st.get_width() / 2
			var base_x = texture_width_half + shadow_component.offset.x
			var base_offset_x = base_x + data.position.x

			p1.x += base_offset_x
			p2.x += base_offset_x
			p3.x += base_offset_x
			p4.x += base_offset_x

			var data_offset = data.get("offset", Vector2.ZERO)
			if data_offset != Vector2.ZERO:
				p1 -= data_offset
				p2 -= data_offset
				p3 -= data_offset
				p4 -= data_offset

			var points = [p4, p3, p2, p1]
			var colors = [color, color, color, color]
			var uvs = [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]

			current_drawing_shadows.tiles.append({
				"main_texture": data.get("main_texture", null),
				"type": "polygon",
				"points": points,
				"colors": colors,
				"uvs": uvs,
				"texture": st,
				"sprite_scale": sprite_scale
			})
			
			var mask_pos = data.position
			if data_offset != Vector2.ZERO:
				mask_pos -= data_offset # Corregir offset si el objeto lo tiene

			current_drawing_shadows.masks.append({
				"main_texture": data.get("main_texture", null),
				"texture": st,
				"position": mask_pos,
				"sprite_scale": total_scale,
				"color": Color.WHITE # color
			})


func _on_canvas1_draw():
	for tile in current_drawing_shadows.tiles:
		if not is_instance_valid(tile.texture):
			continue
		if "main_texture" in tile and tile.main_texture and (
			not is_instance_valid(tile.main_texture) or
			tile.main_texture.has_meta("_disable_shadow")
		):
			continue
		if tile.type == "texture":
			var sprite_scale = tile.sprite_scale
			var pos = tile.position
			var texture = tile.texture
			var texture_size = texture.get_size()
			var scale_offset = texture_size * (sprite_scale - Vector2.ONE) * 0.5
			var adjusted_position = pos - scale_offset
			var color = tile.color
			%Canvas1.draw_texture_rect(texture, Rect2(adjusted_position, texture_size * sprite_scale), false, color)
		elif tile.type == "polygon":
			%Canvas1.draw_polygon(tile.points, tile.colors, tile.uvs, tile.texture)
	%Canvas1.get_parent().get_parent().render_target_update_mode = SubViewport.UPDATE_ONCE


func _on_canvas2_draw():
	for mask in current_drawing_shadows.masks:
		if "main_texture" in mask and mask.main_texture and (
			not is_instance_valid(mask.main_texture) or
			mask.main_texture.has_meta("_disable_shadow")
		):
			continue
		if not is_instance_valid(mask.texture):
			continue
			
		var sprite_scale = mask.sprite_scale
		var pos = mask.position
		var texture = mask.texture
		if not texture: continue
		if "region" in mask:
			var texture_size = mask.region.size
			%Canvas2.draw_texture_rect_region(texture, Rect2(pos, texture_size * sprite_scale), mask.region, mask.color)
		else:
			var texture_size = texture.get_size()
			%Canvas2.draw_texture_rect(texture, Rect2(pos, texture_size * sprite_scale), false, mask.color)
	
	%Canvas2.get_parent().get_parent().render_target_update_mode = SubViewport.UPDATE_ONCE
