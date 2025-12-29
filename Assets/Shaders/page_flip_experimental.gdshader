shader_type canvas_item;


// --- Textures ---

// Front image of the page
uniform sampler2D tex_front : source_color;


// Back image of the page (seen when curling)
uniform sampler2D tex_back : source_color;


// Static page to the left (background)
uniform sampler2D tex_static_left : source_color;


// Static page to the right (background)
uniform sampler2D tex_static_right : source_color;


// --- Configuration ---

// Page turn progress (0.0 to 1.0)
uniform float progress : hint_range(0.0, 1.0) = 0.0;


// View scale: Visually expands the node to leave margin for the turn.
uniform float view_scale : hint_range(1.0, 2.0) = 1.5;


// Controls how high the page lifts during the turn
uniform float fold_height : hint_range(0.0, 1.0) = 0.3;


// If true, flips the animation direction
uniform bool flip_left = false;


// --- Transform & Camera ---

// Global Zoom (1.0 = Default, >1.0 = Zoom In)
uniform float global_zoom : hint_range(0.1, 5.0) = 1.0;


// Global Position Offset
uniform vec2 global_offset = vec2(0.0, 0.0);


// Intensity of the 3D perspective effect
uniform float camera_fov : hint_range(0.0, 1.0) = 0.5;


// Rotation around X axis (Tilt up/down)
uniform float camera_rot_x : hint_range(-1.0, 1.0) = 0.0;


// Rotation around Y axis (Spin left/right)
uniform float camera_rot_y : hint_range(-1.0, 1.0) = 0.0;


// --- Aesthetics & Volume ---

// Strength of the shadows
uniform float shadow_strength : hint_range(0.0, 1.0) = 0.5;


// Strength of the specular highlight
uniform float specular_strength : hint_range(0.0, 1.0) = 0.7;


// Controls the softness/spread of the highlight (Lower = Softer/Wider)
uniform float specular_shininess : hint_range(1.0, 50.0) = 5.0;


// Thickness of the simulated paper stack
uniform float book_thickness : hint_range(0.0, 0.1) = 0.02;


// Color of the paper stack edges
uniform vec4 stack_color : source_color = vec4(0.9, 0.9, 0.9, 1.0);


varying vec2 v_uv;


// --- Functions ---

vec2 apply_camera_perspective(vec2 uv) {
	vec2 pivot = vec2(1.0, 1.0);
	vec2 p = uv - pivot;
	float z = 1.0 + p.x * camera_rot_y + p.y * camera_rot_x;
	z = max(0.1, z);
	float fov_factor = 1.0 + camera_fov;
	p = p / (z * fov_factor);
	return p + pivot;
}


int get_page_state(vec2 uv, vec2 mouse, vec2 top_right, inout vec2 sample_uv, out float dist_to_fold) {
	vec2 to_edge = top_right - mouse;
	if (length(to_edge) < 0.001) { dist_to_fold = 1.0; return 0; }
	
	vec2 to_edge_n = normalize(to_edge);
	vec2 to_pixel = uv - mouse;
	vec2 diagonal = normalize(vec2(1.0));
	float cos_t = dot(to_edge_n, diagonal);
	float cos_t2 = 2.0 * cos_t * cos_t - 1.0;
	vec2 to_edge_perp = vec2(to_edge_n.y, -to_edge_n.x);
	float dir = sign(dot(to_edge_perp, diagonal));
	float sin_t2 = dir * sqrt(1.0 - cos_t2 * cos_t2);
	vec2 next_page_up = vec2(-sin_t2, cos_t2);
	vec2 next_page_right = vec2(next_page_up.y, -next_page_up.x);
	
	if (dot(to_pixel, next_page_up) >= 0.0 && dot(to_pixel, next_page_right) >= 0.0) {
		vec2 half_point = mouse + to_edge * 0.5;
		vec2 to_pix_hp = uv - half_point;
		float proj = dot(to_edge_perp, (uv - half_point));
		vec2 proj_point = half_point + to_edge_perp * proj;
		dist_to_fold = distance(proj_point, uv) / distance(mouse, half_point);
		
		if (dot(to_pix_hp, to_edge) < 0.0) {
			sample_uv = (sample_uv - mouse);
			sample_uv = vec2(sample_uv.y, -sample_uv.x);
			mat2 rot = mat2(vec2(cos_t2, -sin_t2), vec2(sin_t2, cos_t2));
			sample_uv = rot * sample_uv;
			sample_uv.y *= -1.0;
			sample_uv.y = 1.0 - sample_uv.y;
			return 1;
		} else { return 2; }
	}
	vec2 half_point = mouse + to_edge * 0.5;
	vec2 to_edge_perp_shadow = vec2(to_edge_n.y, -to_edge_n.x);
	float proj = dot(to_edge_perp_shadow, (uv - half_point));
	vec2 proj_point = half_point + to_edge_perp_shadow * proj;
	dist_to_fold = distance(proj_point, uv) / distance(mouse, half_point);
	return 0;
}


float gaussian(float x, float center, float width) {
	return exp(-pow(x - center, 2.0) * width);
}


float paper_stack_pattern(vec2 uv) {
	return 0.95 + 0.05 * sin(uv.y * 400.0);
}


void vertex() {
	v_uv = (UV - 0.5) * view_scale + 1.0;
	vec2 tex_size = 1.0 / TEXTURE_PIXEL_SIZE;
	vec2 center = tex_size * 0.5;
	VERTEX = (VERTEX - center) * view_scale + center;
}


