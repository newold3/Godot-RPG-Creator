@tool
class_name ShadowOrquestator
extends Node2D


class ShadowRuntimeData:
	var visible_rect_cache: Dictionary = {}
	var frame_polygon_cache: Dictionary = {}
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
const RESOLUTION_SCALE: float = 1.0

signal synchronized_cameras(final_position: Vector2)
signal refreshed_shadows()



func _ready() -> void:
	set_process(false)
	_rt = ShadowRuntimeData.new()
	%Canvas1.scale = Vector2(RESOLUTION_SCALE, RESOLUTION_SCALE)
	%Canvas2.scale = Vector2(RESOLUTION_SCALE, RESOLUTION_SCALE)
	%Canvas1.position = Vector2.ZERO
	%Canvas2.position = Vector2.ZERO
	var viewport_size = get_viewport().size
	%ShadowSubViewport.size = viewport_size * RESOLUTION_SCALE
	%MaskSubViewport.size = viewport_size * RESOLUTION_SCALE
	%ShadowFinalMix.size = viewport_size * RESOLUTION_SCALE
	%ShadowFinal.size = viewport_size * RESOLUTION_SCALE
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
		var viewport_rect = get_viewport_rect().size
		var adjusted_position = camera_center - (viewport_rect * 0.5 / camera_zoom)
		%Shadows.global_position = adjusted_position
		synchronized_cameras.emit(adjusted_position)



func clear_map_repeating() -> void:
	pass



func enable_map_repeating(_repeat_times: int = 2) -> void:
	pass



func set_current_map_rect(rect: Rect2) -> void:
	if rect != null:
		current_map_rect = rect
	else:
		current_map_rect = Rect2()
	set_viewport_size()



