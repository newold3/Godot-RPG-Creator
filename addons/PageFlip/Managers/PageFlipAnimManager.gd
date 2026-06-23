class_name PageFlipAnimManager extends RefCounted

## Reference to the main book node.
var book: Node2D


## Initializes the animation manager.
func _init(book_node: Node2D) -> void:
	book = book_node


#region Navigation
## Attempts to transition to the next page.
func next_page() -> void:
	if book.is_animating or book.current_spread >= book.total_spreads:
		return
	
	if book.limit_max_pages == -1 and book.current_spread >= book.total_spreads - 1:
		return
		
	var max_allowed_spread = book.total_spreads
	
	if book.limit_max_pages > 0:
		max_allowed_spread = (book.limit_max_pages - 1) / 2
		if max_allowed_spread > book.total_spreads:
			max_allowed_spread = book.total_spreads
			
	if book.limit_max_pages > 0 and book.current_spread >= max_allowed_spread:
		return
	
	if book.current_spread == -1 and book.front_cover_opens_to_page > 1:
		try_emit_book_signals("right")
		var safe_page = book.front_cover_opens_to_page
		
		if book.limit_max_pages > 0 and safe_page > book.limit_max_pages:
			safe_page = book.limit_max_pages
			
		book._auto_turn_target_spread = (safe_page - 1) / 2
		book._auto_turn_target_spread = clampi(book._auto_turn_target_spread, 0, book.total_spreads - 1)
		
		if book.anim_player:
			book.anim_player.speed_scale = 1.0
			
		start_animation(true)
		return

	try_emit_book_signals("right")
	start_animation(true)


## Attempts to transition to the previous page.
func prev_page() -> void:
	if book.is_animating or book.current_spread <= -1:
		return
	
	var target_open_spread = (book.front_cover_opens_to_page - 1) / 2
	
	if book.front_cover_opens_to_page > 1 and book.current_spread == target_open_spread:
		try_emit_book_signals("left")
		book._auto_turn_target_spread = -1
		
		if book.current_spread == 0:
			if book.anim_player:
				book.anim_player.speed_scale = 1.0
		else:
			if book.anim_player:
				book.anim_player.speed_scale = 3.0
				
		start_animation(false)
		return
		
	try_emit_book_signals("left")
	start_animation(false)


## Internal function that handles the actual jump logic using specific spread indices.
func _go_to_page(target_spread_idx: int, total_time: float = 0.5) -> void:
	if book.is_animating:
		return
	
	if target_spread_idx == book.current_spread:
		return
		
	var spreads_to_cross = abs(book.current_spread - target_spread_idx)
	var anim_length = 0.7
	
	if book.anim_player and book.anim_player.has_animation("turn_flexible_page"):
		anim_length = book.anim_player.get_animation("turn_flexible_page").length
		
	var calculated_speed = (spreads_to_cross * anim_length) / total_time
	book._dynamic_auto_speed = clampf(calculated_speed, 1.0, 15.0)
	
	if book.has_method("_pageflip_set_input_enabled"):
		book._pageflip_set_input_enabled(true)
		
	book._auto_turn_target_spread = target_spread_idx
	
	if book.anim_player:
		book.anim_player.speed_scale = book._dynamic_auto_speed
	
	var forward = target_spread_idx > book.current_spread
	start_animation(forward)


## API to jump to a specific page or cover.
func go_to_page(page_num: int = 1, target: int = 0, total_time: float = 0.5) -> void:
	if book.is_animating:
		return
	
	var target_spread_idx: int = 0
	
	match target:
		1: # FRONT_COVER
			target_spread_idx = -1
		2: # BACK_COVER
			if book.limit_max_pages == -1:
				target_spread_idx = book.total_spreads - 1
			else:
				target_spread_idx = book.total_spreads
		0: # CONTENT_PAGE
			var safe_page = page_num
			if safe_page < 1: safe_page = 1
			if book.limit_max_pages > 0 and safe_page > book.limit_max_pages:
				safe_page = book.limit_max_pages
			target_spread_idx = (safe_page - 1) / 2
			if target_spread_idx < 0: target_spread_idx = 0
			if target_spread_idx > book.total_spreads - 1: target_spread_idx = book.total_spreads - 1
	
	_go_to_page(target_spread_idx, total_time)


## Start from the current visual state and end at the cover.
func force_close_book(to_front_cover: bool) -> void:
	if book.is_animating:
		return
		
	if book.has_method("_pageflip_set_input_enabled"):
		book._pageflip_set_input_enabled(true)
	
	book._is_force_closing = true
	book._auto_turn_target_spread = -999
	
	if book.anim_player:
		book.anim_player.speed_scale = 1.0
	
	if to_front_cover:
		start_animation(false)
	else:
		start_animation(true)
