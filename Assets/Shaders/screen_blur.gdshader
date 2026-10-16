shader_type canvas_item;

/* Controls the maximum blur intensity */
uniform float blur_amount : hint_range(0.0, 5.0) = 3.0;

/* Shape type */
uniform int shape_type : hint_enum("Circle", "Square", "Rhombus", "Cross", "Hexagon") = 0;

/* Size of the central unblurred shape */
uniform float shape_size : hint_range(0.0, 1.0) = 0.3;

/* Smoothness of the transition between unblurred and blurred areas */
uniform float shape_smoothness : hint_range(0.001, 1.0) = 0.2;

/* Screen aspect ratio to keep shapes proportionate */
uniform float aspect_ratio = 1.7777;

/* Toggle for the player UV logic */
uniform bool use_player_uv = true;

/* Player position in screen space UV (0.0 to 1.0) */
uniform vec2 player_uv = vec2(0.5, 0.5);

/* Radius of the unblurred circle around the player */
uniform float player_mask_radius : hint_range(0.0, 1.0) = 0.15;

/* Smoothness of the player mask circle */
uniform float player_mask_smoothness : hint_range(0.001, 1.0) = 0.1;

/* Screen texture for the blur effect */
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;


void fragment() {
	vec2 centered_uv = SCREEN_UV - vec2(0.5);
	centered_uv.x *= aspect_ratio;
	
	float dist = 0.0;
	vec2 d = abs(centered_uv);
	
	if (shape_type == 0) {
		dist = length(centered_uv) - shape_size;
	} else if (shape_type == 1) {
		vec2 q = d - vec2(shape_size);
		dist = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0);
	} else if (shape_type == 2) {
		dist = (d.x + d.y) - shape_size;
	} else if (shape_type == 3) {
		float rect1 = max(d.x - shape_size, d.y - (shape_size * 0.3));
		float rect2 = max(d.x - (shape_size * 0.3), d.y - shape_size);
		dist = min(rect1, rect2);
	} else {
		dist = max(d.x, dot(d, normalize(vec2(1.0, 1.732)))) - shape_size;
	}
	
	float base_blur_factor = smoothstep(0.0, shape_smoothness, dist);
	float final_blur_factor = base_blur_factor;
	
	if (use_player_uv) {
		vec2 player_uv_adjusted = SCREEN_UV - player_uv;
		player_uv_adjusted.x *= aspect_ratio;
		
		float player_dist = length(player_uv_adjusted) - player_mask_radius;
		float player_factor = smoothstep(0.0, player_mask_smoothness, player_dist);
		
		final_blur_factor = min(base_blur_factor, player_factor);
	}
	
	COLOR = textureLod(screen_texture, SCREEN_UV, final_blur_factor * blur_amount);
}