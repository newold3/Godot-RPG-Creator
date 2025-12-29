@tool
class_name DynamicPage
extends Polygon2D

# ==============================================================================
# ENUMS & CONSTANTS
# ==============================================================================

## Defines the material physical properties for the page simulation.
enum PagePreset {
	CUSTOM,
	DEFAULT,
	STANDARD_PAPER,
	HEAVY_GRIMOIRE,
	LIGHT_MAGAZINE,
	OLD_SCROLL,
	RIGID_BOARD,
	WET_CLOTH,
	PLASTIC_SHEET,
	METAL_PLATE
}

## Determines the direction of the page turn curve.
enum CurlMode {
	STRAIGHT,
	TOP_CORNER_FIRST,
	BOTTOM_CORNER_FIRST
}

const SKELETON_NAME = "AutoSkeleton"
const SHADOW_NAME = "AutoShadow"


# ==============================================================================
# SIGNALS
# ==============================================================================

signal change_page_requested
signal end_animation


# ==============================================================================
# INTERNAL CACHE
# ==============================================================================

var _custom_cache: Dictionary = {}


# ==============================================================================
# CONFIGURATION
# ==============================================================================

@export_category("Rig Generator")

## Horizontal mesh subdivision. Higher values create smoother bends.
@export_range(1, 20) var subdivision_x: int = 8
## Vertical mesh subdivision. Higher values allow for better corner curling.
@export_range(1, 10) var subdivision_y: int = 5
## Generates the mesh, skeleton, weights and animations.
@export var rebuild_all: bool = false : set = _on_generate_pressed


@export_category("Animation Generator")

@export_group("Quick Presets")
## Select a material style to auto-configure physics.
@export var animation_preset: PagePreset = PagePreset.CUSTOM : set = _on_preset_changed


@export_group("Manual Configuration")
## The AnimationPlayer node to store the generated animations.
@export var anim_player: AnimationPlayer
## Duration of the page turn animation in seconds.
@export var anim_duration: float = 0.75


@export_subgroup("Paper Physics")
## Stiffness of the material. 0.5 = Rubber, 5.0 = Wood.
@export_range(0.5, 5.0, 0.1) var paper_stiffness: float = 2.0
## Bend angle during the lift phase (Negative = Tip drags down).
@export_range(-180.0, 180.0) var lift_bend: float = -10.0
## Bend angle during the landing phase (Negative = Tip floats up).
@export_range(-180.0, 180.0) var land_bend: float = -8.0


@export_subgroup("Curl Effect")
## Which part of the page initiates the movement.
@export var curl_mode: CurlMode = CurlMode.TOP_CORNER_FIRST
## Time delay for the trailing corner (0.0 = None, 1.0 = High lag).
@export_range(0.0, 1.0, 0.05) var curl_lag: float = 0.8


@export_subgroup("Shadow FX")
## Create a dynamic shadow behind the page (Background Shadow).
@export var enable_shadow: bool = true
## The gradient texture used for the back shadow.
@export var shadow_gradient: GradientTexture2D


@export_subgroup("Fine Timing")
## Normalized time (0.0 - 1.0) for the peak lift position.
@export_range(0.05, 0.45, 0.01) var timing_peak_lift: float = 0.15
## Normalized time (0.0 - 1.0) for the landing contact.
@export_range(0.55, 0.95, 0.01) var timing_peak_land: float = 0.85

@export var generate_anims_btn: bool = false : set = _on_anim_pressed


# ==============================================================================
# RUNTIME INITIALIZATION
# ==============================================================================

func _ready():
	self.z_index = 10
	if animation_preset == PagePreset.CUSTOM:
		_save_state_to_cache()


func rebuild(current_page_size: Vector2 = Vector2.ZERO) -> void:
	if not anim_player: return
	_clean_previous_rig()
	_create_rig_logic(current_page_size)
	_generate_animations_logic()


# ==============================================================================
# PRESET LOGIC
# ==============================================================================

