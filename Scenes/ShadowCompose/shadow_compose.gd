@tool
extends Node2D


class ShadowRuntimeData:
	var visible_rect_cache: Dictionary = {}
	var transform_cache: Dictionary = {}
	var current_frame_tick: int = 0
	var current_drawing_shadows = {
		"tiles": [],
		"masks": []
	}


## Array containing all the shadow configuration dictionaries to be rendered
@export var shadow_data: Array:
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

var _rt: ShadowRuntimeData

const EXTRA_MARGIN: int = 400


func _ready() -> void:
	set_process(false)
	_rt = ShadowRuntimeData.new()
	var viewport_size = get_viewport().size
	%ShadowSubViewport.size = viewport_size
	%MaskSubViewport.size = viewport_size
	%ShadowFinalMix.size = viewport_size
	%ShadowFinal.size = viewport_size
	%Canvas1.draw.connect(_on_canvas1_draw)
	%Canvas2.draw.connect(_on_canvas2_draw)
	update()
	await get_tree().process_frame
	set_process(true)


func _validate_property(property):
	if not Engine.is_editor_hint():
		if property.name == "_rt":
			property.usage &= ~PROPERTY_USAGE_EDITOR
			return


func synchronizes_cameras() -> void:
	set_viewport_size()
	var main_camera: Camera2D = GameManager.get_camera()
	if main_camera:
		var camera_center = main_camera.get_screen_center_position()
		var camera_zoom = main_camera.zoom
		var viewport_size = get_viewport_rect().size
		var adjusted_position = camera_center - (viewport_size * 0.5 / camera_zoom)
		%Canvas1.position = - adjusted_position
		%Canvas2.position = - adjusted_position
		%Shadows.global_position = adjusted_position


func clear_map_repeating() -> void:
	%Canvas1Parallax.repeat_times = 1
	%Canvas1Parallax.repeat_size = Vector2.ZERO
	%Canvas2Parallax.repeat_times = 1
	%Canvas2Parallax.repeat_size = Vector2.ZERO


func enable_map_repeating(repeat_times: int = 2) -> void:
	%Canvas1Parallax.repeat_times = repeat_times
	%Canvas2Parallax.repeat_times = repeat_times


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
	var mat: ShaderMaterial = %ShadowLayer.get_material()
	mat.set_shader_parameter("blur_size", RPGSYSTEM.database.system.day_night_config.blur_size)
	mat.set_shader_parameter("overlay_color",RPGSYSTEM.database.system.day_night_config.shadow_color)
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
	visible_area.size = Vector2(viewport_size) * camera_zoom
	visible_area.position = camera_center - (visible_area.size * 0.5)
	visible_area = visible_area.grow(margin)
	return visible_area


func get_screen_tiles_size(current_map: RPGMap) -> Vector2i:
	var main_camera: Camera2D = get_viewport().get_camera_2d()
	if main_camera == null and not in_editor_map:
		return Vector2i.ZERO
	var tile_size = current_map.tile_size
	var tiles: Vector2
	if in_editor_map:
		tiles = get_editor_visible_rect().size / Vector2(tile_size)
	else:
		var zoom = main_camera.zoom
		tiles = (Vector2(get_viewport().size) / zoom) / Vector2(tile_size)
	tiles += Vector2(10, 10)
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
	%ShadowSubViewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	%MaskSubViewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	%ShadowFinalMix.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	%ShadowFinal.render_target_update_mode = SubViewport.UPDATE_ALWAYS


func _calculate_alpha_by_distance_squared(pos1: Vector2, pos2: Vector2, max_distance_squared: float = 100000.0, invert: bool = false) -> float:
	var distance_squared = pos1.distance_squared_to(pos2)
	var normalized_distance = 1.0 - (1.0 / distance_squared * max_distance_squared)
	if invert: return 1.0 - normalized_distance
	else: return normalized_distance


func _encode_y_position_as_alpha(world_y: float, reference_height: float) -> float:
	var normalized = clamp(world_y / reference_height, 0.006, 1.0)
	return normalized


