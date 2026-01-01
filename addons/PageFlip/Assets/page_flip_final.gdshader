shader_type canvas_item;

uniform sampler2D front_texture : source_color, filter_linear_mipmap;
uniform sampler2D back_texture : source_color, filter_linear_mipmap;

// --- DYNAMIC SHADOW ---
// Pass a GradientTexture1D here (From Black to Transparent)
uniform sampler2D spine_shadow_gradient : source_color, filter_linear, repeat_disable;

// This value will be animated from AnimationPlayer (0.0 = Closed/Flat, 1.0 = Max Curve)
uniform float shadow_intensity : hint_range(0.0, 1.0) = 0.0;

// How much the shadow occupies at maximum (e.g. 0.3 = 30% of the page)
uniform float max_shadow_spread : hint_range(0.0, 1.0) = 0.35;

uniform bool debug_mode = false;

void fragment() {
	// 1. FACE DETECTION
	vec2 uv_dx = dFdx(UV);
	vec2 uv_dy = dFdy(UV);
	float face_dir = uv_dx.x * uv_dy.y - uv_dx.y * uv_dy.x;
	bool is_front = face_dir > 0.0;

	// 2. BASE TEXTURE
	vec4 base_color;
	if (is_front) {
		base_color = texture(front_texture, UV);
		if (debug_mode) base_color = vec4(0.0, 1.0, 0.0, 0.5);
	} else {
		base_color = texture(back_texture, vec2(1.0 - UV.x, UV.y));
		if (debug_mode) base_color = vec4(1.0, 0.0, 0.0, 0.5);
	}

	// 3. DYNAMIC SHADOW CALCULATION
	// Prevent division by zero with a small epsilon
	float current_spread = max_shadow_spread * (shadow_intensity + 0.001);

	// Map UV.x to gradient space.
	// If UV.x is 0 (spine), sample_x is 0.
	// If UV.x reaches 'current_spread', sample_x will be 1.
	float sample_x = UV.x / current_spread;

	// Read the gradient texture.
	// Assume the gradient is vertical or horizontal, read at (x, 0)
	float shadow_alpha = texture(spine_shadow_gradient, vec2(sample_x, 0.0)).a;

	// If we exceed the width, cut the shadow
	if (sample_x > 1.0) {
		shadow_alpha = 0.0;
	}

	// Also modulate global opacity with intensity to smooth entry/exit
	shadow_alpha *= shadow_intensity;

	// 4. APPLY SHADOW (MULTIPLY)
	// Assume the shadow is black. If you want a colored shadow, use mix() with a color.
	vec3 final_rgb = mix(base_color.rgb, vec3(0.0, 0.0, 0.0), shadow_alpha);

	COLOR = vec4(final_rgb, base_color.a);
}