func _on_preset_changed(val):
	if animation_preset == PagePreset.CUSTOM:
		_save_state_to_cache()
	
	animation_preset = val
	
	if val == PagePreset.CUSTOM:
		if not _custom_cache.is_empty():
			_load_state_from_cache()
			print("[PageRigger] Restored Custom Settings.")
		notify_property_list_changed()
		return
	
	# Defaults
	curl_mode = CurlMode.BOTTOM_CORNER_FIRST
	curl_lag = 0.3
	enable_shadow = true
	anim_duration = 0.75
	
	match val:
		PagePreset.DEFAULT:
			paper_stiffness = 2.0; lift_bend = -15.0; land_bend = 5.0
			curl_mode = CurlMode.TOP_CORNER_FIRST; curl_lag = 0.5
			anim_duration = 0.75; timing_peak_lift = 0.15; timing_peak_land = 0.85
			
		PagePreset.STANDARD_PAPER:
			paper_stiffness = 2.5; lift_bend = -12.0; land_bend = 3.0
			curl_mode = CurlMode.TOP_CORNER_FIRST; curl_lag = 0.4
			anim_duration = 0.65; timing_peak_lift = 0.12; timing_peak_land = 0.88
			
		PagePreset.HEAVY_GRIMOIRE:
			paper_stiffness = 4.0; lift_bend = -3.0; land_bend = 1.0
			curl_mode = CurlMode.STRAIGHT; curl_lag = 0.1
			anim_duration = 1.1; timing_peak_lift = 0.25; timing_peak_land = 0.75
			
		PagePreset.LIGHT_MAGAZINE:
			paper_stiffness = 0.8; lift_bend = -16.0; land_bend = 0.0
			curl_mode = CurlMode.BOTTOM_CORNER_FIRST; curl_lag = 0.6
			anim_duration = 0.8; timing_peak_lift = 0.10; timing_peak_land = 0.92
			
		PagePreset.OLD_SCROLL:
			paper_stiffness = 1.8; lift_bend = -20.0; land_bend = 8.0
			curl_mode = CurlMode.TOP_CORNER_FIRST; curl_lag = 0.9
			anim_duration = 0.9; timing_peak_lift = 0.18; timing_peak_land = 0.82
			
		PagePreset.RIGID_BOARD:
			paper_stiffness = 5.0; lift_bend = 0.0; land_bend = 0.0
			curl_mode = CurlMode.STRAIGHT; curl_lag = 0.0
			anim_duration = 0.8; timing_peak_lift = 0.2; timing_peak_land = 0.8
			
		PagePreset.WET_CLOTH:
			paper_stiffness = 0.3; lift_bend = -28.0; land_bend = -0.0
			curl_mode = CurlMode.BOTTOM_CORNER_FIRST; curl_lag = 0.6
			anim_duration = 1.3; timing_peak_lift = 0.2; timing_peak_land = 0.95
			
		PagePreset.PLASTIC_SHEET:
			paper_stiffness = 3.5; lift_bend = -12.0; land_bend = 12.0
			curl_mode = CurlMode.TOP_CORNER_FIRST; curl_lag = 0.2
			anim_duration = 0.5; timing_peak_lift = 0.08; timing_peak_land = 0.92
			
		PagePreset.METAL_PLATE:
			paper_stiffness = 5.0; lift_bend = 0.0; land_bend = 0.0
			curl_mode = CurlMode.STRAIGHT; curl_lag = 0.0
			anim_duration = 1.4; timing_peak_lift = 0.15; timing_peak_land = 0.98
	
	notify_property_list_changed()
	if anim_player and skeleton != NodePath(""):
		_generate_animations_logic()
		print("[PageRigger] Preset Applied: ", PagePreset.keys()[val])


func _save_state_to_cache():
	_custom_cache = {
		"stiffness": paper_stiffness, "lift": lift_bend, "land": land_bend,
		"curl_m": curl_mode, "curl_l": curl_lag,
		"t_lift": timing_peak_lift, "t_land": timing_peak_land,
		"dur": anim_duration, "shadow": enable_shadow
	}


