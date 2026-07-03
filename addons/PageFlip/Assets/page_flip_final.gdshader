shader_type canvas_item;

/* Front texture for face A */
uniform sampler2D front_texture : source_color, filter_linear_mipmap;
/* Back texture for face B */
uniform sampler2D back_texture : source_color, filter_linear_mipmap;

/* Dynamic shadow gradient texture */
uniform sampler2D spine_shadow_gradient : source_color, filter_linear, repeat_disable;

/* Shadow intensity modifier */
uniform float shadow_intensity : hint_range(0.0, 1.0) = 0.0;

/* Maximum spread limit for the shadow */
uniform float max_shadow_spread : hint_range(0.0, 1.0) = 0.35;

/* Toggle visual debug mode */
uniform bool debug_mode = false;

/* Top left offset for perspective */
uniform vec2 top_left = vec2(0.0, 0.0);
/* Top right offset for perspective */
uniform vec2 top_right = vec2(0.0, 0.0);
/* Bottom left offset for perspective */
uniform vec2 bottom_left = vec2(0.0, 0.0);
/* Bottom right offset for perspective */
uniform vec2 bottom_right = vec2(0.0, 0.0);

/* Total physical width of the book */
uniform float book_width = 1024.0;
/* Total physical height of the book */
uniform float book_height = 820.0;
/* X offset to align local vertices with global book center */
uniform float node_x_offset = 0.0;
/* Y offset to align local vertices vertically */
uniform float node_y_offset = 0.0;
/* Node scale to counteract transform scaling on absolute offsets */
uniform vec2 node_scale = vec2(1.0, 1.0);
/* Horizontal scale correction applied directly to the mesh vertices */
uniform float dynamic_scale_corr = 1.0;

void vertex() {
	VERTEX.x *= dynamic_scale_corr;

	float real_x = (VERTEX.x * node_scale.x) + node_x_offset;
	float real_y = (VERTEX.y * node_scale.y) + node_y_offset;
	
	vec2 norm_pos = vec2(
		(real_x + (book_width * 0.5)) / book_width,
		(real_y + (book_height * 0.5)) / book_height
	);
	
	vec2 top_offset = mix(top_left, top_right, norm_pos.x);
	vec2 bottom_offset = mix(bottom_left, bottom_right, norm_pos.x);
	vec2 final_offset = mix(top_offset, bottom_offset, norm_pos.y);
	
	vec2 safe_scale = node_scale;
	if (abs(safe_scale.x) < 0.0001) safe_scale.x = 0.0001 * sign(safe_scale.x != 0.0 ? safe_scale.x : 1.0);
	if (abs(safe_scale.y) < 0.0001) safe_scale.y = 0.0001 * sign(safe_scale.y != 0.0 ? safe_scale.y : 1.0);
	
	VERTEX += final_offset / safe_scale;
}

void fragment() {
	vec2 uv_dx = dFdx(UV);
	vec2 uv_dy = dFdy(UV);
	float face_dir = uv_dx.x * uv_dy.y - uv_dx.y * uv_dy.x;
	bool is_front = face_dir > 0.0;

	vec4 base_color;
	if (is_front) {
		base_color = texture(front_texture, UV);
		if (debug_mode) base_color = vec4(0.0, 1.0, 0.0, 0.5);
	} else {
		base_color = texture(back_texture, vec2(1.0 - UV.x, UV.y));
		if (debug_mode) base_color = vec4(1.0, 0.0, 0.0, 0.5);
	}

	COLOR = base_color;
}