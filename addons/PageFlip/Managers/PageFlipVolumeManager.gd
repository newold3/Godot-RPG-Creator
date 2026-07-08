class_name PageFlipVolumeManager extends RefCounted

## Reference to the main book node.
var book: Node2D


## Initializes the volume manager.
func _init(book_node: Node2D) -> void:
	book = book_node


#region Fake 3D Volume Management
## Generates the simulated 3D volume layers under the book.
func generate_volume_layers() -> void:
	if book._volume_root and is_instance_valid(book._volume_root):
		book._volume_root.queue_free()
		
	var final_layer_count = 0
	
	if book.total_spreads > 0:
		final_layer_count = clampi(book.total_spreads, book.min_layers, book.max_layers)
		
	if final_layer_count <= 0:
		return
		
	book._volume_root = Node2D.new()
	book._volume_root.name = "VolumeStackPages"
	book._volume_root.z_index = 0
	book.visuals_container.add_child(book._volume_root)
	book.visuals_container.move_child(book._volume_root, 0)
	
	var vol_spine = Polygon2D.new()
	vol_spine.name = "VolumeSpine"
	vol_spine.color = book.spine_color.darkened(0.8)
	vol_spine.z_index = -1
	
	book.volume_spine = vol_spine
	
	if book.spine_texture:
		vol_spine.texture = book.spine_texture
		
	if book.perspective_shader:
		vol_spine.material = ShaderMaterial.new()
		vol_spine.material.shader = book.perspective_shader
		
	book._volume_root.add_child(vol_spine)
	
	var spine_cap = Polygon2D.new()
	spine_cap.name = "SpineBottomCap"
	spine_cap.color = book.spine_color.darkened(0.65) # Darkened cover color
	spine_cap.z_index = -1
	if book.spine_texture:
		spine_cap.texture = book.spine_texture
	if book.perspective_shader:
		spine_cap.material = ShaderMaterial.new()
		spine_cap.material.shader = book.perspective_shader
	book._volume_root.add_child(spine_cap)
	
	for i in range(final_layer_count):
		var layer_node = Node2D.new()
		layer_node.name = "Layer_%d" % i
		
		var s_left = book.static_left.duplicate()
		var s_right = book.static_right.duplicate()
		
		var lerp_factor = 1.0
		
		if final_layer_count > 1 and book.covers_are_rigid:
			lerp_factor = float(i) / float(final_layer_count - 1)
			
		if i == 0 and book.covers_are_rigid:
			s_left.polygons = []
			s_left.polygon = book._poly_flat
			s_left.uv = book._grid_uvs
			s_left.vertex_colors = book._colors_flat
			s_left.polygons = book._grid_polys
			
			s_right.polygons = []
			s_right.polygon = book._poly_flat
			s_right.uv = book._grid_uvs
			s_right.vertex_colors = book._colors_flat
			s_right.polygons = book._grid_polys
			
			s_left.modulate = book.cover_protrude_color
			s_right.modulate = book.cover_protrude_color
			s_left.scale = book.cover_protrude_scale
			s_right.scale = book.cover_protrude_scale
			
			book._fake_volume_layer0 = layer_node
		else:
			s_left.polygons = []
			s_left.polygon = book._poly_curved_l
			s_left.uv = book._grid_uvs
			s_left.vertex_colors = book._colors_curved_l
			s_left.polygons = book._grid_polys
			
			s_right.polygons = []
			s_right.polygon = book._poly_curved_r
			s_right.uv = book._grid_uvs
			s_right.vertex_colors = book._colors_curved_r
			s_right.polygons = book._grid_polys
			
			var layer_col = book.volume_color
			
			if i % 2 != 0:
				layer_col.r *= book.stripe_darken_ratio
				layer_col.g *= book.stripe_darken_ratio
				layer_col.b *= book.stripe_darken_ratio
				
			s_left.modulate = layer_col
			s_right.modulate = layer_col
			
		s_left.position = Vector2.ZERO
		s_right.position = Vector2.ZERO
		
		s_left.set_script(null)
		s_right.set_script(null)
		
		s_left.texture = book.left_blank_page_texture if book.left_blank_page_texture else null
		s_right.texture = book.right_blank_page_texture if book.right_blank_page_texture else null
		
		if book.perspective_shader:
			s_left.material = ShaderMaterial.new()
			s_left.material.shader = book.perspective_shader
			s_right.material = ShaderMaterial.new()
			s_right.material.shader = book.perspective_shader
			
		layer_node.add_child(s_left)
		layer_node.add_child(s_right)
		
		book._volume_root.add_child(layer_node)


