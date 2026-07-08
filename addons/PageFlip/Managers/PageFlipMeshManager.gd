class_name PageFlipMeshManager extends RefCounted

## Reference to the main book node.
var book: Node2D


## Initializes the mesh manager.
func _init(book_node: Node2D) -> void:
	book = book_node


#region Curve Calculations
## Calculates a dynamic multiplier for page curvature based on book position.
func get_curve_factor_for_spread(spread: float) -> float:
	if book.total_spreads <= 1:
		return 1.0
		
	var max_spread_idx = float(max(1, book.total_spreads - 1))
	var ratio = clampf(spread / max_spread_idx, 0.0, 1.0)
	var sine_val = sin(ratio * PI)
	
	if ratio <= 0.5:
		return lerp(0.15, 1.0, sine_val)
	else:
		return lerp(0.05, 1.0, sine_val)


## Generates interpolated vertex arrays for static pages based on book depth.
func get_blended_arrays(curve_factor: float) -> Dictionary:
	var res = {
		"poly_l": PackedVector2Array(),
		"poly_r": PackedVector2Array(),
		"colors_l": PackedColorArray(),
		"colors_r": PackedColorArray()
	}
	
	if book._poly_flat.size() == 0 or book._poly_curved_l.size() == 0:
		return res
		
	for i in range(book._poly_flat.size()):
		res.poly_l.append(book._poly_flat[i].lerp(book._poly_curved_l[i], curve_factor))
		res.poly_r.append(book._poly_flat[i].lerp(book._poly_curved_r[i], curve_factor))
		res.colors_l.append(book._colors_flat[i].lerp(book._colors_curved_l[i], curve_factor))
		res.colors_r.append(book._colors_flat[i].lerp(book._colors_curved_r[i], curve_factor))
		
	return res


## Generates interpolated vertex arrays for the dynamic flipping page.
func get_blended_dynamic_arrays(curve_factor: float) -> Dictionary:
	var res = {
		"poly": PackedVector2Array(),
		"colors": PackedColorArray()
	}
	
	if book._dyn_poly_flat.size() == 0 or book._dyn_poly_curved.size() == 0:
		return res
		
	for i in range(book._dyn_poly_flat.size()):
		res.poly.append(book._dyn_poly_flat[i].lerp(book._dyn_poly_curved[i], curve_factor))
		res.colors.append(book._dyn_colors_flat[i].lerp(book._dyn_colors_curved[i], curve_factor))
		
	return res
#endregion


#region Mesh Initialization and Size Management
## Synchronizes the skeleton and bone weights from the rigger to the shadow overlays.
func sync_skeleton_to_shadow(source: Polygon2D, target: Polygon2D) -> void:
	if not source.has_node("AutoSkeleton"):
		return
		
	var skel = source.get_node("AutoSkeleton")
	target.skeleton = target.get_path_to(skel)
	target.clear_bones()
	
	for i in range(source.get_bone_count()):
		target.add_bone(source.get_bone_path(i), source.get_bone_weights(i))


## Initializes the shared perspective material for the static pages.
func init_perspective_material() -> void:
	if not book.perspective_shader:
		return
		
	if book.static_left and not book.static_left.material:
		book.static_left.material = ShaderMaterial.new()
		book.static_left.material.shader = book.perspective_shader
		
	if book.static_right and not book.static_right.material:
		book.static_right.material = ShaderMaterial.new()
		book.static_right.material.shader = book.perspective_shader
		
	if book.cover_left_poly and not book.cover_left_poly.material:
		book.cover_left_poly.material = ShaderMaterial.new()
		book.cover_left_poly.material.shader = book.perspective_shader
		
	if book.cover_right_poly and not book.cover_right_poly.material:
		book.cover_right_poly.material = ShaderMaterial.new()
		book.cover_right_poly.material.shader = book.perspective_shader

	var cv_sh_l = book.visuals_container.get_node_or_null("CoverStackShadowLeft") if book.visuals_container else book.find_child("CoverStackShadowLeft", true, false)
	
	if cv_sh_l and not cv_sh_l.material:
		cv_sh_l.material = ShaderMaterial.new()
		cv_sh_l.material.shader = book.perspective_shader

	var cv_sh_r = book.visuals_container.get_node_or_null("CoverStackShadowRight") if book.visuals_container else book.find_child("CoverStackShadowRight", true, false)
	
	if cv_sh_r and not cv_sh_r.material:
		cv_sh_r.material = ShaderMaterial.new()
		cv_sh_r.material.shader = book.perspective_shader

	var st_sh_l = book.visuals_container.get_node_or_null("StackDropShadowLeft") if book.visuals_container else book.find_child("StackDropShadowLeft", true, false)
	
	if st_sh_l and not st_sh_l.material:
		st_sh_l.material = ShaderMaterial.new()
		st_sh_l.material.shader = book.perspective_shader

	var st_sh_r = book.visuals_container.get_node_or_null("StackDropShadowRight") if book.visuals_container else book.find_child("StackDropShadowRight", true, false)
	
	if st_sh_r and not st_sh_r.material:
		st_sh_r.material = ShaderMaterial.new()
		st_sh_r.material.shader = book.perspective_shader

	var sh_left = book.visuals_container.get_node_or_null("InnerShadowLeft") if book.visuals_container else book.find_child("InnerShadowLeft", true, false)
	
	if sh_left and not sh_left.material:
		sh_left.material = ShaderMaterial.new()
		sh_left.material.shader = book.perspective_shader

	var sh_right = book.visuals_container.get_node_or_null("InnerShadowRight") if book.visuals_container else book.find_child("InnerShadowRight", true, false)
	
	if sh_right and not sh_right.material:
		sh_right.material = ShaderMaterial.new()
		sh_right.material.shader = book.perspective_shader

	var ds_poly = book.visuals_container.get_node_or_null("DropShadowPoly") if book.visuals_container else book.find_child("DropShadowPoly", true, false)
	
	if ds_poly and not ds_poly.material:
		ds_poly.material = ShaderMaterial.new()
		ds_poly.material.shader = book.perspective_shader
		
	if book.dynamic_poly:
		var auto_shadow = book.dynamic_poly.get_node_or_null("AutoShadow")
		
		if auto_shadow and not auto_shadow.material:
			auto_shadow.material = ShaderMaterial.new()
			auto_shadow.material.shader = book.perspective_shader
			
	var dyn_sh = book.visuals_container.get_node_or_null("InnerDynamicShadow") if book.visuals_container else book.find_child("InnerDynamicShadow", true, false)
	
	if dyn_sh and not dyn_sh.material:
		dyn_sh.material = ShaderMaterial.new()
		dyn_sh.material.shader = book.perspective_shader