#endregion


#region Animation Logic
## Connects variables with the animation timeline elements depending on rigid physics setups.
func start_animation(forward: bool) -> void:
	book.started_page_flip_animation.emit()
	book.is_animating = true
	book.going_forward = forward
		
	set_flying_slots_active(true)

	var is_rigid_motion = false
	var use_tween = false
	var closing_to_back = false
	var closing_to_front = false
	var target_is_closed = false

	var target_spread_idx = 0

	if book._is_force_closing:
		if forward: 
			target_spread_idx = book.total_spreads
			is_rigid_motion = book.covers_are_rigid
			use_tween = true
			book.is_book_open = false
			closing_to_back = true
			target_is_closed = true
		else: 
			target_spread_idx = -1
			is_rigid_motion = book.covers_are_rigid
			use_tween = true
			book.is_book_open = false
			closing_to_front = true
			target_is_closed = true
	elif book._is_jumping:
		target_spread_idx = book._jump_target_spread
		
		if target_spread_idx == -1:
			is_rigid_motion = book.covers_are_rigid
			use_tween = true
			book.is_book_open = false
			closing_to_front = true
			target_is_closed = true
		elif target_spread_idx == book.total_spreads:
			is_rigid_motion = book.covers_are_rigid
			use_tween = true
			book.is_book_open = false
			closing_to_back = true
			target_is_closed = true
		else:
			if book.current_spread == -1 or book.current_spread == book.total_spreads:
				is_rigid_motion = book.covers_are_rigid
				use_tween = true
			else:
				is_rigid_motion = false
				use_tween = false
			book.is_book_open = true
			target_is_closed = false
	else:
		target_spread_idx = book.current_spread + 1 if forward else book.current_spread - 1

		if forward:
			if book.current_spread == -1:
				is_rigid_motion = book.covers_are_rigid
				use_tween = true
				book.is_book_open = true
				target_is_closed = false
			elif book.current_spread == book.total_spreads - 1:
				is_rigid_motion = book.covers_are_rigid
				use_tween = true
				book.is_book_open = false
				closing_to_back = true
				target_is_closed = true
		else:
			if book.current_spread == book.total_spreads:
				is_rigid_motion = book.covers_are_rigid
				use_tween = true
				book.is_book_open = true
				target_is_closed = false
			elif book.current_spread == 0:
				is_rigid_motion = book.covers_are_rigid
				use_tween = true
				book.is_book_open = false
				closing_to_front = true
				target_is_closed = true

	book._is_current_anim_rigid = is_rigid_motion
	book._pending_target_spread_idx = target_spread_idx

	book._force_hide_vol_left = false
	book._force_hide_vol_right = false
	
	if target_is_closed and is_rigid_motion:
		if forward:
			book._force_hide_vol_right = true
		else:
			book._force_hide_vol_left = true

	book._is_page_flying = true
	book._flying_from_right = forward
	book._visual_spread_index = float(book.current_spread)

	var idx_static_left = -999
	var idx_static_right = -999
	var idx_anim_a = -999
	var idx_anim_b = -999

	if book._is_force_closing:
		if forward:
			idx_static_left = get_page_index_for_spread(book.current_spread, true)
			idx_static_right = -999
			idx_anim_a = get_page_index_for_spread(book.current_spread, false)
			idx_anim_b = -103
		else:
			idx_static_right = get_page_index_for_spread(book.current_spread, false)
			idx_static_left = -999
			idx_anim_a = get_page_index_for_spread(book.current_spread, true)
			idx_anim_b = -100
	elif book._is_jumping:
		if forward:
			idx_static_left = get_page_index_for_spread(book.current_spread, true)
			idx_static_right = get_page_index_for_spread(target_spread_idx, false)
			idx_anim_a = get_page_index_for_spread(book.current_spread, false)
			idx_anim_b = get_page_index_for_spread(target_spread_idx, true)
		else:
			idx_static_left = get_page_index_for_spread(target_spread_idx, true)
			idx_static_right = get_page_index_for_spread(book.current_spread, false)
			idx_anim_a = get_page_index_for_spread(book.current_spread, true)
			idx_anim_b = get_page_index_for_spread(target_spread_idx, false)
	else:
		if forward:
			idx_static_left = get_page_index_for_spread(book.current_spread, true)
			idx_static_right = get_page_index_for_spread(target_spread_idx, false)
			idx_anim_a = get_page_index_for_spread(book.current_spread, false)
			idx_anim_b = get_page_index_for_spread(target_spread_idx, true)
		else:
			idx_static_left = get_page_index_for_spread(target_spread_idx, true)
			idx_static_right = get_page_index_for_spread(book.current_spread, false)
			idx_anim_a = get_page_index_for_spread(book.current_spread, true)
			idx_anim_b = get_page_index_for_spread(target_spread_idx, false)

	var l_is_cover = (idx_static_left <= -100) and book.covers_are_rigid
	var r_is_cover = (idx_static_right <= -100) and book.covers_are_rigid
	
	if l_is_cover:
		book._force_hide_vol_left = true
	if r_is_cover:
		book._force_hide_vol_right = true
	
	if book.cover_left_poly:
		book.cover_left_poly.texture = book.tex_cover_front_in
	if book.cover_right_poly:
		book.cover_right_poly.texture = book.tex_cover_back_in
	
	var c_scale_x = (book.page_width * book.cover_protrude_scale.x + book.cover_protrude_offset.x) / book.page_width
	
	var curve_factor_start = book.mesh_manager.get_curve_factor_for_spread(float(book.current_spread)) if book.get("mesh_manager") else 1.0
	var curve_factor_target = book.mesh_manager.get_curve_factor_for_spread(float(target_spread_idx)) if book.get("mesh_manager") else 1.0
	
	var left_curve_factor = curve_factor_start if forward else curve_factor_target
	var right_curve_factor = curve_factor_target if forward else curve_factor_start
	
	var blended_left = book.mesh_manager.get_blended_arrays(left_curve_factor) if book.get("mesh_manager") else {}
	var blended_right = book.mesh_manager.get_blended_arrays(right_curve_factor) if book.get("mesh_manager") else {}
	
	var left_offset_y = book.inner_page_vertical_offset * left_curve_factor
	var right_offset_y = book.inner_page_vertical_offset * right_curve_factor
	
	book.static_left.polygons = []
	
	if l_is_cover:
		book.static_left.polygon = book._poly_flat
		book.static_left.vertex_colors = book._colors_flat
		book.static_left.polygons = book._grid_polys
		book.static_left.scale = Vector2(c_scale_x, book.cover_protrude_scale.y)
		book.static_left.position = Vector2(-book.page_width * c_scale_x, book.cover_protrude_offset.y)
	else:
		book.static_left.polygon = blended_left.poly_l if blended_left.has("poly_l") and blended_left.poly_l.size() > 0 else book._poly_curved_l
		book.static_left.vertex_colors = blended_left.colors_l if blended_left.has("colors_l") and blended_left.colors_l.size() > 0 else book._colors_curved_l
		book.static_left.polygons = book._grid_polys
		book.static_left.scale = Vector2(1.0, 1.0)
		book.static_left.position = Vector2(-book.page_width, left_offset_y)
		
	book.static_right.polygons = []
	
	if r_is_cover:
		book.static_right.polygon = book._poly_flat
		book.static_right.vertex_colors = book._colors_flat
		book.static_right.polygons = book._grid_polys
		book.static_right.scale = Vector2(c_scale_x, book.cover_protrude_scale.y)
		book.static_right.position = Vector2(0, book.cover_protrude_offset.y)
	else:
		book.static_right.polygon = blended_right.poly_r if blended_right.has("poly_r") and blended_right.poly_r.size() > 0 else book._poly_curved_r
		book.static_right.vertex_colors = blended_right.colors_r if blended_right.has("colors_r") and blended_right.colors_r.size() > 0 else book._colors_curved_r
		book.static_right.polygons = book._grid_polys
		book.static_right.scale = Vector2(1.0, 1.0)
		book.static_right.position = Vector2(0, right_offset_y)

	var sh_left_node = book.visuals_container.get_node_or_null("InnerShadowLeft") if book.visuals_container else null
	if sh_left_node and blended_left.has("poly_l") and blended_left.poly_l.size() > 0:
		sh_left_node.polygon = blended_left.poly_l
		
	var sh_right_node = book.visuals_container.get_node_or_null("InnerShadowRight") if book.visuals_container else null
	if sh_right_node and blended_right.has("poly_r") and blended_right.poly_r.size() > 0:
		sh_right_node.polygon = blended_right.poly_r

	if book.get("content_manager"):
		book.content_manager.update_slot_content(book._slot_1, idx_static_left, true)
		book.content_manager.update_slot_content(book._slot_2, idx_static_right, false)
		book.content_manager.update_slot_content(book._slot_3, idx_anim_a, not forward)
		book.content_manager.update_slot_content(book._slot_4, idx_anim_b, forward)

	book.static_left.texture = book._slot_1.get_texture()
	book.static_right.texture = book._slot_2.get_texture()

	var tex_front = book._slot_3.get_texture()
	var tex_back = book._slot_4.get_texture()
	
	book.dynamic_poly.polygons = []
	
	var json_sh_node_hack = book.visuals_container.get_node_or_null("InnerDynamicShadow") if book.visuals_container else null
	
	if json_sh_node_hack and book.get("mesh_manager"):
		book.mesh_manager.sync_skeleton_to_shadow(book.dynamic_poly, json_sh_node_hack)
	
	if is_rigid_motion:
		book.dynamic_poly.polygon = book._dyn_poly_flat
		book.dynamic_poly.vertex_colors = book._dyn_colors_flat
		book.dynamic_poly.scale = Vector2(c_scale_x, book.cover_protrude_scale.y)
		book.dynamic_poly.position = Vector2(0, book.cover_protrude_offset.y - (book.target_page_size.y * book.cover_protrude_scale.y) / 2.0)
		
		if json_sh_node_hack:
			json_sh_node_hack.polygon = book._dyn_poly_flat
			var sh_cols = PackedColorArray()
			
			for pt in book._dyn_poly_flat:
				sh_cols.append(Color(0.0, 0.0, 0.0, 0.0))
				
			json_sh_node_hack.vertex_colors = sh_cols
			json_sh_node_hack.position = book.dynamic_poly.position
			json_sh_node_hack.scale = book.dynamic_poly.scale
	else:
		var start_curve_factor = book.mesh_manager.get_curve_factor_for_spread(float(book.current_spread)) if book.get("mesh_manager") else 1.0
		var blended_dyn = book.mesh_manager.get_blended_dynamic_arrays(start_curve_factor) if book.get("mesh_manager") else {}
		var start_offset_y = book.inner_page_vertical_offset * start_curve_factor
		
		book.dynamic_poly.polygon = blended_dyn.poly if blended_dyn.has("poly") and blended_dyn.poly.size() > 0 else book._dyn_poly_curved
		book.dynamic_poly.vertex_colors = book._dyn_colors_curved
		book.dynamic_poly.scale = Vector2(1.0, 1.0)
		book.dynamic_poly.position = Vector2(0, -book.target_page_size.y / 2.0 + start_offset_y)
		
		if json_sh_node_hack:
			json_sh_node_hack.polygon = blended_dyn.poly if blended_dyn.has("poly") and blended_dyn.poly.size() > 0 else book._dyn_poly_curved
			var sh_cols = PackedColorArray()
			
			for i in range(book._dyn_poly_flat.size()):
				var pt = book._dyn_poly_flat[i]
				var dist = abs(pt.x) / book.target_page_size.x
				var curve = 0.0
				
				if dist < book.spine_curl_width and book.spine_curl_width > 0:
					var n = 1.0 - (dist / book.spine_curl_width)
					curve = n * n
					
				sh_cols.append(Color(0.0, 0.0, 0.0, curve * book.spine_shadow_darkness))
				
			json_sh_node_hack.vertex_colors = sh_cols
			json_sh_node_hack.position = book.dynamic_poly.position
			json_sh_node_hack.scale = book.dynamic_poly.scale
			
	book.dynamic_poly.polygons = book._grid_polys
	if json_sh_node_hack: json_sh_node_hack.polygons = book._grid_polys
		
	book.dynamic_poly.texture = tex_back

	var auto_shadow = book.dynamic_poly.get_node_or_null("AutoShadow")
	
	if auto_shadow:
		auto_shadow.polygons = []
		
		if is_rigid_motion:
			auto_shadow.polygon = book._dyn_poly_flat
		else:
			auto_shadow.polygon = book._dyn_poly_curved
			
		auto_shadow.polygons = book._grid_polys

	if book.dynamic_poly.material is ShaderMaterial:
		book.dynamic_poly.material.set_shader_parameter("shadow_intensity", 0.0)
		book.dynamic_poly.material.set_shader_parameter("max_shadow_spread", 0.0)

		var shadow_tex = book.dynamic_poly.get("shadow_gradient")
		
		if shadow_tex:
			book.dynamic_poly.material.set_shader_parameter("spine_shadow_gradient", shadow_tex)

		if forward:
			book.dynamic_poly.material.set_shader_parameter("front_texture", tex_front)
			book.dynamic_poly.material.set_shader_parameter("back_texture", tex_back)
		else:
			book.dynamic_poly.material.set_shader_parameter("front_texture", tex_back)
			book.dynamic_poly.material.set_shader_parameter("back_texture", tex_front)

	if closing_to_back:
		book.call_deferred("_set_page_visible", book.static_right, false)
		if book.cover_right_poly: book.call_deferred("_set_page_visible", book.cover_right_poly, false)
	elif closing_to_front:
		book.call_deferred("_set_page_visible", book.static_left, false)
		if book.cover_left_poly: book.call_deferred("_set_page_visible", book.cover_left_poly, false)

	var base_anim_name = "turn_rigid_page" if is_rigid_motion else "turn_flexible_page"
	var final_anim_name = base_anim_name if forward else base_anim_name + "_mirror"

	var anim_len = 1.0
	
	if book.anim_player.has_animation(final_anim_name):
		anim_len = book.anim_player.get_animation(final_anim_name).length
		book.anim_player.current_animation = final_anim_name
		book.anim_player.seek(0.0, true)

	book.call_deferred("_set_page_visible", book.dynamic_poly, true)
	if json_sh_node_hack:
		book.call_deferred("_set_page_visible", json_sh_node_hack, true)
	book.dynamic_poly.z_index = 10
	
	if book.get("volume_manager"):
		book.volume_manager.update_stack_direct(book._current_expansion_factor, float(book.current_spread))

	await RenderingServer.frame_post_draw
	
	var is_jumping_start = (book.current_spread == -1 and book.front_cover_opens_to_page > 1 and book._auto_turn_target_spread != -999)
	
	if is_jumping_start:
		book.anim_player.speed_scale = book.cover_anim_speed
	elif book._auto_turn_target_spread != -999:
		book.anim_player.speed_scale = book.pages_anim_speed

	var motion_duration = anim_len / (book.anim_player.speed_scale if book.anim_player.speed_scale > 0 else 1.0)
	var land_time = max(0.0, motion_duration - book.landing_overlap)
	
	book.get_tree().create_timer(land_time).timeout.connect(on_page_landed_early)

	var start_exp = float(book._current_expansion_factor)
	var end_exp = 1.0 if target_is_closed else 0.0
	var tween = book.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT).set_parallel(true)
	
	var mid_ratio = 0.5
	
	if book.dynamic_poly and "timing_midpoint_ratio" in book.dynamic_poly:
		mid_ratio = book.dynamic_poly.get("timing_midpoint_ratio")
		
	var first_half_duration = motion_duration * mid_ratio
	var second_half_duration = motion_duration * (1.0 - mid_ratio)
	
	book.dynamic_poly.set_meta("flight_arc", 0.0)
	var arc_tween = book.create_tween()
	arc_tween.tween_method(func(v: float): book.dynamic_poly.set_meta("flight_arc", v), 0.0, 1.0, first_half_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	arc_tween.tween_method(func(v: float): book.dynamic_poly.set_meta("flight_arc", v), 1.0, 0.0, second_half_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	var overlap_factor = 0.8
	var delay_time = first_half_duration * overlap_factor
	var entry_duration = motion_duration - delay_time

	var drop_shadow = book.visuals_container.get_node_or_null("DropShadowPoly") if book.visuals_container else null
	
	if drop_shadow and drop_shadow.visible:
		tween.tween_property(drop_shadow, "modulate:a", 0.05, first_half_duration)
		tween.tween_callback(func(): drop_shadow.visible = false).set_delay(first_half_duration)

	var start_idx_l = get_page_index_for_spread(book.current_spread, true)
	var start_idx_r = get_page_index_for_spread(book.current_spread, false)
	var target_idx_l = get_page_index_for_spread(target_spread_idx, true)
	var target_idx_r = get_page_index_for_spread(target_spread_idx, false)

	var start_l_is_cover = (start_idx_l <= -100) and book.covers_are_rigid
	var start_r_is_cover = (start_idx_r <= -100) and book.covers_are_rigid
	var target_l_is_cover = (target_idx_l <= -100) and book.covers_are_rigid
	var target_r_is_cover = (target_idx_r <= -100) and book.covers_are_rigid

	var is_open_start = (book.current_spread >= 0 and book.current_spread < book.total_spreads)
	var is_open_target = (target_spread_idx >= 0 and target_spread_idx < book.total_spreads)

	var l_nodes_logic = [
		{"name": "CoverStackShadowLeft", "start": 1.0 if is_open_start else 0.0, "target": 1.0 if is_open_target else 0.0},
		{"name": "InnerShadowLeft", "start": 1.0 if (start_idx_l != -999 and not start_l_is_cover) else 0.0, "target": 1.0 if (target_idx_l != -999 and not target_l_is_cover) else 0.0}
	]

	for data in l_nodes_logic:
		var nd = book.visuals_container.get_node_or_null(data["name"])
		if nd:
			nd.modulate.a = data["start"]
			nd.visible = true
			tween.tween_property(nd, "modulate:a", data["target"], motion_duration)

	var r_nodes_logic = [
		{"name": "CoverStackShadowRight", "start": 1.0 if is_open_start else 0.0, "target": 1.0 if is_open_target else 0.0},
		{"name": "InnerShadowRight", "start": 1.0 if (start_idx_r != -999 and not start_r_is_cover) else 0.0, "target": 1.0 if (target_idx_r != -999 and not target_r_is_cover) else 0.0}
	]

	for data in r_nodes_logic:
		var nd = book.visuals_container.get_node_or_null(data["name"])
		if nd:
			nd.modulate.a = data["start"]
			nd.visible = true
			tween.tween_property(nd, "modulate:a", data["target"], motion_duration)

	var start_thin_L = (book.current_spread <= 0)
	var end_thin_L = (target_spread_idx <= 0)

	if start_thin_L and not end_thin_L:
		book._stack_scale_left = 0.0
		tween.tween_property(book, "_stack_scale_left", 1.0, entry_duration).set_delay(delay_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	elif not start_thin_L and end_thin_L:
		book._stack_scale_left = 1.0
		tween.tween_property(book, "_stack_scale_left", 0.0, first_half_duration * 0.8)
	elif start_thin_L and end_thin_L:
		book._stack_scale_left = 0.0
	else:
		book._stack_scale_left = 1.0

	var start_thin_R = (book.current_spread >= book.total_spreads - 1)
	var end_thin_R = (target_spread_idx >= book.total_spreads - 1)

	if start_thin_R and not end_thin_R:
		book._stack_scale_right = 0.0
		tween.tween_property(book, "_stack_scale_right", 1.0, entry_duration).set_delay(delay_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	elif not start_thin_R and end_thin_R:
		book._stack_scale_right = 1.0
		tween.tween_property(book, "_stack_scale_right", 0.0, first_half_duration * 0.8)
	elif start_thin_R and end_thin_R:
		book._stack_scale_right = 0.0
	else:
		book._stack_scale_right = 1.0

	if use_tween:
		var compensation_offset = get_compensation_offset(target_is_closed, closing_to_back)
		var camera = book.get_viewport().get_camera_2d()
		var screen_center = camera.get_screen_center_position() if camera else book.get_viewport().size * 0.5
		
		var extra_offset = book.open_offset
		if target_is_closed:
			if closing_to_back:
				extra_offset = book.closed_back_offset
			else:
				extra_offset = book.closed_offset
				
		var final_pos = screen_center + compensation_offset - Vector2(book.target_page_size.x / 2.0, 0.0) + extra_offset
		
		var start_pos = book.visuals_container.global_position
		var start_scale = book.visuals_container.scale
		var start_skew = book.visuals_container.skew
		var start_rot = book.visuals_container.rotation
		
		var target_scale = book.closed_scale if target_is_closed else book.open_scale
		var target_skew = book.closed_skew if target_is_closed else book.open_skew
		var target_rot = book.closed_rotation if target_is_closed else book.open_rotation
		
		if target_is_closed and closing_to_back:
			target_skew *= -1.0
			target_rot *= -1.0
			
		tween.tween_method(
			func(t: float):
				var arc = 0.0
				
				if t < mid_ratio:
					arc = 1.0 - pow((mid_ratio - t) / mid_ratio, 2.0)
				else:
					arc = 1.0 - pow((t - mid_ratio) / (1.0 - mid_ratio), 2.0)
				
				var current_pos = start_pos.lerp(final_pos, t)
				current_pos.y -= book.flight_lift_height * arc
				book.visuals_container.global_position = current_pos
				
				var base_scale = start_scale.lerp(target_scale, t)
				book.visuals_container.scale = base_scale * (1.0 + ((book.flight_zoom_factor - 1.0) * arc))
				
				book.visuals_container.skew = lerp(start_skew, target_skew, t)
				book.visuals_container.rotation = lerp_angle(start_rot, deg_to_rad(target_rot), t)
		,
			0.0, 1.0, float(motion_duration)
		)

	if book.get("volume_manager"):
		tween.tween_method(Callable(book.volume_manager, "tween_expansion_only"), float(start_exp), float(end_exp), float(motion_duration))
	
	tween.tween_property(book, "_visual_spread_index", float(target_spread_idx), float(motion_duration))

	book.anim_player.play(final_anim_name)

	if is_rigid_motion:
		var trigger_time = max(0.0, motion_duration - book.impact_sync_offset)
		book.get_tree().create_timer(trigger_time).timeout.connect(
			func():
				if book.current_spread == 0 or book.current_spread == book.total_spreads - 1:
					if book.has_method("_play_sound"): book._play_sound(book.sfx_book_impact)
				else:
					if book.has_method("_play_sound"): book._play_sound(book.sfx_book_opened)
		)
	else:
		if book.has_method("_play_sound"): book._play_sound(book.sfx_page_flip)


## Executed naturally when an animation completely terminates.
func on_animation_finished(_anim_name: String) -> void:
	if book.has_method("_set_page_visible"):
		book._set_page_visible(book.dynamic_poly, false)
		var dyn_sh = book.visuals_container.get_node_or_null("InnerDynamicShadow") if book.visuals_container else null
		if dyn_sh:
			book._set_page_visible(dyn_sh, false)
			
	set_flying_slots_active(false)
	book.dynamic_poly.z_index = 10
	
	var drop_shadow = book.visuals_container.get_node_or_null("DropShadowPoly") if book.visuals_container else null
	var auto_shadow = book.dynamic_poly.get_node_or_null("AutoShadow")
	
	book._force_hide_vol_left = false
	book._force_hide_vol_right = false
	book._is_page_flying = false
	
	if book._is_force_closing:
		book._is_force_closing = false
		if book.going_forward: book.current_spread = book.total_spreads
		else: book.current_spread = -1
	elif book._is_jumping:
		book._is_jumping = false
		book.current_spread = book._jump_target_spread
	else:
		if book.going_forward and book.current_spread == -1: book.current_spread = 0
		elif book.going_forward and book.current_spread == book.total_spreads - 1: book.current_spread = book.total_spreads
		elif !book.going_forward and book.current_spread == book.total_spreads: book.current_spread = book.total_spreads - 1
		elif !book.going_forward and book.current_spread == 0: book.current_spread = -1
		else:
			if book.going_forward: book.current_spread += 1
			else: book.current_spread -= 1

	var is_closed_now = (book.current_spread == -1 or book.current_spread == book.total_spreads)
	
	if drop_shadow and auto_shadow and not is_closed_now:
		drop_shadow.polygon = auto_shadow.polygon
		drop_shadow.polygons = auto_shadow.polygons
		drop_shadow.uv = auto_shadow.uv
		drop_shadow.texture = auto_shadow.texture
		drop_shadow.scale = auto_shadow.scale
		drop_shadow.position = book.dynamic_poly.position + auto_shadow.position
		drop_shadow.color = auto_shadow.color
		drop_shadow.modulate = auto_shadow.modulate
		drop_shadow.z_index = 1
		drop_shadow.visible = true
	elif drop_shadow:
		drop_shadow.visible = false
	
	if book.get("mesh_manager"):
		book.mesh_manager.update_static_visuals_immediate()
		
	book.is_animating = false
	book._visual_spread_index = float(book.current_spread)
	
	if book.get("volume_manager"):
		book.volume_manager.update_stack_direct(book._current_expansion_factor, book._visual_spread_index)
		book.volume_manager.update_volume_visuals()
	
	var is_back_now = (book.current_spread == book.total_spreads)
	var compensation_offset = get_compensation_offset(is_closed_now, is_back_now)
	var camera = book.get_viewport().get_camera_2d()
	var screen_center = camera.get_screen_center_position() if camera else book.get_viewport().size * 0.5
	
	var extra_offset = book.open_offset
	if is_closed_now:
		if is_back_now:
			extra_offset = book.closed_back_offset
		else:
			extra_offset = book.closed_offset
			
	book.visuals_container.global_position = screen_center + compensation_offset - Vector2(book.target_page_size.x / 2.0, 0.0) + extra_offset
	
	animate_container_transform(is_closed_now, is_back_now, 0.0)
	
	if book._auto_turn_target_spread != -999:
		if book.current_spread < book._auto_turn_target_spread:
			if book.anim_player: book.anim_player.speed_scale = book.pages_anim_speed
			start_animation(true)
			return
		elif book.current_spread > book._auto_turn_target_spread:
			if book.current_spread == 0 and book._auto_turn_target_spread == -1:
				if book.anim_player: book.anim_player.speed_scale = book.cover_anim_speed
			else:
				if book.anim_player: book.anim_player.speed_scale = book.pages_anim_speed
			start_animation(false)
			return
		else:
			book._auto_turn_target_spread = -999
			if book.anim_player: book.anim_player.speed_scale = 1.0
			
	if book.current_spread == book.total_spreads:
		if book.close_condition == book.CloseCondition.CLOSE_FROM_BACK or book.close_condition == book.CloseCondition.ANY_CLOSE:
			book.call_deferred("_perform_close_action")
			return
			
	if book.current_spread == -1:
		if book.close_condition == book.CloseCondition.CLOSE_FROM_FRONT or book.close_condition == book.CloseCondition.ANY_CLOSE:
			book.call_deferred("_perform_close_action")
			return
			
	if book.has_method("_check_scene_activation"):
		book.call_deferred("_check_scene_activation")
		
	book.ended_page_flip_animation.emit()


#endregion


#region Internal Utilities
## Calculates page index mathematically directly associated to a spread orientation.
func get_page_index_for_spread(spread_idx: int, is_left: bool) -> int:
	if spread_idx == -1: return -999 if is_left else -100
	if spread_idx == book.total_spreads: return -103 if is_left else -999
	if spread_idx == 0:
		if is_left: return -101
		if book._runtime_pages.size() == 0: return -102
		return 0
	if is_left: return (spread_idx * 2) - 1
	else:
		var content_idx = spread_idx * 2
		if content_idx >= book._runtime_pages.size(): return -102
		return content_idx


## Marks the landing state explicitly before the actual animation wraps.
func on_page_landed_early() -> void:
	book._is_page_flying = false
	book._visual_spread_index = float(book._pending_target_spread_idx)
	if book.get("volume_manager"):
		book.volume_manager.update_stack_direct(book._current_expansion_factor, book._visual_spread_index)


## Toggles rendering bounds manually depending on the flipping status.
func set_flying_slots_active(is_active: bool) -> void:
	var mode = SubViewport.UPDATE_ALWAYS if is_active else SubViewport.UPDATE_DISABLED
	
	if book._slot_3: book._slot_3.render_target_update_mode = mode
	if book._slot_4: book._slot_4.render_target_update_mode = mode


## Emits events for specific structural transitions.
func try_emit_book_signals(_direction: String) -> void:
	if _direction == "right" and book.current_spread == -1:
		book.book_opened.emit()
	elif _direction == "left" and book.current_spread == book.total_spreads:
		book.book_opened.emit()
	elif _direction == "left" and book.current_spread == 0:
		book.book_closed.emit()
	elif _direction == "right" and book.current_spread == book.total_spreads - 1:
		book.book_closed.emit()


## Retrieves alignment offsets relative to the book structure parameters and center points.
func get_compensation_offset(is_closed: bool, is_back: bool) -> Vector2:
	var target_local_x = 0.0
	
	if is_closed:
		if is_back:
			target_local_x = -book.page_width * 0.5
		else:
			target_local_x = 0.0
	else:
		target_local_x = -book.page_width * 0.5
		
	var target_vec = Vector2(target_local_x, 0)
	var t_scale = book.closed_scale if is_closed else book.open_scale
	var t_rot = book.closed_rotation if is_closed else book.open_rotation
	
	if is_closed and is_back:
		t_rot *= -1.0
		
	target_vec *= t_scale
	target_vec = target_vec.rotated(deg_to_rad(t_rot))
	
	return -target_vec


## Manages container tween values natively supporting book orientations.
func animate_container_transform(target_is_closed: bool, is_back: bool, duration: float) -> void:
	if not book.visuals_container: return
	
	var t_scale = book.closed_scale if target_is_closed else book.open_scale
	var t_skew = book.closed_skew if target_is_closed else book.open_skew
	var t_rot = book.closed_rotation if target_is_closed else book.open_rotation
	
	if target_is_closed and is_back: t_skew *= -1.0
	t_rot *= -1.0
	
	if duration <= 0.0:
		book.visuals_container.scale = t_scale
		book.visuals_container.skew = t_skew
		book.visuals_container.rotation = deg_to_rad(t_rot)
	else:
		var tween = book.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(book.visuals_container, "scale", t_scale, duration)
		tween.tween_property(book.visuals_container, "skew", t_skew, duration)
		tween.tween_property(book.visuals_container, "rotation", deg_to_rad(t_rot), duration)
#endregion