## Calculates floating-point fractional layer count for smooth spine tweening.
func get_layer_count_for_spread_float(spread_idx: float, total_layers: int) -> float:
	if book.total_spreads <= 1:
		return 0.0
		
	var ratio = clampf(spread_idx / float(book.total_spreads - 1), 0.0, 1.0)
	
	return ratio * float(total_layers)


## Calculates how many volume layers should be drawn for a specific spread.
func get_layer_count_for_spread(spread_idx: float, total_layers: int) -> int:
	return int(round(get_layer_count_for_spread_float(spread_idx, total_layers)))


## Helper wrapper for tweening the volume expansion factor.
func tween_expansion_only(factor: float) -> void:
	update_stack_direct(factor, book._visual_spread_index)


## Updates the position of the volume root visually.
func update_volume_visuals() -> void:
	if not book._volume_root:
		return
		
	book._volume_root.position = book.volume_stack_offset


## Updates the visual stack volume rendering and positions.
func update_stack_direct(expansion_factor: float, visual_spread: float) -> void:
	book._current_expansion_factor = expansion_factor
	book._visual_spread_index = visual_spread
	
	book._update_perspective(expansion_factor)
	
	if not book._volume_root:
		return
		
	var current_step = book.layer_offset_open.lerp(book.layer_offset_closed, expansion_factor)
	var total_layers = 0
	
	for child in book._volume_root.get_children():
		if child.name.begins_with("Layer_"):
			total_layers += 1
			
	var y_dir = -1.0 if book.invert_stack_direction else 1.0
	var count_left = 0
	var count_right = 0
	
	if book.is_animating:
		var layers_at_start = 0
		var layers_at_target = 0
		
		if book.total_spreads > 1:
			layers_at_start = int(round(get_layer_count_for_spread_float(float(book.current_spread), total_layers)))
			layers_at_target = int(round(get_layer_count_for_spread_float(float(book._pending_target_spread_idx), total_layers)))
			
		if book.going_forward:
			count_left = layers_at_start
			count_right = (total_layers - layers_at_target) if book.total_spreads > 1 else 0
		else:
			count_left = layers_at_target
			count_right = (total_layers - layers_at_start) if book.total_spreads > 1 else 0
			
		var L_start_is_thin = (layers_at_start == 0)
		var L_target_is_thin = (layers_at_target == 0)
		
		if L_start_is_thin != L_target_is_thin:
			if L_target_is_thin:
				count_left = 0
			else:
				count_left = max(layers_at_start, layers_at_target)
				
		var R_start_vol = (total_layers - layers_at_start) if book.total_spreads > 1 else 0
		var R_target_vol = (total_layers - layers_at_target) if book.total_spreads > 1 else 0
		var R_start_is_thin = (R_start_vol == 0)
		var R_target_is_thin = (R_target_vol == 0)
		
		if R_start_is_thin != R_target_is_thin:
			if R_target_is_thin:
				count_right = 0
			else:
				count_right = max(R_start_vol, R_target_vol)
	else:
		if book.total_spreads > 1:
			count_left = int(round(get_layer_count_for_spread_float(visual_spread, total_layers)))
			count_right = total_layers - count_left
		else:
			count_left = 0
			count_right = 0
			
	var force_hide_left = false
	var force_hide_right = false
	
	if book._stack_scale_left <= 0.001:
		force_hide_left = true
	if book._stack_scale_right <= 0.001:
		force_hide_right = true
	if book._force_hide_vol_left:
		force_hide_left = true
	if book._force_hide_vol_right:
		force_hide_right = true
		
	var base_s_x = 1.0
	var base_s_y = 1.0
	
	if book.inner_page_margin != Vector2.ZERO:
		base_s_x = max(0.001, (book.page_width - book.inner_page_margin.x) / book.page_width)
		base_s_y = max(0.001, (book.target_page_size.y - (book.inner_page_margin.y * 2.0)) / book.target_page_size.y)
		
	var active_s_x = lerp(base_s_x, 1.0, expansion_factor)
	var active_s_y = lerp(base_s_y, 1.0, expansion_factor)
	
	var vol_spine = book._volume_root.get_node_or_null("VolumeSpine")
	var target_w = book.page_width * active_s_x
	
	var left_depth_float = 0.0
	var right_depth_float = 0.0
	
	if book.total_spreads > 1:
		left_depth_float = get_layer_count_for_spread_float(book._visual_spread_index, total_layers)
		right_depth_float = float(total_layers) - left_depth_float
		
	var current_curve_factor = book._get_curve_factor_for_spread(visual_spread)
	var current_offset_y = book.inner_page_vertical_offset * current_curve_factor
	
	if vol_spine and total_layers > 0:
		var left_inner_x = current_step.x * left_depth_float * expansion_factor
		var left_base_off_y = current_step.y * left_depth_float * y_dir
		var bot_off_left = Vector2(-left_inner_x, left_base_off_y) * book._stack_scale_left
		
		var right_inner_x = current_step.x * right_depth_float * expansion_factor
		var right_base_off_y = current_step.y * right_depth_float * y_dir
		var bot_off_right = Vector2(right_inner_x, right_base_off_y) * book._stack_scale_right
		
		var effective_left_depth = left_depth_float if not force_hide_left else 0.0
		var effective_right_depth = right_depth_float if not force_hide_right else 0.0
		var mid_depth_float = max(effective_left_depth, effective_right_depth)
		
		var mid_depth_scale = (book._stack_scale_left + book._stack_scale_right) / 2.0
		var mid_base_off_y = current_step.y * mid_depth_float * y_dir
		var bot_off_mid = Vector2(0.0, mid_base_off_y) * mid_depth_scale
				
		var margin_y = 2.0 * y_dir
		
		if left_depth_float > 0.01:
			bot_off_left.y += margin_y * book._stack_scale_left
		if right_depth_float > 0.01:
			bot_off_right.y += margin_y * book._stack_scale_right
		if mid_depth_scale > 0.01:
			bot_off_mid.y += margin_y * mid_depth_scale
			
		var current_w_l = target_w + (left_inner_x * book._stack_scale_left)
		var scale_x_l = current_w_l / book.page_width if book.page_width > 0 else 1.0
		var current_w_r = target_w + (right_inner_x * book._stack_scale_right)
		var scale_x_r = current_w_r / book.page_width if book.page_width > 0 else 1.0
		
		var st_sh_l = book.visuals_container.get_node_or_null("StackDropShadowLeft")
		if st_sh_l:
			st_sh_l.scale = Vector2(scale_x_l, 1.0)
			st_sh_l.position = Vector2(-current_w_l, current_offset_y) + bot_off_left
			st_sh_l.modulate.a = book._stack_scale_left
			st_sh_l.visible = not force_hide_left
			
		var st_sh_r = book.visuals_container.get_node_or_null("StackDropShadowRight")
		if st_sh_r:
			st_sh_r.scale = Vector2(scale_x_r, 1.0)
			st_sh_r.position = Vector2(0, current_offset_y) + bot_off_right
			st_sh_r.modulate.a = book._stack_scale_right
			st_sh_r.visible = not force_hide_right
			
		var margin = 2.0
		var hw = (book.spine_width / 2.0) + margin
		var pinched_h = book.target_page_size.y - (book.spine_curl_intensity * 2.0)
		var h_scaled = pinched_h * active_s_y + (margin * 2.0)
		
		var p0 = Vector2(-hw, -h_scaled / 2.0 + current_offset_y)
		var p_top_mid = Vector2(0, -h_scaled / 2.0 + current_offset_y)
		var p1 = Vector2(hw, -h_scaled / 2.0 + current_offset_y)
		
		var p3 = Vector2(-hw, h_scaled / 2.0 + current_offset_y)
		var p_bot_mid = Vector2(0, h_scaled / 2.0 + current_offset_y)
		var p2 = Vector2(hw, h_scaled / 2.0 + current_offset_y)
		
		var uniform_bot_off = bot_off_left + bot_off_right
		var final_bot_off_left = Vector2(bot_off_left.x, lerp(bot_off_left.y, uniform_bot_off.y, expansion_factor))
		var final_bot_off_right = Vector2(bot_off_right.x, lerp(bot_off_right.y, uniform_bot_off.y, expansion_factor))
		var final_bot_off_mid = Vector2(bot_off_mid.x, lerp(bot_off_mid.y, uniform_bot_off.y, expansion_factor))
		
		var p4 = p0 + final_bot_off_left
		var p_deep_top_mid = p_top_mid + final_bot_off_mid
		var p_deep_bot_mid = p_bot_mid + final_bot_off_mid
		var p7 = p3 + final_bot_off_left
		
		var p5 = p1 + final_bot_off_right
		var p6 = p2 + final_bot_off_right
		
		var tw = 1.0
		var th = 1.0
		if book.spine_texture:
			tw = float(book.spine_texture.get_width())
			th = float(book.spine_texture.get_height())
		var slice = 1.0
		
		var sp_sh = book.visuals_container.get_node_or_null("SpineDropShadow")
		if sp_sh:
			var sh_off_lx = - book.stack_shadow_offset.x * scale_x_l
			var sh_off_rx = book.stack_shadow_offset.x * scale_x_r
			
			var sp_left_x = lerp(-hw - book.stack_shadow_offset.x, sh_off_lx, book._stack_scale_left)
			var sp_right_x = lerp(hw + book.stack_shadow_offset.x, sh_off_rx, book._stack_scale_right)
			
			var sp_top_y = - h_scaled / 2.0 + current_offset_y + book.stack_shadow_offset.y
			var sp_bot_y = h_scaled / 2.0 + current_offset_y + book.stack_shadow_offset.y
			
			var sp_sh_pts = PackedVector2Array([
				Vector2(sp_left_x, sp_top_y),
				Vector2(sp_right_x, sp_top_y),
				Vector2(sp_right_x, sp_bot_y + final_bot_off_right.y),
				Vector2(sp_left_x, sp_bot_y + final_bot_off_left.y)
			])
			
			sp_sh.polygon = sp_sh_pts
			sp_sh.position = book.volume_stack_offset
			sp_sh.color = Color(0, 0, 0, 0.45)
			sp_sh.z_index = -3
		
		var spine_cap = book._volume_root.get_node_or_null("SpineBottomCap")
		if spine_cap:
			var cap_pts = PackedVector2Array()
			var cap_uvs = PackedVector2Array()
			var cap_faces = []
			
			var shift_x = 15.0
			var cap_p3 = p3 + Vector2(shift_x, 0.0)
			var cap_p7 = p7 + Vector2(shift_x, 0.0)
			
			var N = 12
			for i in range(N + 1):
				var t = float(i) / N
				cap_pts.append(cap_p3.lerp(cap_p7, t))
				cap_uvs.append(Vector2(lerp(0.0, slice, t), th))
				
			var dir = (cap_p7 - cap_p3).normalized()
			var perp = Vector2(-dir.y, dir.x)
			var bulge_amount = book.spine_width * 0.45 * expansion_factor
			
			for i in range(N + 1):
				var t = float(i) / N
				var pt_line = cap_p3.lerp(cap_p7, t)
				var factor = lerp(0.2, 1.0, cos(t * PI / 2.0)) + 0.25 * sin(t * PI)
				var pt_arc = pt_line + perp * bulge_amount * factor
				cap_pts.append(pt_arc)
				cap_uvs.append(Vector2(lerp(0.0, slice, t), th))
				
			for i in range(N):
				var idx0 = i
				var idx1 = i + 1
				var idx2 = N + 1 + i
				var idx3 = N + 1 + i + 1
				cap_faces.append(PackedInt32Array([idx0, idx1, idx3]))
				cap_faces.append(PackedInt32Array([idx0, idx3, idx2]))
				
			spine_cap.polygon = cap_pts
			spine_cap.uv = cap_uvs
			spine_cap.polygons = cap_faces
			spine_cap.position = Vector2.ZERO
			spine_cap.color = book.spine_color.darkened(0.65)
			if book.spine_texture:
				spine_cap.texture = book.spine_texture
		
		var pts = PackedVector2Array()
		var uvs = PackedVector2Array()
		var faces = []
		var face_idx = 0
		var mid_u = tw / 2.0
		
		pts.append_array([p4, p_deep_top_mid, p_top_mid, p0])
		uvs.append_array([Vector2(0, slice), Vector2(mid_u, slice), Vector2(mid_u, 0), Vector2(0, 0)])
		faces.append(PackedInt32Array([face_idx * 4, face_idx * 4 + 1, face_idx * 4 + 2, face_idx * 4 + 3]))
		face_idx += 1
		
		pts.append_array([p_deep_top_mid, p5, p1, p_top_mid])
		uvs.append_array([Vector2(mid_u, slice), Vector2(tw, slice), Vector2(tw, 0), Vector2(mid_u, 0)])
		faces.append(PackedInt32Array([face_idx * 4, face_idx * 4 + 1, face_idx * 4 + 2, face_idx * 4 + 3]))
		face_idx += 1
		
		pts.append_array([p3, p_bot_mid, p_deep_bot_mid, p7])
		uvs.append_array([Vector2(0, th), Vector2(mid_u, th), Vector2(mid_u, th - slice), Vector2(0, th - slice)])
		faces.append(PackedInt32Array([face_idx * 4, face_idx * 4 + 1, face_idx * 4 + 2, face_idx * 4 + 3]))
		face_idx += 1
		
		pts.append_array([p_bot_mid, p2, p6, p_deep_bot_mid])
		uvs.append_array([Vector2(mid_u, th), Vector2(tw, th), Vector2(tw, th - slice), Vector2(mid_u, th - slice)])
		faces.append(PackedInt32Array([face_idx * 4, face_idx * 4 + 1, face_idx * 4 + 2, face_idx * 4 + 3]))
		face_idx += 1
		
		pts.append_array([p4, p0, p3, p7])
		uvs.append_array([Vector2(slice, 0), Vector2(0, 0), Vector2(0, th), Vector2(slice, th)])
		faces.append(PackedInt32Array([face_idx * 4, face_idx * 4 + 1, face_idx * 4 + 2, face_idx * 4 + 3]))
		face_idx += 1
		
		pts.append_array([p1, p5, p6, p2])
		uvs.append_array([Vector2(tw, 0), Vector2(tw - slice, 0), Vector2(tw - slice, th), Vector2(tw, th)])
		faces.append(PackedInt32Array([face_idx * 4, face_idx * 4 + 1, face_idx * 4 + 2, face_idx * 4 + 3]))
		face_idx += 1
		
		pts.append_array([p_deep_top_mid, p4, p7, p_deep_bot_mid])
		uvs.append_array([Vector2(mid_u, 0), Vector2(0, 0), Vector2(0, th), Vector2(mid_u, th)])
		faces.append(PackedInt32Array([face_idx * 4, face_idx * 4 + 1, face_idx * 4 + 2, face_idx * 4 + 3]))
		face_idx += 1
		
		pts.append_array([p5, p_deep_top_mid, p_deep_bot_mid, p6])
		uvs.append_array([Vector2(tw, 0), Vector2(mid_u, 0), Vector2(mid_u, th), Vector2(tw, th)])
		faces.append(PackedInt32Array([face_idx * 4, face_idx * 4 + 1, face_idx * 4 + 2, face_idx * 4 + 3]))
		face_idx += 1
		
		vol_spine.polygon = pts
		vol_spine.uv = uvs
		vol_spine.polygons = faces
		
		var runtime_spine = book.visuals_container.get_node_or_null("RuntimeSpine")
		if runtime_spine:
			var rs_hw = book.spine_width / 2.0 + 4.0
			var rs_h = book.target_page_size.y
			var rs_cover_h = rs_h * book.cover_protrude_scale.y if book.covers_are_rigid else rs_h
			var rs_offset_y = book.cover_protrude_offset.y if book.covers_are_rigid else 0.0
			var rs_top_y = - rs_cover_h / 2.0 + rs_offset_y
			var rs_bot_y = rs_cover_h / 2.0 + rs_offset_y
			
			var rs_p0 = Vector2(-rs_hw, rs_top_y)
			var rs_p1 = Vector2(rs_hw, rs_top_y)
			var rs_p2 = Vector2(rs_hw, rs_bot_y) + final_bot_off_right * expansion_factor
			var rs_p3 = Vector2(-rs_hw, rs_bot_y) + final_bot_off_left * expansion_factor
			
			runtime_spine.polygon = PackedVector2Array([rs_p0, rs_p1, rs_p2, rs_p3])
			runtime_spine.position = book.volume_stack_offset
			
			if book.spine_texture:
				tw = book.spine_texture.get_width()
				th = book.spine_texture.get_height()
				runtime_spine.uv = PackedVector2Array([Vector2(0, 0), Vector2(tw, 0), Vector2(tw, th), Vector2(0, th)])
		
	var left_threshold_idx = total_layers - count_left
	var right_threshold_idx = total_layers - count_right
	var current_layer_index = 0
	
	for child in book._volume_root.get_children():
		if not child.name.begins_with("Layer_"):
			continue
			
		var depth_multiplier = float(total_layers - current_layer_index)
		
		var base_off_x = current_step.x * depth_multiplier
		var base_off_y = (current_step.y * depth_multiplier) * y_dir
		
		child.position = Vector2.ZERO
		
		var l_node = child.get_child(0)
		var r_node = child.get_child(1)
		
		var final_off_x_left = base_off_x * book._stack_scale_left
		var final_off_x_right = base_off_x * book._stack_scale_right
		var final_off_y_left = base_off_y * book._stack_scale_left
		var final_off_y_right = base_off_y * book._stack_scale_right
		
		var is_cover_layer = (current_layer_index == 0 and book.covers_are_rigid)
		
		var show_l = (current_layer_index >= left_threshold_idx) or is_cover_layer
		var show_r = (current_layer_index >= right_threshold_idx) or is_cover_layer
		
		if force_hide_left:
			show_l = false
		if force_hide_right:
			show_r = false
			
		if total_layers > 1 and not is_cover_layer:
			var lerp_factor = 1.0
			
			if book.covers_are_rigid:
				lerp_factor = float(current_layer_index) / float(total_layers - 1)
				
			var final_layer_curve = lerp_factor * current_curve_factor
			var blended_poly_l = PackedVector2Array()
			var blended_poly_r = PackedVector2Array()
			var blended_col_l = PackedColorArray()
			var blended_col_r = PackedColorArray()
			
			if book._poly_flat.size() > 0 and book._poly_curved_l.size() > 0:
				for v_idx in range(book._poly_flat.size()):
					blended_poly_l.append(book._poly_flat[v_idx].lerp(book._poly_curved_l[v_idx], final_layer_curve))
					blended_poly_r.append(book._poly_flat[v_idx].lerp(book._poly_curved_r[v_idx], final_layer_curve))
					blended_col_l.append(book._colors_flat[v_idx].lerp(book._colors_curved_l[v_idx], final_layer_curve))
					blended_col_r.append(book._colors_flat[v_idx].lerp(book._colors_curved_r[v_idx], final_layer_curve))
					
				l_node.polygon = blended_poly_l
				r_node.polygon = blended_poly_r
				l_node.vertex_colors = blended_col_l
				r_node.vertex_colors = blended_col_r
				
		if is_cover_layer:
			final_off_x_left += book.cover_protrude_offset.x
			final_off_x_right += book.cover_protrude_offset.x
			final_off_y_left += book.cover_protrude_offset.y
			final_off_y_right += book.cover_protrude_offset.y
			
			if book.static_left:
				var target_cover_w = book.page_width * book.cover_protrude_scale.x
				var current_w_l = target_cover_w + final_off_x_left
				var scale_x_l = current_w_l / book.page_width
				l_node.scale = Vector2(scale_x_l, book.cover_protrude_scale.y)
				l_node.position.x = - current_w_l
				l_node.position.y = book.cover_protrude_offset.y + final_off_y_left
				l_node.visible = show_l
				
			if book.static_right:
				var target_cover_w = book.page_width * book.cover_protrude_scale.x
				var current_w_r = target_cover_w + final_off_x_right
				var scale_x_r = current_w_r / book.page_width
				r_node.scale = Vector2(scale_x_r, book.cover_protrude_scale.y)
				r_node.position.x = 0.0
				r_node.position.y = book.cover_protrude_offset.y + final_off_y_right
				r_node.visible = show_r
		else:
			if book.static_left:
				var current_w_l = target_w + final_off_x_left
				var scale_x_l = current_w_l / book.page_width
				l_node.scale = Vector2(scale_x_l, active_s_y)
				l_node.position.x = - current_w_l
				l_node.position.y = current_offset_y + final_off_y_left
				l_node.visible = show_l
				
			if book.static_right:
				var current_w_r = target_w + final_off_x_right
				var scale_x_r = current_w_r / book.page_width
				r_node.scale = Vector2(scale_x_r, active_s_y)
				r_node.position.x = 0.0
				r_node.position.y = current_offset_y + final_off_y_right
				r_node.visible = show_r
				
		current_layer_index += 1
#endregion