func set_viewport_size() -> void:
	var viewport_size = get_viewport_rect().size
	var camera_zoom = GameManager.get_camera_zoom()
	viewport_size /= camera_zoom
	%ShadowSubViewport.size = viewport_size * RESOLUTION_SCALE
	%MaskSubViewport.size = viewport_size * RESOLUTION_SCALE
	%ShadowFinalMix.size = viewport_size * RESOLUTION_SCALE
	%ShadowFinal.size = viewport_size * RESOLUTION_SCALE



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
	var camera_center = main_camera.get_screen_center_position()
	var camera_zoom = main_camera.zoom
	var viewport_size = get_viewport_rect().size
	var visible_area = Rect2()
	visible_area.size = Vector2(viewport_size) / camera_zoom
	visible_area.position = camera_center - (visible_area.size * 0.5)
	visible_area = visible_area.grow(margin)
	return visible_area



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
	refreshed_shadows.emit()



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
	_rt.frame_polygon_cache.clear()

	var current_map: RPGMap = in_editor_map if in_editor_map else GameManager.current_map

	if not current_map:
		return
		
	var day_night_data = DayNightManager.get_data()
	var using_data = day_night_data
	var start_id = "shadow_" if using_data == day_night_data else ""

	if not using_data or (not GameManager.current_player and not in_editor_map):
		return
		
	var mat: ShaderMaterial = %ShadowLayer.get_material()
	var visibility := 1.0

	if using_data is RPGDayNightComponent:
		visibility = _get_shadow_visibility(using_data)
		
	var shadow_color = RPGSYSTEM.database.system.day_night_config.shadow_color
	shadow_color.a *= visibility
	mat.set_shader_parameter("overlay_color", shadow_color)

	var sk_val = using_data.get(start_id + "dynamic_skew")
	var sk = float(sk_val)
	var sun_vec = Vector2(sk, 1.0).normalized()
	mat.set_shader_parameter("shadow_direction", sun_vec)

	var map_size_px: Vector2 = Vector2.ZERO

	if "map_size" in current_map:
		if typeof(current_map.map_size) == TYPE_VECTOR2 or typeof(current_map.map_size) == TYPE_VECTOR2I:
			map_size_px = Vector2(current_map.map_size)
			
	if map_size_px == Vector2.ZERO and current_map.has_method("get_used_rect"):
		var used_rect_i = current_map.get_used_rect(false)
		map_size_px = Vector2(used_rect_i.size)
		
	var screen_height = float(map_size_px.y)

	if screen_height <= 0 or screen_height < get_viewport_rect().size.y:
		screen_height = get_viewport_rect().size.y
		
	var camera_top_left: Vector2 = Vector2.ZERO
	var main_camera: Camera2D

	if Engine.is_editor_hint():
		main_camera = get_viewport().get_camera_2d()
	else:
		main_camera = GameManager.get_camera()
		
	if main_camera:
		var camera_center = main_camera.get_screen_center_position()
		var camera_zoom = main_camera.zoom
		var viewport_size = get_viewport_rect().size
		camera_top_left = camera_center - (Vector2(viewport_size) * 0.5 / camera_zoom)
	elif in_editor_map:
		var viewport_transform = get_viewport().get_final_transform()
		var inverse_transform = viewport_transform.affine_inverse()
		camera_top_left = inverse_transform * Vector2.ZERO
		
	var screen_rect = get_visible_area_with_margin(EXTRA_MARGIN)
	var global_elongation = using_data.get(start_id + "elongation")

	var view_rects: Array[Dictionary] = []
	view_rects.append({"rect": screen_rect, "offset": Vector2.ZERO})

	var x_offs = [0]
	if current_map.infinite_horizontal_scroll and map_size_px.x > 0:
		x_offs.append_array([-map_size_px.x, map_size_px.x])
		
	var y_offs = [0]
	if current_map.infinite_vertical_scroll and map_size_px.y > 0:
		y_offs.append_array([-map_size_px.y, map_size_px.y])
		
	for ox in x_offs:
		for oy in y_offs:
			if ox == 0 and oy == 0:
				continue
			var off_vec = Vector2(ox, oy)
			var shifted = Rect2(screen_rect.position + off_vec, screen_rect.size)
			view_rects.append({"rect": shifted, "offset": off_vec})
			
	for data: Dictionary in shadow_data:
		if not data.get("is_new_system", false):
			continue
			
		var textures: Array = data.get("textures", [])
		var positions: Array = data.get("positions", [])
		var regions: Array = data.get("regions", [])
		var feet_offsets: Array = data.get("feet_offsets", [])
		var mask_offsets: Array = data.get("mask_offsets", [])
		var item_alpha: float = data.get("alpha", 1.0)
		var item_scale: Vector2 = data.get("scale", Vector2.ONE)
		var item_rotation: float = data.get("rotation", 0.0)
		var is_flipped: bool = data.get("flip_h", false)
		var item_elongation = data.get("elongation", global_elongation)
		
		for i in range(textures.size()):
			var tex: Texture = textures[i]
			
			if not is_instance_valid(tex): 
				continue
				
			var base_pos: Vector2 = positions[i] if i < positions.size() else Vector2.ZERO
			
			for v_rect in view_rects:
				if not v_rect.rect.has_point(base_pos):
					continue
					
				var draw_pos_world = base_pos - v_rect.offset
				var region: Rect2 = regions[i] if i < regions.size() else Rect2(Vector2.ZERO, tex.get_size())
				var w_half = region.size.x / 2.0
				var h_half = region.size.y / 2.0
				var f_data = feet_offsets[i] if i < feet_offsets.size() else h_half
				var m_offset: Vector2 = mask_offsets[i] if i < mask_offsets.size() else Vector2.ZERO
				var cache_key = [tex.get_rid(), region, item_scale, item_rotation, is_flipped, f_data, m_offset]
				
				var local_shadow_points: PackedVector2Array
				var local_mask_points: PackedVector2Array
				var mask_uvs: PackedVector2Array
				var shadow_uvs: PackedVector2Array
				var local_feet_y: float
				
				var cached_data = _rt.frame_polygon_cache.get(cache_key)
				
				if cached_data:
					local_shadow_points = cached_data.shadow
					local_mask_points = cached_data.mask
					mask_uvs = cached_data.mask_uvs
					shadow_uvs = cached_data.shadow_uvs
					local_feet_y = cached_data.feet_y
				else:
					var inset_l: float = 0.0
					var inset_r: float = 0.0
					local_feet_y = h_half
					
					if typeof(f_data) == TYPE_ARRAY or typeof(f_data) == TYPE_PACKED_FLOAT32_ARRAY:
						if f_data.size() >= 3:
							inset_l = float(f_data[0]) 
							inset_r = float(f_data[1]) 
							local_feet_y = float(f_data[2])
						elif f_data.size() >= 2:
							inset_l = float(f_data[0]) 
							inset_r = float(f_data[1])
						elif f_data.size() >= 1:
							local_feet_y = float(f_data[0])
					elif typeof(f_data) == TYPE_VECTOR3:
						inset_l = f_data.x 
						inset_r = f_data.y 
						local_feet_y = f_data.z
					else:
						local_feet_y = float(f_data)
						
					if is_flipped:
						var temp = inset_l 
						inset_l = inset_r 
						inset_r = temp
						
					var local_mask_points_base = [Vector2(-w_half, -h_half), Vector2(w_half, -h_half), Vector2(w_half, h_half), Vector2(-w_half, h_half)]
					var local_shadow_points_base = [Vector2(-w_half, -h_half), Vector2(w_half, -h_half), Vector2(w_half - inset_r, local_feet_y), Vector2(-w_half + inset_l, local_feet_y)]
					var base_uvs = _get_uvs_from_rect(region, tex.get_size())
					
					if is_flipped: 
						base_uvs = PackedVector2Array([base_uvs[1], base_uvs[0], base_uvs[3], base_uvs[2]])
						
					mask_uvs = base_uvs.duplicate()
					shadow_uvs = base_uvs.duplicate()
					var crop_fraction = clamp((local_feet_y + h_half) / max(0.001, h_half * 2.0), 0.0, 1.0)
					var uv_y_min = mask_uvs[0].y
					var uv_y_max = mask_uvs[2].y
					var new_uv_y = uv_y_min + (uv_y_max - uv_y_min) * crop_fraction
					shadow_uvs[2] = Vector2(shadow_uvs[2].x, new_uv_y)
					shadow_uvs[3] = Vector2(shadow_uvs[3].x, new_uv_y)
					
					var elong_y = float(item_elongation.y) if typeof(item_elongation) == TYPE_VECTOR2 else float(item_elongation)
					local_shadow_points = PackedVector2Array()
					
					for j in range(local_shadow_points_base.size()):
						var p = local_shadow_points_base[j] + m_offset
						var trans_p = (p * item_scale).rotated(item_rotation)
						var anchor_p = ((Vector2(0.0, local_feet_y) + m_offset) * item_scale).rotated(item_rotation)
						var diff_y = anchor_p.y - trans_p.y
						trans_p.y = anchor_p.y - (diff_y * elong_y)
						trans_p.x += (diff_y * elong_y) * sk
						local_shadow_points.append(trans_p)
						
					local_mask_points = PackedVector2Array()
					var mask_nudge = Vector2(1, -2)
					
					for j in range(local_mask_points_base.size()):
						local_mask_points.append(((local_mask_points_base[j] + m_offset) * item_scale).rotated(item_rotation) + mask_nudge)
						
					_rt.frame_polygon_cache[cache_key] = {"shadow": local_shadow_points, "mask": local_mask_points, "mask_uvs": mask_uvs, "shadow_uvs": shadow_uvs, "feet_y": local_feet_y}
					
				var alpha_depth = _encode_y_position_as_alpha(draw_pos_world.y, screen_height)
				var f_color = Color(alpha_depth, item_alpha, 1.0, 0.1)
				var final_colors = PackedColorArray([f_color, f_color, f_color, f_color])
				var screen_local_pos = draw_pos_world - camera_top_left
				var off_shadow = PackedVector2Array()
				
				for j in local_shadow_points.size(): 
					off_shadow.append(local_shadow_points[j] + screen_local_pos)
					
				var off_mask = PackedVector2Array()
				
				for j in local_mask_points.size(): 
					off_mask.append(local_mask_points[j] + screen_local_pos)
					
				var sort_base_y = draw_pos_world.y + local_feet_y
				
				_rt.current_drawing_shadows.tiles.append({"type": "polygon", "points": off_shadow, "colors": final_colors, "uvs": shadow_uvs, "texture": tex, "sort_y": sort_base_y})
				_rt.current_drawing_shadows.masks.append({"type": "polygon", "points": off_mask, "uvs": mask_uvs, "color": Color.WHITE, "texture": tex, "sort_y": sort_base_y})
				
	_rt.current_drawing_shadows.tiles.sort_custom(func(a, b): return a.sort_y < b.sort_y)
	_rt.current_drawing_shadows.masks.sort_custom(func(a, b): return a.sort_y < b.sort_y)




func _on_canvas1_draw():
	for tile in _rt.current_drawing_shadows.tiles:
		if not is_instance_valid(tile.texture): continue
		_draw_safe_polygon(%Canvas1, tile.points, tile.colors, tile.uvs, tile.texture)
	#var debug_size = get_viewport_rect().size
	#var main_camera: Camera2D = GameManager.get_camera()
	#if main_camera:
		#debug_size = get_viewport_rect().size / main_camera.zoom
	#var debug_rect = Rect2(Vector2.ZERO, debug_size)
	#%Canvas1.draw_rect(debug_rect, Color.RED, false, 5.0)
	#%Canvas1.get_parent().render_target_update_mode = SubViewport.UPDATE_ONCE



func _on_canvas2_draw():
	for mask in _rt.current_drawing_shadows.masks:
		if not is_instance_valid(mask.texture): continue
		var colors = PackedColorArray([mask.color, mask.color, mask.color, mask.color])
		_draw_safe_polygon(%Canvas2, mask.points, colors, mask.uvs, mask.texture)
	%Canvas2.get_parent().render_target_update_mode = SubViewport.UPDATE_ONCE



func get_texture() -> ViewportTexture:
	return %ShadowFinal.get_texture()