## Rebuilds the visual meshes, viewports, arrays, and vertex colors for shading.
func apply_new_size() -> void:
	book.page_width = book.target_page_size.x
	book._update_viewports_recursive(book, book.target_page_size)
	var w = book.target_page_size.x
	var h = book.target_page_size.y
	
	var sub_x = 8
	var sub_y = 5
	
	if book.dynamic_poly and book.dynamic_poly.get("subdivision_x") != null:
		sub_x = book.dynamic_poly.get("subdivision_x")
		sub_y = book.dynamic_poly.get("subdivision_y")
		
	var step_x = w / float(sub_x)
	var step_y = h / float(sub_y)
	
	var flat_points = PackedVector2Array()
	var curved_l = PackedVector2Array()
	var curved_r = PackedVector2Array()
	var grid_uvs = PackedVector2Array()
	var grid_polys = []
	var colors_l = PackedColorArray()
	var colors_r = PackedColorArray()
	var colors_flat = PackedColorArray()
	
	var rc = sub_x + 1
	var hw_y = h / 2.0
	
	for y in range(sub_y + 1):
		for x in range(sub_x + 1):
			var px = x * step_x
			var py = (y * step_y) - hw_y
			
			flat_points.append(Vector2(px, py))
			grid_uvs.append(Vector2(px, y * step_y))
			colors_flat.append(Color.WHITE)
			
			var curve_r = 0.0
			var outer_curve_r = 0.0
			var dist_r = px / w
			var out_dist_r = 1.0 - dist_r
			
			if dist_r < book.spine_curl_width and book.spine_curl_width > 0:
				var n = 1.0 - (dist_r / book.spine_curl_width)
				curve_r = n * n
				
			if out_dist_r < book.outer_droop_width and book.outer_droop_width > 0:
				var n = 1.0 - (out_dist_r / book.outer_droop_width)
				outer_curve_r = n * n
				
			var py_r = py + (curve_r * book.spine_curl_intensity) + (outer_curve_r * book.outer_droop_intensity)
			curved_r.append(Vector2(px, py_r))
			
			var shadow_r = 1.0
			colors_r.append(Color(1.0, 1.0, 1.0, 1.0))
			
			var curve_l = 0.0
			var outer_curve_l = 0.0
			var dist_l = (w - px) / w
			var out_dist_l = 1.0 - dist_l
			
			if dist_l < book.spine_curl_width and book.spine_curl_width > 0:
				var n = 1.0 - (dist_l / book.spine_curl_width)
				curve_l = n * n
				
			if out_dist_l < book.outer_droop_width and book.outer_droop_width > 0:
				var n = 1.0 - (out_dist_l / book.outer_droop_width)
				outer_curve_l = n * n
				
			var py_l = py + (curve_l * book.spine_curl_intensity) + (outer_curve_l * book.outer_droop_intensity)
			curved_l.append(Vector2(px, py_l))
			
			var shadow_l = 1.0
			colors_l.append(Color(1.0, 1.0, 1.0, 1.0))
			
	for y in range(sub_y):
		for x in range(sub_x):
			var i = y * rc + x
			grid_polys.append(PackedInt32Array([i, i + 1, i + rc + 1, i + rc]))

	book._grid_polys = grid_polys
	book._grid_uvs = grid_uvs
	book._poly_flat = flat_points
	book._poly_curved_l = curved_l
	book._poly_curved_r = curved_r
	book._colors_flat = colors_flat
	book._colors_curved_l = colors_l
	book._colors_curved_r = colors_r

	var curve_factor = get_curve_factor_for_spread(book._visual_spread_index)
	var current_offset_y = book.inner_page_vertical_offset * curve_factor

	if book.static_left:
		book.static_left.polygons = []
		book.static_left.polygon = curved_l
		book.static_left.uv = grid_uvs
		book.static_left.vertex_colors = colors_l
		book.static_left.polygons = grid_polys
		book.static_left.visible = false
		
	if book.static_right:
		book.static_right.polygons = []
		book.static_right.polygon = curved_r
		book.static_right.uv = grid_uvs
		book.static_right.vertex_colors = colors_r
		book.static_right.polygons = grid_polys
		book.static_right.visible = true
		
	if book.cover_left_poly:
		book.cover_left_poly.polygons = []
		book.cover_left_poly.polygon = flat_points
		book.cover_left_poly.uv = grid_uvs
		book.cover_left_poly.polygons = grid_polys
		book.cover_left_poly.visible = false
		
		if book.covers_are_rigid:
			var c_scale_x = (w * book.cover_protrude_scale.x + book.cover_protrude_offset.x) / w
			book.cover_left_poly.scale = Vector2(c_scale_x, book.cover_protrude_scale.y)
			book.cover_left_poly.position = Vector2(-w * c_scale_x, book.cover_protrude_offset.y)
		else:
			book.cover_left_poly.scale = Vector2(1.0, 1.0)
			book.cover_left_poly.position = Vector2(-w, 0)
			
	if book.cover_right_poly:
		book.cover_right_poly.polygons = []
		book.cover_right_poly.polygon = flat_points
		book.cover_right_poly.uv = grid_uvs
		book.cover_right_poly.polygons = grid_polys
		book.cover_right_poly.visible = false
		
		if book.covers_are_rigid:
			var c_scale_x = (w * book.cover_protrude_scale.x + book.cover_protrude_offset.x) / w
			book.cover_right_poly.scale = Vector2(c_scale_x, book.cover_protrude_scale.y)
			book.cover_right_poly.position = Vector2(0, book.cover_protrude_offset.y)
		else:
			book.cover_right_poly.scale = Vector2(1.0, 1.0)
			book.cover_right_poly.position = Vector2(0, 0)

	var cv_sh_l = book.visuals_container.get_node_or_null("CoverStackShadowLeft") if book.visuals_container else null
	
	if cv_sh_l:
		cv_sh_l.polygons = []
		cv_sh_l.polygon = book._poly_flat
		cv_sh_l.uv = book._grid_uvs
		cv_sh_l.polygons = book._grid_polys
		
		if book.covers_are_rigid:
			var c_scale_x = (w * book.cover_protrude_scale.x + book.cover_protrude_offset.x) / w
			cv_sh_l.scale = Vector2(c_scale_x, book.cover_protrude_scale.y)
			cv_sh_l.position = Vector2(-w * c_scale_x, book.cover_protrude_offset.y)
		else:
			cv_sh_l.scale = Vector2(1.0, 1.0)
			cv_sh_l.position = Vector2(-w, 0)
			
		var colors_cv_l = PackedColorArray()
		for pt in book._poly_flat:
			var dist = (w - pt.x) / w
			var alpha = 0.65 * (1.0 - (dist / 0.5)) if dist < 0.5 else 0.0
			colors_cv_l.append(Color(0, 0, 0, alpha))
		cv_sh_l.vertex_colors = colors_cv_l

	var cv_sh_r = book.visuals_container.get_node_or_null("CoverStackShadowRight") if book.visuals_container else null
	
	if cv_sh_r:
		cv_sh_r.polygons = []
		cv_sh_r.polygon = book._poly_flat
		cv_sh_r.uv = book._grid_uvs
		cv_sh_r.polygons = book._grid_polys
		
		if book.covers_are_rigid:
			var c_scale_x = (w * book.cover_protrude_scale.x + book.cover_protrude_offset.x) / w
			cv_sh_r.scale = Vector2(c_scale_x, book.cover_protrude_scale.y)
			cv_sh_r.position = Vector2(0, book.cover_protrude_offset.y)
		else:
			cv_sh_r.scale = Vector2(1.0, 1.0)
			cv_sh_r.position = Vector2(0, 0)
			
		var colors_cv_r = PackedColorArray()
		for pt in book._poly_flat:
			var dist = pt.x / w
			var alpha = 0.65 * (1.0 - (dist / 0.5)) if dist < 0.5 else 0.0
			colors_cv_r.append(Color(0, 0, 0, alpha))
		cv_sh_r.vertex_colors = colors_cv_r

	var st_sh_l = book.visuals_container.get_node_or_null("StackDropShadowLeft") if book.visuals_container else null
	
	if st_sh_l:
		var sh_poly_l = PackedVector2Array()
		var c_arr_l = PackedColorArray()
		
		for pt in book._poly_curved_l:
			sh_poly_l.append(pt + Vector2(-book.stack_shadow_offset.x, book.stack_shadow_offset.y))
			var dist = (w - pt.x) / w
			var alpha = 0.45
			if dist < book.spine_curl_width and book.spine_curl_width > 0:
				var n = 1.0 - (dist / book.spine_curl_width)
				alpha = 0.45 * (1.0 - (n * n))
			c_arr_l.append(Color(0, 0, 0, alpha))
			
		st_sh_l.polygons = []
		st_sh_l.polygon = sh_poly_l
		st_sh_l.uv = book._grid_uvs
		st_sh_l.polygons = book._grid_polys
		st_sh_l.scale = Vector2(1.0, 1.0)
		st_sh_l.position = Vector2(-book.page_width, current_offset_y)
		st_sh_l.vertex_colors = c_arr_l

	var st_sh_r = book.visuals_container.get_node_or_null("StackDropShadowRight") if book.visuals_container else null
	
	if st_sh_r:
		var sh_poly_r = PackedVector2Array()
		var c_arr_r = PackedColorArray()
		
		for pt in book._poly_curved_r:
			sh_poly_r.append(pt + Vector2(book.stack_shadow_offset.x, book.stack_shadow_offset.y))
			var dist = pt.x / w
			var alpha = 0.45
			if dist < book.spine_curl_width and book.spine_curl_width > 0:
				var n = 1.0 - (dist / book.spine_curl_width)
				alpha = 0.45 * (1.0 - (n * n))
			c_arr_r.append(Color(0, 0, 0, alpha))
			
		st_sh_r.polygons = []
		st_sh_r.polygon = sh_poly_r
		st_sh_r.uv = book._grid_uvs
		st_sh_r.polygons = book._grid_polys
		st_sh_r.scale = Vector2(1.0, 1.0)
		st_sh_r.position = Vector2(0, current_offset_y)
		st_sh_r.vertex_colors = c_arr_r

	var cover_scale_y = book.cover_protrude_scale.y if book.covers_are_rigid else 1.0
	var cover_off_y = book.cover_protrude_offset.y if book.covers_are_rigid else 0.0

	var sh_left = book.visuals_container.get_node_or_null("InnerShadowLeft") if book.visuals_container else null
	var sh_right = book.visuals_container.get_node_or_null("InnerShadowRight") if book.visuals_container else null

	if sh_left:
		sh_left.polygons = []
		sh_left.polygon = book._poly_curved_l
		sh_left.uv = book._grid_uvs
		sh_left.polygons = book._grid_polys
		var sh_colors_l = PackedColorArray()
		
		for i in range(book._poly_curved_l.size()):
			var pt = book._poly_curved_l[i]
			var dist_l = (w - pt.x) / w
			var alpha = 0.0
			
			if dist_l < book.spine_curl_width and book.spine_curl_width > 0:
				var n = 1.0 - (dist_l / book.spine_curl_width)
				alpha = book.spine_shadow_darkness * n * n
				
			sh_colors_l.append(Color(0, 0, 0, alpha))
			
		sh_left.vertex_colors = sh_colors_l
		sh_left.scale = Vector2(1.0, cover_scale_y)
		sh_left.position = Vector2(-book.page_width, current_offset_y + cover_off_y)

	if sh_right:
		sh_right.polygons = []
		sh_right.polygon = book._poly_curved_r
		sh_right.uv = book._grid_uvs
		sh_right.polygons = book._grid_polys
		var sh_colors_r = PackedColorArray()
		
		for i in range(book._poly_curved_r.size()):
			var pt = book._poly_curved_r[i]
			var dist_r = pt.x / w
			var alpha = 0.0
			
			if dist_r < book.spine_curl_width and book.spine_curl_width > 0:
				var n = 1.0 - (dist_r / book.spine_curl_width)
				alpha = book.spine_shadow_darkness * n * n
				
			sh_colors_r.append(Color(0, 0, 0, alpha))
			
		sh_right.vertex_colors = sh_colors_r
		sh_right.scale = Vector2(1.0, cover_scale_y)
		sh_right.position = Vector2(0, current_offset_y + cover_off_y)

	var drop_shadow = book.visuals_container.get_node_or_null("DropShadowPoly") if book.visuals_container else null
	
	if drop_shadow:
		drop_shadow.visible = false
		
	if book.dynamic_poly:
		book.dynamic_poly.position = Vector2(0.0, -h / 2.0 + current_offset_y)
		book.dynamic_poly.visible = false
		
		if book.dynamic_poly.has_method("rebuild"):
			book.dynamic_poly.rebuild(book.target_page_size)
		
		book._dyn_poly_flat = book.dynamic_poly.polygon
		book._dyn_colors_flat = PackedColorArray()
		book._dyn_poly_curved = book._dyn_poly_flat.duplicate()
		book._dyn_colors_curved = PackedColorArray()
		
		for i in range(book._dyn_poly_flat.size()):
			book._dyn_colors_flat.append(Color.WHITE)
			var pt = book._dyn_poly_flat[i]
			var dist = abs(pt.x) / w
			var out_dist = 1.0 - dist
			var curve = 0.0
			var outer_curve = 0.0
			
			if dist < book.spine_curl_width and book.spine_curl_width > 0:
				var n = 1.0 - (dist / book.spine_curl_width)
				curve = n * n
				
			if out_dist < book.outer_droop_width and book.outer_droop_width > 0:
				var n = 1.0 - (out_dist / book.outer_droop_width)
				outer_curve = n * n
				
			book._dyn_poly_curved[i] = Vector2(pt.x, pt.y + (curve * book.spine_curl_intensity) + (outer_curve * book.outer_droop_intensity))
			var dyn_shadow = 1.0 - (curve * book.spine_shadow_darkness)
			book._dyn_colors_curved.append(Color(dyn_shadow, dyn_shadow, dyn_shadow, 1.0))
			
		book.dynamic_poly.polygons = []
		book.dynamic_poly.polygon = book._dyn_poly_flat
		book.dynamic_poly.vertex_colors = book._dyn_colors_flat
		book.dynamic_poly.polygons = grid_polys

		var dyn_sh = book.visuals_container.get_node_or_null("InnerDynamicShadow")
		if dyn_sh:
			sync_skeleton_to_shadow(book.dynamic_poly, dyn_sh)
			var dyn_sh_flat_colors = PackedColorArray()
			
			for pt in book._dyn_poly_flat:
				dyn_sh_flat_colors.append(Color(0.0, 0.0, 0.0, 0.0))
				
			dyn_sh.polygons = []
			dyn_sh.polygon = book._dyn_poly_flat
			dyn_sh.uv = book.dynamic_poly.uv
			dyn_sh.vertex_colors = dyn_sh_flat_colors
			dyn_sh.polygons = book.dynamic_poly.polygons
			dyn_sh.position = book.dynamic_poly.position
			dyn_sh.scale = book.dynamic_poly.scale

	build_spine()
	
	if book.get("volume_manager") != null and book.volume_manager.has_method("generate_volume_layers"):
		book.volume_manager.generate_volume_layers()
		
	fit_camera_to_book()
	
	if book.is_inside_tree() and not book.is_animating:
		update_static_visuals_immediate()
		
		if book.get("volume_manager") != null and book.volume_manager.has_method("update_stack_direct"):
			book.volume_manager.update_stack_direct(book._current_expansion_factor, book._visual_spread_index)


