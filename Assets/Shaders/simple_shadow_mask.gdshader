shader_type canvas_item;

uniform sampler2D shadow_texture : hint_default_transparent;
uniform sampler2D mask_texture   : hint_default_transparent;

uniform vec4 overlay_color : source_color = vec4(0.0, 0.0, 0.0, 0.5);
uniform vec4 debug_color : source_color = vec4(1.0, 0.0, 0.0, 0.5);
uniform bool debug_enabled = false;

// --- CONFIGURATION ---
uniform float distortion_strength : hint_range(0.0, 0.1) = 0.02;
uniform float sun_displacement_strength : hint_range(0.0, 0.1) = 0.02;
uniform vec2 shadow_direction = vec2(0.0, -1.0);

uniform float overlap_threshold : hint_range(0.0, 1.0) = 0.15; 

const float border_width = 1.5;


void fragment() {
	vec4 base_shadow = texture(shadow_texture, UV);
	vec4 base_mask   = texture(mask_texture, UV);
	
	if (base_shadow.a < 0.01 && base_mask.a < 0.01) {
		discard;
	}

	float mask_alpha = base_mask.a;
	float shadow_y   = base_shadow.r;
	float mask_y     = base_mask.r;

	vec2 final_uv = UV;

	// ------------------------------------------------
	// 1. DYNAMIC DISTORTION
	// ------------------------------------------------
	if (mask_alpha > 0.09) {
		vec2 ps = vec2(1.0) / vec2(textureSize(mask_texture, 0));

		float a_up    = texture(mask_texture, UV + vec2(0.0, -ps.y * 2.0)).a;
		float a_down  = texture(mask_texture, UV + vec2(0.0,  ps.y * 2.0)).a;
		float a_left  = texture(mask_texture, UV + vec2(-ps.x * 2.0, 0.0)).a;
		float a_right = texture(mask_texture, UV + vec2( ps.x * 2.0, 0.0)).a;

		vec2 slope = vec2(a_left - a_right, a_up - a_down);
		vec2 refraction_offset = slope * distortion_strength;
		float incidence = dot(normalize(slope + vec2(0.001)), shadow_direction); 
		vec2 sun_offset = shadow_direction * (mask_alpha * sun_displacement_strength) * (1.0 + incidence);

		final_uv += refraction_offset + sun_offset;
	}

	// ------------------------------------------------
	// 2. RESAMPLE
	// ------------------------------------------------
	vec4 distorted_shadow = texture(shadow_texture, final_uv);
	
	if (distorted_shadow.a < 0.01) {
		if (!debug_enabled) discard;
		else COLOR = vec4(0.0, 0.0, 1.0, 0.5);
	}
	else {

		bool should_discard = false;

		// ------------------------------------------------
		// 3. DEPTH LOGIC + OVERLAP
		// ------------------------------------------------
		if (mask_alpha > 0.09) {
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
					
					if (distorted_shadow.a < overlap_threshold) {
						should_discard = true;
					}
				}
			}
		}

		if (should_discard) {
			if (!debug_enabled) discard;
			else COLOR = debug_color;
		}
		else {
			COLOR = overlay_color;
		}
	}
}