func _load_state_from_cache():
	paper_stiffness = _custom_cache.get("stiffness", 1.5)
	lift_bend = _custom_cache.get("lift", -30.0)
	land_bend = _custom_cache.get("land", -15.0)
	curl_mode = _custom_cache.get("curl_m", CurlMode.BOTTOM_CORNER_FIRST)
	curl_lag = _custom_cache.get("curl_l", 0.3)
	timing_peak_lift = _custom_cache.get("t_lift", 0.15)
	timing_peak_land = _custom_cache.get("t_land", 0.85)
	anim_duration = _custom_cache.get("dur", 1.0)
	enable_shadow = _custom_cache.get("shadow", true)


# ==============================================================================
# RIGGING LOGIC
# ==============================================================================

func _calculate_polygon_rect() -> Rect2:
	if polygon.size() == 0:
		return Rect2(0,0,0,0)
	
	var min_v = polygon[0]
	var max_v = polygon[0]
	
	for v in polygon:
		min_v.x = min(min_v.x, v.x)
		min_v.y = min(min_v.y, v.y)
		max_v.x = max(max_v.x, v.x)
		max_v.y = max(max_v.y, v.y)
		
	return Rect2(min_v, max_v - min_v)


func _create_rig_logic(current_page_size: Vector2 = Vector2.ZERO):
	self.z_index = 10
	
	var original_size = Vector2(512, 820)
	var tex_size: Vector2 = Vector2.ZERO
	if current_page_size != Vector2.ZERO:
		tex_size = current_page_size
	elif texture:
		tex_size = texture.get_size()
	if tex_size == Vector2.ZERO:
		tex_size = original_size
	
	var step_x = tex_size.x / subdivision_x
	var step_y = tex_size.y / subdivision_y
	
	# Prepare Gradient Texture for Background Shadow
	var applied_shadow_tex: Texture2D = null
	if not shadow_gradient:
		shadow_gradient = preload("uid://rm7bporlv3cf")
	var dup = shadow_gradient.duplicate()
	if dup is GradientTexture2D:
		dup.width = int(tex_size.x)
	applied_shadow_tex = dup
	
	# --- 0. BACKGROUND SHADOW ---
	if enable_shadow:
		var shadow = Polygon2D.new()
		shadow.name = SHADOW_NAME
		shadow.z_index = -1
		
		if applied_shadow_tex:
			shadow.texture = applied_shadow_tex
			shadow.color = Color.WHITE
		else:
			shadow.color = Color(0, 0, 0, 0.5)
			
		var margin = 4.0
		shadow.polygon = PackedVector2Array([
			Vector2(margin, margin), Vector2(tex_size.x - margin, margin),
			Vector2(tex_size.x - margin, tex_size.y - margin), Vector2(margin, tex_size.y - margin)
		])
		shadow.uv = shadow.polygon
		add_child(shadow)
		if Engine.is_editor_hint() and get_tree().edited_scene_root:
			shadow.owner = get_tree().edited_scene_root

	# --- 1. MESH & UV ---
	var new_uvs = PackedVector2Array()
	for y in range(subdivision_y + 1):
		for x in range(subdivision_x + 1):
			new_uvs.append(Vector2(x * step_x, y * step_y))
	self.uv = new_uvs
	self.polygon = new_uvs
	
	var new_polygons = []
	var rc = subdivision_x + 1
	for y in range(subdivision_y):
		for x in range(subdivision_x):
			var i = y * rc + x
			new_polygons.append(PackedInt32Array([i, i + 1, i + rc + 1, i + rc]))
	self.polygons = new_polygons
	
	# --- 2. SKELETON ---
	var sk = Skeleton2D.new()
	sk.name = SKELETON_NAME
	add_child(sk)
	if Engine.is_editor_hint() and get_tree().edited_scene_root:
		sk.owner = get_tree().edited_scene_root
	self.skeleton = NodePath(SKELETON_NAME)
	
	# --- 3. BONES (Structured Hierarchy) ---
	for y in range(subdivision_y + 1):
		var parent_bone: Bone2D = null
		
		for x in range(subdivision_x + 1):
			var b = Bone2D.new()
			b.name = "Bone_%d_%d" % [x, y]
			b.set_autocalculate_length_and_angle(false)
			b.set_length(step_x)
			
			if x == 0:
				# Root bone (Spine)
				sk.add_child(b)
				b.position = Vector2(0, y * step_y)
			else:
				# Child bone
				if parent_bone:
					parent_bone.add_child(b)
				b.position = Vector2(step_x, 0)
			
			if Engine.is_editor_hint() and get_tree().edited_scene_root:
				b.owner = get_tree().edited_scene_root
			
			b.set_rest(b.transform)
			parent_bone = b
	
	# --- 4. WEIGHTS (Gradient Skinning) ---
	_apply_weights_to_polygon(self, sk)

	queue_redraw()
	notify_property_list_changed()