## Fits the editor camera precisely to the size of the book.
func fit_camera_to_book() -> void:
	var cam = book.get_node_or_null("Camera2D")
	if not cam: return
	var total_book_width = book.target_page_size.x * 2.0
	var total_book_height = book.target_page_size.y * 2.0
	var margin = 1.0
	var required_width = total_book_width * margin
	var required_height = total_book_height * margin
	var screen_size = book.get_viewport_rect().size
	if screen_size == Vector2.ZERO: return
	var zoom_x = screen_size.x / required_width
	var zoom_y = screen_size.y / required_height
	var final_zoom = min(zoom_x, zoom_y)
	cam.zoom = Vector2(final_zoom, final_zoom)


## Rebuilds the geometry of the central spine to match sizes and offsets.
func build_spine() -> void:
	if book._spine_poly and is_instance_valid(book._spine_poly):
		book._spine_poly.queue_free()
	elif book.visuals_container.has_node("RuntimeSpine"):
		var node = book.visuals_container.get_node("RuntimeSpine")
		node.queue_free()
		book.visuals_container.remove_child(node)
		
	if book.spine_width <= 0:
		return
		
	book._spine_poly = Polygon2D.new()
	book._spine_poly.name = "RuntimeSpine"
	book._spine_poly.z_index = 1
	book._spine_poly.texture = book.spine_texture
	
	var hw = book.spine_width / 2.0 + 4
	var h = book.target_page_size.y
	
	var cover_h = h * book.cover_protrude_scale.y if book.covers_are_rigid else h
	var offset_y = book.cover_protrude_offset.y if book.covers_are_rigid else 0.0
	
	var top_y = - cover_h / 2.0 + offset_y
	var bot_y = cover_h / 2.0 + offset_y
	
	book._spine_poly.polygon = PackedVector2Array([Vector2(-hw, top_y), Vector2(hw, top_y), Vector2(hw, bot_y), Vector2(-hw, bot_y)])
	
	if book.spine_texture:
		var tw = book.spine_texture.get_width()
		var th = book.spine_texture.get_height()
		book._spine_poly.uv = PackedVector2Array([Vector2(0, 0), Vector2(tw, 0), Vector2(tw, th), Vector2(0, th)])
	else:
		book._spine_poly.color = book.spine_color
		
	if book.perspective_shader:
		book._spine_poly.material = ShaderMaterial.new()
		book._spine_poly.material.shader = book.perspective_shader
		
	book.visuals_container.add_child(book._spine_poly)
	book._spine_poly.position = book.volume_stack_offset
	
	if book.is_inside_tree() and Engine.is_editor_hint():
		book._spine_poly.owner = book.get_tree().edited_scene_root
		
	update_perspective(book._current_expansion_factor)
