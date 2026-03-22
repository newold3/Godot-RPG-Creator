shader_type canvas_item;

//* Texture containing the rendered shadows */
uniform sampler2D shadow_texture : hint_default_transparent;
//* Texture containing the rendered masks */
uniform sampler2D mask_texture   : hint_default_transparent;

//* Final color applied to the shadows */
uniform vec4 overlay_color : source_color = vec4(0.0, 0.0, 0.0, 0.5);
//* Color used to represent the mask area in debug mode */
uniform vec4 debug_mask_color : source_color = vec4(1.0, 0.0, 0.0, 0.5);
//* Color used to represent the shadow area in debug mode */
uniform vec4 debug_shadow_color : source_color = vec4(0.0, 0.0, 1.0, 0.5);
//* Toggles debug visualization on and off */
uniform bool debug_enabled = false;

//* Direction vector for shadow casting and distortion */
uniform vec2 shadow_direction = vec2(0.0, -1.0);
//* Alpha threshold to determine when shadows overlap masks */
uniform float overlap_threshold : hint_range(0.0, 1.0) = 0.15; 
//* Strength of the UV distortion caused by the mask */
uniform float mask_distort_strength : hint_range(0.0, 1.0) = 0.1;

const float border_width = 1.5;


// Processes the fragment to apply shadows, depth masking, and debug colors
void fragment() {
	vec4 base_mask = texture(mask_texture, UV);
	float mask_alpha = base_mask.a;
	float mask_y = base_mask.r;
	vec2 final_uv = UV;
	if (mask_alpha > 0.01) {
		vec2 distortion = shadow_direction * (mask_y * mask_distort_strength);
		final_uv += distortion;
	}
	vec4 base_shadow = texture(shadow_texture, final_uv);
	if (base_shadow.a < 0.01 && mask_alpha < 0.01) {
		discard;
	}
	float shadow_y = base_shadow.r;
	bool should_discard = false;
	if (base_shadow.a >= 0.01) {
		if (mask_alpha > 0.2) {
			float depth_margin = 0.001;
			bool caster_is_in_front = shadow_y > (mask_y + depth_margin);
			if (!caster_is_in_front) {
				vec2 ps = vec2(1.0) / vec2(textureSize(mask_texture, 0));
				float a_up    = texture(mask_texture, UV + vec2(0.0, -ps.y * border_width)).a;
				float a_down  = texture(mask_texture, UV + vec2(0.0,  ps.y * border_width)).a;
				float a_left  = texture(mask_texture, UV + vec2(-ps.x * border_width, 0.0)).a;
				float a_right = texture(mask_texture, UV + vec2( ps.x * border_width, 0.0)).a;
				bool is_edge = a_up < 0.02 || a_down < 0.02 || a_left < 0.02 || a_right < 0.02;
				if (!is_edge) {
					if (base_shadow.a < overlap_threshold) {
						should_discard = true;
					}
				}
			}
		}
	} else {
		if (!debug_enabled) {
			discard;
		}
	}
	if (should_discard && !debug_enabled) {
		discard;
	}
	if (debug_enabled) {
		vec4 out_color = vec4(0.0);
		if (mask_alpha > 0.01) {
			out_color = debug_mask_color;
			out_color.a *= mask_alpha;
		}
		if (base_shadow.a > 0.01) {
			vec4 s_color = debug_shadow_color;
			s_color.a *= base_shadow.a;
			if (out_color.a > 0.01) {
				out_color = mix(out_color, s_color, 0.5);
			} else {
				out_color = s_color;
			}
		}
		COLOR = out_color;
	} else {
		COLOR = overlay_color;
	}
}