func _get_shadow_visibility(dn: RPGDayNightComponent) -> float:
	var h := dn.current_hour
	var min_alpha = RPGSYSTEM.database.system.day_night_config.shadow_night_strength
	var max_alpha = RPGSYSTEM.database.system.day_night_config.shadow_day_strength
	if h >= 8.0 and h < 18.0: 
		return max_alpha
	if h >= 18.0 and h < 23.9: 
		return remap(h, 18.0, 23.9, max_alpha, min_alpha)
	if h >= 23.9 or h < 5.0: 
		return min_alpha
	if h >= 5.0 and h < 8.0: 
		return remap(h, 5.0, 8.0, min_alpha, max_alpha)
	return max_alpha


func _get_smart_used_rect(texture: Texture) -> Rect2:
	if texture.resource_path.is_empty():
		var img = texture.get_image()
		if img: return img.get_used_rect()
		return Rect2(Vector2.ZERO, texture.get_size())
	var id = texture.get_rid()
	if _rt.visible_rect_cache.has(id):
		return _rt.visible_rect_cache[id]
	var img = texture.get_image()
	var rect = Rect2(Vector2.ZERO, texture.get_size())
	if img:
		rect = img.get_used_rect()
	_rt.visible_rect_cache[id] = rect
	return rect


func _get_uvs_from_rect(rect: Rect2, texture_size: Vector2) -> PackedVector2Array:
	var uv_min = rect.position / texture_size
	var uv_max = rect.end / texture_size
	return PackedVector2Array([
		uv_min,
		Vector2(uv_max.x, uv_min.y),
		uv_max,
		Vector2(uv_min.x, uv_max.y)
	])


func _is_polygon_safe(points: PackedVector2Array) -> bool:
	if points.size() < 3:
		return false
	return not Geometry2D.triangulate_polygon(points).is_empty()


func _draw_safe_polygon(canvas: Node2D, points: PackedVector2Array, colors: PackedColorArray, uvs: PackedVector2Array, texture: Texture2D) -> void:
	if _is_polygon_safe(points):
		canvas.draw_polygon(points, colors, uvs, texture)