#endregion


#region Static Visual Synchronization
## Renders visuals out instantly bypassing natural timing delays.
func update_static_visuals_immediate() -> void:
	if book._poly_flat.size() == 0:
		apply_new_size()
		
	var idx_l = book._get_page_index_for_spread(book.current_spread, true)
	var idx_r = book._get_page_index_for_spread(book.current_spread, false)
	
	if book.get("content_manager") != null and book.content_manager.has_method("update_slot_content"):
		book.content_manager.update_slot_content(book._slot_1, idx_l, true)
		book.content_manager.update_slot_content(book._slot_2, idx_r, false)
		
	book.static_left.texture = book._slot_1.get_texture()
	book.static_right.texture = book._slot_2.get_texture()
	
	var valid_l = (idx_l != -999)
	var valid_r = (idx_r != -999)
	
	if book.has_method("_set_page_visible"):
		book._set_page_visible(book.static_left, valid_l)
		book._set_page_visible(book.static_right, valid_r)
		
	var l_is_cover = (idx_l <= -100) and book.covers_are_rigid
	var r_is_cover = (idx_r <= -100) and book.covers_are_rigid
	
	var c_scale_x = (book.page_width * book.cover_protrude_scale.x + book.cover_protrude_offset.x) / book.page_width
	
	var curve_factor = get_curve_factor_for_spread(float(book.current_spread))
	var blended = get_blended_arrays(curve_factor)
	var current_offset_y = book.inner_page_vertical_offset * curve_factor
	
	book.static_left.polygons = []
	if l_is_cover:
		book.static_left.polygon = book._poly_flat
		book.static_left.vertex_colors = book._colors_flat
		book.static_left.polygons = book._grid_polys
		book.static_left.scale = Vector2(c_scale_x, book.cover_protrude_scale.y)
		book.static_left.position = Vector2(-book.page_width * c_scale_x, book.cover_protrude_offset.y)
	else:
		book.static_left.polygon = blended.poly_l if blended.has("poly_l") and blended.poly_l.size() > 0 else book._poly_curved_l
		book.static_left.vertex_colors = blended.colors_l if blended.has("colors_l") and blended.colors_l.size() > 0 else book._colors_curved_l
		book.static_left.polygons = book._grid_polys
		book.static_left.scale = Vector2(1.0, 1.0)
		book.static_left.position = Vector2(-book.page_width, current_offset_y)
		
	book.static_right.polygons = []
	if r_is_cover:
		book.static_right.polygon = book._poly_flat
		book.static_right.vertex_colors = book._colors_flat
		book.static_right.polygons = book._grid_polys
		book.static_right.scale = Vector2(c_scale_x, book.cover_protrude_scale.y)
		book.static_right.position = Vector2(0, book.cover_protrude_offset.y)
	else:
		book.static_right.polygon = blended.poly_r if blended.has("poly_r") and blended.poly_r.size() > 0 else book._poly_curved_r
		book.static_right.vertex_colors = blended.colors_r if blended.has("colors_r") and blended.colors_r.size() > 0 else book._colors_curved_r
		book.static_right.polygons = book._grid_polys
		book.static_right.scale = Vector2(1.0, 1.0)
		book.static_right.position = Vector2(0, current_offset_y)
	
	if book.cover_left_poly:
		if book.current_spread == book.total_spreads:
			book.cover_left_poly.texture = book.tex_cover_front_out
		else:
			book.cover_left_poly.texture = book.tex_cover_front_in
		if book.has_method("_set_page_visible"):
			book._set_page_visible(book.cover_left_poly, book.current_spread > -1)
		
	if book.cover_right_poly:
		if book.current_spread == -1:
			book.cover_right_poly.texture = book.tex_cover_back_out
		else:
			book.cover_right_poly.texture = book.tex_cover_back_in
		if book.has_method("_set_page_visible"):
			book._set_page_visible(book.cover_right_poly, book.current_spread < book.total_spreads)

	var is_open = (book.current_spread >= 0 and book.current_spread < book.total_spreads)
	var has_l_stack = (is_open and book.current_spread > 0)
	var has_r_stack = (is_open and book.current_spread < book.total_spreads - 1)

	var cv_sh_l = book.visuals_container.get_node_or_null("CoverStackShadowLeft") if book.visuals_container else null
	if cv_sh_l:
		if book.has_method("_set_page_visible"):
			book._set_page_visible(cv_sh_l, is_open)
		cv_sh_l.modulate.a = 1.0 if is_open else 0.0

	var cv_sh_r = book.visuals_container.get_node_or_null("CoverStackShadowRight") if book.visuals_container else null
	if cv_sh_r:
		if book.has_method("_set_page_visible"):
			book._set_page_visible(cv_sh_r, is_open)
		cv_sh_r.modulate.a = 1.0 if is_open else 0.0

	var st_sh_l = book.visuals_container.get_node_or_null("StackDropShadowLeft") if book.visuals_container else null
	if st_sh_l:
		if book.has_method("_set_page_visible"):
			book._set_page_visible(st_sh_l, has_l_stack)
		
	var st_sh_r = book.visuals_container.get_node_or_null("StackDropShadowRight") if book.visuals_container else null
	if st_sh_r:
		if book.has_method("_set_page_visible"):
			book._set_page_visible(st_sh_r, has_r_stack)

	var sh_left = book.visuals_container.get_node_or_null("InnerShadowLeft") if book.visuals_container else null
	if sh_left:
		var show_sh_l = false
		if book.has_method("_set_page_visible"):
			book._set_page_visible(sh_left, show_sh_l)
		sh_left.modulate.a = 0.0
		
	var sh_right = book.visuals_container.get_node_or_null("InnerShadowRight") if book.visuals_container else null
	if sh_right:
		var show_sh_r = false
		if book.has_method("_set_page_visible"):
			book._set_page_visible(sh_right, show_sh_r)
		sh_right.modulate.a = 0.0