func _apply_weights_to_polygon(poly: Polygon2D, sk: Skeleton2D):
	poly.clear_bones()
	
	var bone_map = {}
	for y in range(subdivision_y + 1):
		for x in range(subdivision_x + 1):
			var bname = "Bone_%d_%d" % [x, y]
			var bone_node = sk.find_child(bname, true, false)
			if bone_node:
				bone_map[bname] = bone_node.get_path()

	var vertex_count = poly.polygon.size()
	
	var weights_per_bone = {}
	
	for bpath in bone_map.values():
		var w_arr = PackedFloat32Array()
		w_arr.resize(vertex_count)
		w_arr.fill(0.0)
		weights_per_bone[bpath] = w_arr
	
	var vert_idx = 0
	for y in range(subdivision_y + 1):
		for x in range(subdivision_x + 1):
			var primary_name = "Bone_%d_%d" % [x, y]
			var prev_name = "Bone_%d_%d" % [x - 1, y]
			var next_name = "Bone_%d_%d" % [x + 1, y]
			
			var primary_path = bone_map.get(primary_name)
			var prev_path = bone_map.get(prev_name)
			var next_path = bone_map.get(next_name)
			
			var w_center = 0.7
			var w_neighbor = 0.15
			
			if primary_path: weights_per_bone[primary_path][vert_idx] += w_center
			if prev_path: weights_per_bone[prev_path][vert_idx] += w_neighbor
			else: weights_per_bone[primary_path][vert_idx] += w_neighbor
			if next_path: weights_per_bone[next_path][vert_idx] += w_neighbor
			else: weights_per_bone[primary_path][vert_idx] += w_neighbor
			
			vert_idx += 1

	for bpath in weights_per_bone:
		poly.add_bone(bpath, weights_per_bone[bpath])


# ==============================================================================
# ANIMATION LOGIC
# ==============================================================================

func _generate_animations_logic():
	var library: AnimationLibrary
	if anim_player.has_animation_library(""): library = anim_player.get_animation_library("")
	else: library = AnimationLibrary.new(); anim_player.add_animation_library("", library)
	
	_create_single_anim(library, "turn_flexible_page", false, false)
	_create_single_anim(library, "turn_rigid_page", true, false)
	_create_single_anim(library, "turn_flexible_page_mirror", false, true)
	_create_single_anim(library, "turn_rigid_page_mirror", true, true)
	notify_property_list_changed()