func set_drawing_textures() -> void:
	_rt.current_frame_tick += 1
	if _rt.current_frame_tick > 10000:
		_rt.current_frame_tick = 0
	_rt.current_drawing_shadows.tiles.clear()
	_rt.current_drawing_shadows.masks.clear()
	var current_map: RPGMap
	if in_editor_map:
		current_map = in_editor_map
	else:
		current_map = GameManager.current_map
	var day_night_data = DayNightManager.get_data()
	var using_data = day_night_data
	var start_id = "shadow_" if using_data == day_night_data else ""
	if not using_data or not current_map or (not GameManager.current_player and not in_editor_map):
		return
	if using_data is RPGDayNightComponent:
		var mat: ShaderMaterial = %ShadowLayer.get_material()
		var visibility := _get_shadow_visibility(using_data)
		var shadow_color = RPGSYSTEM.database.system.day_night_config.shadow_color
		shadow_color.a *= visibility
		mat.set_shader_parameter("overlay_color", shadow_color)
		var sk = using_data[start_id + "dynamic_skew"]
		var sun_vec = Vector2(sk, 1.0).normalized()
		mat.set_shader_parameter("shadow_direction", sun_vec)
	var map_rect: Rect2 = current_map.get_used_rect(false)
	var viewport_size: Vector2i = map_rect.size
	var screen_height = float(viewport_size.y)
	if screen_height < get_viewport_rect().size.y:
		screen_height = get_viewport_rect().size.y
	var screen_rect = get_visible_area_with_margin(EXTRA_MARGIN * 2.0)
	var composite_correction_offset = Vector2(-current_map.tile_size.x, -current_map.tile_size.y)
	var single_correction_offset = Vector2(current_map.tile_size.x * 0.5, current_map.tile_size.y)
	var infinite_x = current_map.infinite_horizontal_scroll
	var infinite_y = current_map.infinite_vertical_scroll
	var map_size_px = Vector2(current_map.get_map_size_in_tiles()) * Vector2(current_map.tile_size)
	
	var screen_tiles_size = get_screen_tiles_size(current_map)
	var half_view_x = int(screen_tiles_size.x / 2.0) + 4
	var half_view_y = int(screen_tiles_size.y / 2.0) + 4
	var p_tile = Vector2i()
	if not in_editor_map and GameManager.current_player:
		var p_pos = GameManager.current_player.global_position
		if GameManager.current_player.is_on_vehicle and is_instance_valid(GameManager.current_player.current_vehicle):
			p_pos = GameManager.current_player.current_vehicle.global_position
		p_tile = Vector2i(p_pos / Vector2(current_map.tile_size))
		
	for data: Dictionary in shadow_data:
		if ("texture" in data and not is_instance_valid(data.texture)) or \
			("main_node" in data and not is_instance_valid(data.main_node)) or \
			("main_texture" in data and not is_instance_valid(data.main_texture)) or \
			not "cell" in data:
			continue
		if "main_texture" in data and (not is_instance_valid(data.main_texture) or data.main_texture.has_meta("_disable_shadow")):
			continue
		var base_pos = data.position
		var valid_offsets: Array[Vector2] = []
		if in_editor_map:
			var data_offset = data.get("offset", Vector2.ZERO)
			if screen_rect.has_point(base_pos - data_offset):
				valid_offsets.append(Vector2.ZERO)
		else:
			var cell: Vector2i = data.cell
			var diff_x = abs(cell.x - p_tile.x)
			var diff_y = abs(cell.y - p_tile.y)
			var map_size_tiles = current_map.get_map_size_in_tiles()
			if infinite_x: diff_x = min(diff_x, abs(diff_x - map_size_tiles.x))
			if infinite_y: diff_y = min(diff_y, abs(diff_y - map_size_tiles.y))
			if diff_x <= half_view_x and diff_y <= half_view_y:
				if infinite_x or infinite_y:
					var start_x = -1 if infinite_x else 0
					var end_x = 1 if infinite_x else 0
					var start_y = -1 if infinite_y else 0
					var end_y = 1 if infinite_y else 0
					for ox in range(start_x, end_x + 1):
						for oy in range(start_y, end_y + 1):
							var offset_vec = Vector2(ox * map_size_px.x, oy * map_size_px.y)
							if screen_rect.has_point(base_pos + offset_vec):
								valid_offsets.append(offset_vec)
				else:
					valid_offsets.append(Vector2.ZERO)
		if valid_offsets.is_empty():
			continue
			
		var obj_alpha: float = 1.0
		if data.has("main_node") and is_instance_valid(data.main_node):
			obj_alpha = data.main_node.modulate.a
			
		if data.has("sprites") and data.has("main_node") and not data.sprites.is_empty():
			var m_scale = data.main_node.scale
			var m_rot = data.main_node.rotation
			var sk = using_data[start_id + "dynamic_skew"]
			var elongation = using_data[start_id + "elongation"]
			var alpha_depth = _encode_y_position_as_alpha(base_pos.y + map_rect.position.y, screen_height)
			var color = Color(alpha_depth, obj_alpha, 1.0, 1.0)
			var mask_color = Color(alpha_depth, 1.0, 1.0, 1.0)
			for sprite in data.sprites:
				if not is_instance_valid(sprite) or not is_instance_valid(sprite.texture): continue
				var region = sprite.region_rect
				var final_uvs = _get_uvs_from_rect(region, sprite.texture.get_size())
				var w_half = region.size.x / 2.0
				var h_half = region.size.y / 2.0
				var sprite_pos = sprite.position
				var local_points = [Vector2(-w_half, -h_half), Vector2(w_half, -h_half), Vector2(w_half, h_half), Vector2(-w_half, h_half)]
				var base_points = PackedVector2Array()
				var final_colors = PackedColorArray()
				var feet_offset: int = data.get("feet_offset", 0)
				for i in local_points.size():
					var p = local_points[i]
					p += sprite_pos
					var trans_p = p * m_scale
					trans_p = trans_p.rotated(m_rot)
					trans_p.x += trans_p.y * sk
					if typeof(elongation) == TYPE_VECTOR2: trans_p *= elongation
					else: trans_p *= Vector2(1.0, elongation)
					if feet_offset and "feet_offset" in data:
						if i == 3: trans_p.x += feet_offset
						if i == 2: trans_p.x -= feet_offset
					trans_p += base_pos
					base_points.append(trans_p)
					final_colors.append(color)
				var mask_nudge = Vector2(1, -2)
				var m_offset = data.get("mask_offset", Vector2.ZERO)
				var base_mask_points = PackedVector2Array([
					base_points[3] + mask_nudge + m_offset,
					base_points[2] - mask_nudge + m_offset,
					base_points[1] + mask_nudge + m_offset,
					base_points[0] - mask_nudge + m_offset
				])
				for offset_vec in valid_offsets:
					var offset_shadow_points = PackedVector2Array()
					for p in base_points:
						offset_shadow_points.append(p + offset_vec)
					var offset_mask_points = PackedVector2Array()
					for p in base_mask_points:
						offset_mask_points.append(p + offset_vec)
					_rt.current_drawing_shadows.tiles.append({
						"main_texture": data.get("main_texture", null),
						"type": "polygon",
						"points": offset_shadow_points,
						"colors": final_colors,
						"uvs": final_uvs,
						"texture": sprite.texture
					})
					_rt.current_drawing_shadows.masks.append({
						"main_texture": data.get("main_texture", null),
						"texture": sprite.texture,
						"position": sprite.global_position + composite_correction_offset + data.get("mask_offset", Vector2.ZERO) + offset_vec,
						"sprite_scale": sprite.scale,
						"color": mask_color,
						"region": region
					})
		else:
			var st: Texture = data.get("texture", null)
			if not is_instance_valid(st): continue
			var q_points = []
			var is_auto_cropped = false
			if "quad_points" in data:
				q_points = data.quad_points.duplicate()
			else:
				is_auto_cropped = true
				var used_rect = _get_smart_used_rect(st)
				var full_size = st.get_size()
				var texture_center = full_size / 2.0
				var pos = data.position
				var s_scale = data.get("sprite_scale", Vector2.ONE) * data.get("scale", Vector2.ONE)
				var offset = data.get("offset", Vector2.ZERO)
				var tl_offset = used_rect.position - texture_center
				var tr_offset = Vector2(used_rect.end.x, used_rect.position.y) - texture_center
				var br_offset = used_rect.end - texture_center
				var bl_offset = Vector2(used_rect.position.x, used_rect.end.y) - texture_center
				var center_pos = pos + offset + single_correction_offset
				if data.get("is_tileset", false):
					center_pos = pos + offset + (full_size / 2.0)
				else:
					center_pos = pos + offset + single_correction_offset
				var p_tl = center_pos + (tl_offset * s_scale)
				var p_tr = center_pos + (tr_offset * s_scale)
				var p_br = center_pos + (br_offset * s_scale)
				var p_bl = center_pos + (bl_offset * s_scale)
				var f_off = data.get("feet_offset", 0)
				p_bl.x += f_off
				p_br.x -= f_off
				q_points = [p_bl, p_br, p_tr, p_tl]
			var p_bl = q_points[0]
			var p_br = q_points[1]
			var p_tr = q_points[2]
			var p_tl = q_points[3]
			var height = p_bl.y - p_tl.y
			var sk = using_data[start_id + "dynamic_skew"]
			var skew_offset = -height * sk
			var s_tl = p_tl + Vector2(skew_offset, 0)
			var s_tr = p_tr + Vector2(skew_offset, 0)
			var elongation = using_data[start_id + "elongation"]
			var vec_l = s_tl - p_bl
			var vec_r = s_tr - p_br
			if typeof(elongation) == TYPE_VECTOR2:
				s_tl = p_bl + (vec_l * Vector2(1, elongation.y))
				s_tr = p_br + (vec_r * Vector2(1, elongation.y))
			else:
				s_tl = p_bl + (vec_l * elongation)
				s_tr = p_br + (vec_r * elongation)
			var final_h = p_bl.y - s_tl.y
			var final_skew = -final_h * sk
			s_tl.x = p_tl.x + final_skew
			s_tr.x = p_tr.x + final_skew
			var base_shadow_points = PackedVector2Array([s_tl, s_tr, p_br, p_bl])
			var base_y = p_bl.y
			var alpha_depth = _encode_y_position_as_alpha(base_y, screen_height)
			var color = Color(alpha_depth, obj_alpha, 1.0, 1.0)
			var colors = PackedColorArray([color, color, color, color])
			var uvs = PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
			var mask_nudge = Vector2(1, -2)
			var m_offset = data.get("mask_offset", Vector2.ZERO)
			var base_mask_points: PackedVector2Array
			var mask_tex: Texture = st
			var mask_uvs: PackedVector2Array = uvs
			if data.has("mask_points"):
				base_mask_points = data.mask_points
				if data.has("mask_texture"):
					mask_tex = data.mask_texture
				if data.has("mask_uvs"):
					mask_uvs = data.mask_uvs
			else:
				base_mask_points = PackedVector2Array([
					q_points[3] + mask_nudge + m_offset,
					q_points[2] - mask_nudge + m_offset,
					q_points[1] + mask_nudge + m_offset,
					q_points[0] - mask_nudge + m_offset
				])
			for offset_vec in valid_offsets:
				var offset_shadow_points = PackedVector2Array()
				for p in base_shadow_points:
					offset_shadow_points.append(p + offset_vec)
				var offset_mask_points = PackedVector2Array()
				for p in base_mask_points:
					offset_mask_points.append(p + offset_vec)
				_rt.current_drawing_shadows.tiles.append({
					"main_texture": data.get("main_texture", null),
					"type": "polygon",
					"points": offset_shadow_points,
					"colors": colors,
					"uvs": uvs,
					"texture": st,
					"is_cropped": is_auto_cropped
				})
				_rt.current_drawing_shadows.masks.append({
					"main_texture": data.get("main_texture", null),
					"type": "polygon",
					"texture": mask_tex,
					"points": offset_mask_points,
					"uvs": mask_uvs,
					"color": Color.WHITE,
					"is_cropped": is_auto_cropped
				})
	_rt.current_drawing_shadows.tiles.sort_custom(func(a, b): return a.texture.get_rid().get_id() < b.texture.get_rid().get_id())
	_rt.current_drawing_shadows.masks.sort_custom(func(a, b): return a.texture.get_rid().get_id() < b.texture.get_rid().get_id())