#endregion


#region Perspective Matrix Update
## Applies the perspective material parameters to a node.
func apply_perspective_to_node(node: Node2D, tl: Vector2, tr: Vector2, bl: Vector2, br: Vector2, bw: float, bh: float) -> void:
	if not node:
		return
		
	if node.material is ShaderMaterial:
		node.material.set_shader_parameter("top_left", tl)
		node.material.set_shader_parameter("top_right", tr)
		node.material.set_shader_parameter("bottom_left", bl)
		node.material.set_shader_parameter("bottom_right", br)
		node.material.set_shader_parameter("book_width", bw)
		node.material.set_shader_parameter("book_height", bh)
		node.material.set_shader_parameter("node_x_offset", node.position.x)
		node.material.set_shader_parameter("node_y_offset", node.position.y)
		node.material.set_shader_parameter("node_scale", node.scale)
		node.material.set_shader_parameter("dynamic_scale_corr", 1.0)


## Updates the perspective parameters based on the current expansion factor.
func update_perspective(factor: float) -> void:
	var tl = book.open_top_left.lerp(book.closed_top_left, factor)
	var tr = book.open_top_right.lerp(book.closed_top_right, factor)
	var bl = book.open_bottom_left.lerp(book.closed_bottom_left, factor)
	var br = book.open_bottom_right.lerp(book.closed_bottom_right, factor)
	var bw = book.target_page_size.x * 2.0
	var bh = book.target_page_size.y

	apply_perspective_to_node(book.static_left, tl, tr, bl, br, bw, bh)
	apply_perspective_to_node(book.static_right, tl, tr, bl, br, bw, bh)
	
	if book.cover_left_poly:
		apply_perspective_to_node(book.cover_left_poly, tl, tr, bl, br, bw, bh)
	if book.cover_right_poly:
		apply_perspective_to_node(book.cover_right_poly, tl, tr, bl, br, bw, bh)
		
	apply_perspective_to_node(book.dynamic_poly, tl, tr, bl, br, bw, bh)
	
	if book._spine_poly:
		apply_perspective_to_node(book._spine_poly, tl, tr, bl, br, bw, bh)

	if book.visuals_container:
		var cv_sh_l = book.visuals_container.get_node_or_null("CoverStackShadowLeft")
		if cv_sh_l:
			apply_perspective_to_node(cv_sh_l, tl, tr, bl, br, bw, bh)
		var cv_sh_r = book.visuals_container.get_node_or_null("CoverStackShadowRight")
		if cv_sh_r:
			apply_perspective_to_node(cv_sh_r, tl, tr, bl, br, bw, bh)
		var st_sh_l = book.visuals_container.get_node_or_null("StackDropShadowLeft")
		if st_sh_l:
			apply_perspective_to_node(st_sh_l, tl, tr, bl, br, bw, bh)
		var st_sh_r = book.visuals_container.get_node_or_null("StackDropShadowRight")
		if st_sh_r:
			apply_perspective_to_node(st_sh_r, tl, tr, bl, br, bw, bh)
		var sh_left = book.visuals_container.get_node_or_null("InnerShadowLeft")
		if sh_left:
			apply_perspective_to_node(sh_left, tl, tr, bl, br, bw, bh)
		var sh_right = book.visuals_container.get_node_or_null("InnerShadowRight")
		if sh_right:
			apply_perspective_to_node(sh_right, tl, tr, bl, br, bw, bh)
		var ds_poly = book.visuals_container.get_node_or_null("DropShadowPoly")
		if ds_poly:
			apply_perspective_to_node(ds_poly, tl, tr, bl, br, bw, bh)
			
		var dyn_sh = book.visuals_container.get_node_or_null("InnerDynamicShadow")
		if dyn_sh:
			apply_perspective_to_node(dyn_sh, tl, tr, bl, br, bw, bh)

	if book._volume_root:
		var vol_spine = book._volume_root.get_node_or_null("VolumeSpine")
		if vol_spine:
			apply_perspective_to_node(vol_spine, tl, tr, bl, br, bw, bh)
			
		var spine_cap = book._volume_root.get_node_or_null("SpineBottomCap")
		if spine_cap:
			apply_perspective_to_node(spine_cap, tl, tr, bl, br, bw, bh)
			
		for i in range(book._volume_root.get_child_count()):
			var layer = book._volume_root.get_child(i)
			if layer.name.begins_with("Layer_") and layer.get_child_count() >= 2:
				var l_node = layer.get_child(0)
				var r_node = layer.get_child(1)
				apply_perspective_to_node(l_node, tl, tr, bl, br, bw, bh)
				apply_perspective_to_node(r_node, tl, tr, bl, br, bw, bh)

	if book.dynamic_poly:
		var auto_shadow = book.dynamic_poly.get_node_or_null("AutoShadow")
		if auto_shadow and auto_shadow.material is ShaderMaterial:
			auto_shadow.material.set_shader_parameter("top_left", tl)
			auto_shadow.material.set_shader_parameter("top_right", tr)
			auto_shadow.material.set_shader_parameter("bottom_left", bl)
			auto_shadow.material.set_shader_parameter("bottom_right", br)
			auto_shadow.material.set_shader_parameter("book_width", bw)
			auto_shadow.material.set_shader_parameter("book_height", bh)
			auto_shadow.material.set_shader_parameter("node_x_offset", book.dynamic_poly.position.x)
			auto_shadow.material.set_shader_parameter("node_y_offset", book.dynamic_poly.position.y)
			auto_shadow.material.set_shader_parameter("node_scale", auto_shadow.scale * book.dynamic_poly.scale)
			auto_shadow.material.set_shader_parameter("dynamic_scale_corr", 1.0)