func _create_single_anim(library: AnimationLibrary, anim_name: String, is_rigid: bool, is_mirror: bool):
	var anim = Animation.new()
	anim.length = anim_duration
	anim.step = 0.01
	
	if library.has_animation(anim_name): library.remove_animation(anim_name)
	library.add_animation(anim_name, anim)
	
	var sk_node = find_child(SKELETON_NAME, true, false)
	if not sk_node: return
	
	var my_path = anim_player.get_node(anim_player.root_node).get_path_to(self)
	
	var visible_col = Color(1, 1, 1, 1)
	var invisible_col = Color(1, 1, 1, 0)
	var faded_col = Color(1, 1, 1, 0.6)
	
	var t_mid = anim_duration * 0.5
	var t_end_snap = anim_duration * 0.95
	
	# ==========================================================================
	# 1. VISIBILITY & Z-INDEX
	# ==========================================================================
	var z_track = anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(z_track, str(my_path) + ":z_index")
	anim.track_set_interpolation_type(z_track, Animation.INTERPOLATION_NEAREST)
	anim.track_insert_key(z_track, 0.0, 10)
	anim.track_insert_key(z_track, anim_duration * 0.15, 25)
	anim.track_insert_key(z_track, anim_duration * 0.65, 10)

	# ==========================================================================
	# 2. BACKGROUND SHADOW
	# ==========================================================================
	var shadow_node = find_child(SHADOW_NAME, true, false)
	if shadow_node and enable_shadow:
		var shadow_path = anim_player.get_node(anim_player.root_node).get_path_to(shadow_node)
		var t_scale = anim.add_track(Animation.TYPE_VALUE)
		anim.track_set_path(t_scale, str(shadow_path) + ":scale")
		anim.track_set_interpolation_type(t_scale, Animation.INTERPOLATION_CUBIC)
		var t_mod = anim.add_track(Animation.TYPE_VALUE)
		anim.track_set_path(t_mod, str(shadow_path) + ":modulate")
		
		var s_start = Vector2(-1.0, 1.0) if is_mirror else Vector2(1.0, 1.0)
		var s_end = Vector2(1.0, 1.0) if is_mirror else Vector2(-1.0, 1.0)
		
		anim.track_insert_key(t_scale, 0.0, s_start)
		anim.track_insert_key(t_mod, 0.0, invisible_col)
		anim.track_insert_key(t_mod, anim_duration * 0.1, visible_col)
		
		anim.track_insert_key(t_scale, t_mid, Vector2(0.01, 1.0))
		anim.track_insert_key(t_mod, t_mid, faded_col)
		
		anim.track_insert_key(t_scale, t_end_snap, s_end)
		anim.track_insert_key(t_scale, anim_duration, s_end)
		anim.track_insert_key(t_mod, t_end_snap, invisible_col)
		anim.track_insert_key(t_mod, anim_duration, invisible_col)

	# ==========================================================================
	# 3. BONE ANIMATION
	# ==========================================================================
	for y in range(subdivision_y + 1):
		var row_factor = 1.0
		if not is_rigid and curl_mode != CurlMode.STRAIGHT:
			var y_ratio = float(y) / float(max(1, subdivision_y))
			if curl_mode == CurlMode.TOP_CORNER_FIRST:
				row_factor = lerp(1.0, 1.0 - curl_lag, y_ratio)
			elif curl_mode == CurlMode.BOTTOM_CORNER_FIRST:
				row_factor = lerp(1.0 - curl_lag, 1.0, y_ratio)
		
		var time_offset = (1.0 - row_factor) * (anim_duration * 0.1)
		
		for x in range(subdivision_x + 1):
			var bone_name = "Bone_%d_%d" % [x, y]
			var bone = sk_node.find_child(bone_name, true, false)
			if not bone: continue
			
			var t_idx = anim.add_track(Animation.TYPE_VALUE)
			var path = anim_player.get_node(anim_player.root_node).get_path_to(bone)
			anim.track_set_path(t_idx, str(path) + ":rotation_degrees")
			anim.track_set_interpolation_type(t_idx, Animation.INTERPOLATION_CUBIC)
			
			var deg_flat_right = 0.0; var deg_flat_left = -179.9; var deg_mid = -90.0
			
			if is_rigid:
				if x == 0:
					var s = deg_flat_left if is_mirror else deg_flat_right
					var e = deg_flat_right if is_mirror else deg_flat_left
					anim.track_insert_key(t_idx, 0.0, s)
					anim.track_insert_key(t_idx, anim_duration * 0.5, deg_mid)
					anim.track_insert_key(t_idx, anim_duration, e)
				else:
					anim.track_insert_key(t_idx, 0.0, 0.0)
					anim.track_insert_key(t_idx, anim_duration, 0.0)
			else:
				var x_ratio = float(x) / float(subdivision_x)
				var influence = pow(x_ratio, paper_stiffness)
				var t_lift = clamp((anim_duration * timing_peak_lift) + time_offset, 0.0, (anim_duration * 0.5) - 0.05)
				var t_mid_bone = anim_duration * 0.5
				var t_land = clamp((anim_duration * timing_peak_land) - time_offset, t_mid_bone + 0.05, anim_duration)
				
				if x == 0:
					# ROOT BONE
					var s = deg_flat_left if is_mirror else deg_flat_right
					var e = deg_flat_right if is_mirror else deg_flat_left
					var sl = -15.0 * row_factor
					if is_mirror: sl = deg_flat_left - sl
					var slt = lerp(-90.0, -180.0, timing_peak_land)
					if is_mirror: slt = lerp(-90.0, 0.0, timing_peak_land)
					
					anim.track_insert_key(t_idx, 0.0, s)
					anim.track_insert_key(t_idx, t_lift, sl)
					anim.track_insert_key(t_idx, t_mid_bone, deg_mid)
					anim.track_insert_key(t_idx, t_land, slt)
					
					var t_settle = lerp(t_land, anim_duration, 0.7)
					var s_settle = lerp(slt, e, 0.85)
					anim.track_insert_key(t_idx, t_settle, s_settle)
					
					anim.track_insert_key(t_idx, anim_duration, e)
				else:
					# SURFACE BONES (CURVED)
					var bm = -1.0 if is_mirror else 1.0
					
					anim.track_insert_key(t_idx, 0.0, 0.0)
					anim.track_insert_key(t_idx, t_lift, lift_bend * row_factor * bm * influence)
					# REMOVED FORCED 0.0 AT MIDPOINT FOR ORGANIC CURVE
					
					var val_land = land_bend * row_factor * bm * influence
					anim.track_insert_key(t_idx, t_land, val_land)
					
					var t_settle = lerp(t_land, anim_duration, 0.75)
					anim.track_insert_key(t_idx, t_settle, val_land * 0.15)
					
					anim.track_insert_key(t_idx, anim_duration, 0.0)

	# ==========================================================================
	# 4. MAIN POLYGON SCALE ("SQUASH & STRETCH")
	# ==========================================================================
	if not is_rigid:
		var t_main_scale = anim.add_track(Animation.TYPE_VALUE)
		anim.track_set_path(t_main_scale, str(my_path) + ":scale")
		anim.track_set_interpolation_type(t_main_scale, Animation.INTERPOLATION_LINEAR)
		var squash_x = 0.88
		
		anim.track_insert_key(t_main_scale, 0.0, Vector2(1, 1))
		anim.track_insert_key(t_main_scale, t_mid, Vector2(1, 1))
		anim.track_insert_key(t_main_scale, t_mid + (anim_duration * 0.1), Vector2(squash_x, 1))
		anim.track_insert_key(t_main_scale, anim_duration * 0.85, Vector2(1, 1))
		anim.track_insert_key(t_main_scale, anim_duration, Vector2(1, 1))

	var method_track = anim.add_track(Animation.TYPE_METHOD)
	anim.track_set_path(method_track, str(my_path))
	anim.track_insert_key(method_track, anim_duration * 0.5, {"method": "_trigger_midpoint", "args": []})
	anim.track_insert_key(method_track, anim_duration, {"method": "_trigger_end", "args": []})


# ==============================================================================
# HELPER FUNCTIONS
# ==============================================================================

func _trigger_midpoint(): emit_signal("change_page_requested")
func _trigger_end(): emit_signal("end_animation")


func _on_generate_pressed(val):
	if val:
		rebuild_all=false
		_clean_previous_rig()
		_create_rig_logic()
		_generate_animations_logic()


func _on_anim_pressed(val):
	if val:
		generate_anims_btn=false
		if anim_player and skeleton!=NodePath(""):
			_generate_animations_logic()


func _clean_previous_rig():
	for c in get_children():
		remove_child(c)
		c.free()
	var old_shadow = find_child(SHADOW_NAME, true, false)
	if old_shadow: old_shadow.free()
	clear_bones()
	skeleton = NodePath("")