func _on_canvas1_draw():
	for tile in _rt.current_drawing_shadows.tiles:
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
			var uvs = tile.uvs
			if tile.get("is_cropped", false):
				var rect = _get_smart_used_rect(tile.texture)
				uvs = _get_uvs_from_rect(rect, tile.texture.get_size())
			_draw_safe_polygon(%Canvas1, tile.points, tile.colors, uvs, tile.texture)
	%Canvas1.get_parent().get_parent().render_target_update_mode = SubViewport.UPDATE_ONCE


func _on_canvas2_draw():
	for mask in _rt.current_drawing_shadows.masks:
		if "main_texture" in mask and mask.main_texture and (
			not is_instance_valid(mask.main_texture) or
			mask.main_texture.has_meta("_disable_shadow")
		):
			continue
		if not is_instance_valid(mask.texture):
			continue
		if mask.get("type") == "polygon":
			var colors = PackedColorArray([mask.color, mask.color, mask.color, mask.color])
			var uvs = mask.uvs
			if mask.get("is_cropped", false):
				var rect = _get_smart_used_rect(mask.texture)
				uvs = _get_uvs_from_rect(rect, mask.texture.get_size())
			_draw_safe_polygon(%Canvas2, mask.points, colors, uvs, mask.texture)
		else:
			var sprite_scale = mask.sprite_scale
			var texture = mask.texture
			var pos = mask.position - texture.get_size() * 0.5 * sprite_scale
			if "region" in mask:
				var texture_size = mask.region.size
				%Canvas2.draw_texture_rect_region(texture, Rect2(pos, texture_size * sprite_scale), mask.region, mask.color)
			else:
				var texture_size = texture.get_size()
				%Canvas2.draw_texture_rect(texture, Rect2(pos, texture_size * sprite_scale), false, mask.color)
	%Canvas2.get_parent().get_parent().render_target_update_mode = SubViewport.UPDATE_ONCE