void fragment() {
	// --- TRANSFORMATIONS START ---
	vec2 uv_work = v_uv;
	
	// 1. Apply Offset
	uv_work -= global_offset;
	
	// 2. Apply Zoom (Scale around center 1.0, 1.0)
	vec2 pivot = vec2(1.0, 1.0);
	uv_work = (uv_work - pivot) / global_zoom + pivot;
	
	// 3. Apply Fake 3D Camera
	vec2 uv_distorted = apply_camera_perspective(uv_work);
	// --- TRANSFORMATIONS END ---
	
	
	// Prepare coordinate space for Page Logic
	// uv_paper is the "Physical" space.
	// It is inverted on Y, and inverted on X if flip_left is true.
	vec2 uv_paper = uv_distorted;
	if (flip_left) uv_paper.x = 1.0 - uv_paper.x; 
	uv_paper.y = 1.0 - uv_paper.y;                
	uv_paper.x = (uv_paper.x - 0.5) * 2.0;        
	
	// Animation Logic
	vec2 p_start = vec2(1.0, 1.0);
	vec2 p_mid = vec2(0.1, fold_height);
	vec2 p_end = vec2(-1.0, 1.0);
	vec2 mouse_pos = (progress < 0.5) ? mix(p_start, p_mid, progress * 2.0) : mix(p_mid, p_end, (progress - 0.5) * 2.0);
	
	vec2 spine_origin = vec2(0.0, 1.0);
	vec2 spine_vec = mouse_pos - spine_origin;
	mouse_pos = spine_origin + normalize(spine_vec) * min(length(spine_vec), 1.4);
	
	vec2 sample_uv = uv_paper;
	float dist_to_fold = 0.0;
	
	int state = get_page_state(uv_paper, mouse_pos, vec2(1.0, 1.0), sample_uv, dist_to_fold);
	
	vec2 tex_uv = sample_uv;
	tex_uv.y = 1.0 - tex_uv.y;
	if (flip_left) tex_uv.x = 1.0 - tex_uv.x;
	
	vec3 col = vec3(0.0);
	float alpha = 0.0;
	float anim_strength = sin(progress * 3.14159);
	
	
	// --- A. ANIMATED PAGE ---
	if (tex_uv.x >= 0.0 && tex_uv.x <= 1.0 && tex_uv.y >= 0.0 && tex_uv.y <= 1.0) {
		if (state == 0) {
			col = texture(tex_front, tex_uv).rgb;
			float shadow = smoothstep(0.70, 1.0, 1.0 - dist_to_fold);
			col *= (1.0 - shadow * shadow_strength * anim_strength);
			alpha = 1.0;
		} else if (state == 1) {
			col = texture(tex_back, tex_uv).rgb;
			float highlight = gaussian(dist_to_fold, 0.40, specular_shininess);
			col += vec3(1.0) * highlight * specular_strength * anim_strength;
			float darken_factor = smoothstep(0.0, 0.6, dist_to_fold);
			float darken_val = mix(0.9, 1.0, darken_factor); 
			col *= mix(1.0, darken_val, anim_strength);
			alpha = 1.0;
		}
	}
	
	
	// --- B. STATIC BACKGROUND ---
	if (alpha < 0.1) {
		
		// 1. Recover "Real" Background Coordinates
		// We use the distorted/zoomed coordinates directly.
		vec2 bg_coord = uv_distorted;
		bg_coord.y = 1.0 - bg_coord.y;         
		bg_coord.x = (bg_coord.x - 0.5) * 2.0; 
		
		bool is_right_side = (bg_coord.x >= 0.0 && bg_coord.x <= 1.0 && bg_coord.y >= 0.0 && bg_coord.y <= 1.0);
		bool is_left_side = (bg_coord.x < 0.0 && bg_coord.x >= -1.0 && bg_coord.y >= 0.0 && bg_coord.y <= 1.0);
		
		// 2. Stack Thickness (Volume)
		vec2 bg_coord_shifted = bg_coord;
		bg_coord_shifted.y += book_thickness; 
		
		bool stack_right = (bg_coord_shifted.x >= 0.0 && bg_coord_shifted.x <= 1.0 && bg_coord_shifted.y >= 0.0 && bg_coord_shifted.y <= 1.0);
		bool stack_left = (bg_coord_shifted.x < 0.0 && bg_coord_shifted.x >= -1.0 && bg_coord_shifted.y >= 0.0 && bg_coord_shifted.y <= 1.0);
		
		if ((stack_right && !is_right_side) || (stack_left && !is_left_side)) {
			col = stack_color.rgb * paper_stack_pattern(v_uv);
			col *= 0.8;
			alpha = 1.0;
		}
		
		// 3. Static Textures
		bool drawn_bg = false;
		
		if (is_right_side) {
			vec2 static_uv = vec2(bg_coord.x, 1.0 - bg_coord.y);
			col = texture(tex_static_right, static_uv).rgb;
			alpha = 1.0;
			drawn_bg = true;
		} 
		else if (is_left_side) {
			vec2 margin_uv = vec2(bg_coord.x + 1.0, 1.0 - bg_coord.y);
			col = texture(tex_static_left, margin_uv).rgb;
			alpha = 1.0;
			drawn_bg = true;
		}
		
		// 4. Drop Shadow
		if (drawn_bg) {
			vec2 corner = vec2(1.0, 1.0);
			vec2 to_corner = corner - mouse_pos;
			vec2 midpoint = mouse_pos + to_corner * 0.5;
			vec2 fold_normal = normalize(to_corner);
			float dist_to_line = dot(fold_normal, uv_paper - midpoint);
			
			float drop_shadow = smoothstep(0.15, 0.0, abs(dist_to_line));
			col *= (1.0 - drop_shadow * shadow_strength * anim_strength);
		}
	}
	
	COLOR = vec4(col, alpha);
}