#endregion


#region Process Hook
## Processes the timeline and visual alignment updates during an active animation.
func process_animation_update(_delta: float) -> void:
	if not book._is_current_anim_rigid and book.dynamic_poly and book.dynamic_poly.visible and book.dynamic_poly.has_node("AutoSkeleton/Bone_0_0"):
		var sk = book.dynamic_poly.get_node("AutoSkeleton")
		var bone = sk.get_node("Bone_0_0") as Bone2D
		
		if bone:
			var current_curve_factor = get_curve_factor_for_spread(book._visual_spread_index)
			var current_offset_y = book.inner_page_vertical_offset * current_curve_factor
			var cos_factor = cos(bone.rotation)
			var pts = book._dyn_poly_flat.duplicate()
			var shadow_pts = book._dyn_poly_flat.duplicate()
			var w = book.target_page_size.x
			var colors = PackedColorArray()
			var dyn_shadow_colors = PackedColorArray()
			
			var light_factor = 0.0
			var shadow_fade_factor = 1.0
			
			if book.anim_player and book.anim_player.is_playing() and book.anim_player.current_animation_length > 0.0:
				var t = book.anim_player.current_animation_position / book.anim_player.current_animation_length
				var mid_ratio = 0.5
				
				if "timing_midpoint_ratio" in book.dynamic_poly:
					mid_ratio = book.dynamic_poly.get("timing_midpoint_ratio")
					
				mid_ratio = clampf(mid_ratio, 0.01, 0.99)
				
				# Calculate target_fade_t (when the page is fully landed and should match static page shading)
				var fade_target_t = 0.8
				if book.anim_player.speed_scale > 0:
					var motion_duration = book.anim_player.current_animation_length / book.anim_player.speed_scale
					var t_overlap = book.landing_overlap / motion_duration
					fade_target_t = clampf(1.0 - t_overlap, 0.6, 0.9)
					
				var end_ratio = fade_target_t
				
				if t < mid_ratio:
					var n = t / mid_ratio
					light_factor = smoothstep(0.0, 1.0, n)
				elif t >= end_ratio:
					light_factor = 0.0
				else:
					var n = (t - mid_ratio) / (end_ratio - mid_ratio)
					light_factor = smoothstep(1.0, 0.0, n)
					
				var half_first_part = mid_ratio * 0.5
				var half_second_part = mid_ratio + ((1.0 - mid_ratio) * 0.5)
				
				if t < half_first_part:
					shadow_fade_factor = 1.0
				elif t < mid_ratio:
					var n = (t - half_first_part) / (mid_ratio - half_first_part)
					shadow_fade_factor = lerp(1.0, book.min_shadow_opacity_during_flip, n)
				elif t < half_second_part:
					shadow_fade_factor = book.min_shadow_opacity_during_flip
				else:
					var n = (t - half_second_part) / (fade_target_t - half_second_part)
					shadow_fade_factor = lerp(book.min_shadow_opacity_during_flip, 1.0, clampf(n, 0.0, 1.0))
					
			for i in range(pts.size()):
				var pt = pts[i]
				var dist = abs(pt.x) / w
				var out_dist = 1.0 - dist
				var curve = 0.0
				var outer_curve = 0.0
				
				if dist < book.spine_curl_width and book.spine_curl_width > 0:
					var n = 1.0 - (dist / book.spine_curl_width)
					curve = n * n
					
				if out_dist < book.outer_droop_width and book.outer_droop_width > 0:
					var n = 1.0 - (out_dist / book.outer_droop_width)
					outer_curve = n * n
					
				var total_curve = (curve * book.spine_curl_intensity) + (outer_curve * book.outer_droop_intensity)
				total_curve *= current_curve_factor
				
				pts[i] = Vector2(pt.x, pt.y + (total_curve * cos_factor))
				shadow_pts[i] = Vector2(pt.x, pt.y + total_curve)
				
				var raw_shadow = 0.0
				var lit_base_val = 1.0
				
				colors.append(Color(lit_base_val, lit_base_val, lit_base_val, 1.0))
				dyn_shadow_colors.append(Color(0.0, 0.0, 0.0, raw_shadow))
				
			# Update viewport-based shadow overlay modulation
			var sh3 = get_spine_shadow_overlay(book._slot_3)
			if sh3:
				sh3.modulate.a = shadow_fade_factor
				
			var sh4 = get_spine_shadow_overlay(book._slot_4)
			if sh4:
				sh4.modulate.a = shadow_fade_factor
				
			book.dynamic_poly.position.y = - book.target_page_size.y / 2.0 + current_offset_y
			book.dynamic_poly.polygons = []
			book.dynamic_poly.polygon = pts
			book.dynamic_poly.vertex_colors = colors
			book.dynamic_poly.polygons = book._grid_polys
			
			var auto_shadow = book.dynamic_poly.get_node_or_null("AutoShadow")
			
			if auto_shadow:
				auto_shadow.polygons = []
				auto_shadow.polygon = shadow_pts
				auto_shadow.polygons = book._grid_polys
				
			var dyn_sh = book.visuals_container.get_node_or_null("InnerDynamicShadow")
			
			if dyn_sh:
				dyn_sh.polygons = []
				dyn_sh.polygon = pts
				dyn_sh.vertex_colors = dyn_shadow_colors
				dyn_sh.polygons = book.dynamic_poly.polygons
				dyn_sh.position = book.dynamic_poly.position
				dyn_sh.scale = book.dynamic_poly.scale
				dyn_sh.visible = book.dynamic_poly.visible


func get_spine_shadow_overlay(slot: SubViewport) -> TextureRect:
	if not slot:
		return null
	return slot.get_node_or_null("_SpineShadowOverlay") as TextureRect


#endregion
